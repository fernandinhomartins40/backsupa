#!/bin/bash
# BaaS Supabase Clone - Script de execução completo
# Executa todas as partes do sistema sem Docker

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir com cores
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

# Verificar se estamos no diretório correto
if [ ! -f "package.json" ]; then
    print_error "Execute este script na raiz do projeto backsupa"
    exit 1
fi

print_status "🚀 Iniciando BaaS Supabase Clone..."

# Verificar dependências
print_status "Verificando dependências..."

if ! command -v node &> /dev/null; then
    print_error "Node.js não encontrado! Instale o Node.js primeiro."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm não encontrado! Instale o npm primeiro."
    exit 1
fi

node_version=$(node --version)
print_success "Node.js $node_version encontrado"

# Função para verificar se uma porta está em uso
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 0 # Porta em uso
    else
        return 1 # Porta livre
    fi
}

# Verificar portas necessárias
print_status "Verificando portas disponíveis..."

ports_to_check=(3000 3001 3002 3003)
for port in "${ports_to_check[@]}"; do
    if check_port $port; then
        print_warning "Porta $port já está em uso"
    else
        print_success "Porta $port disponível"
    fi
done

# Função para instalar dependências se necessário
install_if_needed() {
    local dir=$1
    local name=$2
    
    if [ -d "$dir" ]; then
        cd "$dir"
        if [ ! -d "node_modules" ]; then
            print_status "Instalando dependências para $name..."
            npm install
            print_success "Dependências do $name instaladas"
        else
            print_success "Dependências do $name já instaladas"
        fi
        cd - > /dev/null
    else
        print_warning "Diretório $dir não encontrado"
    fi
}

# Instalar dependências de todos os componentes
print_status "📦 Instalando dependências..."

install_if_needed "apps/studio" "Studio"
install_if_needed "docker/control-api" "Control API"
install_if_needed "docker/billing-system/billing-api" "Billing API"
install_if_needed "docker/billing-system/marketplace" "Marketplace API"

# Criar arquivos de configuração se não existirem
print_status "⚙️ Configurando variáveis de ambiente..."

# Control API
if [ ! -f "docker/control-api/.env" ] && [ -f "docker/control-api/.env.example" ]; then
    cp "docker/control-api/.env.example" "docker/control-api/.env"
    print_success "Arquivo .env criado para Control API"
fi

# Billing API
if [ ! -f "docker/billing-system/billing-api/.env" ] && [ -f "docker/billing-system/billing-api/.env.example" ]; then
    cp "docker/billing-system/billing-api/.env.example" "docker/billing-system/billing-api/.env"
    print_success "Arquivo .env criado para Billing API"
fi

# Função para executar serviços em background
run_service() {
    local dir=$1
    local name=$2
    local port=$3
    local command=${4:-"npm start"}
    
    if [ -d "$dir" ]; then
        print_status "Iniciando $name na porta $port..."
        cd "$dir"
        
        # Verificar se já está rodando
        if check_port $port; then
            print_warning "$name já está rodando na porta $port"
        else
            # Executar em background
            nohup $command > "../logs/${name,,}.log" 2>&1 &
            local pid=$!
            echo $pid > "../logs/${name,,}.pid"
            print_success "$name iniciado com PID $pid"
        fi
        
        cd - > /dev/null
    else
        print_error "Diretório $dir não encontrado"
    fi
}

# Criar diretório de logs
mkdir -p logs

print_status "🎬 Iniciando serviços..."

# 1. Control API (Porta 3001)
run_service "docker/control-api" "Control-API" 3001

# 2. Billing API (Porta 3002) 
run_service "docker/billing-system/billing-api" "Billing-API" 3002

# 3. Marketplace API (Porta 3003)
run_service "docker/billing-system/marketplace" "Marketplace-API" 3003

# 4. Studio (Porta 3000)
run_service "apps/studio" "Studio" 3000 "npm run dev"

# Aguardar um pouco para os serviços iniciarem
print_status "⏳ Aguardando serviços iniciarem..."
sleep 5

# Verificar se os serviços estão rodando
print_status "🔍 Verificando status dos serviços..."

services=(
    "Studio:3000:http://localhost:3000"
    "Control-API:3001:http://localhost:3001/health"
    "Billing-API:3002:http://localhost:3002/health"
    "Marketplace-API:3003:http://localhost:3003/health"
)

all_running=true

for service in "${services[@]}"; do
    IFS=':' read -r name port url <<< "$service"
    
    if check_port $port; then
        print_success "$name está rodando na porta $port"
        print_status "  URL: $url"
    else
        print_error "$name NÃO está rodando na porta $port"
        all_running=false
    fi
done

echo ""
if [ "$all_running" = true ]; then
    print_success "🎉 Todos os serviços estão rodando!"
    echo ""
    print_status "📝 URLs de acesso:"
    echo "  🎨 Studio:          http://localhost:3000"
    echo "  🔧 Control API:     http://localhost:3001/health"
    echo "  💰 Billing API:     http://localhost:3002/api/plans"
    echo "  🏪 Marketplace API: http://localhost:3003/api/templates"
    echo ""
    print_status "📋 Comandos úteis:"
    echo "  Logs: tail -f logs/*.log"
    echo "  Parar: ./stop-baas.sh"
    echo "  Status: ./status-baas.sh"
else
    print_error "❌ Alguns serviços falharam ao iniciar"
    print_status "Verifique os logs em: logs/"
fi

print_status "🚀 BaaS Supabase Clone inicializado!"

# Instruções finais
echo ""
print_status "📚 Próximos passos:"
echo "1. Configure um banco PostgreSQL"
echo "2. Execute os schemas SQL em docker/billing-system/"
echo "3. Configure as variáveis de ambiente nas APIs"
echo "4. Teste as APIs e o Studio"
echo ""
print_warning "⚠️  ATENÇÃO: Esta execução é para desenvolvimento."
print_warning "   Para produção, use Docker e configure adequadamente."