#!/bin/bash
# metrics-collector.sh - Coleta métricas de uso das instâncias Supabase
# Executa a cada 5 minutos via cron para coletar dados de uso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/metrics-collector.log"
TEMP_DIR="${SCRIPT_DIR}/temp"

# Configuração do banco master
MASTER_DB_URL="${MASTER_DB_URL:-postgresql://postgres:postgres@localhost:5432/supabase_master}"

# Criar diretórios necessários
mkdir -p "$(dirname "$LOG_FILE")" "$TEMP_DIR"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Função para executar query no banco master
query_master() {
    psql "$MASTER_DB_URL" -t -c "$1" 2>/dev/null || echo ""
}

# Função para executar query em instância específica
query_instance() {
    local instance_id="$1"
    local query="$2"
    local port db_url
    
    # Obter porta da instância
    port=$(docker port "${instance_id}_kong" 8000/tcp 2>/dev/null | cut -d: -f2 || echo "")
    
    if [ -z "$port" ]; then
        return 1
    fi
    
    # URL do banco da instância (assumindo padrão)
    db_url="postgresql://postgres:postgres@localhost:${port}/postgres"
    
    psql "$db_url" -t -c "$query" 2>/dev/null || echo ""
}

# Função para obter métricas de uma instância
collect_instance_metrics() {
    local instance_id="$1"
    local project_id="$2"
    local org_id="$3"
    local period_start="$4"
    local period_end="$5"
    
    log "Coletando métricas da instância: $instance_id"
    
    # Verificar se containers estão rodando
    if ! docker ps --format "{{.Names}}" | grep -q "^${instance_id}_"; then
        log "⚠️  Instância $instance_id não está rodando"
        return 1
    fi
    
    # 1. Métricas de API (via logs do Kong)
    local api_requests=0
    if docker logs "${instance_id}_kong" --since "5m" 2>/dev/null | grep -c "HTTP" >/dev/null 2>&1; then
        api_requests=$(docker logs "${instance_id}_kong" --since "5m" 2>/dev/null | grep "HTTP" | wc -l || echo "0")
    fi
    
    # 2. Métricas de storage (via PostgreSQL)
    local storage_bytes=0
    local db_size_query="SELECT pg_database_size(current_database());"
    storage_bytes=$(query_instance "$instance_id" "$db_size_query" | tr -d ' ' || echo "0")
    
    # 3. Métricas de bandwidth (estimativa via logs)
    local bandwidth_bytes=0
    if docker logs "${instance_id}_nginx" --since "5m" 2>/dev/null | grep -E "HTTP.*[0-9]+ [0-9]+" >/dev/null 2>&1; then
        bandwidth_bytes=$(docker logs "${instance_id}_nginx" --since "5m" 2>/dev/null | \
            grep -E "HTTP.*[0-9]+ [0-9]+" | \
            awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/ && $i > 1000) sum+=$i} END {print sum+0}' || echo "0")
    fi
    
    # 4. Conexões de banco ativas
    local db_connections=0
    local connections_query="SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
    db_connections=$(query_instance "$instance_id" "$connections_query" | tr -d ' ' || echo "0")
    
    # Validar valores numéricos
    api_requests=${api_requests//[^0-9]/}
    storage_bytes=${storage_bytes//[^0-9]/}
    bandwidth_bytes=${bandwidth_bytes//[^0-9]/}
    db_connections=${db_connections//[^0-9]/}
    
    # Garantir que valores não estejam vazios
    api_requests=${api_requests:-0}
    storage_bytes=${storage_bytes:-0}
    bandwidth_bytes=${bandwidth_bytes:-0}
    db_connections=${db_connections:-0}
    
    # Inserir métricas no banco master
    local insert_query="
    INSERT INTO usage_metrics (project_id, organization_id, metric_type, value, period_start, period_end)
    VALUES 
        ($project_id, $org_id, 'api_requests', $api_requests, '$period_start', '$period_end'),
        ($project_id, $org_id, 'storage_bytes', $storage_bytes, '$period_start', '$period_end'),
        ($project_id, $org_id, 'bandwidth_bytes', $bandwidth_bytes, '$period_start', '$period_end'),
        ($project_id, $org_id, 'db_connections', $db_connections, '$period_start', '$period_end')
    ON CONFLICT (project_id, metric_type, period_start) DO UPDATE SET
        value = EXCLUDED.value,
        recorded_at = NOW();
    "
    
    if query_master "$insert_query" >/dev/null; then
        log "✅ Métricas coletadas: API:$api_requests, Storage:${storage_bytes}bytes, Bandwidth:${bandwidth_bytes}bytes, DB:$db_connections"
    else
        log "❌ Erro ao inserir métricas para instância $instance_id"
    fi
}

# Função para coletar métricas de todas as instâncias
collect_all_metrics() {
    log "🔍 Iniciando coleta de métricas..."
    
    # Definir período (últimos 5 minutos)
    local period_end period_start
    period_end=$(date -u '+%Y-%m-%d %H:%M:00')
    period_start=$(date -u -d '5 minutes ago' '+%Y-%m-%d %H:%M:00')
    
    log "📊 Período: $period_start até $period_end"
    
    # Buscar todas as instâncias ativas
    local instances_query="
    SELECT 
        p.instance_id,
        p.id as project_id,
        p.organization_id
    FROM projects p 
    WHERE p.deleted_at IS NULL 
    AND p.instance_id IS NOT NULL
    "
    
    local instances_count=0
    local success_count=0
    
    # Processar cada instância
    while IFS='|' read -r instance_id project_id org_id; do
        if [ -n "$instance_id" ] && [ "$instance_id" != " " ]; then
            instances_count=$((instances_count + 1))
            
            # Remover espaços em branco
            instance_id=$(echo "$instance_id" | tr -d ' ')
            project_id=$(echo "$project_id" | tr -d ' ')
            org_id=$(echo "$org_id" | tr -d ' ')
            
            if collect_instance_metrics "$instance_id" "$project_id" "$org_id" "$period_start" "$period_end"; then
                success_count=$((success_count + 1))
            fi
        fi
    done < <(query_master "$instances_query" | grep -v "^$")
    
    log "📈 Coleta finalizada: $success_count/$instances_count instâncias processadas"
}

# Função para limpar métricas antigas
cleanup_old_metrics() {
    log "🧹 Limpando métricas antigas (>30 dias)..."
    
    local cleanup_query="
    DELETE FROM usage_metrics 
    WHERE period_start < NOW() - INTERVAL '30 days';
    "
    
    local deleted_count
    deleted_count=$(query_master "$cleanup_query" | grep "DELETE" | awk '{print $2}' || echo "0")
    
    if [ -n "$deleted_count" ] && [ "$deleted_count" != "0" ]; then
        log "🗑️  Removidas $deleted_count métricas antigas"
    fi
}

# Função para verificar health das instâncias
check_instances_health() {
    log "🔍 Verificando health das instâncias..."
    
    local total=0
    local healthy=0
    local unhealthy=0
    
    # Buscar todas as instâncias
    while IFS='|' read -r instance_id project_name; do
        if [ -n "$instance_id" ] && [ "$instance_id" != " " ]; then
            total=$((total + 1))
            instance_id=$(echo "$instance_id" | tr -d ' ')
            project_name=$(echo "$project_name" | tr -d ' ')
            
            # Verificar se containers estão rodando
            local containers_running=0
            for service in kong studio db; do
                if docker ps --format "{{.Names}}" | grep -q "^${instance_id}_${service}$"; then
                    containers_running=$((containers_running + 1))
                fi
            done
            
            if [ $containers_running -eq 3 ]; then
                healthy=$((healthy + 1))
                log "✅ $project_name ($instance_id) - Saudável"
            else
                unhealthy=$((unhealthy + 1))
                log "❌ $project_name ($instance_id) - $containers_running/3 containers rodando"
            fi
        fi
    done < <(query_master "SELECT instance_id, name FROM projects WHERE deleted_at IS NULL AND instance_id IS NOT NULL" | grep -v "^$")
    
    log "📊 Health check: $healthy saudáveis, $unhealthy com problemas de $total total"
}

# Função para gerar relatório de uso
generate_usage_report() {
    local org_id="${1:-}"
    local output_file="${TEMP_DIR}/usage_report_$(date +%Y%m%d_%H%M%S).json"
    
    log "📋 Gerando relatório de uso..."
    
    # Query para relatório
    local report_query="
    SELECT 
        o.name as organization,
        p.name as project,
        p.instance_id,
        metric_type,
        SUM(value) as total_value,
        DATE(period_start) as usage_date
    FROM usage_metrics um
    JOIN projects p ON um.project_id = p.id
    JOIN organizations o ON um.organization_id = o.id
    WHERE um.period_start >= NOW() - INTERVAL '7 days'
    $([ -n "$org_id" ] && echo "AND o.id = $org_id")
    GROUP BY o.name, p.name, p.instance_id, metric_type, DATE(period_start)
    ORDER BY usage_date DESC, organization, project;
    "
    
    if query_master "\\copy ($report_query) TO '$output_file' WITH CSV HEADER;" >/dev/null; then
        log "📊 Relatório gerado: $output_file"
        return 0
    else
        log "❌ Erro ao gerar relatório"
        return 1
    fi
}

# Função principal
main() {
    log "🚀 Iniciando metrics collector..."
    
    # Verificar se o banco master está acessível
    if ! query_master "SELECT 1;" >/dev/null; then
        log "❌ Não foi possível conectar ao banco master"
        exit 1
    fi
    
    # Verificar se Docker está rodando
    if ! docker ps >/dev/null 2>&1; then
        log "❌ Docker não está acessível"
        exit 1
    fi
    
    # Executar coleta de métricas
    collect_all_metrics
    
    # Executar health check
    check_instances_health
    
    # Limpar métricas antigas (uma vez por dia)
    if [ "$(date +%H%M)" = "0300" ]; then
        cleanup_old_metrics
    fi
    
    log "✅ Coleta de métricas finalizada"
}

# Tratamento de sinais
trap 'log "⚠️ Interrompido pelo usuário"; exit 1' INT TERM

# Verificar argumentos
case "${1:-}" in
    --report)
        generate_usage_report "${2:-}"
        ;;
    --health)
        check_instances_health
        ;;
    --cleanup)
        cleanup_old_metrics
        ;;
    *)
        main
        ;;
esac