# Contexto do Projeto: Migração V2V (VMware para Proxmox)

Este diretório contém a documentação operacional padronizada para migração de servidores Windows do ambiente VMware para Proxmox VE.

## 📚 Documentação Mestre Oficial

A documentação foi consolidada e revisada para garantir total segurança, repetibilidade e clareza. Utilize os arquivos mestre abaixo como referência:

* **`PLAYBOOK_MIGRACAO_V2V.md`**: O playbook operacional prático e direto com índice dos passos para replicação imediata do processo.
* **`MANUAL_UNIFICADO_MIGRACAO_V2V.md`**: O manual técnico unificado completo e definitivo. Contém todos os procedimentos de pré-migração, streaming de disco por SSH (`cat` + `dd`), injeção de drivers VirtIO via executável, ajustes de boot UEFI, preservação do MAC Address e limpeza de rede.
* **`JORNADA_E_CASE_MIGRACAO_V2V.md`**: O relato de caso detalhado registrando cada desafio técnico ("mazela"), diagnósticos de causa raiz e soluções aplicadas na migração do servidor `rdp`.
* **`ROADMAP_MIGRACAO_V2V_LINKEDIN.md`**: A linha do tempo completa do projeto com diagramas de arquitetura, marcos finalizados e modelo de post para redes sociais.

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
Todos os rascunhos anteriores e arquivos legado (`legacy/`, `NovoModelo/`, `PlanoDeMigracao*.md`, `ROTEIRO_FINAL_MIGRACAO_RDP.md`) foram organizados no diretório **`archive/`**, mantendo a raiz do projeto limpa e focada.