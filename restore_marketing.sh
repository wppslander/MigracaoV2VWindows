#!/bin/bash
# ==============================================================================
# Script: restore_marketing.sh
# Finalidade: Restaurar o backup do Setor Marketing (/Pool2/marketing_backup)
#             para a nova unidade F:\Marketing da VM (//10.1.50.14/Marketing)
# Execução: Executar no nó Proxmox VE (10.1.50.212) como root.
# ==============================================================================

set -e

ENV_FILE="/root/.env"
DEST_SHARE="//10.1.50.14/Marketing"
MOUNT_POINT="/mnt/win_marketing_dest"
SRC_DIR="/Pool2/marketing_backup"
LOG_FILE="/var/log/restore_marketing.log"

echo "==========================================================" | tee -a "$LOG_FILE"
echo " [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando restauracao do Marketing para a VM" | tee -a "$LOG_FILE"
echo "==========================================================" | tee -a "$LOG_FILE"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ ERRO: Arquivo $ENV_FILE nao encontrado!" | tee -a "$LOG_FILE"
    exit 1
fi

mkdir -p "$MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT"; then
    echo "ℹ️  $MOUNT_POINT ja esta montado." | tee -a "$LOG_FILE"
else
    echo "🔄 Montando $DEST_SHARE em $MOUNT_POINT..." | tee -a "$LOG_FILE"
    mount -t cifs "$DEST_SHARE" "$MOUNT_POINT" \
        -o credentials="$ENV_FILE",iocharset=utf8,vers=3.0
    echo "✅ Compartilhamento montado com sucesso." | tee -a "$LOG_FILE"
fi

echo "🔄 Iniciando copia com rsync..." | tee -a "$LOG_FILE"
rsync -rhtvP --no-o --no-g --stats "$SRC_DIR/" "$MOUNT_POINT/" 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "✅ Restauracao concluida com sucesso!" | tee -a "$LOG_FILE"
echo "📁 Destino: $DEST_SHARE (F:\\Marketing)" | tee -a "$LOG_FILE"
echo "📄 Log: $LOG_FILE" | tee -a "$LOG_FILE"

echo "🔄 Desmontando $MOUNT_POINT..." | tee -a "$LOG_FILE"
umount "$MOUNT_POINT"
echo "✅ Desmontado de forma limpa." | tee -a "$LOG_FILE"
echo "==========================================================" | tee -a "$LOG_FILE"
