# Contexto do Projeto: Migração V2V (VMware para Proxmox)

Este diretório contém a documentação operacional padronizada para migração de servidores Windows do ambiente VMware para Proxmox VE.

## 📚 Documentação Mestre Oficial

A documentação foi consolidada e simplificada. Utilize os arquivos abaixo como referência:

* **`README.md`**: Visão executiva, arquitetura, scripts e guia de alto nível.
* **`PLAYBOOK_MIGRACAO_V2V.md`**: O guia operacional definitivo completo (Passos 0 a 8 + Matriz de Troubleshooting).
* **`sync_marketing.sh` / `restore_marketing.sh`**: Scripts de suporte para movimentação e sincronização dos volumes de dados.

---

## 🚨 Pontos Críticos de Atenção (Safety Checks)

Todo procedimento de migração V2V deve respeitar rigorosamente os seguintes pontos de controle:

1. **Snapshots:** A VM de origem **DEVE** ter os snapshots consolidados ("Delete All") antes do corte.
2. **BitLocker:** Deve ser desativado no Windows antes da migração (`manage-bde -status`).
3. **Drivers VirtIO:** Injetar drivers executando **`virtio-win-guest-tools.exe`** na raiz do CD VirtIO para garantir o registro dos certificados digitais da Red Hat (evitando o erro `Code 31`).
4. **Boot Seguro em 2 Etapas:** Primeiro boot no barramento nativo `sata0` para garantir boot limpo sem Tela Azul; em seguida, habilitar `sc config vioscsi start= boot` e `viostor` para migrar com segurança total para `scsi0` (`ssd=1`).
5. **Rede & Licenciamento:** Manter o MAC Address oficial da origem (`00:0C:29:05:98:75`) no adaptador VirtIO e efetuar a limpeza de placas ocultas (`devmgr_show_nonpresent_devices=1`).

---

## 🎯 Escopo da Migração
* **VM Concluída:** `rdp` (`10.1.50.14` / Windows Server 2016).

---

## 📁 Arquivos Antigos e Históricos
Todos os rascunhos, relatos de caso, scripts legados e materiais acessórios foram consolidados na pasta **`antigo/`** (ignorada no git), mantendo a raiz do projeto estritamente focada na operação.