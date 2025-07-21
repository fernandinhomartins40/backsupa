#!/bin/bash
# first-time-setup.sh - Script para preparar VPS para primeiro deploy
# Uso: curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/scripts/deploy/first-time-setup.sh | bash

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Preparando VPS para primeiro deploy ===${NC}"

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root${NC}"
   exit 1
fi

# Diretório da aplicação
APP_DIR="/opt/supabase-baas"

# Criar diretório se não existir
echo -e "${YELLOW}Criando estrutura de diretórios...${NC}"
mkdir -p $APP_DIR
cd $APP_DIR

# Instalar Docker se não estiver instalado
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Instalando Docker...${NC}"
    curl -fsSL https://get.docker.com | bash
    systemctl start docker
    systemctl enable docker
fi

# Instalar Docker Compose se não estiver instalado
if ! command -v docker compose &> /dev/null; then
    echo -e "${YELLOW}Instalando Docker Compose...${NC}"
    curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Clonar repositório se não existir
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Clonando repositório...${NC}"
    git clone https://github.com/fernandinhomartins40/backsupa.git .
else
    echo -e "${YELLOW}Atualizando repositório...${NC}"
    git pull origin main
fi

# Verificar se temos o docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}Copiando docker-compose.yml do diretório docker...${NC}"
    cp docker/docker-compose.yml ./docker-compose.yml
fi

# Criar arquivo .env básico se não existir
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Criando arquivo .env básico...${NC}"
    cat > .env << 'EOF'
# Configurações básicas para primeiro deploy
POSTGRES_PASSWORD=your-secure-password-here
JWT_SECRET=your-jwt-secret-here
ANON_KEY=your-anon-key-here
SERVICE_ROLE_KEY=your-service-role-key-here

# Domínio (ajuste conforme necessário)
API_EXTERNAL_URL=http://localhost:8000
SUPABASE_PUBLIC_URL=http://localhost:8000

# Portas
POSTGRES_PORT=5432
KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443
STUDIO_PORT=3000
EOF
    echo -e "${YELLOW}⚠️  IMPORTANTE: Edite o arquivo .env e configure as senhas seguras!${NC}"
fi

# Testar Docker Compose
echo -e "${YELLOW}Testando Docker Compose...${NC}"
docker compose config

# Criar volumes necessários
echo -e "${YELLOW}Criando volumes Docker...${NC}"
docker volume create supabase-db-data || true
docker volume create supabase-storage || true

# Definir permissões
echo -e "${YELLOW}Configurando permissões...${NC}"
chown -R $USER:$USER $APP_DIR
chmod -R 755 $APP_DIR

echo -e "${GREEN}✅ VPS preparado com sucesso!${NC}"
echo ""
echo -e "${GREEN}Próximos passos:${NC}"
echo "1. Configure as variáveis no arquivo .env"
echo "2. Configure a secret VPS_PASSWORD no GitHub"
echo "3. Faça push para a branch main para iniciar o deploy automático"
echo ""
echo -e "${YELLOW}Para deploy manual:${NC}"
echo "cd $APP_DIR && docker compose up -d --build"
