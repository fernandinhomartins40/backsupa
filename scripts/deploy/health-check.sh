#!/bin/bash
# health-check.sh - Script de verificação de saúde dos serviços
# Uso: ./health-check.sh [--verbose] [--json]

set -euo pipefail

# Configurações
APP_DIR="/opt/supabase-baas/current"
VERBOSE=false
JSON_OUTPUT=false
TIMEOUT=10

# Parse argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --json|-j)
      JSON_OUTPUT=true
      shift
      ;;
    --timeout|-t)
      TIMEOUT="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--verbose] [--json] [--timeout seconds]"
      exit 1
      ;;
  esac
done

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis de resultado
RESULTS=()
OVERALL_STATUS="healthy"

# Função de log
log() {
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "$1"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == "true" && "$JSON_OUTPUT" == "false" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Função para adicionar resultado
add_result() {
    local service="$1"
    local status="$2"
    local message="$3"
    local response_time="${4:-0}"
    
    RESULTS+=("{\"service\":\"$service\",\"status\":\"$status\",\"message\":\"$message\",\"response_time\":$response_time}")
    
    if [[ "$status" != "healthy" ]]; then
        OVERALL_STATUS="unhealthy"
    fi
}

# Verificar se serviço está rodando
check_service_running() {
    local service="$1"
    local container_name="$2"
    
    log_verbose "Checking if $service is running..."
    
    if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
        return 0
    else
        return 1
    fi
}

# Verificar endpoint HTTP
check_http_endpoint() {
    local service="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    log_verbose "Checking HTTP endpoint: $url"
    
    local start_time=$(date +%s%N)
    local http_status
    local response_time
    
    if http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null); then
        local end_time=$(date +%s%N)
        response_time=$(( (end_time - start_time) / 1000000 ))
        
        if [[ "$http_status" == "$expected_status" ]]; then
            add_result "$service" "healthy" "HTTP $http_status" "$response_time"
            log "${GREEN}✅${NC} $service: HTTP $http_status (${response_time}ms)"
        else
            add_result "$service" "degraded" "HTTP $http_status (expected $expected_status)" "$response_time"
            log "${YELLOW}⚠️${NC} $service: HTTP $http_status (expected $expected_status, ${response_time}ms)"
        fi
    else
        add_result "$service" "unhealthy" "Connection failed" "0"
        log "${RED}❌${NC} $service: Connection failed"
    fi
}

# Verificar PostgreSQL
check_postgresql() {
    local service="PostgreSQL"
    
    log_verbose "Checking PostgreSQL connection..."
    
    local start_time=$(date +%s%N)
    
    if docker exec supabase_master_db pg_isready -U postgres >/dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local response_time=$(( (end_time - start_time) / 1000000 ))
        
        add_result "$service" "healthy" "Connection successful" "$response_time"
        log "${GREEN}✅${NC} $service: Connection successful (${response_time}ms)"
    else
        add_result "$service" "unhealthy" "Connection failed" "0"
        log "${RED}❌${NC} $service: Connection failed"
    fi
}

# Verificar uso de disco
check_disk_usage() {
    local service="Disk Space"
    local threshold=90
    
    log_verbose "Checking disk usage..."
    
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ "$usage" -lt "$threshold" ]]; then
        add_result "$service" "healthy" "Usage: ${usage}%" "0"
        log "${GREEN}✅${NC} $service: ${usage}% used"
    elif [[ "$usage" -lt 95 ]]; then
        add_result "$service" "degraded" "Usage: ${usage}% (warning)" "0"
        log "${YELLOW}⚠️${NC} $service: ${usage}% used (warning)"
    else
        add_result "$service" "unhealthy" "Usage: ${usage}% (critical)" "0"
        log "${RED}❌${NC} $service: ${usage}% used (critical)"
    fi
}

# Verificar uso de memória
check_memory_usage() {
    local service="Memory"
    local threshold=90
    
    log_verbose "Checking memory usage..."
    
    local usage=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    
    if [[ "$usage" -lt "$threshold" ]]; then
        add_result "$service" "healthy" "Usage: ${usage}%" "0"
        log "${GREEN}✅${NC} $service: ${usage}% used"
    elif [[ "$usage" -lt 95 ]]; then
        add_result "$service" "degraded" "Usage: ${usage}% (warning)" "0"
        log "${YELLOW}⚠️${NC} $service: ${usage}% used (warning)"
    else
        add_result "$service" "unhealthy" "Usage: ${usage}% (critical)" "0"
        log "${RED}❌${NC} $service: ${usage}% used (critical)"
    fi
}

