# 🚀 Guia de Execução: Migração V2V (VM: rdp)

Este documento contém os comandos e procedimentos validados especificamente para a VM **rdp**.

## 🌐 Detalhes do Ambiente
* **VM Alvo:** `rdp` (VMID VMware: 3)
* **Proxmox PVE:** `10.1.50.212`
* **VMware ESXi:** `10.1.50.252`
* **MAC Address Original:** `00:0C:29:05:98:75`

---

## 🔍 FASE 0: Verificações Pré-Migração (VM LIGADA)
* **Snapshots:** Verificado (OK - Nenhum encontrado).
* **Conectividade:** Verificado (OK).
* **MAC Address:** Salvo (`00:0C:29:05:98:75`).

---

## 🏗️ FASE 1: Preparação do Ambiente
1. **Storage ESXi:** Já configurado no Proxmox como `ESXI_PRODUCAO`.
2. **Drivers VirtIO:** ISO localizada em `/var/lib/vz/template/iso/virtio-win.iso`.

---

## ✂️ FASE 2: O Corte (Janela de Manutenção)
1. **Desligamento Limpo:** No Windows Server da VM `rdp`, execute: `shutdown /s /t 0`
2. **Criação da VMID 104 no Proxmox:**
   * BIOS OVMF (UEFI), Q35, 4 cores, 12 GB RAM.
   * Placa de rede `net0` configurada com o MAC `00:0C:29:05:98:75`.

---

## 🔧 FASE 3: Boot Estratégico (A "Cirurgia" com Disco Isca)
1. **Ajuste de Discos:**
   * Vincular o disco principal como **SATA 0** (reconhecido nativamente no boot).
   * Criar disco temporário de 1 GB em **SCSI 1** (Disco Isca).
   * Montar ISO VirtIO no drive CD-ROM.
2. **Ordem de Boot:** Definir `sata0` como prioridade.

---

## 🚀 FASE 4: Instalação de Drivers (Via Executável) e Conversão para SCSI 0
1. **Ligar a VM:** O Windows inicia via SATA 0.
2. **Instalação dos Drivers:**
   * Executar **`D:\virtio-win-guest-tools.exe`** diretamente no Windows.
   * *Motivo Técnico:* O executável registra automaticamente a cadeia de certificados da Red Hat no Windows, evitando a falha de driver `Code 31`.
3. **Conversão para Alta Performance:**
   * Desligar a VM.
   * Removido disco de 1 GB (Isca) e desvinculado SATA 0.
   * Re-vinculado disco principal como **SCSI 0** (`ssd=1`).
   * Habilitado `QEMU Guest Agent` (`agent: 1`).
   * *Ajuste de Boot UEFI:* Se a VM cair no Shell UEFI ao trocar para SCSI 0, execute `fs0:\EFI\Microsoft\Boot\bootmgfw.efi` e ajuste a ordem padrão no menu Boot Maintenance Manager.

---

## 🌐 FASE 5: Limpeza de Rede e IP Fixo
1. **Remover Hardware Fantasma:**
   ```cmd
   set devmgr_show_nonpresent_devices=1
   start devmgmt.msc
   ```
   * Em **Exibir > Mostrar dispositivos ocultos**, desinstalar a placa de rede antiga VMware Intel 82574L.
2. **Configurar IP:** Fixar `10.1.50.14` na nova interface Red Hat VirtIO Ethernet Adapter (MAC: `00:0C:29:05:98:75`).
3. **Remover VMware Tools:** Desinstalar pelo Painel de Controle.
