#!/bin/bash
# backup_instance.sh - Fazer backup completo de uma instância Supabase
# Uso: ./backup_instance.sh <instance_id> [--compress] [--encrypt]

INSTANCE_ID=$1
COMPRESS=""
ENCRYPT=""
DOCKER_DIR="/opt/supabase-instances"
BACKUP_DIR="/opt/backups/instances"
DATE=$(date +%Y%m%d_%H%M%S)

# Parse argumentos
while [[ $# -gt 1 ]]; do
    case $2 in
        --compress) COMPRESS="true"; shift ;;
        --encrypt) ENCRYPT="true"; shift ;;
        *) echo "Argumento desconhecido: $2"; exit 1 ;;
    esac
done

if [ -z "$INSTANCE_ID" ]; then
    echo "Uso: $0 <instance_id> [--compress] [--encrypt]"
    echo ""
    echo "Instâncias disponíveis:"
    ls -1 "$DOCKER_DIR" 2>/dev/null | grep -E "^[0-9]+_.*_[0-9]+$" || echo "  Nenhuma instância encontrada"
    exit 1
fi

INSTANCE_DIR="$DOCKER_DIR/$INSTANCE_ID"
BACKUP_INSTANCE_DIR="$BACKUP_DIR/$INSTANCE_ID"

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "❌ Erro: Instância '$INSTANCE_ID' não encontrada"
    exit 1
fi

echo "💾 Iniciando backup da instância: $INSTANCE_ID"
echo "   Data/Hora: $(date)"
echo "   Destino: $BACKUP_INSTANCE_DIR/$DATE"

# Criar diretório de backup
mkdir -p "$BACKUP_INSTANCE_DIR/$DATE"

# Verificar se a instância está rodando
cd "$INSTANCE_DIR"
IS_RUNNING=""
if docker-compose ps studio 2>/dev/null | grep "Up" > /dev/null; then
    IS_RUNNING="true"
    echo "   Status: Instância está rodando"
else
    echo "   Status: Instância está parada"
fi

# 1. Backup do banco de dados PostgreSQL
echo "🗄️  Fazendo backup do banco de dados..."
if [ "$IS_RUNNING" = "true" ]; then
    # Instância rodando - usar docker exec
    docker exec "${INSTANCE_ID}_db" pg_dump -U postgres -c --if-exists postgres > "$BACKUP_INSTANCE_DIR/$DATE/database.sql"
    if [ $? -eq 0 ]; then
        echo "   ✅ Backup do banco concluído"
        DB_SIZE=$(du -h "$BACKUP_INSTANCE_DIR/$DATE/database.sql" | cut -f1)
        echo "   📊 Tamanho: $DB_SIZE"
    else
        echo "   ❌ Erro no backup do banco"
        exit 1
    fi
else
    # Instância parada - iniciar temporariamente só o DB
    echo "   Iniciando banco temporariamente para backup..."
    docker-compose up -d db
    sleep 10
    
    docker exec "${INSTANCE_ID}_db" pg_dump -U postgres -c --if-exists postgres > "$BACKUP_INSTANCE_DIR/$DATE/database.sql"
    
    # Parar o banco novamente
    docker-compose stop db
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Backup do banco concluído"
    else
        echo "   ❌ Erro no backup do banco"
        exit 1
    fi
fi

# 2. Backup dos volumes Docker
echo "📦 Fazendo backup dos volumes..."

# Volume de dados do storage
if docker volume ls | grep "${INSTANCE_ID}_storage_data" > /dev/null; then
    echo "   Backup do volume de storage..."
    docker run --rm \
        -v "${INSTANCE_ID}_storage_data:/data:ro" \
        -v "$BACKUP_INSTANCE_DIR/$DATE:/backup" \
        alpine tar czf /backup/storage_data.tar.gz -C /data . 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Backup do storage concluído"
        STORAGE_SIZE=$(du -h "$BACKUP_INSTANCE_DIR/$DATE/storage_data.tar.gz" | cut -f1)
        echo "   📊 Tamanho: $STORAGE_SIZE"
    fi
fi

# Volume de dados do banco
if docker volume ls | grep "${INSTANCE_ID}_db_data" > /dev/null; then
    echo "   Backup do volume do banco..."
    docker run --rm \
        -v "${INSTANCE_ID}_db_data:/data:ro" \
        -v "$BACKUP_INSTANCE_DIR/$DATE:/backup" \
        alpine tar czf /backup/db_data.tar.gz -C /data . 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Backup dos dados do banco concluído"
        DB_VOL_SIZE=$(du -h "$BACKUP_INSTANCE_DIR/$DATE/db_data.tar.gz" | cut -f1)
        echo "   📊 Tamanho: $DB_VOL_SIZE"
    fi
fi

