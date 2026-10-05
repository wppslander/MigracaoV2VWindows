# Manual de Migração V2V (VMware para Proxmox) - v3

**Status:** Aprovado e Otimizado para Rede Ponto a Ponto (2.5 Gbps) e Integração Nativa de Storage.

---

## 🚨 Pontos Críticos de Atenção (Safety Checks) ANTES de Iniciar
* **Consolidação de Snapshots:** A VM de origem **DEVE** ter os snapshots consolidados ("Delete All" no ESXi) antes do shutdown.
* **Desativar BitLocker:** Se o Windows Server tiver BitLocker ativado no drive C:, ele **precisa ser suspenso ou desativado** antes do shutdown para evitar bloqueio pelo vTPM/Controladora.

---

## Fase 1: Infraestrutura e Rede Ponto a Ponto (Agora)
O objetivo aqui é isolar o tráfego de armazenamento da rede corporativa e saturar o link de 2.5 Gbps.

* **Conexão Física:** Conecte o cabo de rede diretamente entre a placa de 2.5 Gbps do host ESXi e a do Proxmox.
* **Configuração de IP no ESXi:**
  * Crie um novo vSwitch apontando para essa interface física (ou adicione um VMkernel port se já houver vSwitch).
  * Atribua o IP estático: `10.99.99.1`, Máscara: `255.255.255.252 (/30)`. Sem gateway.
* **Configuração de IP no Proxmox:**
  * Edite o `/etc/network/interfaces` ou use a GUI para configurar a interface correspondente.
  * Atribua o IP estático: `10.99.99.2`, Máscara: `255.255.255.252 (/30)`. Sem gateway.
  * Aplique a configuração (`ifreload -a` no shell do Proxmox).
* **Teste de Conectividade:**
  * Do shell do Proxmox, dispare: `ping 10.99.99.1`. Tem que responder.
  * Verifique se as portas 443 e 902 estão abertas no ESXi: `nc -zv 10.99.99.1 443` e `nc -zv 10.99.99.1 902`. A 902 é crítica para a transferência dos blocos do disco.

## Fase 2: Integração do Storage no Proxmox (Agora)
Faça o Proxmox enxergar o ESXi como um repositório de dados utilizando o link isolado.

* No painel do Proxmox, vá em Datacenter -> Storage -> Add -> ESXi.
* **ID:** `ESXI_MIGRATION` (ou o que preferir).
* **Server:** `10.99.99.1` (Crucial usar o IP da rede /30 e não o IP de gerência normal).
* **Username/Password:** Credenciais do root do ESXi. Garanta que o SSH e a API estejam habilitados.
* **Skip Certificate Verification:** Marque a caixa se não houver CA válida.
* Clique em Add. O storage do VMware deve aparecer na árvore à esquerda do Proxmox.

## Fase 3: Preparação e Download de Drivers (Agora)
Deixe o terreno pronto para quando a VM chegar.

* No Proxmox, baixe a ISO mais recente dos drivers VirtIO para Windows.
* No shell do Proxmox: `wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso -O /var/lib/vz/template/iso/virtio-win.iso` (Ajuste o caminho se seu storage de ISOs for diferente).
## Fase 4: O Corte e a Transferência (Final da Tarde)
Início do downtime.

* **Shutdown Limpo:** Acesse the Windows Server e desligue o sistema operacional normalmente (`shutdown /s /t 0`). **Nunca migre com a VM ligada ou suspensa.**
* No Proxmox, selecione o seu nó local e vá na aba do storage `ESXI_MIGRATION` criado na Fase 2.
* Clique na aba Import.
* Selecione a VM do Windows na lista.
* **Configurações de UEFI (Se a VM de origem for UEFI):**
  * Após clicar em Import (ou durante a configuração na aba advanced), certifique-se de que a **BIOS** está em **OVMF (UEFI)** e a **Machine** em **q35**.
  * Adicione um **EFI Disk** caso o Proxmox não o crie automaticamente.
* Configure os parâmetros de importação:
  * **Target Storage:** Selecione o seu pool de armazenamento principal no Proxmox (ex: `local-zfs` ou `local-lvm`).
  * **Format:** `Raw` (se ZFS/LVM-Thin) ou `qcow2` (se storage em diretório/ext4).
  * **Disks:** Mantenha os discos selecionados.
  * **Advanced/Network:** Desconecte as interfaces de rede por enquanto (para evitar conflitos de IP quando a VM ligar no novo ambiente).
