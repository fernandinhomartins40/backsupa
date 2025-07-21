#!/bin/bash
# restore_instance.sh - Restaurar uma instância Supabase a partir de backup
# Uso: ./restore_instance.sh <instance_id> <backup_file> [--force]

INSTANCE_ID=$1
BACKUP_FILE=$2
FORCE=""
DOCKER_DIR="/opt/supabase-instances"
TEMP_RESTORE_DIR="/tmp/supabase_restore_$$"

# Parse argumentos
if [ "$3" = "--force" ]; then
    FORCE="true"
fi

if [ -z "$INSTANCE_ID" ] || [ -z "$BACKUP_FILE" ]; then
    echo "Uso: $0 <instance_id> <backup_file> [--force]"
    echo ""
    echo "Exemplos:"
    echo "  $0 123_myapp_1640995200 /opt/backups/instances/backup.tar.gz"
    echo "  $0 123_myapp_1640995200 /opt/backups/instances/backup.tar.gz --force"
    exit 1
fi

INSTANCE_DIR="$DOCKER_DIR/$INSTANCE_ID"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Erro: Arquivo de backup não encontrado: $BACKUP_FILE"
    exit 1
fi

# Verificar se instância já existe
if [ -d "$INSTANCE_DIR" ] && [ "$FORCE" != "true" ]; then
    echo "⚠️  ATENÇÃO: Instância '$INSTANCE_ID' já existe!"
    echo "   Esta operação irá SOBRESCREVER todos os dados existentes"
    echo "   Use --force para confirmar ou escolha outro instance_id"
    echo ""
    read -p "Continuar mesmo assim? (digite 'YES' para confirmar): " confirmation
    
    if [ "$confirmation" != "YES" ]; then
        echo "❌ Operação cancelada"
        exit 1
    fi
fi

echo "🔄 Iniciando restauração da instância: $INSTANCE_ID"
echo "   Backup: $BACKUP_FILE"
echo "   Data/Hora: $(date)"

# Criar diretório temporário
mkdir -p "$TEMP_RESTORE_DIR"
trap "rm -rf $TEMP_RESTORE_DIR" EXIT

# 1. Parar instância se estiver rodando
if [ -d "$INSTANCE_DIR" ]; then
    echo "🛑 Parando instância existente..."
    cd "$INSTANCE_DIR"
    if [ -f "docker-compose.yml" ]; then
        docker-compose down -v --remove-orphans 2>/dev/null || true
    fi
    
    # Remover volumes existentes
    docker volume ls -q | grep "^${INSTANCE_ID}_" | xargs -r docker volume rm 2>/dev/null || true
fi

# 2. Extrair backup
echo "📦 Extraindo backup..."
cd "$TEMP_RESTORE_DIR"

# Detectar tipo de arquivo
if [[ "$BACKUP_FILE" == *.gpg ]]; then
    echo "🔓 Descriptografando backup..."
    if ! gpg --decrypt "$BACKUP_FILE" > backup.tar.gz 2>/dev/null; then
        echo "❌ Erro na descriptografia. Verifique a senha."
        exit 1
    fi
    BACKUP_FILE="backup.tar.gz"
fi

if [[ "$BACKUP_FILE" == *.tar.gz ]] || [[ "$BACKUP_FILE" == *.tgz ]]; then
    echo "   Extraindo arquivo compactado..."
    tar xzf "$BACKUP_FILE"
    BACKUP_DIR=$(ls -1 | head -1)
else
    echo "   Copiando diretório de backup..."
    cp -r "$BACKUP_FILE" .
    BACKUP_DIR=$(basename "$BACKUP_FILE")
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Erro: Estrutura de backup inválida"
    exit 1
fi

echo "   ✅ Backup extraído"

# 3. Verificar integridade do backup
echo "🔍 Verificando integridade do backup..."
if [ ! -f "$BACKUP_DIR/database.sql" ]; then
    echo "❌ Erro: Backup do banco de dados não encontrado"
    exit 1
fi

if [ ! -f "$BACKUP_DIR/docker-compose.yml" ]; then
    echo "❌ Erro: Configuração docker-compose não encontrada"
    exit 1
fi

# Verificar metadados se disponível
if [ -f "$BACKUP_DIR/backup_metadata.json" ]; then
    BACKUP_VERSION=$(grep '"backup_version"' "$BACKUP_DIR/backup_metadata.json" | cut -d'"' -f4)
    BACKUP_DATE=$(grep '"backup_date"' "$BACKUP_DIR/backup_metadata.json" | cut -d'"' -f4)
    echo "   📋 Versão do backup: $BACKUP_VERSION"
    echo "   📅 Data do backup: $BACKUP_DATE"
fi

echo "   ✅ Backup válido"

# 4. Recriar estrutura da instância
echo "📁 Recriando estrutura da instância..."
mkdir -p "$INSTANCE_DIR"

# Copiar configurações
cp -r "$BACKUP_DIR/volumes" "$INSTANCE_DIR/" 2>/dev/null || true
cp "$BACKUP_DIR/docker-compose.yml" "$INSTANCE_DIR/"
cp "$BACKUP_DIR/.env" "$INSTANCE_DIR/" 2>/dev/null || true

echo "   ✅ Estrutura recriada"

# 5. Recriar volumes Docker
echo "🗄️  Recriando volumes Docker..."
cd "$INSTANCE_DIR"

