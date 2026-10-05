# Plano de Migração V2V (VMware para Proxmox)

Este documento descreve o plano atualizado e estruturado para a migração de servidores Windows do ambiente VMware para o Proxmox VE.

## 1. Investigação e Pré-requisitos

Antes de iniciar qualquer procedimento técnico, valide os seguintes pontos críticos na VM de origem (VMware):

*   **[X] Modo da BIOS (Confirmado):** A VM utiliza **UEFI**. Isso exigirá configuração específica de Máquina (`q35`) e BIOS (`OVMF`) no Proxmox.
*   **[X] Consolidação de Snapshots (Confirmado):** A VM não possui snapshots pendentes.
*   **[X] Preservação do MAC Address (Crítico para ERP/Sankhya):** O MAC Address atual é **`00:0C:29:05:98:75`** (ou `00-0C-29-05-98-75`). Este endereço exato deve ser colado no campo "MAC address" da nova placa VirtIO no Proxmox.
*   **[X] Documentação de Rede (Crucial):**
    *   **Versão do Windows:** Windows Server 2016 (Build 14393 / 1607). Na ISO do VirtIO, os drivers estarão na pasta `2k16`.
    *   **Adaptador de Origem:** Intel E1000 (`Ethernet0`)
    *   **IP Estático:** `10.1.50.14`
    *   **Máscara:** `255.255.255.0`
    *   **Gateway Padrão:** `10.1.50.1`
    *   **DNS:** `10.1.50.1` e `1.1.1.1`
*   **Remoção do VMware Tools:** Se migrarmos com o VMware Tools instalado, o Windows vai tentar carregar drivers de vídeo e rede da VMware no boot do Proxmox, causando lentidão e lixo no registro. Desinstale pelo *Painel de Controle* e reinicie a VM ainda no ESXi antes do corte.
*   **[X] Desativar BitLocker:** Verificado via CMD (`manage-bde`). A feature do BitLocker sequer está instalada no servidor, portanto, **não há risco de bloqueio de boot**.
*   **Verificação de Portas:** Garanta que as portas `443` (API) e `902` (MKS/Data) estejam acessíveis no ESXi a partir do Proxmox.
*   **Sistema de arquivos (Referência):**
    *   Unidade G (Marketing): 387,9 GB / 849,9 GB
    *   Unidade D (Administrativo): 349,1 GB / 502,1 GB
    *   Unidade C (Root): 69,7 GB / 97,8 GB

---

## 2. Preparação do ambiente e conectividade

O objetivo aqui é conectar o Proxmox ao ESXi para importar a VM diretamente da API do VMware.

Como a conexão será feita através da rede local (LAN) existente, os IPs dos hosts são:
*   **Servidor VMware (Origem):** `10.1.50.252`
*   **Servidor Proxmox (Destino):** `10.1.50.212`

> **Atenção (Gargalo de Rede):** Como o tráfego de 1.5 TB passará pela rede de produção, a migração disputará banda com os usuários e outros serviços. É altamente recomendado que a cópia dos dados ocorra fora do horário comercial para evitar lentidão na rede da empresa.

### Configuração no Proxmox (Lado Destino)

O ESXi já está na rede, então o Proxmox só precisa ser autorizado a conectar na API e no serviço de cópia (NFC) do VMware.

1.  **Ajuste de Firewall no VMware (via SSH ou Console do ESXi):** Garanta que o ESXi aceite conexões vindas do Proxmox nas portas de gerenciamento e cópia de arquivos (NFC):
    ```bash
    # Libera o tráfego de gerenciamento/API (Porta 443)
    esxcli network firewall ruleset set -e true -r webAccess
    # Libera a porta 902 (NFC) necessária para a transferência dos blocos do disco
    esxcli network firewall ruleset set -e true -r vpxa
    ```
