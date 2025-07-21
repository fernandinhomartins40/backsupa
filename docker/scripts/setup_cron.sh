#!/bin/bash
# setup_cron.sh - Configurar jobs de backup automatizado
# Uso: ./setup_cron.sh [--backup-time="02:00"] [--cleanup-days=30]

BACKUP_TIME="02:00"
CLEANUP_DAYS="30"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRON_FILE="/etc/cron.d/supabase-backup"

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-time=*) BACKUP_TIME="${1#*=}"; shift ;;
        --cleanup-days=*) CLEANUP_DAYS="${1#*=}"; shift ;;
        *) echo "Argumento desconhecido: $1"; exit 1 ;;
    esac
done

echo "🕒 Configurando cron jobs para backup automático"
echo "   Horário do backup: $BACKUP_TIME diariamente"
echo "   Limpeza: backups > $CLEANUP_DAYS dias"
echo "   Diretório dos scripts: $SCRIPT_DIR"

# Verificar se scripts existem
BACKUP_SCRIPT="$SCRIPT_DIR/backup/backup_all.sh"
CLEANUP_SCRIPT="$SCRIPT_DIR/backup/cleanup_backups.sh"

if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "❌ Script de backup não encontrado: $BACKUP_SCRIPT"
    exit 1
fi

if [ ! -f "$CLEANUP_SCRIPT" ]; then
    echo "❌ Script de limpeza não encontrado: $CLEANUP_SCRIPT"
    exit 1
fi

# Verificar permissões
if [ ! -x "$BACKUP_SCRIPT" ]; then
    echo "🔧 Aplicando permissões de execução..."
    chmod +x "$BACKUP_SCRIPT"
fi

if [ ! -x "$CLEANUP_SCRIPT" ]; then
    chmod +x "$CLEANUP_SCRIPT"
fi

# Verificar se é root ou tem sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script precisa ser executado como root"
    echo "💡 Use: sudo $0"
    exit 1
fi

# Extrair hora e minuto
HOUR=$(echo "$BACKUP_TIME" | cut -d: -f1)
MINUTE=$(echo "$BACKUP_TIME" | cut -d: -f2)

# Validar formato
if ! [[ "$HOUR" =~ ^[0-9]{1,2}$ ]] || ! [[ "$MINUTE" =~ ^[0-9]{2}$ ]]; then
    echo "❌ Formato de horário inválido. Use HH:MM (ex: 02:00)"
    exit 1
fi

if [ "$HOUR" -gt 23 ] || [ "$MINUTE" -gt 59 ]; then
    echo "❌ Horário inválido. Use HH:MM (ex: 02:00)"
    exit 1
fi

# Criar arquivo de cron
echo "📝 Criando arquivo de cron: $CRON_FILE"

cat > "$CRON_FILE" << EOF
# Backup automático do Supabase Multi-Tenant
# Criado automaticamente em $(date)

# Variáveis de ambiente
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SHELL=/bin/bash

# Backup diário de todas as instâncias às $BACKUP_TIME
$MINUTE $HOUR * * * root $BACKUP_SCRIPT --compress --parallel=2 >/dev/null 2>&1

# Limpeza semanal de backups antigos (domingos às 03:00)
0 3 * * 0 root $CLEANUP_SCRIPT --days=$CLEANUP_DAYS >/dev/null 2>&1

# Verificação de espaço em disco (diariamente às 23:00)
0 23 * * * root $SCRIPT_DIR/backup/check_disk_space.sh >/dev/null 2>&1
EOF

# Aplicar permissões corretas
chmod 644 "$CRON_FILE"

# Recarregar crontab
if command -v systemctl > /dev/null 2>&1; then
    systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
elif command -v service > /dev/null 2>&1; then
    service cron reload 2>/dev/null || service crond reload 2>/dev/null || true
fi

echo "✅ Cron jobs configurados com sucesso!"
echo ""
echo "📋 Jobs configurados:"
echo "   Backup diário: $BACKUP_TIME (todas as instâncias, compressão habilitada)"
echo "   Limpeza semanal: Domingos às 03:00 (remove backups > $CLEANUP_DAYS dias)"
echo "   Verificação de espaço: Diariamente às 23:00"
echo ""
echo "🔍 Para verificar os jobs:"
echo "   cat $CRON_FILE"
echo ""
echo "📊 Para monitorar logs:"
echo "   tail -f /var/log/supabase-backup.log"
echo ""
echo "🎛️  Para modificar configurações:"
echo "   $0 --backup-time=\"03:30\" --cleanup-days=45"

# Criar script de verificação de espaço se não existir
DISK_CHECK_SCRIPT="$SCRIPT_DIR/backup/check_disk_space.sh"
if [ ! -f "$DISK_CHECK_SCRIPT" ]; then
    echo ""
    echo "📝 Criando script de verificação de espaço..."
    
    cat > "$DISK_CHECK_SCRIPT" << 'EOF'
#!/bin/bash
# check_disk_space.sh - Verificar espaço em disco e alertar se necessário

BACKUP_DIR="/opt/backups/instances"
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90
LOG_FILE="/var/log/supabase-backup.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

if [ ! -d "$BACKUP_DIR" ]; then
    exit 0
fi

# Verificar uso do disco
DISK_USAGE=$(df -h "$BACKUP_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_TOTAL=$(df -h "$BACKUP_DIR" | tail -1 | awk '{print $2}')
DISK_USED=$(df -h "$BACKUP_DIR" | tail -1 | awk '{print $3}')
DISK_AVAILABLE=$(df -h "$BACKUP_DIR" | tail -1 | awk '{print $4}')

if [ "$DISK_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
    log "🚨 CRÍTICO: Uso de disco $DISK_USAGE% (Usado: $DISK_USED / Total: $DISK_TOTAL)"
    
    # Webhook de emergência se configurado
    if [ -n "$EMERGENCY_WEBHOOK_URL" ]; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"🚨 CRÍTICO: Disco de backup em $DISK_USAGE% (Supabase)\"}" \
             "$EMERGENCY_WEBHOOK_URL" > /dev/null 2>&1 || true
    fi
    
elif [ "$DISK_USAGE" -ge "$WARNING_THRESHOLD" ]; then
    log "⚠️  AVISO: Uso de disco $DISK_USAGE% (Usado: $DISK_USED / Total: $DISK_TOTAL / Disponível: $DISK_AVAILABLE)"
fi

# Estatísticas dos backups
BACKUP_COUNT=$(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.gpg" \) | wc -l)
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)

log "📊 Estatísticas: $BACKUP_COUNT backups, $BACKUP_SIZE total, disco $DISK_USAGE% usado"
EOF
    
    chmod +x "$DISK_CHECK_SCRIPT"
    echo "   ✅ Script de verificação criado"
fi

echo ""
echo "🎉 Configuração do backup automático concluída!"
echo ""
echo "💡 Próximos passos recomendados:"
echo "   1. Configurar webhook para notificações (opcional):"
echo "      export BACKUP_WEBHOOK_URL='https://hooks.slack.com/...'"
echo "   2. Testar backup manual:"
echo "      $BACKUP_SCRIPT --compress"
echo "   3. Monitorar logs de backup:"
echo "      tail -f /var/log/supabase-backup.log"