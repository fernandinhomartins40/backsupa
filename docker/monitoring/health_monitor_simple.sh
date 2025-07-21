#!/bin/bash
# health_monitor_simple.sh - Health check simplificado baseado na especificação
# Executar a cada 30 segundos

MASTER_DB_URL="${MASTER_DB_URL:-postgresql://postgres:postgres@localhost:5432/supabase_master}"
ALERTMANAGER_URL="http://localhost:9093"
STATUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/status"

# Função de log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEALTH] $1"
}

# Função para enviar alerta
send_alert() {
    local alertname="$1"
    local instance="$2"
    local summary="$3"
    local severity="${4:-warning}"
    
    local payload=$(cat << EOF
[{
    "labels": {
        "alertname": "$alertname",
        "instance": "$instance",
        "severity": "$severity"
    },
    "annotations": {
        "summary": "$summary"
    },
    "startsAt": "$(date -Iseconds)"
}]
EOF
    )
    
    curl -s -X POST "$ALERTMANAGER_URL/api/v1/alerts" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null 2>&1 && \
        log "🔔 Alerta enviado: $alertname para $instance"
}

log "🔍 Iniciando verificação de saúde das instâncias..."

# Criar diretório de status se não existir
mkdir -p "$STATUS_DIR"

# Inicializar contadores
total_instances=0
healthy_instances=0
unhealthy_instances=0

# Verificar cada instância baseada em containers Studio
for instance in $(docker ps --format "{{.Names}}" | grep "_studio$" | sed 's/_studio//'); do
    ((total_instances++))
    instance_healthy=true
    
    log "📊 Verificando instância: $instance"
    
    # Check 1: Verificar se containers estão rodando
    for service in "studio" "kong" "db"; do
        container_name="${instance}_${service}"
        if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log "❌ Container $container_name não está rodando"
            send_alert "InstanceDown" "$instance" "Instance $instance containers are down" "critical"
            instance_healthy=false
            break
        fi
    done
    
    # Check 2: Verificar HTTP response do Kong se containers OK
    if [ "$instance_healthy" = true ]; then
        # Obter subdomínio do banco master
        subdomain=""
        if command -v psql > /dev/null 2>&1 && [ -n "$MASTER_DB_URL" ]; then
            subdomain=$(psql "$MASTER_DB_URL" -t -c "
                SELECT subdomain 
                FROM projects 
                WHERE instance_id='$instance'
            " 2>/dev/null | xargs)
        fi
        
        # Obter porta do Kong diretamente
        kong_port=$(docker port "${instance}_kong" 8000/tcp 2>/dev/null | cut -d: -f2)
        
        if [ -n "$kong_port" ]; then
            http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$kong_port" 2>/dev/null)
            
            if [[ ! "$http_code" =~ ^(200|302|401|404)$ ]]; then
                log "❌ HTTP check falhou para $instance (código: $http_code)"
                send_alert "HTTPEndpointDown" "$instance" "HTTP endpoint returning $http_code" "critical"
                instance_healthy=false
            fi
        fi
    fi
    
    # Atualizar contadores
    if [ "$instance_healthy" = true ]; then
        ((healthy_instances++))
        log "✅ Instância $instance saudável"
    else
        ((unhealthy_instances++))
        log "❌ Instância $instance com problemas"
    fi
done

# Gerar status page HTML simples
cat > "$STATUS_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Supabase BaaS - Status</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 20px; 
            background: #f5f5f5; 
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
        }
        .header { 
            text-align: center; 
            margin-bottom: 30px; 
        }
        .summary { 
            display: flex; 
            justify-content: center; 
            gap: 20px; 
            margin-bottom: 20px; 
        }
        .summary-item { 
            text-align: center; 
            padding: 15px; 
            border-radius: 8px; 
            min-width: 120px; 
        }
        .summary-total { background: #e3f2fd; }
        .summary-healthy { background: #e8f5e8; }
        .summary-unhealthy { background: #fdeaea; }
        .last-update { 
            text-align: center; 
            color: #666; 
            margin-top: 20px; 
        }
    </style>
    <meta http-equiv="refresh" content="30">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Supabase BaaS - Status</h1>
            <p>Monitoramento em tempo real das instâncias</p>
        </div>
        
        <div class="summary">
            <div class="summary-item summary-total">
                <h3>$total_instances</h3>
                <p>Total</p>
            </div>
            <div class="summary-item summary-healthy">
                <h3>$healthy_instances</h3>
                <p>Saudáveis</p>
            </div>
            <div class="summary-item summary-unhealthy">
                <h3>$unhealthy_instances</h3>
                <p>Com Problemas</p>
            </div>
        </div>
        
        <div class="last-update">
            <p>Última atualização: $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p>Próxima atualização automática em 30 segundos</p>
        </div>
    </div>
</body>
</html>
EOF

# Gerar API JSON
cat > "$STATUS_DIR/status.json" << EOF
{
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
    "summary": {
        "total": $total_instances,
        "healthy": $healthy_instances,
        "unhealthy": $unhealthy_instances
    },
    "last_check": "$(date -Iseconds)"
}
EOF

log "📊 Health check concluído: $total_instances total, $healthy_instances saudáveis, $unhealthy_instances com problemas"