2.  **Captura da Fingerprint SHA256:** Execute no shell do Proxmox para obter a "identidade" do ESXi sem precisar de certificados SSL válidos:
    ```bash
    openssl x509 -in <(openssl s_client -connect 10.1.50.252:443 -prexit 2>/dev/null) -noout -fingerprint -sha256 | cut -d'=' -f2
    ```
3.  **Integração do Storage de Importação:** No Proxmox: *Datacenter* > *Storage* > *Add* > *ESXi*.
    *   **ID:** `ESXi_Migracao`
    *   **Server:** `10.1.50.252`
    *   **Username:** `root`
    *   **Password:** SuaSenha
    *   **Fingerprint:** (Cole o código obtido no comando anterior)
    *   **Skip Certificate Verification:** Marcado.

### Teste de Conectividade (Validação)

Antes de iniciar o "Corte", valide se as portas estão abertas para evitar que a migração pare em 0%. No shell do Proxmox (`10.1.50.212`), rode:
```bash
# Valida latência na rede
ping 10.1.50.252 -c 4

# Valida acesso à API (443) e ao tráfego de dados (902)
nc -zv 10.1.50.252 443 902
```
*O retorno deve ser `Connection to 10.1.50.252 port [443/902] succeeded!`*

#### Checklist de Prontidão do Passo 2 (Concluído):
- [X] Ping respondendo entre `10.1.50.212` e `10.1.50.252`.
- [X] Conexão validada nas portas 443 e 902 (Netcat).
- [X] Autenticação SSH sem senha (chaves RSA) configurada entre Proxmox e VMware ESXi.
- [X] Storage ESXi adicionado e validado no Proxmox.

---

## 3. Execução da Migração

A execução deve seguir uma ordem lógica para evitar corrupção de dados e garantir que o Windows reconheça o novo hardware virtual.

### Preparação Final na Origem (VMware)

1.  **Desinstalação do VMware Tools:** Remova completamente o VMware Tools e reinicie a VM uma última vez no ESXi. Isso limpa drivers proprietários que causam conflitos no Proxmox.
2.  **Shutdown Limpo:** Execute o desligamento via CMD para garantir que o sistema de arquivos esteja íntegro:
    ```cmd
    shutdown /s /t 0
    ```

### Importação para o Proxmox

1.  **Import Wizard:** No Proxmox, utilize a aba *Import* dentro do storage ESXi configurado no Passo 2.
2.  **Configurações de Destino:** Selecione o *Target Storage* (ZFS, LVM-Thin, etc.) e o formato de disco (Qcow2 é recomendado para snapshots).
3.  **Ajuste Crítico de Hardware (Pós-Importação):** Antes de ligar a VM, vá na aba *Hardware* da nova VM no Proxmox e faça os seguintes ajustes:
    *   **Tipo de CPU:** Altere para `host` (passagem direta de instruções físicas).
    *   **Firmware UEFI:**
        *   Dê um duplo clique em *Machine* e altere para `q35`.
        *   Dê um duplo clique em *BIOS* e altere para `OVMF (UEFI)`.
        *   Clique em *Add* > *EFI Disk* (selecione o mesmo storage do disco C: e desmarque a opção "Pre-enroll keys").
    *   **Controladora SCSI (Performance):** Dê um duplo clique em *SCSI Controller* e altere para **`VirtIO SCSI single`** (necessário para o TRIM/Discard funcionar corretamente em múltiplos discos).
    *   **Placa de Rede (MAC Address):** Remova a placa de rede importada. Adicione uma nova do modelo `VirtIO (paravirtualized)` e **cole manualmente o MAC Address anotado do VMware** no campo "MAC address". Isso evita a quebra de licença do ERP Sankhya e do Windows.

### Cirurgia VirtIO (Injeção de Drivers)

Este passo é vital para evitar o erro `INACCESSIBLE_BOOT_DEVICE`.

1.  **Alteração Temporária do Barramento:**
    *   Desconecte o disco `C:` do barramento `SCSI`.
    *   Reconecte-o como `SATA` (Barramento 0). O Windows possui drivers nativos para SATA e dará o boot sem BSOD.
