#!/bin/bash
# BaaS Supabase Clone - Script para parar todos os serviços

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

print_status "🛑 Parando BaaS Supabase Clone..."

# Função para parar serviço por PID
stop_service() {
    local name=$1
    local pid_file="logs/${name,,}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            print_status "Parando $name (PID: $pid)..."
            kill $pid
            sleep 2
            
            # Verificar se o processo foi terminado
            if kill -0 $pid 2>/dev/null; then
                print_warning "Forçando parada do $name..."
                kill -9 $pid
            fi
            
            print_success "$name parado"
        else
            print_warning "$name já estava parado"
        fi
        
        rm -f "$pid_file"
    else
        print_warning "Arquivo PID para $name não encontrado"
    fi
}

# Função para parar por porta
stop_by_port() {
    local port=$1
    local name=$2
    
    print_status "Verificando porta $port para $name..."
    
    # Tentar encontrar o processo pela porta (Linux/Mac)
    if command -v lsof &> /dev/null; then
        local pid=$(lsof -ti:$port 2>/dev/null || echo "")
        if [ -n "$pid" ]; then
            print_status "Matando processo na porta $port (PID: $pid)..."
            kill $pid 2>/dev/null || true
            sleep 1
            print_success "Processo na porta $port terminado"
        fi
    fi
    
    # Windows (se estiver usando GitBash/WSL)
    if command -v netstat &> /dev/null && [[ "$OSTYPE" == "msys" ]]; then
        local pid=$(netstat -ano | grep ":$port " | awk '{print $5}' | head -1)
        if [ -n "$pid" ] && [ "$pid" != "0" ]; then
            print_status "Matando processo na porta $port (PID: $pid)..."
            taskkill //PID $pid //F 2>/dev/null || true
            print_success "Processo na porta $port terminado"
        fi
    fi
}

# Parar serviços por PID primeiro
if [ -d "logs" ]; then
    stop_service "Studio"
    stop_service "Control-API"
    stop_service "Billing-API"
    stop_service "Marketplace-API"
else
    print_warning "Diretório logs não encontrado"
fi

# Parar por portas como fallback
print_status "Verificando portas..."
stop_by_port 3000 "Studio"
stop_by_port 3001 "Control-API"
stop_by_port 3002 "Billing-API"
stop_by_port 3003 "Marketplace-API"

# Limpar arquivos temporários
print_status "Limpando arquivos temporários..."
if [ -d "logs" ]; then
    rm -f logs/*.pid
    print_success "Arquivos PID removidos"
fi

# Verificar se algum processo ainda está rodando
print_status "Verificando se os serviços foram parados..."

check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port " || \
       (command -v lsof &> /dev/null && lsof -ti:$port &>/dev/null); then
        return 0 # Porta ainda em uso
    else
        return 1 # Porta livre
    fi
}

all_stopped=true
for port in 3000 3001 3002 3003; do
    if check_port $port; then
        print_warning "Porta $port ainda está em uso"
        all_stopped=false
    else
        print_success "Porta $port livre"
    fi
done

echo ""
if [ "$all_stopped" = true ]; then
    print_success "✅ Todos os serviços foram parados com sucesso!"
else
    print_warning "⚠️  Alguns serviços podem ainda estar rodando"
    print_status "Use: netstat -tuln | grep '300[0-3]' para verificar"
fi

print_status "🏁 BaaS Supabase Clone parado!"