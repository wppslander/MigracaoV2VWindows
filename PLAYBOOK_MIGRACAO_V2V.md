# 📋 Playbook Operacional de Migração V2V: VMware ESXi ➔ Proxmox VE

> **Guia de Execução Rápida, Passo a Passo e 100% Replicável**  
> **Target:** Windows Server (UEFI / OVMF / GPT / ZFS / VirtIO SCSI)  
> **Caso de Referência:** VM `rdp` (`10.1.50.14`) | ESXi `10.1.50.252` ➔ Proxmox `10.1.50.212` (`moov`)

---

## 📑 Índice dos Passos

1. [Fase 0: Pré-Requisitos na Origem (Product Key, Marketing, SSH Keys & Shutdown)](#-passo-0-pré-requisitos-e-salvaguardas-na-origem)
2. [Fase 1: Provisionamento da VM no Proxmox VE](#-passo-1-provisionamento-da-vm-no-proxmox-ve)
3. [Fase 2: Streaming de Dados em Bloco via SSH (106 MB/s)](#-passo-2-streaming-de-dados-em-bloco-via-ssh)
4. [Fase 3: Primeiro Boot Seguro sob Barramento SATA0](#-passo-3-primeiro-boot-seguro-sob-barramento-sata0)
5. [Fase 4: Injeção dos Drivers VirtIO e QEMU Guest Agent](#-passo-4-injeção-dos-drivers-virtio-e-qemu-guest-agent)
6. [Fase 5: Preparação do Registro para VirtIO SCSI (Boot Start)](#-passo-5-preparação-do-registro-para-virtio-scsi-boot-start)
7. [Fase 6: Conversão Oficial (SATA0 ➔ SCSI0) & Criação do Disco Marketing (800GB)](#-passo-6-conversão-oficial-de-barramento-sata0--scsi0)
8. [Fase 7: Pós-Boot SCSI, Formatação do Marketing, Carga dos Dados e Rede](#-passo-7-pós-boot-scsi-limpeza-de-rede-e-ativação-de-licença)
9. [Fase 8: Homologação e Checklist Final](#-passo-8-homologação-e-checklist-final)
10. [Plano de Contingência e Rollback Imediato](#-plano-de-contingência-e-rollback-imediato)
11. [Matriz de Resolução de Problemas (Troubleshooting)](#-matriz-de-resolução-de-problemas-troubleshooting)

---

## 🛑 Passo 0: Pré-Requisitos e Salvaguardas na Origem

Execute estes passos com a VM ainda rodando ou antes de iniciar o corte:

### 0.1 Extrair a Chave de Licença do Windows (Product Key)
No Windows da VM de origem (PowerShell como Administrador):
```powershell
$map="BCDFGHJKMPQRTVWXY2346789"; $value = (get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").digitalproductid[52..66]; $productKey = ""; for ($i = 24; $i -ge 0; $i--) { $r = 0; for ($j = 14; $j -ge 0; $j--) { $r = ($r * 256) -bxor $value[$j]; $value[$j] = [math]::Floor([double]($r / 24)); $r = $r % 24 }; $productKey = $map[$r] + $productKey; if (($i % 5 -eq 0) -and ($i -ne 0)) { $productKey = "-" + $productKey } }; Write-Host "Chave do Windows: $productKey"
```
*Anote a chave retornada para reativação posterior.*

### 0.2 Sincronização Prévia dos Dados de Marketing
Com o servidor de produção ainda ligado na origem (`10.1.50.14`), sincronize a pasta do Setor Marketing para o Proxmox (`/Pool2/marketing_backup`).

Execute no Proxmox VE (`10.1.50.212`):
```bash
/root/sync_marketing.sh
```
*Este script monta automaticamente `//10.1.50.14/SETOR MARKETING` em `/mnt/win_marketing` usando as credenciais de `/root/.env`, sincroniza incrementalmente via `rsync` com log em `/var/log/sync_marketing.log` e desmonta de forma limpa.*

### 0.3 Validar BitLocker e Snapshots
- **BitLocker:** No CMD Admin, execute `manage-bde -status`. Se estiver ativo, desative antes da migração (`manage-bde -off C:`).
- **Snapshots:** No vSphere/ESXi Client, verifique se há snapshots ativos na VM. **Consolide e remova todos** ("Delete All").
- **Anotar MAC Address e IP:**
  - MAC Address oficial da VM (ex: `00:0C:29:05:98:75`)
  - Configurações IP (ex: `10.1.50.14/24`, Gateway `10.1.50.1`, DNS `10.1.50.1`)

### 0.4 Configurar Chaves SSH sem Senha (Proxmox ➔ ESXi)
O streaming de disco de alta velocidade exige comunicação direta SSH sem interrupção de senha:
1. No Proxmox VE (`10.1.50.212`), gere a chave se ainda não existir:
   ```bash
   ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
   ```
2. Instale a chave pública no VMware ESXi 7.0 (`10.1.50.252`):
   ```bash
   cat ~/.ssh/id_ed25519.pub | ssh root@10.1.50.252 "cat >> /etc/ssh/keys-root/authorized_keys"
   ```
3. Valide o acesso sem senha:
   ```bash
   ssh root@10.1.50.252 "esxcli system version get"
   ```

### 0.5 Desligamento Limpo da VM de Origem
Após finalizar a sincronização do marketing e a cópia dos dados:
No Windows da origem:
```cmd
shutdown /s /t 0
```

---

## 🛠️ Passo 1: Provisionamento da VM no Proxmox VE

No terminal SSH do Proxmox VE (`10.1.50.212`):

```bash
# 1.1 Criar a casca da VM (Ajustar VMID, memória, cores e MAC conforme o servidor)
qm create 104 --name rdp \
  --memory 12288 --cores 4 --cpu host \
  --machine pc-q35-8.1 --bios ovmf \
  --ostype win10 \
  --net0 virtio=00:0C:29:05:98:75,bridge=vmbr0

# 1.2 Criar o disco EFI limpo no Storage ZFS (Pool2)
qm set 104 --efidisk0 Pool2:1,format=raw,efitype=4m,pre-enrolled-keys=0

# 1.3 Montar o VirtIO ISO no drive de CD-ROM
qm set 104 --ide2 local:iso/virtio-win.iso,media=cdrom
```

---

## ⚡ Passo 2: Streaming de Dados em Bloco via SSH

Garante taxa sustentada de 106 MB/s sem sofrer gargalos ou *timeouts* da API Web/FUSE.

No Proxmox VE:
```bash
nohup ssh root@10.1.50.252 "cat '/vmfs/volumes/datastore1/rdp/rdp-flat.vmdk'" | \
  dd of=/dev/zvol/Pool2/vm-104-disk-1 status=progress bs=1M > /tmp/migration_rdp.log 2>&1 &
```

Para acompanhar em tempo real:
```bash
tail -f /tmp/migration_rdp.log
```
> ⏱️ *Tempo estimado para 700-750 GB em link 1 Gbps: ~1h58m.*

---

## 🔌 Passo 3: Primeiro Boot Seguro sob Barramento SATA0

> **Regra de Ouro:** O primeiro boot DEVE ser em `sata0`. Como o Windows nativamente suporta controladoras AHCI/SATA, o boot é 100% garantido sem risco de Tela Azul (`INACCESSIBLE_BOOT_DEVICE`).

No Proxmox VE:
```bash
# Conecta o volume ZFS como sata0 e define como boot
qm set 104 --sata0 Pool2:vm-104-disk-1
qm set 104 --boot order=sata0

# Inicia a máquina virtual
qm start 104
```

Acesse o console no Proxmox (**VM 104 ➔ Console / noVNC**) e faça login no Windows.

---

## 📦 Passo 4: Injeção dos Drivers VirtIO e QEMU Guest Agent

No Windows da VM 104:

1. Abra o **Windows Explorer** e acesse a unidade de CD-ROM (onde está montada a ISO VirtIO, ex: `D:`).
2. **Execute o instalador oficial completo:**
   ```text
   D:\virtio-win-guest-tools.exe
   ```
3. Avance o instalador com as opções padrão.
   > **Por que este executável?** Ele instala e confia na cadeia de certificados da Red Hat no Windows Server. Se instalar o `.inf` avulso, o Windows Server bloqueia o driver com **Code 31**. O instalador também já configura o **QEMU Guest Agent** e a placa de rede VirtIO.

---

## ⚙️ Passo 5: Preparação do Registro para VirtIO SCSI (Boot Start)

Para que o Windows possa dar boot diretamente pelo barramento VirtIO SCSI sem dar tela azul, o serviço de driver precisa ser configurado com início em tempo de boot (`Start = 0`).

No Windows, abra o **CMD como Administrador** e execute:

```cmd
sc config vioscsi start= boot
sc config viostor start= boot
```
*(Ambos devem retornar: `[SC] ChangeServiceConfig SUCCESS`)*

Em seguida, desligue a VM de forma limpa:
```cmd
shutdown /s /t 0
```

---

## 🔄 Passo 6: Conversão Oficial de Barramento (SATA0 ➔ SCSI0)

Com a VM desligada, faça a alteração no Proxmox VE.

### Opção A: Via Terminal Proxmox CLI (Recomendado - 3 segundos)
Execute no Shell do Proxmox:
```bash
# 1. Desconecta sata0 e reconecta como scsi0 com SSD Emulation
qm set 104 --delete sata0 --scsi0 Pool2:vm-104-disk-1,ssd=1

# 2. Cria e anexa o novo disco de 800 GiB para o Marketing como scsi1 (SSD Emulation)
# Se o volume vm-104-disk-3 já existir: qm set 104 --scsi1 Pool2:vm-104-disk-3,ssd=1
# Para criar novo de 800G:
qm set 104 --scsi1 Pool2:800,ssd=1

# 3. Atualiza a ordem de boot garantindo o scsi0 como primário
qm set 104 --boot order=scsi0

# 4. Desmonta a ISO VirtIO do CD-ROM e garante o Guest Agent ativo
qm set 104 --ide2 none
qm set 104 --agent enabled=1

# 5. Inicia a VM
qm start 104
```

### Opção B: Via Interface Web do Proxmox (GUI)
1. Acesse **VM 104 ➔ Hardware**.
2. Clique em **Hard Disk (sata0)** e clique no botão **Detach** (Desconectar) no topo.
   * *O disco virará **Unused Disk 0**.*
3. Dê **duplo clique** no **Unused Disk 0**:
   * Altere **Bus/Device** para **SCSI** (Index `0`).
   * Marque a caixa **SSD emulation**.
   * Clique em **Add**.
4. Acesse **VM 104 ➔ Options ➔ Boot Order**:
   * Clique em **Edit**, marque **scsi0**, mova-o para o topo da lista e desmarque o antigo `sata0`. Clique em **OK**.
5. Clique em **Start** para ligar a VM.

---

## 🌐 Passo 7: Pós-Boot SCSI, Limpeza de Rede e Ativação de Licença

Faça login no Windows (agora rodando 100% sobre controladora VirtIO SCSI de alta performance):

### 7.1 Confirmar o Controlador SCSI
- Abra o Gerenciador de Dispositivos (`devmgmt.msc`).
- Em **Controladores de Armazenamento**, confirme a presença de **Red Hat VirtIO SCSI controller**.

### 7.2 Remover Placas de Rede Antigas Ocultas (Fantasmas)
No CMD como Administrador:
```cmd
set devmgr_show_nonpresent_devices=1
start devmgmt.msc
```
- No Gerenciador de Dispositivos: menu **Exibir** ➔ **Mostrar dispositivos ocultos**.
- Em **Adaptadores de rede**, localize a placa antiga (ex: **Intel(R) 82574L Gigabit Network Connection** esmaecida), clique com o botão direito e selecione **Desinstalar dispositivo**.

### 7.3 Configurar o IP Fixo na Placa VirtIO
- Configure o IP estático na nova placa **Red Hat VirtIO Ethernet Adapter**:
  - IP: `10.1.50.14`
  - Máscara: `255.255.255.0`
  - Gateway: `10.1.50.1`
  - DNS: `10.1.50.1` (ou DNS corporativo)

### 7.4 Reativar a Licença do Windows Server
No CMD como Administrador:
```cmd
slmgr.vbs /ipk XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
slmgr.vbs /ato
```
*Aguarde a mensagem de confirmação: "Produto ativado com êxito".*

### 7.5 Desinstalar VMware Tools
- Abra o **Painel de Controle** ➔ **Programas e Recursos**.
- Selecione **VMware Tools** e desinstale. Reinicie se solicitado.

### 7.6 Inicializar e Formatar a Nova Unidade do Marketing (Windows)
1. No Windows Server, abra o **Gerenciamento de Disco** (`diskmgmt.msc`).
2. O novo disco de 800 GiB aparecerá como **Disco 1 (Não Inicializado)**.
3. Clique com o botão direito nele ➔ **Inicializar Disco** ➔ Selecione **GPT**.
4. Clique com o botão direito no espaço Não Alocado ➔ **Novo Volume Simples**:
   - Sistema de arquivos: **NTFS**.
   - Tamanho da unidade de alocação: **Padrão (4096 bytes)**.
   - Letra da Unidade: Atribuir a letra desejada (ex: `E:` ou `D:`).
   - Rótulo do Volume: **Marketing**.
5. Compartilhe a pasta/unidade na rede como **`SETOR MARKETING`** com permissões para o grupo corporativo e usuário de serviço/backup.


### 7.7 Carga e Restauração dos Dados do Marketing (`/Pool2/marketing_backup` ➔ Windows)
Com a unidade formatada e compartilhada no Windows:

Você pode executar o script de restauração automatizado:
```bash
# Executar no Proxmox VE
/root/restore_marketing.sh
```
*(Script versionado no repositório como `restore_marketing.sh`).*

Ou executar manualmente os passos equivalentes:
```bash
# Criar ponto de montagem e conectar na nova unidade da VM
mkdir -p /mnt/win_marketing_dest
mount -t cifs "//10.1.50.14/SETOR MARKETING" /mnt/win_marketing_dest \
    -o credentials=/root/.env,iocharset=utf8,vers=3.0

# Copiar os arquivos restaurados do pool ZFS para a nova unidade da VM
rsync -rhtvP --no-o --no-g --stats /Pool2/marketing_backup/ /mnt/win_marketing_dest/

# Desmontar ao concluir
umount /mnt/win_marketing_dest
```

### 7.8 Salvaguarda de Rede & Homologação sem Conflito de IP
> ⚠️ **Atenção Crítica de Rede:**  
> Enquanto o servidor antigo estiver em produção no ESXi com o IP `10.1.50.14`, a VM 104 no Proxmox DEVE permanecer com o cabo de rede desconectado (`link_down=1` na interface `net0`) para evitar conflito de ARP/IP na rede física:
> ```bash
> # Para manter a rede desligada durante testes locais via console:
> qm set 104 --net0 virtio=00:0C:29:05:98:75,bridge=vmbr0,link_down=1
> ```
> * **Para testar RDP em Homologação:** Altere temporariamente o IP da VM 104 via console para um IP livre da rede (ex: `10.1.50.214/24`) e ative o link (`link_down=0`).
> * **No Go-Live Oficial:** Após desligar a VM antiga no ESXi (`shutdown /s /t 0`), suba o link oficial na VM 104:
> ```bash
> qm set 104 --net0 virtio=00:0C:29:05:98:75,bridge=vmbr0,link_down=0
> ```

---

## ✅ Passo 8: Homologação e Checklist Final `[100% VALIDADO]`

- [x] VM inicializa sem BSOD diretamente pelo disco `scsi0` (`ssd=1`).
- [x] IP `10.1.50.14` respondendo a pings e acessível via RDP (`mstsc`).
- [x] QEMU Guest Agent reportando IPs e uso de memória no painel do Proxmox.
- [x] Status do Windows: "O Windows está ativado" (`slmgr.vbs /dli`).
- [x] Teste de login de usuários, aplicações de produção e impressoras validados.
- [x] Unidade de dados do Marketing (800 GiB) montada e íntegra.


---

## 🛟 Plano de Contingência e Rollback Imediato

Se ocorrer qualquer imprevisto grave durante o processo:

1. **Rollback do barramento para SATA0 (se SCSI falhar):**
   ```bash
   qm set 104 --delete scsi0 --sata0 Pool2:vm-104-disk-1
   qm set 104 --boot order=sata0
   qm start 104
   ```
2. **Rollback total para o VMware ESXi:**
   - Desligar a VM 104 no Proxmox (`qm stop 104`).
   - Ligar novamente a VM `rdp` original no ESXi (`10.1.50.252`). Como o disco da origem permaneceu 100% intocado (apenas lido via `cat`), a VM original volta a produzir imediatamente.

---

## 🛡️ Matriz de Resolução de Problemas (Troubleshooting)

| Erro / Sintoma | Causa Raiz | Solução Testada & Validada |
| :--- | :--- | :--- |
| **Reativação de Licença Solicitada** | Mudança no identificador de hardware virtual (Q35/VirtIO). | Executar no CMD Admin: `slmgr.vbs /ipk <CHAVE>` e `slmgr.vbs /ato`. |
| **Timeout de I/O na API/Import do Proxmox** | Limite de tempo em arquivos VMDK >500 GB via FUSE/HTTP. | Streaming assíncrono direto via SSH: `ssh cat ... \| dd of=/dev/zvol/... bs=1M`. |
| **Driver VirtIO com Code 31** | Ausência dos certificados de assinatura Red Hat no Windows 2016. | Executar o instalador completo **`virtio-win-guest-tools.exe`** da raiz do CD. |
| **INACCESSIBLE_BOOT_DEVICE (BSOD)** | Driver `vioscsi` com `Start=3` (Demand) em vez de `0` (Boot). | Manter em `sata0` provisório, rodar `sc config vioscsi start= boot` e depois virar para `scsi0`. |
| **Loop no UEFI Interactive Shell v2.2** | NVRAM (`efidisk0`) reteve ponteiros antigos da topologia VMware. | Resetar o disco EFI (`qm set 104 --delete efidisk0 ...`) ou digitar `FS0:\EFI\Boot\bootx64.efi`. |
| **Conflito de IP e Hardware Fantasma** | Adaptador Intel esmaecido do VMware retendo o IP corporativo. | Habilitar `devmgr_show_nonpresent_devices=1`, desinstalar placa oculta e aplicar IP na VirtIO. |
