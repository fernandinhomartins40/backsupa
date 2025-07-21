#!/bin/bash
# start_instance.sh - Iniciar uma instância Supabase específica
# Uso: ./start_instance.sh <instance_id>

INSTANCE_ID=$1
DOCKER_DIR="/opt/supabase-instances"

if [ -z "$INSTANCE_ID" ]; then
    echo "Uso: $0 <instance_id>"
    echo ""
    echo "Instâncias disponíveis:"
    ls -1 "$DOCKER_DIR" 2>/dev/null | grep -E "^[0-9]+_.*_[0-9]+$" || echo "  Nenhuma instância encontrada"
    exit 1
fi

INSTANCE_DIR="$DOCKER_DIR/$INSTANCE_ID"

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "❌ Erro: Instância '$INSTANCE_ID' não encontrada"
    echo "Diretório: $INSTANCE_DIR"
    exit 1
fi

if [ ! -f "$INSTANCE_DIR/docker-compose.yml" ]; then
    echo "❌ Erro: docker-compose.yml não encontrado para a instância '$INSTANCE_ID'"
    exit 1
fi

echo "🚀 Iniciando instância: $INSTANCE_ID"

cd "$INSTANCE_DIR"

# Verificar se já está rodando
if docker-compose ps | grep "Up" > /dev/null 2>&1; then
    echo "⚠️  Instância já está rodando"
    docker-compose ps
    exit 0
fi

# Iniciar serviços
docker-compose up -d

# Aguardar serviços ficarem prontos
echo "⏳ Aguardando serviços ficarem prontos..."
sleep 5

# Verificar status
echo "📊 Status dos serviços:"
docker-compose ps

# Verificar se Studio está acessível
STUDIO_PORT=$(docker-compose ps studio | grep "studio" | sed 's/.*:\([0-9]*\)->.*/\1/')
if [ -n "$STUDIO_PORT" ]; then
    echo ""
    echo "🌐 Verificando conectividade..."
    for i in {1..30}; do
        if curl -s "http://localhost:$STUDIO_PORT" > /dev/null 2>&1; then
            echo "✅ Studio acessível em: http://localhost:$STUDIO_PORT"
            break
        fi
        echo "   Tentativa $i/30..."
        sleep 2
    done
fi

# Atualizar status no banco master se disponível
if [ -n "$MASTER_DB_URL" ]; then
    psql "$MASTER_DB_URL" -c "
        UPDATE projects 
        SET status = 'running', updated_at = NOW() 
        WHERE instance_id = '$INSTANCE_ID'
    " 2>/dev/null
fi

echo ""
echo "✅ Instância '$INSTANCE_ID' iniciada com sucesso!"