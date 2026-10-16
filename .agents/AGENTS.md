# AGENTS.md - Contexto & Estado Atual da Migração V2V

## 📌 Visão Geral do Projeto
Migração operacional de servidor Windows RDP do ambiente **VMware ESXi** para **Proxmox VE**.

* **VM Alvo:** `rdp` (`10.1.50.14` / `rdp.dominio.local`) - Windows Server 2016 (64-bit), 4 vCPUs, 12 GB RAM, UEFI.

* **Proxmox VE (Destino):** `10.1.50.212` (User: `root`, Hostname: `moov`, PVE 8.1.10)
* **VMware ESXi (Origem):** `10.1.50.252` (User: `root`, ESXi 7.0.0)
* **MAC Address Oficial da Origem:** `00:0C:29:05:98:75`

---

## 🚦 Status Atual (Última atualização: 05/10/2026 - 08:15h) - 🟢 100% CONCLUÍDO
* [x] **Conectividade & Cópia:** Volume ZFS `Pool2/vm-104-disk-1` (700 GiB) 100% transferido via SSH stream (106 MB/s).
* [x] **Conversão VirtIO SCSI Validada:** VMID 104 convertida com sucesso de `sata0` para `scsi0` (`ssd=1`) com drivers `vioscsi` e `viostor` em `start= boot`. Zero BSOD.
* [x] **Drivers VirtIO & Agent:** Instalados via `virtio-win-guest-tools.exe` com certificados Red Hat validados.
* [x] **Rede, Limpeza & Licença:** MAC Address mantido (`00:0C:29:05:98:75`), IP `10.1.50.14` fixado, placas esmaecidas removidas e licença Retail do Windows Server ativada (`slmgr.vbs /ato`).
* [x] **Unidade de Marketing (800 GiB):** Disco `scsi1` provisionado, formatado em NTFS/GPT e dados restaurados com sucesso (`restore_marketing.sh`).
* [x] **Go-Live Definitivo & Produção:** Servidor RDP em produção no Proxmox VE, homologado pelos usuários com total estabilidade e performance.

---

## 📄 Arquivos de Referência do Projeto
* `README.md`: Visão executiva, arquitetura, scripts e guia rápido do repositório.
* `PLAYBOOK_MIGRACAO_V2V.md`: Playbook operacional consolidado passo a passo com troubleshooting, pronto para replicação.
* `sync_marketing.sh`: Script operacional de montagem CIFS e rsync incremental do marketing.
* `restore_marketing.sh`: Script operacional de restauração dos dados para o novo volume do Windows.
* `credentials.env.example`: Modelo de variáveis/credenciais.
* `antigo/`: Diretório contendo documentação histórica, relatos de caso e legados (ignorado pelo git).

---

## ☀️ Próxima Etapa da Infraestrutura
1. **[ ] Migração Proxmox para Proxmox:** Aproveitar o aprendizado deste projeto para as próximas migrações entre nós Proxmox, utilizando os recursos nativos simplificados (`qm remote-migrate`, ZFS send/receive ou Proxmox Backup Server).

