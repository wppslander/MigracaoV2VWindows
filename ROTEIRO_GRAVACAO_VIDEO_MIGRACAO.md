# 🎬 Roteiro de Gravação de Vídeo Técnico: Migração V2V na Prática
## "Como Migrar Servidores Windows Críticos de VMware para Proxmox VE (Zero BSOD & Zero Downtime Inesperado)"

> **Formato Sugerido:** Vídeo de 10 a 14 minutos (ideal para YouTube, Tech Talk ou fatiado em cortes/carrossel para LinkedIn).  
> **Tom de Voz:** Confiante, pragmático, de engenharia sênior (focado em resolver dores reais de produção).  
> **Recursos Visuais:** Compartilhamento de tela alternando entre slides com diagramas, Proxmox GUI, Terminal SSH e Console do Windows.

---

## 📌 Guia Rápido de Produção do Vídeo

* **Câmera:** Canto inferior direito ou tela dividida (Facecam + Tela).
* **Setup Visual:**
  - Aba 1: Diagrama de Arquitetura do repositório ([README.md](README.md)).
  - Aba 2: Terminal SSH do Proxmox VE.
  - Aba 3: Painel Web do Proxmox VE (VM 104).
  - Aba 4: Console no Windows Server (Gerenciador de Dispositivos e CMD).

---

## ⏱️ Linha do Tempo do Roteiro

```
00:00 - 01:15 ➔ Bloco 1: O Gancho (A dor do mercado com a Broadcom & O desafio do Windows)
01:15 - 02:45 ➔ Bloco 2: O Cenário Real (700GB OS + 800GB Dados + UEFI)
02:45 - 05:00 ➔ Bloco 3: O Streaming de 106 MB/s (Superando timeouts de API)
05:00 - 07:30 ➔ Bloco 4: O "Golpe de Mestre" Contra a Tela Azul (Boot em 2 Etapas)
07:30 - 08:45 ➔ Bloco 5: Erro Code 31 e Assinaturas VirtIO
08:45 - 10:15 ➔ Bloco 6: Rede, MAC Address, Hardware Fantasma & Licença
10:15 - 11:30 ➔ Bloco 7: Desacoplamento e Carga de 800 GB (Marketing)
11:30 - 12:30 ➔ Bloco 8: Conclusão, Proxmox para Proxmox & Chamada para Ação
```

---

## 🎙️ Roteiro Passo a Passo (O que falar & O que mostrar)

### 🔴 Bloco 1: O Gancho (A Dor do Mercado) `[00:00 - 01:15]`
* **O que mostrar na tela:** Câmera cheia ou manchetes sobre a migração em massa de VMware para Proxmox VE após as mudanças de licenciamento da Broadcom.
* **O que falar:**
  > *"Fala pessoal! Com a reestruturação da VMware pela Broadcom, praticamente todo profissional de TI e SysAdmin está correndo contra o tempo para migrar sua infraestrutura para o Proxmox VE.*  
  > *Mas vamos ser muito honestos: migrar uma máquina Linux é moleza, o kernel já traz tudo pronto. Agora, quando você precisa migrar um **Windows Server de produção com mais de 700 GB, firmware UEFI, licenças ativas e dezenas de usuários conectados via RDP**... aí o bicho pega.*  
  > *A maioria das pessoas tenta usar o importador padrão da web e toma timeout, ou sobe o disco no Proxmox e cai na clássica Tela Azul `INACCESSIBLE_BOOT_DEVICE`.*  
  > *Neste vídeo, eu vou te mostrar a engenharia exata que usei para migrar um servidor Windows Server 2016 crítico de 1.5 TB de VMware ESXi para Proxmox com ZFS, com **zero tela azul, zero perda de dados e aproveitamento de 100% do link de rede**. Bora pra tela!"*

---

### 🖥️ Bloco 2: O Cenário & Arquitetura `[01:15 - 02:45]`
* **O que mostrar na tela:** O diagrama Mermaid do `README.md` mostrando Origem (ESXi), Pipeline SSH e Destino (Proxmox com ZFS Pool2).
* **O que falar:**
  > *"Nosso laboratório de produção aqui é um caso de alta responsabilidade:*
  > *- **Origem:** VMware ESXi 7.0 com uma VM Windows Server 2016 (4 vCPUs, 12 GB de RAM, BIOS UEFI).*
  > *- **Armazenamento:** 700 GB no disco de sistema `C:` mais uma pasta compartilhada corporativa de 800 GB.*
  > *- **Destino:** Proxmox VE 8.1 sobre ZFS Storage Pool.*
  > *- **Desafio:** Manter o mesmo IP, o mesmo MAC Address para não perder licenciamentos, e realizar a janela de corte mais rápida possível sem corrupção."*

