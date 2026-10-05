## 0. Acesso Inicial

1. **Servidor de Salto:** O acesso ao ambiente deve ser feito primeiramente através do servidor **moon**.
2. **Proxmox GUI:** Acesse via `10.1.50.212` após estar no ambiente.

---

## 1. O Corte (Início do Downtime)

1. **Preparação:** Desinstale o BitDefender no Windows.
2. **Coleta de Informações de Rede:** Anote o MAC Address original da interface VMware (`00:0C:29:05:98:75`).
3. **Desligamento:** Acesse a VM `rdp` e desligue pelo Windows:
   - `shutdown /s /t 0`
4. **Importação no Proxmox:**
   * Direct SSH block copy para `Pool2:vm-104-disk-1`.
   * **Target Network:** Configurar MAC Address fixo `00:0C:29:05:98:75`.

---

## 2. Configuração Proxmox (Boot e Drivers)

1. **Hardware da VM (Ajustes UEFI):**
   * **BIOS:** Altere de `Default (SeaBIOS)` para **OVMF (UEFI)**.
   * **Add > EFI Disk:** Adicione um disco EFI no storage **`Pool2`**. **Não marque** "Pre-Enroll Keys".
   * **Machine:** Altere para **q35**.
   * **SCSI Controller:** Garanta que esteja como **VirtIO SCSI**.
   * **Rede:** Mude o MAC Address para `00:0C:29:05:98:75`.
2. **Ajuste dos Discos:**
   * Selecione o disco principal -> Adicione como **SATA 0**.
   * **Add > Hard Disk** -> Crie um disco de **1GB** em **SCSI** (no storage `Pool2` - Disco Isca).
   * Garanta que a ISO `virtio-win.iso` esteja montada no CD-ROM (`ide2`).
3. **Opções:** Em **Boot Order**, coloque o **SATA 0** em 1º lugar.
4. **Ligar VM & Instalação Segura de Drivers:**
   * Ligue a VM (boot UEFI em SATA 0).
   * Abra o CD-ROM no Windows (`D:\`) e execute **`virtio-win-guest-tools.exe`**.
   * *Nota Importante:* O executável instala os drivers Red Hat com registro automático de certificados no Windows, prevenindo o erro `Code 31` (falha de assinatura/driver).

---

## 3. Validação, Rede e Limpeza

1. **Troca para SCSI 0:**
   * Desligue a VM.
   * Remova o disco de 1GB (Isca).
   * Remova SATA 0 -> Readicione como **SCSI 0** (Marque `SSD Emulation`).
   * Em **Options**, altere `QEMU Guest Agent` para **Enabled** e defina Boot Order para **SCSI 0**.
   * *Nota UEFI Boot:* Se a VM iniciar caindo no `UEFI Interactive Shell`, digite `fs0:\EFI\Microsoft\Boot\bootmgfw.efi` para subir o Windows e ajuste a ordem permanente no menu UEFI (`F2`/`ESC`).
2. **Limpeza de "Hardware Fantasma" (Manual via Terminal):**
   * Abra o **CMD como Administrador**:
     ```cmd
     set devmgr_show_nonpresent_devices=1
     start devmgmt.msc
     ```
   * Em **Exibir (View)** > **Mostrar dispositivos ocultos (Show hidden devices)**.
   * Em **Adaptadores de Rede**, desinstale o antigo **Intel(R) 82574L**.
3. **Configuração de IP Fixo (VirtIO):**
   * Placa **Red Hat VirtIO Ethernet Adapter** (MAC: `00:0C:29:05:98:75`):
   * **IP:** `10.1.50.14`
   * **Máscara:** `255.255.255.0`
   * **Gateway:** `10.1.50.1`
   * **DNS:** `10.1.50.1` / `1.1.1.1`
4. **Limpeza Final:** Ligue a VM e desinstale o **VMware Tools** pelo Painel de Controle.

---

## 4. Plano de Contingência (Rollback)

**Se a migração falhar ou a VM não der boot após 30 minutos de tentativa:**

1. **Desligue** a VM no Proxmox.
2. **Acesse o VMware** (`10.1.50.252`).
3. **Ligue a VM `rdp` original.**
