#!/bin/bash
# health_monitor.sh - Script de monitoramento de saúde das instâncias
# Executado a cada 30 segundos via cron para verificar status e enviar alertas

DOCKER_DIR="/opt/supabase-instances"
MASTER_DB_URL="${MASTER_DB_URL:-postgresql://postgres:postgres@localhost:5432/supabase_master}"
ALERTMANAGER_URL="http://localhost:9093"
STATUS_DIR="/opt/monitoring/status"
LOG_FILE="/var/log/supabase-health.log"

# Webhooks para notificações
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

# Função de log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEALTH] $1" | tee -a "$LOG_FILE"
}

# Função para enviar alerta
send_alert() {
    local alertname="$1"
    local instance="$2"
    local summary="$3"
    local severity="${4:-warning}"
    
    # Payload para Alertmanager
    local payload=$(cat << EOF
[{
    "labels": {
        "alertname": "$alertname",
        "instance": "$instance",
        "severity": "$severity",
        "source": "health_monitor"
    },
    "annotations": {
        "summary": "$summary",
        "description": "Detectado pelo health monitor em $(date)"
    },
    "startsAt": "$(date -Iseconds)"
}]
EOF
    )
    
    # Enviar para Alertmanager
    if curl -s -X POST "$ALERTMANAGER_URL/api/v1/alerts" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null 2>&1; then
        log "🔔 Alerta enviado: $alertname para $instance"
    else
        log "❌ Falha ao enviar alerta para Alertmanager"
    fi
    
    # Enviar para Slack se configurado
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        local slack_payload=$(cat << EOF
{
    "text": "🚨 Supabase BaaS Alert",
    "attachments": [
        {
            "color": "$([ "$severity" = "critical" ] && echo "danger" || echo "warning")",
            "fields": [
                {"title": "Alerta", "value": "$alertname", "short": true},
                {"title": "Instância", "value": "$instance", "short": true},
                {"title": "Severidade", "value": "$severity", "short": true},
                {"title": "Descrição", "value": "$summary", "short": false}
            ],
            "footer": "Supabase Health Monitor",
            "ts": $(date +%s)
        }
    ]
}
EOF
        )
        
        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$slack_payload" > /dev/null 2>&1
    fi
}

# Função para verificar container
check_container() {
    local container_name="$1"
    local instance_id="$2"
    local service="$3"
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        # Container está rodando
        local status=$(docker inspect "$container_name" --format "{{.State.Status}}")
        local health=$(docker inspect "$container_name" --format "{{.State.Health.Status}}" 2>/dev/null || echo "none")
        
        if [ "$status" = "running" ]; then
            if [ "$health" = "unhealthy" ]; then
                send_alert "ContainerUnhealthy" "$instance_id" "Container $container_name está unhealthy" "warning"
                return 1
            fi
            return 0
        else
            send_alert "ContainerNotRunning" "$instance_id" "Container $container_name não está running: $status" "critical"
            return 1
        fi
    else
        send_alert "ContainerMissing" "$instance_id" "Container $container_name não encontrado" "critical"
        return 1
    fi
}

# Função para verificar conectividade HTTP
check_http_endpoint() {
    local url="$1"
    local instance_id="$2"
    local timeout="${3:-5}"
    
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    
    if [[ "$http_code" =~ ^(200|302|401)$ ]]; then
        return 0
    else
        send_alert "HTTPEndpointDown" "$instance_id" "Endpoint $url retornou código $http_code" "critical"
        return 1
    fi
}

# Função para verificar banco de dados
check_database() {
    local instance_id="$1"
    local db_container="${instance_id}_db"
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${db_container}$"; then
        send_alert "DatabaseContainerDown" "$instance_id" "Container de banco $db_container não está rodando" "critical"
        return 1
    fi
    
    # Verificar se PostgreSQL está aceitando conexões
    if ! docker exec "$db_container" pg_isready -U postgres -h localhost > /dev/null 2>&1; then
        send_alert "DatabaseNotReady" "$instance_id" "PostgreSQL no container $db_container não está aceitando conexões" "critical"
        return 1
    fi
    
    return 0
}

# Função para obter informações da instância do banco master
get_instance_info() {
    local instance_id="$1"
    
    if command -v psql > /dev/null 2>&1 && [ -n "$MASTER_DB_URL" ]; then
        psql "$MASTER_DB_URL" -t -c "
            SELECT name, subdomain, port, status 
            FROM projects 
            WHERE instance_id = '$instance_id' 
            AND deleted_at IS NULL
        " 2>/dev/null | tr '|' ' '
    fi
}

