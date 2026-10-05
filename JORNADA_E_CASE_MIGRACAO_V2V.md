# 📜 Jornada de Migração V2V: Relato de Caso, Desafios & Soluções de Engenharia

> **Caso Prático:** Migração de Servidor Crítico Windows Server 2016 (RDP / 700 GB Storage / UEFI)  
> **Origem:** VMware ESXi 7.0 (`10.1.50.252`) ➔ **Destino:** Proxmox VE 8.1 (`10.1.50.212` - Host `moov`)  
> **Resultado:** 🟢 **100% Sucesso com Zero Perda de Dados e Estabilidade Total**

---

## 🎬 Introdução & Contexto
Migrar servidores de produção com grandes volumes de dados (700GB+) entre hipervisores heterogêneos (VMware ESXi para Proxmox VE) é uma das tarefas mais delicadas da engenharia de infraestrutura. 

Além da transferência massiva de blocos, o desafio central reside nas incompatibilidades de firmware (UEFI/NVRAM), drivers de armazenamento (VirtIO vs AHCI/SCSI), reativação de licenças do Windows e assinaturas digitais.

Este documento registra a jornada real, detalhando cada obstáculo ("as mazelas do caminho"), os diagnósticos técnicos efetuados e as soluções consolidadas.

---

## 🌋 As Mazelas do Caminho & Soluções de Engenharia

### 1. ⚠️ Mazela #1: O Gargalo e Timeout da API FUSE HTTP (700 GB VMDK)
* **O Problema:** Durante as tentativas de importação nativa via GUI/FUSE Storage do Proxmox, a leitura da imagem monolítica de 700 GB sofria *timeouts* de I/O na camada de abstração HTTP, interrompendo o processo.
* **Diagnóstico:** Discos rígidos virtuais de grande porte exigem streaming direto de baixo nível no nível de blocos, sem passar por intermediários com *timeouts* de requisição Web.
* **A Solução de Engenharia:** Criação de um pipeline assíncrono e persistente de baixo nível conectando ambos os hipervisores via SSH direto:
  ```bash
  nohup ssh root@10.1.50.252 "cat '/vmfs/volumes/datastore1/rdp/rdp-flat.vmdk'" | \
    dd of=/dev/zvol/Pool2/vm-104-disk-1 status=progress bs=1M > /tmp/migration_rdp.log 2>&1 &
  ```
* **O Resultado:** Transferência de **751.6 GB** concluída de forma 100% autônoma a **106 MB/s** (aproveitamento total de 100% do link de 1Gbps) em apenas **1 hora e 58 minutos**.

---

### 2. ⚠️ Mazela #2: O Erro `Code 31` na Injeção Manual de Drivers VirtIO
* **O Problema:** Durante a tentativa de instalar o driver do controlador VirtIO SCSI manualmente via Gerenciador de Dispositivos (apontando para a pasta `.inf`), o Windows Server 2016 recusava a inicialização do dispositivo exibindo a mensagem:  
  `This device is not working properly because Windows cannot load the drivers required for this device (Code 31)`.
* **Diagnóstico:** O Windows Server 2016 não possuía no seu repositório local os certificados digitais raiz da Red Hat. A instalação manual do arquivo `.inf` pula o registro de certificados, fazendo o sistema bloquear o driver por segurança.
* **A Solução de Engenharia:** Em vez de apontar para a pasta do driver manualmente, executamos diretamente o instalador oficial na raiz da ISO:
  ```text
  D:\virtio-win-guest-tools.exe
  ```
* **O Resultado:** O executável instalou e registrou automaticamente a cadeia de certificados da Red Hat nas autoridades confiáveis do Windows, liberando o driver SCSI, instalando a placa de rede VirtIO e o **QEMU Guest Agent** sem nenhum erro de assinatura.

---

