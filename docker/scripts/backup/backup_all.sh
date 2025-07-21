#!/bin/bash
# backup_all.sh - Fazer backup de todas as instâncias Supabase
# Uso: ./backup_all.sh [--compress] [--encrypt] [--parallel=N]

COMPRESS=""
ENCRYPT=""
PARALLEL="1"
DOCKER_DIR="/opt/supabase-instances"
BACKUP_DIR="/opt/backups/instances"
LOG_FILE="/var/log/supabase-backup.log"

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --compress) COMPRESS="--compress"; shift ;;
        --encrypt) ENCRYPT="--encrypt"; shift ;;
        --parallel=*) PARALLEL="${1#*=}"; shift ;;
        *) echo "Argumento desconhecido: $1"; exit 1 ;;
    esac
done

# Função de log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Criar diretório de log se não existir
mkdir -p "$(dirname "$LOG_FILE")"

log "🚀 Iniciando backup automático de todas as instâncias"
log "   Configurações:"
log "     Compressão: $([ -n "$COMPRESS" ] && echo "Habilitada" || echo "Desabilitada")"
log "     Criptografia: $([ -n "$ENCRYPT" ] && echo "Habilitada" || echo "Desabilitada")"
log "     Paralelismo: $PARALLEL processos"

# Verificar diretório de instâncias
if [ ! -d "$DOCKER_DIR" ]; then
    log "❌ Diretório de instâncias não encontrado: $DOCKER_DIR"
    exit 1
fi

# Obter lista de instâncias
INSTANCES=($(ls -1 "$DOCKER_DIR" 2>/dev/null | grep -E "^[0-9]+_.*_[0-9]+$" | sort))

if [ ${#INSTANCES[@]} -eq 0 ]; then
    log "📭 Nenhuma instância encontrada para backup"
    exit 0
fi

log "📋 Encontradas ${#INSTANCES[@]} instâncias para backup:"
for instance in "${INSTANCES[@]}"; do
    log "   - $instance"
done

# Função para backup de uma instância
backup_instance() {
    local instance=$1
    local script_dir="$(dirname "$(dirname "$0")")"
    
    log "💾 Iniciando backup da instância: $instance"
    
    if "$script_dir/backup/backup_instance.sh" "$instance" $COMPRESS $ENCRYPT >> "$LOG_FILE" 2>&1; then
        log "✅ Backup concluído: $instance"
        return 0
    else
        log "❌ Erro no backup: $instance"
        return 1
    fi
}

# Exportar função para uso com parallel
export -f backup_instance
export -f log
export LOG_FILE
export COMPRESS
export ENCRYPT

# Executar backups
START_TIME=$(date +%s)
FAILED_COUNT=0

if command -v parallel > /dev/null 2>&1 && [ "$PARALLEL" -gt 1 ]; then
    log "🔄 Executando backups em paralelo ($PARALLEL processos)..."
    
    # Usar GNU parallel se disponível
    printf '%s\n' "${INSTANCES[@]}" | parallel -j "$PARALLEL" backup_instance {}
    
    # Verificar resultados
    for instance in "${INSTANCES[@]}"; do
        if ! grep -q "✅ Backup concluído: $instance" "$LOG_FILE"; then
            ((FAILED_COUNT++))
        fi
    done
else
    log "🔄 Executando backups sequencialmente..."
    
    # Execução sequencial
    for instance in "${INSTANCES[@]}"; do
        if ! backup_instance "$instance"; then
            ((FAILED_COUNT++))
        fi
    done
fi

# Calcular estatísticas finais
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
SUCCESS_COUNT=$((${#INSTANCES[@]} - FAILED_COUNT))

log ""
log "📊 Resumo do backup automático:"
log "   Total de instâncias: ${#INSTANCES[@]}"
log "   Sucessos: $SUCCESS_COUNT"
log "   Falhas: $FAILED_COUNT"
log "   Duração total: ${DURATION}s ($(date -u -d @$DURATION +%H:%M:%S))"

# Calcular espaço usado pelos backups
if [ -d "$BACKUP_DIR" ]; then
    TOTAL_BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    log "   Espaço usado por backups: $TOTAL_BACKUP_SIZE"
fi

# Limpeza automática de backups antigos (mais de 30 dias)
log ""
log "🧹 Limpando backups antigos (>30 dias)..."
CLEANUP_COUNT=0

find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +30 -delete 2>/dev/null && {
    CLEANUP_COUNT=$(find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +30 | wc -l)
}

# Limpar diretórios vazios
find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null

if [ "$CLEANUP_COUNT" -gt 0 ]; then
    log "   🗑️  $CLEANUP_COUNT backups antigos removidos"
else
    log "   ✨ Nenhum backup antigo para remover"
fi

# Verificar espaço em disco
DISK_USAGE=$(df -h "$BACKUP_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    log "⚠️  AVISO: Uso de disco alto ($DISK_USAGE%)"
    log "   Considere limpar backups mais antigos ou aumentar espaço"
fi

# Enviar notificação se configurado
if [ -n "$BACKUP_WEBHOOK_URL" ]; then
    PAYLOAD=$(cat << EOF
{
    "text": "Backup Supabase Concluído",
    "attachments": [
        {
            "color": "$([ $FAILED_COUNT -eq 0 ] && echo "good" || echo "warning")",
            "fields": [
                {"title": "Total", "value": "${#INSTANCES[@]}", "short": true},
                {"title": "Sucessos", "value": "$SUCCESS_COUNT", "short": true},
                {"title": "Falhas", "value": "$FAILED_COUNT", "short": true},
                {"title": "Duração", "value": "${DURATION}s", "short": true}
            ]
        }
    ]
}
EOF
    )
    
    curl -X POST -H "Content-Type: application/json" \
         -d "$PAYLOAD" "$BACKUP_WEBHOOK_URL" > /dev/null 2>&1 || true
fi

# Status de saída
if [ $FAILED_COUNT -eq 0 ]; then
    log "🎉 Backup automático concluído com sucesso!"
    exit 0
else
    log "⚠️  Backup automático concluído com $FAILED_COUNT falhas"
    exit 1
fi