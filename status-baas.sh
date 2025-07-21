#!/bin/bash
# BaaS Supabase Clone - Script para verificar status dos serviços

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se uma porta está em uso
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port " || \
       (command -v lsof &> /dev/null && lsof -ti:$port &>/dev/null 2>&1); then
        return 0 # Porta em uso
    else
        return 1 # Porta livre
    fi
}

# Função para fazer request HTTP
check_http() {
    local url=$1
    local timeout=${2:-5}
    
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout $timeout "$url" > /dev/null 2>&1; then
            return 0 # OK
        else
            return 1 # Erro
        fi
    else
        return 1 # curl não disponível
    fi
}

# Função para verificar PID
check_pid() {
    local name=$1
    local pid_file="logs/${name,,}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            echo "$pid"
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

print_status "🔍 Verificando status do BaaS Supabase Clone..."
echo ""

# Verificar cada serviço
services=(
    "Studio:3000:http://localhost:3000"
    "Control-API:3001:http://localhost:3001/health"
    "Billing-API:3002:http://localhost:3002/health"  
    "Marketplace-API:3003:http://localhost:3003/health"
)

echo "┌─────────────────┬────────┬──────┬─────────┬─────────────────────────────────────┐"
echo "│ Serviço         │ Porta  │ PID  │ Status  │ URL                                 │"
echo "├─────────────────┼────────┼──────┼─────────┼─────────────────────────────────────┤"

all_running=true

for service in "${services[@]}"; do
    IFS=':' read -r name port url <<< "$service"
    
    # Verificar porta
    if check_port $port; then
        port_status="✅"
    else
        port_status="❌"
        all_running=false
    fi
    
    # Verificar PID
    if pid=$(check_pid "$name"); then
        pid_display="$pid"
    else
        pid_display="N/A"
    fi
    
    # Verificar HTTP (apenas para APIs)
    if [[ "$name" != "Studio" ]]; then
        if check_http "$url" 3; then
            http_status="🟢"
        else
            http_status="🔴"
            all_running=false
        fi
    else
        # Para o Studio, apenas verificar porta
        if check_port $port; then
            http_status="🟢"
        else
            http_status="🔴"
            all_running=false
        fi
    fi
    
    # Determinar status geral
    if [[ "$port_status" == "✅" && "$http_status" == "🟢" ]]; then
        status="🟢 UP"
    else
        status="🔴 DOWN"
    fi
    
    printf "│ %-15s │ %-6s │ %-4s │ %-7s │ %-35s │\n" \
        "$name" "$port" "$pid_display" "$status" "$url"
done

echo "└─────────────────┴────────┴──────┴─────────┴─────────────────────────────────────┘"
echo ""

# Status geral
if [ "$all_running" = true ]; then
    print_success "🎉 Todos os serviços estão funcionando!"
else
    print_error "❌ Alguns serviços não estão funcionando"
fi

# Verificar logs recentes
print_status "📋 Logs recentes:"
if [ -d "logs" ]; then
    for log_file in logs/*.log; do
        if [ -f "$log_file" ]; then
            service_name=$(basename "$log_file" .log)
            print_status "  📄 $service_name:"
            tail -3 "$log_file" 2>/dev/null | sed 's/^/    /' || echo "    (sem logs)"
        fi
    done
else
    print_warning "  Diretório logs não encontrado"
fi

echo ""

# Recursos do sistema
print_status "💻 Recursos do sistema:"
if command -v free &> /dev/null; then
    memory_info=$(free -h | grep "Mem:" | awk '{print $3 "/" $2}')
    print_status "  RAM: $memory_info"
fi

if command -v df &> /dev/null; then
    disk_info=$(df -h . | tail -1 | awk '{print $3 "/" $2 " (" $5 " usado)"}')
    print_status "  Disco: $disk_info"
fi

if command -v uptime &> /dev/null; then
    load_info=$(uptime | awk -F'load average:' '{print $2}')
    print_status "  Load:$load_info"
fi

echo ""

# Comandos úteis
print_status "🔧 Comandos úteis:"
echo "  📊 Logs ao vivo:    tail -f logs/*.log"
echo "  🔄 Reiniciar:       ./stop-baas.sh && ./run-baas.sh"
echo "  ⚙️  Configuração:    ls -la docker/*/.*env*"
echo "  🧼 Limpar logs:     rm -f logs/*.log"

# Verificar dependências opcionais
echo ""
print_status "🔍 Dependências opcionais:"

optional_deps=(
    "docker:Docker para containers"
    "postgresql:PostgreSQL para banco de dados"
    "redis:Redis para cache"
    "nginx:Nginx para proxy reverso"
)

for dep in "${optional_deps[@]}"; do
    IFS=':' read -r cmd desc <<< "$dep"
    if command -v $cmd &> /dev/null; then
        version=$($cmd --version 2>/dev/null | head -1 || echo "instalado")
        print_success "  ✅ $desc ($version)"
    else
        print_warning "  ⚠️  $desc (não instalado)"
    fi
done

echo ""
print_status "📊 Status completo verificado!"