### 3. ⚠️ Mazela #3: A Armadilha da Tela Azul `INACCESSIBLE_BOOT_DEVICE` & A Vitória do VirtIO SCSI
* **O Problema:** Ao tentar inicializar o disco diretamente sob barramento VirtIO SCSI (`scsi0`) logo após a migração, o Windows Server 2016 entrava em *loop* de Tela Azul (`INACCESSIBLE_BOOT_DEVICE` - BSOD 0x7B).
* **Diagnóstico:** Quando o driver de armazenamento (`vioscsi` / `viostor`) é instalado, o Windows o marca por padrão no Registro como `Start = 3` (Demand Start - início sob demanda). Ao dar boot direto pelo barramento SCSI, o kernel do Windows ainda não carregou o driver e não consegue ler a partição do sistema.
* **A Estratégia em Duas Etapas (O Golpe de Mestre):**
  1. **Etapa de Segurança (Boot Nativo):** O servidor realizou o primeiro boot no barramento **`sata0`** nativo (AHCI), garantindo inicialização 100% livre de BSOD para que pudéssemos rodar o instalador de drivers (`virtio-win-guest-tools.exe`).
  2. **Etapa de Promoção do Serviço no Registro:** Com o sistema ativo no Windows, elevamos a inicialização dos drivers VirtIO SCSI para tempo de boot direto via CMD Admin:
     ```cmd
     sc config vioscsi start= boot
     sc config viostor start= boot
     ```
  3. **Virada no Proxmox (SATA0 ➔ SCSI0):** Com a VM desligada, o disco foi desconectado de `sata0` e reconectado como `scsi0` com emulação SSD (`ssd=1`).
* **O Resultado:** 🟢 **Boot instantâneo e perfeito**, sem nenhuma tela azul, com a VM operando em modo para-virtualizado máximo de I/O, suporte a TRIM/Discard e emulação de SSD sob o storage ZFS.

---

### 4. ⚠️ Mazela #4: O Labirinto do UEFI Interactive Shell v2.2 & NVRAM
* **O Problema:** Ao alterar a configuração de discos no Proxmox, a VM reiniciava caindo direto na tela amarela do `UEFI Interactive Shell v2.2`, ou ciclava entre tentativas de boot por rede `PXEv4`, `PXEv6`, `HTTPv4` e `HTTPv6`.
* **Diagnóstico:** O arquivo de configuração da NVRAM do UEFI (`efidisk0`) guardou a rota de hardware PCI antiga do controlador SATA. Quando a topologia de hardware foi modificada, o UEFI perdeu o ponteiro da partição FAT32 de boot (`EFI System Partition`).
* **A Solução de Engenharia:** 
  1. Recriação limpa do disco EFI no Proxmox: `qm set 104 --delete efidisk0 && qm set 104 --efidisk0 Pool2:1,format=raw,efitype=4m,pre-enrolled-keys=0`.
  2. Apontamento direto do bootloader fallback: `FS0:\EFI\Boot\bootx64.efi`.
* **O Resultado:** O firmware UEFI auto-detectou o sistema operacional na partição GPT e iniciou o Windows Server 2016 de forma transparente.

---

### 5. ⚠️ Mazela #5: Reativação da Licença do Windows por Troca de Hardware Virtual
* **O Problema:** Após iniciar a VM no Proxmox, o Windows passou a exibir o aviso de que a licença não estava ativada.
* **Diagnóstico:** O Windows monitora alterações de hardware da placa-mãe (mudança da BIOS VMware para Q35/OVMF e barramentos de disco). Quando o índice de mudança de hardware excede o limite tolerado, o status de ativação é resetado.
* **A Solução de Engenharia:** 
  1. Extração do código da chave de licença (*Product Key*) registrada no Registro do Windows através de script em PowerShell:
     ```powershell
     $map="BCDFGHJKMPQRTVWXY2346789"; $value = (get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").digitalproductid[52..66]; $productKey = ""; for ($i = 24; $i -ge 0; $i--) { $r = 0; for ($j = 14; $j -ge 0; $j--) { $r = ($r * 256) -bxor $value[$j]; $value[$j] = [math]::Floor([double]($r / 24)); $r = $r % 24 }; $productKey = $map[$r] + $productKey; if (($i % 5 -eq 0) -and ($i -ne 0)) { $productKey = "-" + $productKey } }; Write-Host "Chave: $productKey"
     ```
  2. Reativação via linha de comando no CMD Administrador:
     ```cmd
     slmgr.vbs /ipk SUACHAVE-AQUI
     slmgr.vbs /ato
     ```