---

### ⚡ Bloco 3: Engenharia de Transferência (Bypass de Timeout HTTP) `[02:45 - 05:00]`
* **O que mostrar na tela:** Terminal SSH do Proxmox mostrando o comando `cat` via SSH canalizado no `dd`.
* **O que falar:**
  > *"Primeira grande lição: **não use a API web ou importador FUSE para arquivos monolíticos de centenas de gigabytes**. Eles costumam estourar timeout HTTP no meio da cópia.*  
  > *Como resolvemos isso com engenharia limpa de baixo nível?*  
  > *Criamos chaves SSH sem senha entre o Proxmox e o ESXi e disparamos um streaming direto em nível de bloco:*
  > ```bash
  > nohup ssh root@IP_ESXI "cat '/vmfs/volumes/.../rdp-flat.vmdk'" | \
  >   dd of=/dev/zvol/Pool2/vm-104-disk-1 status=progress bs=1M &
  > ```
  > *Isso lê o disco bruto direto no ESXi e grava direto no volume ZFS do Proxmox. Resultado? **106 MB/s cravados do início ao fim**, saturando 100% da placa Gigabit. Migramos 751 GB em menos de 2 horas, de forma totalmente autônoma e sem arquivos temporários duplicados."*

---

### 🛡️ Bloco 4: O "Golpe de Mestre" Contra a Tela Azul (BSOD 0x7B) `[05:00 - 07:30]`
* **O que mostrar na tela:** Interface do Proxmox mostrando o disco em `sata0`, depois o prompt de comando do Windows com o `sc config vioscsi start= boot`.
* **O que falar:**
  > *"Aqui está o segredo que separa quem tem sucesso de quem fica travado a noite inteira em chamado de emergência.*  
  > *Se você pegar o disco do Windows recém-copiado do VMware e plugar direto como `VirtIO SCSI`, o Windows **vai tomar Tela Azul (BSOD 0x7B - Inaccessible Boot Device)**. Por quê? Porque o Windows não tem o driver SCSI inicializado durante o boot antecipado.*  
  > *Nós usamos uma **Estratégia de 2 Etapas:**  
  > 1. **Primeiro Boot Seguro:** Montamos o disco temporariamente no barramento **`sata0`** nativo. O Windows Server boota liso, sem tela azul nenhuma!  
  > 2. **Instalação dos Drivers:** Com a máquina rodando, instalamos as ferramentas VirtIO.  
  > 3. **A Promoção no Registro:** Aqui está a linha de ouro no CMD como Administrador:  
  > ```cmd
  > sc config vioscsi start= boot
  > sc config viostor start= boot
  > ```  
  > *Isso força o Windows a carregar o driver VirtIO SCSI no momento em que o kernel acorda.  
  > Depois disso, é só desligar, alterar no Proxmox de `sata0` para **`scsi0`** com **SSD emulation**, e ligar de novo.*  
  > *O Windows inicializa em segundos, com performance para-virtualizada máxima e suporte a TRIM no ZFS!*  
  >  
  > *Mas atenção: **eu não fui direto para a virada de produção**. Aqui está a maior prova de senioridade: antes do corte definitivo, eu fiz um **Dry-Run Completo**.*  
  > *Eu peguei essa imagem clonada e deixei a máquina rodando no Proxmox **'seca', sem rede nenhuma (link_down=1), por 3 dias inteiros (72 horas de soak test)**.*  
  > *Por que sem rede? Primeiro: se você ligar uma cópia do Windows Server na rede com o original ligado, você causa um desastre no Active Directory, quebra os segredos Kerberos da conta de máquina e derruba o domínio corporativo. Segundo: rodando isolado por 3 dias, pude monitorar o Event Viewer, verificar estabilidade dos drivers VirtIO e ter 100% de certeza de que não havia memory leak. Foi isso que transformou o go-live final em um passeio!"*

---


### 🔑 Bloco 5: A Mazela do Code 31 e os Certificados Red Hat `[07:30 - 08:45]`
* **O que mostrar na tela:** O CD da ISO VirtIO destacando o `virtio-win-guest-tools.exe` versus as pastas manuais de drivers `.inf`.
* **O que falar:**
  > *"Outro problema que você vai encontrar no Windows Server 2016: se você for no Gerenciador de Dispositivos e mandar atualizar o driver apontando para a pasta `.inf` do VirtIO, o Windows recusa e dá o infame erro **Code 31** ('Windows cannot load the drivers required').*  
  > *A causa? O Windows Server antigo não tem as autoridades certificadoras da Red Hat registradas por padrão.*  
  > *A solução é simples, mas vital: **sempre rode o `virtio-win-guest-tools.exe` da raiz da ISO**. Ele instala os certificados confiáveis da Red Hat, o driver de rede, o QEMU Guest Agent e o controlador SCSI de uma só vez, sem reclamar de assinatura digital."*

