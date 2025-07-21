#!/bin/bash
# update_monitoring.sh - Auto-discovery de instâncias Supabase para Prometheus
# Executado automaticamente via cron para atualizar lista de targets

DOCKER_DIR="/opt/supabase-instances"
MONITORING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCES_FILE="$MONITORING_DIR/instances.json"
MASTER_DB_URL="${MASTER_DB_URL:-postgresql://postgres:postgres@localhost:5432/supabase_master}"

# Função de log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DISCOVERY] $1" | tee -a /var/log/supabase-monitoring.log
}

log "🔍 Iniciando auto-discovery de instâncias..."

# Array para armazenar targets
targets=()

# Verificar se há instâncias rodando
if ! docker ps --format "{{.Names}}" | grep -q "_kong"; then
    log "📭 Nenhuma instância Kong encontrada"
else
    # Descobrir instâncias através dos containers Kong
    while IFS= read -r container; do
        if [[ "$container" =~ ^([0-9]+_[^_]+_[0-9]+)_kong$ ]]; then
            instance_id="${BASH_REMATCH[1]}"
            
            # Obter porta do Kong
            kong_port=$(docker port "$container" 8000/tcp 2>/dev/null | cut -d: -f2)
            
            if [ -n "$kong_port" ]; then
                # Obter informações adicionais do banco master (se disponível)
                project_name=""
                org_id=""
                subdomain=""
                
                if command -v psql > /dev/null 2>&1 && [ -n "$MASTER_DB_URL" ]; then
                    project_info=$(psql "$MASTER_DB_URL" -t -c "
                        SELECT name, organization_id, subdomain 
                        FROM projects 
                        WHERE instance_id = '$instance_id' 
                        AND status = 'running'
                    " 2>/dev/null | tr '|' ' ')
                    
                    if [ -n "$project_info" ]; then
                        read -r project_name org_id subdomain <<< "$project_info"
                        project_name=$(echo "$project_name" | xargs)
                        org_id=$(echo "$org_id" | xargs)
                        subdomain=$(echo "$subdomain" | xargs)
                    fi
                fi
                
                # Verificar se Studio está respondendo
                studio_port=""
                studio_container="${instance_id}_studio"
                if docker ps --format "{{.Names}}" | grep -q "^${studio_container}$"; then
                    studio_port=$(docker port "$studio_container" 3000/tcp 2>/dev/null | cut -d: -f2)
                fi
                
                # Criar target para Kong (API Gateway)
                target_kong=$(cat << EOF
{
    "targets": ["host.docker.internal:$kong_port"],
    "labels": {
        "job": "supabase-kong",
        "instance_id": "$instance_id",
        "project_name": "${project_name:-unknown}",
        "org_id": "${org_id:-unknown}",
        "subdomain": "${subdomain:-unknown}",
        "service": "kong",
        "port": "$kong_port"
    }
}
EOF
                )
                targets+=("$target_kong")
                
                # Criar target para Studio se disponível
                if [ -n "$studio_port" ]; then
                    target_studio=$(cat << EOF
{
    "targets": ["host.docker.internal:$studio_port"],
    "labels": {
        "job": "supabase-studio",
        "instance_id": "$instance_id",
        "project_name": "${project_name:-unknown}",
        "org_id": "${org_id:-unknown}",
        "subdomain": "${subdomain:-unknown}",
        "service": "studio",
        "port": "$studio_port"
    }
}
EOF
                    )
                    targets+=("$target_studio")
                fi
                
                log "✅ Descoberto: $instance_id (Kong:$kong_port$([ -n "$studio_port" ] && echo ", Studio:$studio_port"))"
            else
                log "⚠️  Instância $instance_id encontrada mas sem porta Kong"
            fi
        fi
    done < <(docker ps --format "{{.Names}}" | grep "_kong$")
fi

# Gerar arquivo JSON final
if [ ${#targets[@]} -eq 0 ]; then
    # Arquivo vazio se não houver targets
    echo '[]' > "$INSTANCES_FILE"
    log "📄 Arquivo instances.json atualizado (0 targets)"
else
    # Converter array em JSON válido
    printf '%s\n' "${targets[@]}" | jq -s . > "$INSTANCES_FILE"
    log "📄 Arquivo instances.json atualizado (${#targets[@]} targets)"
fi

# Verificar se arquivo foi criado corretamente
if [ ! -f "$INSTANCES_FILE" ] || ! jq empty "$INSTANCES_FILE" 2>/dev/null; then
    log "❌ Erro ao gerar instances.json, usando fallback"
    echo '[]' > "$INSTANCES_FILE"
fi

# Reload Prometheus se estiver rodando
if docker ps --format "{{.Names}}" | grep -q "supabase_prometheus"; then
    if curl -s -X POST http://localhost:9090/-/reload > /dev/null 2>&1; then
        log "🔄 Prometheus recarregado com sucesso"
    else
        log "⚠️  Falha ao recarregar Prometheus (pode ser normal)"
    fi
fi

# Estatísticas finais
total_instances=$(echo "${targets[@]}" | jq -s 'map(select(.labels.service == "kong")) | length' 2>/dev/null || echo 0)
total_targets=${#targets[@]}

log "📊 Discovery concluído: $total_instances instâncias, $total_targets targets"

# Criar métricas customizadas para o exporter
cat > "/tmp/supabase_discovery_metrics.prom" << EOF
# HELP supabase_instances_total Total number of Supabase instances discovered
# TYPE supabase_instances_total gauge
supabase_instances_total $total_instances

# HELP supabase_monitoring_targets_total Total number of monitoring targets
# TYPE supabase_monitoring_targets_total gauge
supabase_monitoring_targets_total $total_targets

# HELP supabase_discovery_last_run_timestamp Unix timestamp of last discovery run
# TYPE supabase_discovery_last_run_timestamp gauge
supabase_discovery_last_run_timestamp $(date +%s)
EOF

# Mover métricas para o exporter se estiver configurado
if [ -d "/opt/monitoring/exporter/metrics" ]; then
    mv "/tmp/supabase_discovery_metrics.prom" "/opt/monitoring/exporter/metrics/"
fi

log "✅ Auto-discovery concluído"