2.  **Preparação para Drivers:**
    *   Monte a ISO do `VirtIO-Win` no drive de CD/DVD virtual.
    *   **Disco Isca:** Adicione um novo disco rígido de 1GB utilizando o barramento `SCSI`. Isso forçará o Windows a detectar um dispositivo SCSI desconhecido.
3.  **Instalação de Drivers:**
    *   Ligue a VM e faça login no Windows.
    *   Abra o Gerenciador de Dispositivos (`devmgmt.msc`).
    *   Localize o "Controlador de Armazenamento" com exclamação (o disco isca) e atualize o driver apontando para a pasta `vioscsi` dentro da ISO VirtIO.
    *   Localize o "Adaptador de Rede" e atualize o driver apontando para a pasta `NetKVM`.

### Finalização do Barramento

1.  **Retorno ao SCSI:**
    *   Desligue a VM.
    *   Remova o "Disco Isca" de 1GB.
    *   Desconecte o disco `C:` do barramento `SATA`.
    *   Reconecte o disco `C:` no barramento `SCSI` (Barramento 0).
2.  **Boot Final:** Ligue a VM. O Windows agora carregará o driver `vioscsi` durante o boot e iniciará o sistema diretamente pelo barramento SCSI com performance otimizada.

---

## 4. Validação e Pós-Migração

Este procedimento visa validar a tradução do hardware pelo Proxmox, limpar drivers legados e garantir a estabilidade do Windows Server.

### Conferência Crítica de Hardware (Pré-Boot)

Não ligue a VM imediatamente após a importação. Verifique na aba *Hardware* do Proxmox:
*   **Modelo de Rede:** Confirme se o modelo é idêntico ao da origem (`E1000` ou `VMXNET3`). O Wizard pode ter sugerido `VirtIO` automaticamente; altere manualmente se necessário para manter a compatibilidade imediata.
*   **Barramento do Disco:** Garanta que o disco `C:` esteja em `SATA` para o primeiro boot da "cirurgia" e os discos `D:` e `G:` estejam mapeados corretamente.

### Boot, Performance e Armazenamento

*   **Validação do Barramento:** Confirme no Gerenciador de Dispositivos se o controlador de armazenamento aparece como "Red Hat VirtIO SCSI controller".
*   **Ativação do Discard (TRIM):** Se o seu storage no Proxmox for SSD ou NVMe (como o ZFS ou LVM-Thin), você precisa habilitar o Discard para evitar degradação de performance.
    *   *No Proxmox:* Vá em *VM* > *Hardware* > *Hard Disk* > *Edit* e marque a opção `Discard`.
    *   *No Windows:* Otimize as unidades via `dfrgui.exe` (o Windows deve reconhecer agora como "Unidade de Estado Sólido").
*   **Remoção do Disco Isca:** Se ainda não o fez, remova o disco de 1GB criado no Passo 3.

### Limpeza de Rede e "Adaptadores Fantasma"

O Windows mantém os registros das placas `VMXNET3` ocultos, o que impede você de configurar o mesmo IP estático na nova placa `VirtIO`.

1.  **Script de Limpeza (Via PowerShell como Administrador):**
    ```powershell
    # Exibe dispositivos ocultos (não presentes) no Gerenciador de Dispositivos
    $env:devmgr_show_nonpresent_devices = 1
    devmgmt.msc
    ```
2.  **Ação Manual:**
    *   No Gerenciador de Dispositivos, vá em *Exibir* > *Mostrar dispositivos ocultos*.
    *   Expanda *Adaptadores de rede*.
    *   Desinstale todos os adaptadores cinzas (`VMware`, `VMXNET3`, `Intel E1000`).
3.  **Reconfiguração de IP:** Atribua novamente o IP estático, máscara, gateway e DNS na nova placa `NetKVM` (VirtIO).

### Integração e Sincronismo (QEMU Guest Agent)