# Verificar containers Docker
check_docker_containers() {
    log_verbose "Checking Docker containers..."
    
    # Lista de containers esperados
    local expected_containers=(
        "supabase_master_db:PostgreSQL Master"
        "supabase_nginx:Nginx Proxy" 
        "supabase_control_api:Control API"
        "supabase_billing_api:Billing API"
        "supabase_marketplace_api:Marketplace API"
    )
    
    for container_info in "${expected_containers[@]}"; do
        local container_name=$(echo "$container_info" | cut -d: -f1)
        local service_name=$(echo "$container_info" | cut -d: -f2)
        
        if check_service_running "$service_name" "$container_name"; then
            add_result "$service_name Container" "healthy" "Running" "0"
            log "${GREEN}✅${NC} $service_name: Container running"
        else
            add_result "$service_name Container" "unhealthy" "Not running" "0"
            log "${RED}❌${NC} $service_name: Container not running"
        fi
    done
}

# Verificar conectividade de rede
check_network_connectivity() {
    local service="Network"
    
    log_verbose "Checking network connectivity..."
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        add_result "$service" "healthy" "Internet connectivity OK" "0"
        log "${GREEN}✅${NC} $service: Internet connectivity OK"
    else
        add_result "$service" "degraded" "Internet connectivity issues" "0"
        log "${YELLOW}⚠️${NC} $service: Internet connectivity issues"
    fi
}

# Verificar logs recentes para erros
check_logs_for_errors() {
    local service="System Logs"
    
    log_verbose "Checking recent logs for errors..."
    
    local error_count
    error_count=$(journalctl --since "5 minutes ago" --priority err --no-pager -q | wc -l)
    
    if [[ "$error_count" -eq 0 ]]; then
        add_result "$service" "healthy" "No recent errors" "0"
        log "${GREEN}✅${NC} $service: No recent errors"
    elif [[ "$error_count" -lt 5 ]]; then
        add_result "$service" "degraded" "$error_count errors in last 5 minutes" "0"
        log "${YELLOW}⚠️${NC} $service: $error_count errors in last 5 minutes"
    else
        add_result "$service" "unhealthy" "$error_count errors in last 5 minutes" "0"
        log "${RED}❌${NC} $service: $error_count errors in last 5 minutes"
    fi
}

# Função principal
main() {
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "${BLUE}🔍 Supabase BaaS Health Check${NC}"
        echo -e "${BLUE}================================${NC}"
        echo ""
    fi
    
    # Verificar se diretório da aplicação existe
    if [[ ! -d "$APP_DIR" ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo '{"status":"unhealthy","message":"Application directory not found","checks":[]}'
        else
            echo -e "${RED}❌ Application directory not found: $APP_DIR${NC}"
        fi
        exit 1
    fi
    
    cd "$APP_DIR" 2>/dev/null || true
    
    # Executar verificações
    check_docker_containers
    check_postgresql
    check_http_endpoint "Nginx" "http://localhost/health" "200"
    check_http_endpoint "Control API" "http://localhost:3001/health" "200"
    check_http_endpoint "Billing API" "http://localhost:3002/health" "200"  
    check_http_endpoint "Marketplace API" "http://localhost:3003/health" "200"
    check_disk_usage
    check_memory_usage
    check_network_connectivity
    check_logs_for_errors
    
    # Output final
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        # JSON output
        local results_json=$(printf '%s,' "${RESULTS[@]}")
        results_json="[${results_json%,}]"
        
        cat << EOF
{
  "status": "$OVERALL_STATUS",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "checks": $results_json,
  "summary": {
    "total_checks": ${#RESULTS[@]},
    "healthy": $(echo "${RESULTS[@]}" | grep -o '"status":"healthy"' | wc -l),
    "degraded": $(echo "${RESULTS[@]}" | grep -o '"status":"degraded"' | wc -l),
    "unhealthy": $(echo "${RESULTS[@]}" | grep -o '"status":"unhealthy"' | wc -l)
  }
}
EOF
    else
        # Human-readable output
        echo ""
        echo -e "${BLUE}================================${NC}"
        
        if [[ "$OVERALL_STATUS" == "healthy" ]]; then
            echo -e "${GREEN}✅ Overall Status: HEALTHY${NC}"
        else
            echo -e "${RED}❌ Overall Status: UNHEALTHY${NC}"
        fi
        
        echo -e "${BLUE}Timestamp: $(date)${NC}"
        echo -e "${BLUE}Total Checks: ${#RESULTS[@]}${NC}"
        
        local healthy_count=$(echo "${RESULTS[@]}" | grep -o '"status":"healthy"' | wc -l)
        local degraded_count=$(echo "${RESULTS[@]}" | grep -o '"status":"degraded"' | wc -l) 
        local unhealthy_count=$(echo "${RESULTS[@]}" | grep -o '"status":"unhealthy"' | wc -l)
        
        echo -e "${GREEN}Healthy: $healthy_count${NC} | ${YELLOW}Degraded: $degraded_count${NC} | ${RED}Unhealthy: $unhealthy_count${NC}"
    fi
    
    # Exit code baseado no status
    if [[ "$OVERALL_STATUS" == "healthy" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Executar health check
main "$@"