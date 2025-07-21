#!/bin/bash
# update_monitoring_simple.sh - Auto-discovery simplificado baseado na especificação
# Gerar instances.json baseado em containers rodando

MONITORING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCES_FILE="$MONITORING_DIR/instances.json"
MASTER_DB_URL="${MASTER_DB_URL:-postgresql://postgres:postgres@localhost:5432/supabase_master}"

# Função de log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DISCOVERY] $1"
}

log "🔍 Iniciando auto-discovery de instâncias Kong..."

# Gerar targets baseado em containers Kong rodando
{
    echo "["
    first=true
    
    docker ps --format "{{.Names}}" | grep "_kong$" | while read container; do
        if [ "$first" = false ]; then
            echo ","
        fi
        first=false
        
        # Extrair instance_id removendo sufixo _kong
        instance=${container%_kong}
        
        # Obter porta do Kong
        port=$(docker port "$container" 8000/tcp 2>/dev/null | cut -d: -f2)
        
        if [ -n "$port" ]; then
            # Obter informações do banco master se disponível
            project_name="unknown"
            org_id="unknown"
            
            if command -v psql > /dev/null 2>&1 && [ -n "$MASTER_DB_URL" ]; then
                project_info=$(psql "$MASTER_DB_URL" -t -c "
                    SELECT name, organization_id 
                    FROM projects 
                    WHERE instance_id = '$instance' 
                    AND status = 'running'
                " 2>/dev/null | tr '|' ' ')
                
                if [ -n "$project_info" ]; then
                    read -r project_name org_id <<< "$project_info"
                    project_name=$(echo "$project_name" | xargs)
                    org_id=$(echo "$org_id" | xargs)
                fi
            fi
            
            echo -n "{\"targets\": [\"localhost:$port\"], \"labels\": {\"instance\": \"$instance\", \"project_name\": \"$project_name\", \"org_id\": \"$org_id\"}}"
            
            log "✅ Descoberto: $instance (porta $port)"
        else
            log "⚠️  Container $container sem porta Kong"
        fi
    done
    echo
    echo "]"
} > "$INSTANCES_FILE"

# Verificar se arquivo foi criado corretamente
if [ ! -f "$INSTANCES_FILE" ] || ! jq empty "$INSTANCES_FILE" 2>/dev/null; then
    log "❌ Erro ao gerar instances.json, usando fallback"
    echo '[]' > "$INSTANCES_FILE"
fi

# Contar targets
TARGET_COUNT=$(jq length "$INSTANCES_FILE" 2>/dev/null || echo 0)
log "📄 Arquivo instances.json atualizado ($TARGET_COUNT targets)"

# Reload Prometheus se estiver rodando
if docker ps --format "{{.Names}}" | grep -q "supabase_prometheus"; then
    if curl -s -X POST http://localhost:9090/-/reload > /dev/null 2>&1; then
        log "🔄 Prometheus recarregado com sucesso"
    else
        log "⚠️  Falha ao recarregar Prometheus (pode ser normal)"
    fi
fi

log "✅ Auto-discovery concluído"