Sem o Agent, o Proxmox não consegue realizar um "Shutdown" limpo via interface (ele força o desligamento elétrico) e não exibe o IP da VM no sumário.

*   **No Proxmox:** Vá em *VM* > *Options* > *QEMU Guest Agent* e mude para `Enabled`. (Requer reinicialização da VM).
*   **No Windows:**
    *   Execute o instalador `virtio-win-guest-tools.exe` contido na ISO do VirtIO.
    *   Verifique se o serviço "QEMU Guest Agent" está em execução (`services.msc`).
*   **Sincronia de Tempo (RTC):** Para evitar erros de log e autenticação no Windows Server:
    *   No Proxmox, em *VM* > *Options*, garanta que o `RTC Start Date` esteja correto e que o fuso horário esteja batendo com o host.

### Verificação de Saúde do Sistema de Arquivos

Após a migração de 1.5 TB, é prudente garantir que a cópia bloco-a-bloco não gerou inconsistências lógicas no NTFS. Execute em cada partição (`C:`, `D:` e `G:`):
```cmd
chkdsk C: /f
chkdsk D: /f
chkdsk G: /f
```

## 5. Plano de Recuperação (Rollback)

Caso a migração falhe (ex: Tela Azul irreversível no Proxmox, lentidão extrema, ou falha grave de licenciamento do ERP) e a janela de manutenção esteja se esgotando, execute o rollback imediato para a origem:

1.  **Desligamento no Destino:** Force o desligamento (Stop) da VM importada no Proxmox para evitar qualquer conflito de IP na rede.
2.  **Religar na Origem:** Volte ao painel do VMware ESXi (`10.1.50.252`) e ligue a VM original. Como fizemos apenas uma cópia dos dados, a VM original continua intacta.
3.  **Reinstalação do VMware Tools:** Como o VMware Tools foi removido no Passo 3, o Windows subirá genérico.
    *   No ESXi, clique com o botão direito na VM > *Guest OS* > *Install VMware Tools*.
    *   Acesse a VM via console, abra o drive de CD virtual e execute o instalador (`setup64.exe`).
    *   Reinicie a VM após a instalação.
4.  **Validação de Rede:** Confirme se a placa de rede original (Intel E1000) subiu com o IP estático correto (`10.1.50.14`). Caso tenha perdido a configuração, reinsira os dados anotados no Passo 1.
5.  **Teste de Aplicação:** Peça para um usuário-chave validar o acesso ao ERP Sankhya e aos mapeamentos de rede.

---

## 6. Checklist de Conclusão do Projeto

| Item | Status | Observação |
| :--- | :---: | :--- |
| **IP Estático** | [ ] | Validar se os serviços (ERP/Sankhya/Marketing) respondem no novo IP. |
| **QEMU Agent** | [ ] | Status "Running" no Sumário do Proxmox. |
| **Performance** | [ ] | CPU Type definido como host e Discard ativo. |
| **Limpeza** | [ ] | VMware Tools desinstalado e drivers ocultos removidos. |

> **⚠️ CRÍTICO:** Após terminar tudo e validar que está 100%, tire um **Snapshot no Proxmox** com a descrição "Pós-Migração-Limpo". Se algo apresentar instabilidade nos próximos dias devido a algum driver remanescente, você tem um ponto de retorno imediato.

---

## 6. Planejamento de Tempo Estimado

| Atividade | Tempo estimado | Observação |
| :--- | :--- | :--- |
| **Investigação e pré-requisitos** | 30 Min | Snapshots e BitLocker |
| **Preparação do Ambiente** | 2 horas | Rede /30 e Storage ESXi |
| **Transferência de Dados** | 2 a 3 horas | Base: 1.5 TB @ 2.5 Gbps |
| **Cirurgia VirtIO e Drivers** | 1 hora | Injeção manual no Windows |
| **Validação Final** | 15 min | Limpeza de Rede e Agente |
