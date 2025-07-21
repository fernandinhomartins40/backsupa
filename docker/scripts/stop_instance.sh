#!/bin/bash
# stop_instance.sh - Parar uma instância Supabase específica
# Uso: ./stop_instance.sh <instance_id>

INSTANCE_ID=$1
DOCKER_DIR="/opt/supabase-instances"

if [ -z "$INSTANCE_ID" ]; then
    echo "Uso: $0 <instance_id>"
    echo ""
    echo "Instâncias em execução:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "_studio|_db|_kong" || echo "  Nenhuma instância em execução"
    exit 1
fi

INSTANCE_DIR="$DOCKER_DIR/$INSTANCE_ID"

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "❌ Erro: Instância '$INSTANCE_ID' não encontrada"
    exit 1
fi

if [ ! -f "$INSTANCE_DIR/docker-compose.yml" ]; then
    echo "❌ Erro: docker-compose.yml não encontrado para a instância '$INSTANCE_ID'"
    exit 1
fi

echo "🛑 Parando instância: $INSTANCE_ID"

cd "$INSTANCE_DIR"

# Verificar se está rodando
if ! docker-compose ps | grep "Up" > /dev/null 2>&1; then
    echo "⚠️  Instância já está parada"
    docker-compose ps
    exit 0
fi

# Parar serviços graciosamente
echo "⏳ Parando serviços..."
docker-compose stop

# Verificar se parou completamente
echo "📊 Status final dos serviços:"
docker-compose ps

# Atualizar status no banco master se disponível
if [ -n "$MASTER_DB_URL" ]; then
    psql "$MASTER_DB_URL" -c "
        UPDATE projects 
        SET status = 'stopped', updated_at = NOW() 
        WHERE instance_id = '$INSTANCE_ID'
    " 2>/dev/null
fi

echo ""
echo "✅ Instância '$INSTANCE_ID' parada com sucesso!"
echo ""
echo "💡 Para iniciar novamente:"
echo "   ./start_instance.sh $INSTANCE_ID"