# 📌 TODO.md - Homologação & Status Final da Migração V2V

## 🟢 STATUS GERAL: JORNADA CONCLUÍDA COM 100% DE SUCESSO!
O servidor Windows RDP (VMID 104) encontra-se em produção estável no Proxmox VE com barramento VirtIO SCSI, SSD emulation, rede Gigabit preservada e unidade de Marketing de 800 GiB restaurada.

---

## 🧪 FASE 1: Homologação do Servidor RDP (VMID 104) `[100% CONCLUÍDO]`

- [x] **Migração e Boot Inicial:** Servidor migrado para Proxmox VE rodando sob barramento `sata0` com total estabilidade.
- [x] **Instalação de Drivers & Agent:** VirtIO Ethernet e QEMU Guest Agent instalados via `virtio-win-guest-tools.exe`.
- [x] **Rede & Licenciamento:** MAC Address (`00:0C:29:05:98:75`) mantido, IP `10.1.50.14` fixado e licença Retail ativada com sucesso.
- [x] **Testar Otimização do Barramento para VirtIO SCSI (`scsi0`):**
  1. No Windows Server (CMD Administrador), executar:
     ```cmd
     sc config vioscsi start= boot
     sc config viostor start= boot
     ```
  2. Efetuar shutdown limpo (`shutdown /s /t 0`).
  3. No Proxmox VE, alterar de SATA para SCSI 0 com SSD Emulation:
     ```bash
     qm set 104 --delete sata0 --scsi0 Pool2:vm-104-disk-1,ssd=1
     qm set 104 --boot order=scsi0
     qm start 104
     ```
  4. ✅ **VALIDADO COM SUCESSO:** Boot limpo, sem BSOD, disco rodando 100% sob VirtIO SCSI com SSD emulation ativa.
- [x] **Unidade de 800 GiB para o Marketing (`scsi1`):**
  - [x] Script `sync_marketing.sh` criado e implantado no Proxmox (`/root/sync_marketing.sh`).
  - [x] Executar carga final incremental da pasta `//10.1.50.14/SETOR MARKETING` para `/Pool2/marketing_backup/`.
  - [x] Vincular disco de 800G à VM 104 (`qm set 104 --scsi1 Pool2:800,ssd=1`).
  - [x] Inicializar (GPT), formatar (NTFS) e restaurar os dados de `/Pool2/marketing_backup/` usando `restore_marketing.sh`.
- [x] **Homologação dos Usuários:**
  - [x] Validar conexões de usuários via RDP (`mstsc`).
  - [x] Verificar funcionamento de impressoras, aplicações e sistemas internos.
  - [x] Medir tempo de resposta e consumo de CPU/Memória no Proxmox (excelente performance com ZFS e SSD emulation).

---

## 🚀 FASE 2: GO-LIVE DEFINITIVO & VIRADA OFICIAL `[100% CONCLUÍDO]`

- [x] **Notificar Downtime:** Agendamento e comunicação da janela de corte com os usuários.
- [x] **Sincronização Final do Marketing:** Executado `/root/sync_marketing.sh` para cópia delta de segurança.
- [x] **Corte de Dados na Origem:** Desligamento limpo da VM original no ESXi 7.0 (`shutdown /s /t 0`).
- [x] **Streaming de Blocos:** Transferência consolidada via SSH direto (`cat` + `dd`) a 106 MB/s.
- [x] **Execução do Playbook Validado (`PLAYBOOK_MIGRACAO_V2V.md`):**
  - [x] Montagem sob `scsi0` (`ssd=1`).
  - [x] Anexação e montagem da unidade de 800G do marketing (`scsi1`).
  - [x] Reativação da licença Retail (`slmgr.vbs /ato`).
  - [x] Subida do link da interface de rede (`link_down=0`).
  - [x] Restauração dos dados de Marketing via `restore_marketing.sh`.
- [x] **Validação Final e Entrega:** Servidor RDP liberado para produção e operando perfeitamente.

---

## 🔮 PRÓXIMOS PASSOS (Futuras Migrações)

- [ ] **Migração Proxmox para Proxmox:**
  - Aproveitar a infraestrutura nativa do ecossistema Proxmox (migrações muito mais simples e diretas com `qm remote-migrate`, Proxmox Backup Server ou replicação de Storage ZFS).

