#!/bin/bash
# delete_instance.sh - Deletar uma instância Supabase completamente
# Uso: ./delete_instance.sh <instance_id> [--force]

INSTANCE_ID=$1
FORCE_DELETE=""
DOCKER_DIR="/opt/supabase-instances"
BACKUP_DIR="/opt/backups/instances"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Parse argumentos
if [ "$2" = "--force" ]; then
    FORCE_DELETE="true"
fi

if [ -z "$INSTANCE_ID" ]; then
    echo "Uso: $0 <instance_id> [--force]"
    echo ""
    echo "Instâncias disponíveis:"
    ls -1 "$DOCKER_DIR" 2>/dev/null | grep -E "^[0-9]+_.*_[0-9]+$" || echo "  Nenhuma instância encontrada"
    exit 1
fi

INSTANCE_DIR="$DOCKER_DIR/$INSTANCE_ID"

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "❌ Erro: Instância '$INSTANCE_ID' não encontrada"
    exit 1
fi

# Confirmar deleção se não usar --force
if [ "$FORCE_DELETE" != "true" ]; then
    echo "⚠️  ATENÇÃO: Esta operação irá DELETAR PERMANENTEMENTE a instância '$INSTANCE_ID'"
    echo "   - Todos os dados serão perdidos"
    echo "   - Containers serão removidos"
    echo "   - Volumes serão removidos"
    echo "   - Configurações nginx serão removidas"
    echo ""
    read -p "Tem certeza? Digite 'DELETE' para confirmar: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        echo "❌ Operação cancelada"
        exit 1
    fi
fi

echo "🗑️  Deletando instância: $INSTANCE_ID"

# 1. Criar backup antes da deleção
echo "💾 Criando backup final..."
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR/$INSTANCE_ID"

if [ -f "$INSTANCE_DIR/docker-compose.yml" ]; then
    cd "$INSTANCE_DIR"
    
    # Backup do banco de dados se estiver rodando
    if docker-compose ps db | grep "Up" > /dev/null 2>&1; then
        echo "   Fazendo backup do banco de dados..."
        docker exec "${INSTANCE_ID}_db" pg_dump -U postgres postgres > "$BACKUP_DIR/$INSTANCE_ID/final_backup_${BACKUP_TIMESTAMP}.sql" 2>/dev/null || true
    fi
    
    # Backup dos volumes
    echo "   Fazendo backup dos volumes..."
    if docker volume ls | grep "${INSTANCE_ID}_" > /dev/null 2>&1; then
        docker run --rm \
            -v "${INSTANCE_ID}_storage_data:/data" \
            -v "$BACKUP_DIR/$INSTANCE_ID:/backup" \
            alpine tar czf "/backup/storage_final_${BACKUP_TIMESTAMP}.tar.gz" -C /data . 2>/dev/null || true
    fi
fi

# 2. Parar e remover containers
echo "🛑 Parando e removendo containers..."
cd "$INSTANCE_DIR"
docker-compose down -v --remove-orphans 2>/dev/null || true

# 3. Remover volumes Docker
echo "🗄️  Removendo volumes..."
docker volume ls -q | grep "^${INSTANCE_ID}_" | xargs -r docker volume rm 2>/dev/null || true

# 4. Remover rede Docker
echo "🌐 Removendo rede..."
docker network rm "${INSTANCE_ID}_network" 2>/dev/null || true

# 5. Remover configuração nginx
echo "⚙️  Removendo configuração nginx..."
# Extrair subdomínio do docker-compose
if [ -f "$INSTANCE_DIR/docker-compose.yml" ]; then
    SUBDOMAIN=$(grep -E "DEFAULT_PROJECT_NAME|container_name.*studio" "$INSTANCE_DIR/docker-compose.yml" | head -1 | sed 's/.*: *"\?//' | sed 's/"\?$//' | sed 's/_studio$//')
    if [ -n "$SUBDOMAIN" ] && [ -f "$NGINX_ENABLED_DIR/$SUBDOMAIN" ]; then
        rm -f "$NGINX_ENABLED_DIR/$SUBDOMAIN"
        rm -f "/etc/nginx/sites-available/$SUBDOMAIN"
        echo "   Configuração nginx removida: $SUBDOMAIN"
    fi
fi

# Recarregar nginx
if command -v nginx > /dev/null 2>&1; then
    nginx -t && nginx -s reload 2>/dev/null || true
fi

# 6. Remover diretório da instância
echo "📁 Removendo arquivos da instância..."
rm -rf "$INSTANCE_DIR"

# 7. Atualizar banco master
echo "💾 Atualizando banco master..."
if [ -n "$MASTER_DB_URL" ]; then
    psql "$MASTER_DB_URL" -c "
        UPDATE projects 
        SET status = 'deleted', updated_at = NOW(), deleted_at = NOW() 
        WHERE instance_id = '$INSTANCE_ID'
    " 2>/dev/null || true
fi

# 8. Limpar containers órfãos relacionados
echo "🧹 Limpando containers órfãos..."
docker container prune -f 2>/dev/null || true

echo ""
echo "✅ Instância '$INSTANCE_ID' deletada com sucesso!"
echo ""
echo "📦 Backup criado em:"
echo "   $BACKUP_DIR/$INSTANCE_ID/"
echo ""
echo "📊 Recursos liberados:"
echo "   - Containers Docker removidos"
echo "   - Volumes de dados removidos"
echo "   - Configuração nginx removida"
echo "   - Arquivos locais removidos"
echo ""
echo "💡 Para restaurar esta instância (se necessário):"
echo "   ./restore_instance.sh $INSTANCE_ID $BACKUP_DIR/$INSTANCE_ID/final_backup_${BACKUP_TIMESTAMP}.sql"