# Função para gerar relatório de status
generate_status_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local total_instances=0
    local healthy_instances=0
    local unhealthy_instances=0
    
    # Criar diretório de status se não existir
    mkdir -p "$STATUS_DIR"
    
    # Iniciar HTML
    cat > "$STATUS_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Supabase BaaS - Status</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .instance-card { border: 1px solid #ddd; border-radius: 8px; padding: 15px; }
        .status-healthy { border-left: 5px solid #28a745; }
        .status-unhealthy { border-left: 5px solid #dc3545; }
        .status-unknown { border-left: 5px solid #ffc107; }
        .service-status { display: flex; justify-content: space-between; margin: 5px 0; }
        .service-status span { padding: 2px 8px; border-radius: 4px; font-size: 12px; }
        .status-ok { background: #d4edda; color: #155724; }
        .status-error { background: #f8d7da; color: #721c24; }
        .status-warning { background: #fff3cd; color: #856404; }
        .summary { display: flex; justify-content: center; gap: 20px; margin-bottom: 20px; }
        .summary-item { text-align: center; padding: 15px; border-radius: 8px; min-width: 120px; }
        .summary-total { background: #e3f2fd; }
        .summary-healthy { background: #e8f5e8; }
        .summary-unhealthy { background: #fdeaea; }
        .last-update { text-align: center; color: #666; margin-top: 20px; }
    </style>
    <meta http-equiv="refresh" content="30">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Supabase BaaS - Status Dashboard</h1>
            <p>Monitoramento em tempo real das instâncias</p>
        </div>
        
        <div class="summary">
            <div class="summary-item summary-total">
                <h3 id="total-count">0</h3>
                <p>Total</p>
            </div>
            <div class="summary-item summary-healthy">
                <h3 id="healthy-count">0</h3>
                <p>Saudáveis</p>
            </div>
            <div class="summary-item summary-unhealthy">
                <h3 id="unhealthy-count">0</h3>
                <p>Com Problemas</p>
            </div>
        </div>
        
        <div class="status-grid">
EOF
    
    # Verificar cada instância
    for instance_dir in "$DOCKER_DIR"/*; do
        if [ ! -d "$instance_dir" ]; then
            continue
        fi
        
        local instance_id=$(basename "$instance_dir")
        
        # Verificar se é um ID de instância válido
        if [[ ! "$instance_id" =~ ^[0-9]+_.*_[0-9]+$ ]]; then
            continue
        fi
        
        ((total_instances++))
        
        # Obter informações da instância
        local instance_info=$(get_instance_info "$instance_id")
        local project_name=""
        local subdomain=""
        local port=""
        local db_status=""
        
        if [ -n "$instance_info" ]; then
            read -r project_name subdomain port db_status <<< "$instance_info"
            project_name=$(echo "$project_name" | xargs)
            subdomain=$(echo "$subdomain" | xargs)
            port=$(echo "$port" | xargs)
            db_status=$(echo "$db_status" | xargs)
        fi
        
        # Verificar status dos containers
        local studio_status="unknown"
        local kong_status="unknown"
        local db_status_check="unknown"
        local overall_status="unknown"
        
        # Verificar Studio
        if check_container "${instance_id}_studio" "$instance_id" "studio" 2>/dev/null; then
            studio_status="ok"
        else
            studio_status="error"
        fi
        
        # Verificar Kong
        if check_container "${instance_id}_kong" "$instance_id" "kong" 2>/dev/null; then
            kong_status="ok"
        else
            kong_status="error"
        fi
        
        # Verificar Database
        if check_database "$instance_id" 2>/dev/null; then
            db_status_check="ok"
        else
            db_status_check="error"
        fi
        
        # Verificar HTTP se tiver porta
        local http_status="unknown"
        if [ -n "$port" ] && [ "$port" != "null" ]; then
            if check_http_endpoint "http://localhost:$port" "$instance_id" 3 2>/dev/null; then
                http_status="ok"
            else
                http_status="error"
            fi
        fi
        
        # Determinar status geral
        if [[ "$studio_status" == "ok" && "$kong_status" == "ok" && "$db_status_check" == "ok" ]]; then
            overall_status="healthy"
            ((healthy_instances++))
        else
            overall_status="unhealthy"
            ((unhealthy_instances++))
        fi
        
        # Adicionar card da instância ao HTML
        cat >> "$STATUS_DIR/index.html" << EOF
            <div class="instance-card status-$overall_status">
                <h3>$instance_id</h3>
                <p><strong>Projeto:</strong> ${project_name:-"N/A"}</p>
                <p><strong>Subdomínio:</strong> ${subdomain:-"N/A"}</p>
                <p><strong>Porta:</strong> ${port:-"N/A"}</p>
                
                <div class="service-status">
                    <span>Studio:</span>
                    <span class="status-$studio_status">$studio_status</span>
                </div>
                
                <div class="service-status">
                    <span>Kong API:</span>
                    <span class="status-$kong_status">$kong_status</span>
                </div>
                
                <div class="service-status">
                    <span>Database:</span>
                    <span class="status-$db_status_check">$db_status_check</span>
                </div>
                
                <div class="service-status">
                    <span>HTTP:</span>
                    <span class="status-$http_status">$http_status</span>
                </div>
            </div>
EOF
    done
    
    # Finalizar HTML
    cat >> "$STATUS_DIR/index.html" << EOF
        </div>
        
        <div class="last-update">
            <p>Última atualização: $timestamp</p>
            <p>Próxima atualização automática em 30 segundos</p>
        </div>
    </div>
    
    <script>
        document.getElementById('total-count').textContent = '$total_instances';
        document.getElementById('healthy-count').textContent = '$healthy_instances';
        document.getElementById('unhealthy-count').textContent = '$unhealthy_instances';
    </script>
</body>
</html>
EOF
    
    # Gerar versão JSON para APIs
    cat > "$STATUS_DIR/status.json" << EOF
{
    "timestamp": "$timestamp",
    "summary": {
        "total": $total_instances,
        "healthy": $healthy_instances,
        "unhealthy": $unhealthy_instances
    },
    "last_check": "$(date -Iseconds)"
}
EOF
    
    log "📊 Relatório de status gerado: $total_instances total, $healthy_instances saudáveis, $unhealthy_instances com problemas"
}

# Função principal
main() {
    log "🔍 Iniciando verificação de saúde das instâncias..."
    
    # Verificar se diretório de instâncias existe
    if [ ! -d "$DOCKER_DIR" ]; then
        log "❌ Diretório de instâncias não encontrado: $DOCKER_DIR"
        exit 1
    fi
    
    # Gerar relatório de status
    generate_status_report
    
    log "✅ Verificação de saúde concluída"
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi