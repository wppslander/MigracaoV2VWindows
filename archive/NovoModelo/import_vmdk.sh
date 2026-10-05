#!/bin/bash
# Script de automação para importação de VMDK no Proxmox

echo "=== Importação V2V (VMware -> Proxmox) ==="
echo ""
echo "Listando arquivos disponíveis em /root/migracao_temp/:"
ls -lh /root/migracao_temp/*.vmdk 2>/dev/null || echo "Nenhum arquivo .vmdk encontrado ainda em /root/migracao_temp/."
echo ""

read -p "Digite o ID da Máquina Virtual de destino (ex: 200): " VM_ID
read -p "Digite o caminho completo absoluto para o arquivo .vmdk: " VMDK_PATH
read -p "Qual o storage de destino? [local-lvm]: " STORAGE_DESTINO

# Valor padrão para storage (caso enter seja pressionado vazio)
STORAGE_DESTINO=${STORAGE_DESTINO:-local-lvm}

if [ -z "$VM_ID" ] || [ -z "$VMDK_PATH" ]; then
    echo "Erro: VM_ID ou caminho do disco não informados."
    exit 1
fi

if [ ! -f "$VMDK_PATH" ]; then
    echo "Aviso: O arquivo $VMDK_PATH não pôde ser verificado neste diretório."
    echo "No entanto, prosseguiremos assumindo que você digitou o caminho correto (ex. NFS)."
fi

echo ""
echo "Iniciando a importação do disco..."
echo "Comando gerado: qm importdisk $VM_ID \"$VMDK_PATH\" $STORAGE_DESTINO --format qcow2"
echo ""

qm importdisk "$VM_ID" "$VMDK_PATH" "$STORAGE_DESTINO" --format qcow2

if [ $? -eq 0 ]; then
    echo ""
    echo "[SUCESSO] Importação concluída! Vá para a interface do Proxmox,"
    echo "abra a VM $VM_ID -> Hardware, e faça o Attach (adicionar) do disco 'Unused' criado."
else
    echo ""
    echo "[ERRO] Erro durante a importação. Verifique os logs do qm e tente novamente."
fi
