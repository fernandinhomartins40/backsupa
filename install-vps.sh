#!/bin/bash
# Script de Instalação Simplificada - Supabase BaaS Multi-Tenant
# VPS: root@82.25.69.57
# Execute: curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh | bash

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configurações
REPO_URL="https://github.com/fernandinhomartins40/backsupa.git"
INSTALL_DIR="/opt/supabase-baas"
DOMAIN="${DOMAIN:-82.25.69.57.sslip.io}"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
    error "Execute como root: sudo bash install-vps.sh"
fi

log "🚀 Iniciando instalação do Supabase BaaS Multi-Tenant..."

# Atualizar sistema
log "Atualizando sistema..."
apt update && apt upgrade -y

# Instalar dependências
log "Instalando dependências..."
apt install -y git curl wget vim htop ufw fail2ban nginx nginx-extras lua-cjson jq openssl docker.io docker-compose certbot python3-certbot-nginx

# Configurar Docker
systemctl enable docker
systemctl start docker

# Configurar firewall
log "Configurando firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000:3010/tcp
ufw --force enable

# Clonar repositório
log "Baixando código..."
git clone "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Tornar scripts executáveis
chmod +x deploy-vps.sh
chmod +x docker/*.bash
chmod +x docker/*.sh
chmod +x scripts/*.sh

# Executar deploy
log "Executando deploy automático..."
./deploy-vps.sh

log "✅ Instalação concluída!"
log "Acesse: https://demo.$DOMAIN"
log "Grafana: https://$DOMAIN:3004 (admin/admin)"
log "Logs: tail -f /var/log/supabase-baas-deploy.log"
