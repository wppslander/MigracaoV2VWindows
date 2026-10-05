# Manual de Migração V2V: VMware ➔ Proxmox (Guia Operacional)

Este guia consolida o procedimento para migração segura de Windows Server, focado na integridade dos dados e performance final.

---

## 🚨 CHECKLIST CRÍTICO DE SEGURANÇA
**Itens Obrigatórios:**
- [ ] **Snapshots:** "Delete All" no VMware. (Risco de corrupção se ignorado).
- [ ] **BitLocker:** Desativado/Decriptado.
- [ ] **Espaço em Disco:** Verifique se o Proxmox tem espaço livre suficiente.
- [ ] **VM Desligada:** A origem deve estar OFF.

---

## 📂 FASE 1: Transporte dos Arquivos
Transfira os arquivos `.vmdk` e `.ovf` para o diretório `/root/migracao_temp/` no servidor Proxmox.

**Método A: Terminal (Rsync/SCP)**
*Recomendado para grandes volumes ou conexões instáveis.*
```bash
# Exemplo genérico (ajuste os caminhos):
rsync -avhP /origem/arquivos/*.vmdk root@<IP_PROXMOX>:/root/migracao_temp/
```

**Método B: Interface Gráfica (WinSCP/FileZilla)**
1.  Conecte ao Proxmox via SFTP (Porta 22).
2.  Navegue até `/root/migracao_temp/`.
3.  Arraste os arquivos `.vmdk`.

---

## 🏗️ FASE 2: Criar a "Casca" da VM (Proxmox GUI)
1.  **Create VM:** Defina ID (ex: `200`) e Nome.
2.  **OS:** Windows (Versão correta).
3.  **System:** 
    *   ✅ **Qemu Agent**.
    *   **BIOS:** `OVMF (UEFI)` (Obrigatório para Windows UEFI).
    *   **EFI Disk:** Adicione ao criar ou logo após.
    *   **Machine:** `q35`.
4.  **Disks:** ⚠️ **DELETE** o disco padrão (`scsi0`). A VM deve ficar **sem discos**.
5.  **CPU:** Tipo: **Host** (Para máxima performance).
6.  **Network:** Modelo **Intel E1000** (Compatibilidade).

---

## 💉 FASE 3: Importação Automática (Terminal do Proxmox)

Utilize o script de automação fornecido `import_vmdk.sh` para facilitar a importação contornando as etapas manuais demoradas.

### Como usar o Script de Automação:
1. Certifique-se de que o arquivo `import_vmdk.sh` está no servidor (ex: `/root/`).
2. Dê permissão de execução:
```bash
chmod +x import_vmdk.sh
```
3. Execute o script e siga as instruções na tela:
```bash
./import_vmdk.sh
```
O script perguntará o ID da VM de destino e o caminho do arquivo destino, procedendo com a importação automaticamente para a localidade escolhida.

> *Nota: Caso a VM tenha mais de um disco, execute o script novamente para o(s) disco(s) adicional(is).*

---

## 🔧 FASE 4: Boot Estratégico (GUI)
1.  **UEFI Check:** Garanta que o **EFI Disk** está presente. Caso contrário, adicione em `Add > EFI Disk`.
2.  **Attach Discos:** Na aba Hardware, adicione os discos *Unused* como **SATA**.
    > *Nota: SATA é obrigatório no primeiro boot.*
3.  **Disco Isca:** Adicione um disco de **1GB** como **SCSI** (VirtIO SCSI).
4.  **ISO:** Insira `virtio-win.iso`.
5.  **Boot Order:** **SATA0** em primeiro.

---

## 🚀 FASE 5: Instalação e Virada de Chave
1.  **Instalar Drivers:**
    *   Ligue a VM.
    *   Instale o driver do controlador de armazenamento (pasta `vioscsi` ou via instalador MSI).
    *   Verifique no Gerenciador de Dispositivos se o **Red Hat VirtIO SCSI** aparece.
    *   Desligue a VM.

2.  **Virada de Chave (Performance):**
    *   Remova o disco isca de 1GB.
    *   Detach SATA (C:) -> Attach **SCSI** (Marque `SSD Emulation` e `Discard`).
    *   Detach SATA (Dados) -> Attach **SCSI**.
    *   Rede: Mude de Intel E1000 para **VirtIO**.

3.  **Finalização Automação (Rede Fantasma):**
    *   Ligue a VM.
    *   Transfira e execute o script **`post_migration_cleanup.ps1`** dentro do Windows como *Administrador*.
    *   O script abrirá o Gerenciador de Dispositivos.
    *   Clique em `Exibir > Mostrar dispositivos ocultos` e desinstale os adaptadores de rede antigos (E1000/VMXNET3).
    *   Configure IP Fixo na nova interface (VirtIO Red Hat).
    *   Remova pelo Painel de Controle o VMware Tools.

---
**FIM**
