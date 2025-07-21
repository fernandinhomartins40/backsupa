#!/bin/bash
# cleanup_backups.sh - Limpar backups antigos automaticamente
# Uso: ./cleanup_backups.sh [--days=30] [--instance=instance_id] [--dry-run]

DAYS="30"
INSTANCE=""
DRY_RUN=""
BACKUP_DIR="/opt/backups/instances"

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --days=*) DAYS="${1#*=}"; shift ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --dry-run) DRY_RUN="true"; shift ;;
        *) echo "Argumento desconhecido: $1"; exit 1 ;;
    esac
done

echo "🧹 Limpeza de backups antigos"
echo "   Dias de retenção: $DAYS"
echo "   Instância específica: $([ -n "$INSTANCE" ] && echo "$INSTANCE" || echo "Todas")"
echo "   Modo de teste: $([ "$DRY_RUN" = "true" ] && echo "Sim" || echo "Não")"
echo ""

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Diretório de backups não encontrado: $BACKUP_DIR"
    exit 1
fi

# Função para converter bytes em formato legível
human_readable() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(($bytes / 1073741824))GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(($bytes / 1048576))MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(($bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}

# Encontrar backups para remover
TOTAL_SIZE=0
TOTAL_FILES=0

if [ -n "$INSTANCE" ]; then
    SEARCH_PATH="$BACKUP_DIR/$INSTANCE"
else
    SEARCH_PATH="$BACKUP_DIR"
fi

if [ ! -d "$SEARCH_PATH" ]; then
    echo "📭 Nenhum backup encontrado para limpar"
    exit 0
fi

echo "🔍 Analisando backups antigos..."

# Encontrar arquivos antigos
OLD_FILES=()
while IFS= read -r -d '' file; do
    OLD_FILES+=("$file")
    SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    TOTAL_FILES=$((TOTAL_FILES + 1))
done < <(find "$SEARCH_PATH" -type f \( -name "*.tar.gz" -o -name "*.gpg" \) -mtime +$DAYS -print0 2>/dev/null)

# Encontrar diretórios antigos (backups não compactados)
OLD_DIRS=()
while IFS= read -r -d '' dir; do
    if [[ "$(basename "$dir")" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        OLD_DIRS+=("$dir")
        SIZE=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        TOTAL_FILES=$((TOTAL_FILES + 1))
    fi
done < <(find "$SEARCH_PATH" -type d -mtime +$DAYS -print0 2>/dev/null)

if [ $TOTAL_FILES -eq 0 ]; then
    echo "✨ Nenhum backup antigo encontrado"
    exit 0
fi

echo "📊 Backups encontrados para remoção:"
echo "   Arquivos/Diretórios: $TOTAL_FILES"
echo "   Espaço a liberar: $(human_readable $TOTAL_SIZE)"
echo ""

if [ "$DRY_RUN" = "true" ]; then
    echo "🔍 MODO DE TESTE - Arquivos que seriam removidos:"
    for file in "${OLD_FILES[@]}"; do
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        echo "   📄 $file ($(human_readable $SIZE))"
    done
    for dir in "${OLD_DIRS[@]}"; do
        SIZE=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)
        echo "   📁 $dir ($(human_readable $SIZE))"
    done
    echo ""
    echo "💡 Execute sem --dry-run para realizar a limpeza"
    exit 0
fi

# Confirmação se não for modo automático
if [ -t 0 ]; then  # Se executando em terminal interativo
    echo "⚠️  Esta operação irá DELETAR PERMANENTEMENTE $TOTAL_FILES backups"
    echo "   Espaço a liberar: $(human_readable $TOTAL_SIZE)"
    echo ""
    read -p "Continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        echo "❌ Operação cancelada"
        exit 1
    fi
fi

# Executar limpeza
echo "🗑️  Removendo backups antigos..."

REMOVED_COUNT=0
REMOVED_SIZE=0

# Remover arquivos
for file in "${OLD_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        
        if rm "$file" 2>/dev/null; then
            echo "   ✅ Removido: $(basename "$file") ($(human_readable $SIZE))"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
            REMOVED_SIZE=$((REMOVED_SIZE + SIZE))
        else
            echo "   ❌ Erro ao remover: $(basename "$file")"
        fi
    fi
done

# Remover diretórios
for dir in "${OLD_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        SIZE=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)
        
        if rm -rf "$dir" 2>/dev/null; then
            echo "   ✅ Removido: $(basename "$dir") ($(human_readable $SIZE))"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
            REMOVED_SIZE=$((REMOVED_SIZE + SIZE))
        else
            echo "   ❌ Erro ao remover: $(basename "$dir")"
        fi
    fi
done

# Remover diretórios vazios
find "$SEARCH_PATH" -type d -empty -delete 2>/dev/null

echo ""
echo "📊 Limpeza concluída:"
echo "   Itens removidos: $REMOVED_COUNT de $TOTAL_FILES"
echo "   Espaço liberado: $(human_readable $REMOVED_SIZE)"

# Calcular espaço restante
REMAINING_SIZE=0
if [ -d "$BACKUP_DIR" ]; then
    REMAINING_SIZE=$(du -sb "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo 0)
fi

echo "   Espaço total dos backups: $(human_readable $REMAINING_SIZE)"

# Verificar uso do disco
DISK_USAGE=$(df -h "$BACKUP_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
echo "   Uso do disco: $DISK_USAGE%"

if [ "$DISK_USAGE" -gt 80 ]; then
    echo ""
    echo "⚠️  AVISO: Uso do disco ainda alto ($DISK_USAGE%)"
    echo "💡 Considere:"
    echo "   - Reduzir período de retenção (--days)"
    echo "   - Comprimir backups antigos"
    echo "   - Mover backups para armazenamento externo"
fi

echo ""
echo "✅ Limpeza finalizada!"