* Clique em Import. O processo vai iniciar. Acompanhe a barra de progresso. Em 2.5 Gbps constante, 1.5 TB levará entre 1h30 e 2h.

## Fase 5: A Cirurgia do VirtIO (Pós-Transferência)
A importação terminou. Se você ligar a VM agora, dará Blue Screen of Death (0x7B) ou erro de boot se for UEFI mal configurado. Siga os passos exatos:

* Selecione a VM recém-importada no Proxmox e vá em Hardware.
* **Verificação UEFI:** Se a VM for UEFI, valide:
  * BIOS: **OVMF (UEFI)**.
  * **EFI Disk** presente.
  * Machine: **q35**.
* **Isolamento de Boot Seguro:**
... (rest of the steps) ...
  * Dê um duplo clique no disco C: (o menor, do SO) e anote qual é (ex: `scsi0`).
  * Detach (Desanexar) esse disco. Ele vai virar um "Unused Disk".
  * Dê um duplo clique no "Unused Disk" e adicione-o novamente usando o barramento **SATA** ou **IDE**.
  * *Nota:* Deixe os discos de dados em paz por enquanto.
* **Injeção do Driver ("Disco Isca"):**
  * Vá em Add -> Hard Disk. Crie um disco inútil de 1 GB no barramento **SCSI** (garanta que a controladora em Options -> SCSI Controller seja VirtIO SCSI single).
  * Vá em Add -> CD/DVD Drive. Monte a ISO do `virtio-win.iso` que você baixou na Fase 3.
* **Primeiro Boot:**
  * Ligue a VM. O Windows Server deve iniciar usando o barramento SATA/IDE, sem dar tela azul.
  * Faça login. Vá no Gerenciador de Dispositivos (Device Manager).
  * Você verá dispositivos desconhecidos (Controladora SCSI).
  * Clique com o botão direito -> Atualizar Driver -> Procurar no computador -> Aponte para a unidade de CD (ISO do VirtIO) na pasta `vioscsi\2k16\amd64` (ou versão do seu OS). Instale o driver. O disco inútil de 1 GB agora será reconhecido.
  * *Opcional mas recomendado:* Instale o QEMU Guest Agent e o driver de rede NetKVM pelo executável principal na raiz do CD (`virtio-win-gt-x64.exe`).
* **Reversão para Alta Performance:**
  * Desligue o Windows normalmente.
  * No Proxmox (aba Hardware), selecione o disco inútil de 1 GB -> Detach -> Remove.
  * Selecione o disco C: (que está como SATA/IDE) -> Detach.
  * Dê um duplo clique no agora "Unused Disk" referente ao C: e adicione-o de volta ao barramento **SCSI**.
  * *Certifique-se de marcar a opção Discard nos discos se o storage físico for SSD/NVMe.*

## Fase 6: Validação Final
* Ligue a VM. O Windows agora dará boot pelo C: usando a controladora VirtIO SCSI de altíssima performance.
* Verifique se os discos de dados estão acessíveis. O Windows pode pedir para reativar as partições no Gerenciamento de Disco (Online), faça isso se necessário.
* **Adicionar Rede:** Adicione uma placa de rede na VM (modelo VirtIO paravirtualized), conecte à bridge correta (ex: `vmbr0`).
* **Limpeza da "Rede Fantasma":** Antes de colocar o IP antigo, o Windows vai alertar que o IP já está em uso pelo adaptador antigo invisível.
  * Abra o CMD como Administrador e rode:
    ```cmd
    set devmgr_show_nonpresent_devices=1
    start devmgmt.msc
    ```
  * No Gerenciador de Dispositivos, vá em **Exibir > "Mostrar dispositivos ocultos"**.
  * Expanda "Adaptadores de Rede" e **desinstale** o adaptador antigo do VMware (VMXNET3/E1000).
* **Configuração de IP:** Configure o IP de produção no Windows na nova placa VirtIO.
* **QEMU Guest Agent:** Acesse Options da VM no Proxmox e ative QEMU Guest Agent (marque a caixa). Verifique em "Summary" se os IPs da VM aparecem, confirmando que o agente está se comunicando com o host.

**Tudo operante. O ESXi pode ser desligado.**