---

### 🌐 Bloco 6: Placas Fantasmas, MAC Address e Licença `[08:45 - 10:15]`
* **O que mostrar na tela:** O Gerenciador de Dispositivos mostrando as placas de rede ocultas e o comando `slmgr.vbs /ato`.
* **O que falar:**
  > *"Dois pontos críticos de pós-migração que quase ninguém lembra:*  
  > *1. **Placa de Rede Oculta:** O Windows guarda a placa antiga da VMware escondida no Registro. Se você tentar colocar o IP antigo na nova placa VirtIO, ele vai dizer que o IP já pertence a outro adaptador.  
  > Nós executamos:  
  > ```cmd
  > set devmgr_show_nonpresent_devices=1
  > start devmgmt.msc
  > ```  
  > *Mandamos exibir dispositivos ocultos e desinstalamos a placa Intel antiga. Além disso, configuramos a placa VirtIO no Proxmox com o **mesmo MAC Address original da VMware**.*  
  > *2. **Licenciamento do Windows:** Como a placa-mãe virtual mudou de VMware para Q35, o Windows pede reativação. Basta extrair a chave original via script PowerShell e ativar no CMD com `slmgr.vbs /ato`. Ativação 100% regularizada!"*

---

### 📁 Bloco 7: Desacoplamento e Carga dos 800 GB do Marketing `[10:15 - 11:30]`
* **O que mostrar na tela:** Os scripts `sync_marketing.sh` e `restore_marketing.sh` no repositório.
* **O que falar:**
  > *"Por fim, tínhamos 800 GB de dados do setor de Marketing. Em vez de inchar o disco de sistema, aproveitamos a migração para fazer uma boa prática de arquitetura: **desacoplamos os dados em um segundo disco virtual dedicado (`scsi1`)**.*  
  > *Desenvolvemos dois scripts bash elegantes:*  
  > *- O `sync_marketing.sh`: realizou o backup prévio a quente via CIFS e rsync direto para o pool ZFS enquanto os usuários ainda trabalhavam.*  
  > *- O `restore_marketing.sh`: após formatar o novo disco em NTFS e GPT no Windows, restaurou todos os dados preservando estrutura e permissões.*  
  > *Dessa forma, a janela de downtime da empresa ficou restrita a poucos minutos!"*

---

### 🚀 Bloco 8: Conclusão & O Futuro `[11:30 - 13:00]`
* **O que mostrar na tela:** Página principal do repositório no GitHub (`github.com/wppslander/MigracaoV2VWindows`) com todos os playbooks e manuais.
* **O que falar:**
  > *"E o resultado final? Servidor em produção, usuários conectados via RDP trabalhando normalmente na segunda-feira de manhã, tempo de resposta excelente e zero chamados de lentidão ou tela azul.*  
  > *E o melhor de tudo: vencer essa barreira heterogênea do VMware para o Proxmox nos deu o domínio total da stack. As próximas migrações serão **Proxmox para Proxmox**, onde tudo é nativo com `qm remote-migrate`, replicação ZFS e Proxmox Backup Server.*  
  > *Toda essa documentação, o playbook passo a passo e os scripts que utilizei estão versionados e higienizados no meu repositório do GitHub.*  
  > *Se esse conteúdo te ajudou ou abriu seus olhos para um projeto de migração na sua empresa, deixe seu like, se inscreva no canal e comente aqui embaixo qual tem sido a sua maior dor ao sair do VMware. Um grande abraço e até a próxima!"*

---

## 💡 Dicas de Gravação para Arrebentar

1. **Gere curiosidade nos primeiros 15 segundos:** Não comece com vinheta longa. Comece falando do terror da Tela Azul e dos aumentos de preço da Broadcom.
2. **Mostre os comandos:** Desenvolvedores e engenheiros de infraestrutura adoram ver comandos de terminal e o `status=progress` do `dd` fluindo em 106 MB/s.
3. **Link do Repositório:** Coloque o link do seu GitHub na descrição do vídeo e fixado no primeiro comentário.
4. **Cortes para LinkedIn/Shorts:**
   - *Corte 1 (60s):* "Por que o seu Windows dá Tela Azul ao migrar pro Proxmox (e o comando mágico do Registro)".
   - *Corte 2 (60s):* "Como transferir 750 GB de ESXi para Proxmox a 106 MB/s sem estourar timeout".