# Extrair nomes dos volumes do docker-compose
STORAGE_VOLUME="${INSTANCE_ID}_storage_data"
DB_VOLUME="${INSTANCE_ID}_db_data"

# Criar volumes
docker volume create "$STORAGE_VOLUME" > /dev/null
docker volume create "$DB_VOLUME" > /dev/null

# Restaurar dados do storage se disponível
if [ -f "$TEMP_RESTORE_DIR/$BACKUP_DIR/storage_data.tar.gz" ]; then
    echo "   Restaurando dados do storage..."
    docker run --rm \
        -v "$STORAGE_VOLUME:/data" \
        -v "$TEMP_RESTORE_DIR/$BACKUP_DIR:/backup" \
        alpine sh -c "cd /data && tar xzf /backup/storage_data.tar.gz"
fi

# Restaurar dados do banco se disponível
if [ -f "$TEMP_RESTORE_DIR/$BACKUP_DIR/db_data.tar.gz" ]; then
    echo "   Restaurando dados do banco..."
    docker run --rm \
        -v "$DB_VOLUME:/data" \
        -v "$TEMP_RESTORE_DIR/$BACKUP_DIR:/backup" \
        alpine sh -c "cd /data && tar xzf /backup/db_data.tar.gz"
fi

echo "   ✅ Volumes restaurados"

# 6. Iniciar instância
echo "🚀 Iniciando instância..."
docker-compose up -d db

# Aguardar banco ficar pronto
echo "⏳ Aguardando banco de dados..."
for i in {1..60}; do
    if docker exec "${INSTANCE_ID}_db" pg_isready -U postgres > /dev/null 2>&1; then
        echo "   ✅ Banco de dados pronto"
        break
    fi
    
    if [ $i -eq 60 ]; then
        echo "   ❌ Timeout aguardando banco de dados"
        exit 1
    fi
    
    echo "   Tentativa $i/60..."
    sleep 2
done

# 7. Restaurar schema e dados do banco
echo "💾 Restaurando banco de dados..."
if docker exec -i "${INSTANCE_ID}_db" psql -U postgres -d postgres < "$TEMP_RESTORE_DIR/$BACKUP_DIR/database.sql" > /dev/null 2>&1; then
    echo "   ✅ Banco de dados restaurado"
else
    echo "   ⚠️  Possíveis erros na restauração do banco (verifique logs)"
fi

# 8. Iniciar todos os serviços
echo "🎯 Iniciando todos os serviços..."
docker-compose up -d

# Aguardar serviços ficarem prontos
echo "⏳ Aguardando serviços..."
sleep 10

# Verificar se Studio está acessível
STUDIO_PORT=$(docker-compose ps studio | grep "studio" | sed 's/.*:\([0-9]*\)->.*/\1/')
if [ -n "$STUDIO_PORT" ]; then
    for i in {1..30}; do
        if curl -s "http://localhost:$STUDIO_PORT" > /dev/null 2>&1; then
            echo "   ✅ Studio acessível em: http://localhost:$STUDIO_PORT"
            break
        fi
        
        if [ $i -eq 30 ]; then
            echo "   ⚠️  Studio pode não estar totalmente pronto"
        fi
        
        sleep 2
    done
fi

# 9. Atualizar nginx se necessário
echo "🌐 Configurando nginx..."
SUBDOMAIN=$(grep -E "DEFAULT_PROJECT_NAME|container_name.*studio" docker-compose.yml | head -1 | sed 's/.*: *"\?//' | sed 's/"\?$//' | sed 's/_studio$//')
if [ -n "$SUBDOMAIN" ]; then
    "$(dirname "$0")/../nginx-manager.sh" add_route "$SUBDOMAIN" "$STUDIO_PORT" 2>/dev/null || true
fi

# 10. Atualizar banco master se disponível
if [ -n "$MASTER_DB_URL" ]; then
    echo "💾 Atualizando banco master..."
    psql "$MASTER_DB_URL" -c "
        UPDATE projects 
        SET status = 'running', updated_at = NOW() 
        WHERE instance_id = '$INSTANCE_ID'
    " 2>/dev/null || echo "   ⚠️  Não foi possível atualizar banco master"
fi

# 11. Verificar integridade final
echo "🔍 Verificação final..."
FINAL_STATUS="✅ SUCESSO"

# Verificar containers
if ! docker-compose ps | grep "Up" > /dev/null; then
    FINAL_STATUS="⚠️  PARCIAL - Alguns serviços podem não estar rodando"
fi

# Verificar conectividade do banco
if ! docker exec "${INSTANCE_ID}_db" pg_isready -U postgres > /dev/null 2>&1; then
    FINAL_STATUS="❌ FALHA - Banco de dados não está respondendo"
fi

echo ""
echo "🎉 Restauração concluída!"
echo "   Status: $FINAL_STATUS"
echo "   Instance ID: $INSTANCE_ID"
if [ -n "$STUDIO_PORT" ]; then
    echo "   Studio: http://localhost:$STUDIO_PORT"
fi
echo "   Diretório: $INSTANCE_DIR"
echo ""
echo "📊 Status dos serviços:"
docker-compose ps
echo ""
echo "💡 Comandos úteis:"
echo "   Verificar logs:     docker-compose logs"
echo "   Parar instância:    ./stop_instance.sh $INSTANCE_ID"
echo "   Deletar instância:  ./delete_instance.sh $INSTANCE_ID"