* **O Resultado:** Licença do Windows Server reativada com sucesso.

---

### 6. 📁 Marco #6: Desacoplamento & Restauração Segura da Unidade de Marketing (800 GiB)
* **O Cenário:** A pasta compartilhada corporativa de Marketing concentrava um grande volume de dados críticos. A engenharia optou por desacoplá-la do disco de sistema `C:`, provisionando um novo disco virtual VirtIO SCSI (`scsi1` de 800 GiB) no pool ZFS com emulação SSD.
* **A Solução de Engenharia:** 
  1. Criação do script de coleta prévia `sync_marketing.sh`, montando o compartilhamento CIFS e realizando backup incremental via `rsync` diretamente para `/Pool2/marketing_backup/`.
  2. Inicialização do disco no Windows via GPT, formatação NTFS e compartilhamento na rede.
  3. Restauração automatizada através do script `restore_marketing.sh`.
* **O Resultado:** Volume restaurado com integridade total, desacoplado do sistema operacional e operando com máxima performance sob barramento VirtIO SCSI.

---

### 🧪 7. 🛡️ Marco #7: A Prova dos 9 — O Dry-Run & Soak Test de 72 Horas sem Rede
* **O Cenário:** A maior armadilha em migrações V2V é tentar o go-live "na coragem" sem validação prévia de longevidade, gerando riscos de *split-brain* no Active Directory ou travamentos por *memory leak* em novos drivers.
* **A Solução de Engenharia:** Antes da janela de corte oficial, foi realizado um **Dry-Run Completo**:
  1. A imagem completa do servidor de 700 GB foi clonada para o Proxmox VE.
  2. O servidor foi inicializado de forma 100% isolada (`link_down=1` na interface `net0`).
  3. A VM operou continuamente por **3 dias inteiros (72 horas de Soak Test)** em console fechado.
* **O Resultado:** Validação empírica de estabilidade de kernel, monitoramento de Event Viewer livre de erros de hardware e comprovação absoluta de que o barramento VirtIO SCSI não apresentaria instabilidade a médio prazo. Quando a virada oficial aconteceu, o risco já era virtualmente zero.

---


## 🏆 Conclusão & Lições Aprendidas

1. **Ferramentas de Baixo Nível Superam Abstrações de Interface:** O uso de `cat` + `dd` via SSH direto garantiu a transferência de 700 GB sem falhar uma única vez por *timeout*.
2. **Respeito às Exigências de Assinatura do Windows:** O uso do executável oficial `virtio-win-guest-tools.exe` é indispensável para evitar bloqueios de certificado (`Code 31`).
3. **Estratégia Gradual (SATA0 ➔ SCSI0):** Iniciar pelo barramento nativo `sata0` garantiu zero downtime no primeiro boot. Em seguida, a elevação dos serviços no Registro (`sc config vioscsi start= boot`) permitiu a migração limpa para `scsi0` com emulação SSD, entregando estabilidade absoluta e performance para-virtualizada máxima.
4. **Gestão de Licenciamento:** A extração antecipada da Product Key garante a reativação sem interrupção após a mudança de hardware virtual.
5. **Automação de Carga Delta de Dados:** A criação de scripts dedicados para montagem CIFS e rsync (`sync_marketing.sh` e `restore_marketing.sh`) reduziu o tempo de corte final e garantiu a restauração íntegra de volumes secundários.
6. **O Futuro É Mais Simples:** Superar o abismo heterogêneo VMware ➔ Proxmox nos deu domínio total da stack. As próximas migrações na infraestrutura serão **Proxmox para Proxmox**, usufruindo das facilidades nativas como `qm remote-migrate`, replicação ZFS e Proxmox Backup Server.

---
*Relatório de engenharia consolidado após a homologação e entrada em produção da VM no Proxmox VE.*

