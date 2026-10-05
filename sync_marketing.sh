#!/bin/bash
# ==============================================================================
# Script: sync_marketing.sh
# Finalidade: Montar o compartilhamento do Setor Marketing da VM de produção
#             (10.1.50.14) e sincronizar via rsync para o Proxmox (/Pool2/marketing_backup)
# Execução: Executar no nó Proxmox VE (10.1.50.212) como root.
# ==============================================================================

set -e

ENV_FILE="/root/.env"
SRC_SHARE="//10.1.50.14/SETOR MARKETING"
MOUNT_POINT="/mnt/win_marketing"
DEST_DIR="/Pool2/marketing_backup"
LOG_FILE="/var/log/sync_marketing.log"

echo "=========================================================="
echo " [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando rotina de sincronização do Marketing"
echo "=========================================================="

# 1. Validação de pré-requisitos
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ ERRO: Arquivo de credenciais $ENV_FILE não encontrado!"
    exit 1
fi

mkdir -p "$MOUNT_POINT"
mkdir -p "$DEST_DIR"

# 2. Montagem do compartilhamento CIFS (se não estiver montado)
if mountpoint -q "$MOUNT_POINT"; then
    echo "ℹ️  $MOUNT_POINT já está montado."
else
    echo "🔄 Montando $SRC_SHARE em $MOUNT_POINT..."
    mount -t cifs "$SRC_SHARE" "$MOUNT_POINT" \
        -o credentials="$ENV_FILE",iocharset=utf8,ro,vers=3.0
    echo "✅ Compartilhamento montado com sucesso."
fi

# 3. Execução do Rsync incremental
echo "🔄 Iniciando sincronização incremental com rsync..."
rsync -rhtvP --no-o --no-g --stats "$MOUNT_POINT/" "$DEST_DIR/" 2>&1 | tee -a "$LOG_FILE"

echo ""
echo "✅ Sincronização concluída com sucesso!"
echo "📁 Destino: $DEST_DIR"
echo "📄 Log gravado em: $LOG_FILE"

# 4. Desmontagem segura (opcional / comentar se preferir manter montado)
echo "🔄 Desmontando $MOUNT_POINT..."
umount "$MOUNT_POINT"
echo "✅ Desmontado com sucesso."
echo "=========================================================="
