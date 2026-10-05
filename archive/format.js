const fs = require('fs');

const text = `1. Investigação e Pré-requisitos
Antes de iniciar qualquer procedimento técnico, valide os seguintes pontos críticos na VM de origem (VMware):
- Consolidação de Snapshots: A VM deve ter todos os snapshots consolidados ("Delete All").
- Desativar BitLocker: Suspenda ou desative o BitLocker no drive C: para evitar bloqueios de boot.
- Verificação de Portas: Garanta que as portas 443 (API) e 902 (MKS/Data) estejam acessíveis no ESXi a partir do Proxmox.

---

2. Preparação do Ambiente
Esta fase foca na configuração da infraestrutura necessária para uma transferência de alta performance (2.5 Gbps).
- Rede Ponto a Ponto: Conexão física direta entre os hosts. Configurar IPs 10.99.99.1 (ESXi) e 10.99.99.2 (Proxmox) com máscara /30.
- Integração de Storage: Adicionar o host ESXi como um storage nativo no Proxmox (Datacenter -> Storage -> Add -> ESXi) utilizando o link isolado.
- Download de Drivers: Baixar a ISO mais recente do VirtIO-Win no Proxmox (/var/lib/vz/template/iso/).

---

3. Execução da Migração
O "Corte" deve ser realizado preferencialmente em janelas de manutenção.
- Shutdown: Desligamento limpo do Windows Server (shutdown /s /t 0).
- Importação: Utilizar a aba "Import" no storage ESXi do Proxmox. Selecionar Target Storage e Formato (Raw/Qcow2).
- Cirurgia VirtIO: 
  1. Alterar barramento do disco C: para SATA/IDE temporariamente.
  2. Adicionar um "Disco Isca" (SCSI 1GB) para forçar o Windows a carregar o driver VirtIO.
  3. Instalar drivers (vioscsi, NetKVM) via Gerenciador de Dispositivos.
  4. Reverter o disco C: para o barramento SCSI após a instalação.

---

4. Validação e Pós-Migração
Garantia de que o sistema está operante e otimizado no novo ambiente.
- Boot e Performance: Validar o boot via VirtIO SCSI e ativar a opção "Discard" (SSD/NVMe).
- Rede Fantasma: Remover adaptadores ocultos (VMXNET3/E1000) via Gerenciador de Dispositivos (set devmgr_show_nonpresent_devices=1).
- QEMU Guest Agent: Ativar nas opções da VM e validar a comunicação no Sumário do Proxmox.

---

5. Planejamento de Tempo Estimado

Atividade | Tempo Estimado | Observação
---|---|---
Investigação e Pré-requisitos | 15 - 30 min | Snapshots e BitLocker
Preparação do Ambiente | 20 min | Rede /30 e Storage ESXi
Transferência de Dados | 1h 30m - 2h | Base: 1.5 TB @ 2.5 Gbps
Cirurgia VirtIO e Drivers | 30 min | Injeção manual no Windows
Validação Final | 15 min | Limpeza de Rede e Agente
Manual de Migração V2V (VMware para Proxmox) - v3
`;

const patterns = [
  { p: "1. Investigação e Pré-requisitos", style: "heading2" },
  { p: "2. Preparação do Ambiente", style: "heading2" },
  { p: "3. Execução da Migração", style: "heading2" },
  { p: "4. Validação e Pós-Migração", style: "heading2" },
  { p: "5. Planejamento de Tempo Estimado", style: "heading2" },
  { p: "Manual de Migração V2V (VMware para Proxmox) - v3", style: "heading1" },
  { p: "Atividade | Tempo Estimado | Observação", style: "bold" }
];

const formats = [];
patterns.forEach(({p, style}) => {
  const index = text.indexOf(p);
  if (index !== -1) {
    // +1 for 1-based index, string length for end index
    formats.push(`{startIndex: ${index + 1}, endIndex: ${index + 1 + p.length}, style: '${style}'}`);
  }
});
console.log(formats.join(',\n'));