# 3. Backup das configurações
echo "⚙️  Fazendo backup das configurações..."
cp -r "$INSTANCE_DIR/volumes" "$BACKUP_INSTANCE_DIR/$DATE/" 2>/dev/null
cp "$INSTANCE_DIR/docker-compose.yml" "$BACKUP_INSTANCE_DIR/$DATE/" 2>/dev/null
cp "$INSTANCE_DIR/.env" "$BACKUP_INSTANCE_DIR/$DATE/" 2>/dev/null || true

# Criar arquivo de metadados
cat > "$BACKUP_INSTANCE_DIR/$DATE/backup_metadata.json" << EOF
{
    "instance_id": "$INSTANCE_ID",
    "backup_date": "$(date -Iseconds)",
    "backup_version": "1.0",
    "instance_status": "$([ "$IS_RUNNING" = "true" ] && echo "running" || echo "stopped")",
    "backup_type": "full",
    "compressed": $([ "$COMPRESS" = "true" ] && echo "true" || echo "false"),
    "encrypted": $([ "$ENCRYPT" = "true" ] && echo "true" || echo "false"),
    "backup_size": "$(du -sh "$BACKUP_INSTANCE_DIR/$DATE" | cut -f1)"
}
EOF

echo "   ✅ Configurações e metadados salvos"

# 4. Compactar se solicitado
if [ "$COMPRESS" = "true" ]; then
    echo "🗜️  Compactando backup..."
    cd "$BACKUP_INSTANCE_DIR"
    tar czf "${INSTANCE_ID}_${DATE}.tar.gz" "$DATE"
    
    if [ $? -eq 0 ]; then
        COMPRESSED_SIZE=$(du -h "${INSTANCE_ID}_${DATE}.tar.gz" | cut -f1)
        echo "   ✅ Backup compactado: $COMPRESSED_SIZE"
        
        # Remover diretório não compactado
        rm -rf "$DATE"
        BACKUP_FILE="${INSTANCE_ID}_${DATE}.tar.gz"
    else
        echo "   ❌ Erro na compactação"
        BACKUP_FILE="$DATE"
    fi
else
    BACKUP_FILE="$DATE"
fi

# 5. Criptografar se solicitado
if [ "$ENCRYPT" = "true" ]; then
    echo "🔐 Criptografando backup..."
    
    if command -v gpg > /dev/null 2>&1; then
        cd "$BACKUP_INSTANCE_DIR"
        gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
            --s2k-digest-algo SHA512 --s2k-count 65536 \
            --symmetric --output "${BACKUP_FILE}.gpg" "$BACKUP_FILE"
        
        if [ $? -eq 0 ]; then
            echo "   ✅ Backup criptografado"
            rm "$BACKUP_FILE"
            BACKUP_FILE="${BACKUP_FILE}.gpg"
        else
            echo "   ❌ Erro na criptografia"
        fi
    else
        echo "   ⚠️  GPG não encontrado, pulando criptografia"
    fi
fi

# 6. Registrar backup no banco master (se disponível)
if [ -n "$MASTER_DB_URL" ]; then
    echo "💾 Registrando backup no banco master..."
    psql "$MASTER_DB_URL" -c "
        INSERT INTO backups (instance_id, backup_date, backup_path, backup_size, backup_type, status)
        VALUES (
            '$INSTANCE_ID',
            NOW(),
            '$BACKUP_INSTANCE_DIR/$BACKUP_FILE',
            '$(du -b "$BACKUP_INSTANCE_DIR/$BACKUP_FILE" | cut -f1)',
            'full',
            'completed'
        )
    " 2>/dev/null || echo "   ⚠️  Não foi possível registrar no banco master"
fi

# 7. Calcular tamanho final e estatísticas
FINAL_SIZE=$(du -sh "$BACKUP_INSTANCE_DIR/$BACKUP_FILE" | cut -f1)
TOTAL_FILES=$(find "$BACKUP_INSTANCE_DIR/$BACKUP_FILE" -type f 2>/dev/null | wc -l)

echo ""
echo "🎉 Backup concluído com sucesso!"
echo "📁 Localização: $BACKUP_INSTANCE_DIR/$BACKUP_FILE"
echo "📊 Tamanho final: $FINAL_SIZE"
echo "📄 Arquivos: $TOTAL_FILES"
echo "⏱️  Duração: $(($(date +%s) - $(date -d "$DATE" +%s 2>/dev/null || echo 0))) segundos"
echo ""
echo "💡 Para restaurar este backup:"
echo "   ./restore_instance.sh $INSTANCE_ID $BACKUP_INSTANCE_DIR/$BACKUP_FILE"
echo ""
echo "🧹 Para limpar backups antigos:"
echo "   ./cleanup_backups.sh --instance=$INSTANCE_ID --days=30"