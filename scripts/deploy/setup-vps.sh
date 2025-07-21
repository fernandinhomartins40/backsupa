#!/bin/bash
# setup-vps.sh - Script inicial para configurar VPS
# Uso: ./setup-vps.sh

set -euo pipefail

# Configurações
VPS_USER="root"
APP_DIR="/opt/supabase-baas"
LOG_FILE="/var/log/supabase-setup.log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S') WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S') ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

# Verificar se é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
}

# Atualizar sistema
update_system() {
    log "Atualizando sistema..."
    
    apt-get update -y
    apt-get upgrade -y
    
    # Instalar pacotes essenciais
    apt-get install -y \
        curl \
        wget \
        unzip \
        git \
        htop \
        vim \
        ufw \
        fail2ban \
        jq \
        openssl \
        sshpass \
        net-tools \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common
        
    log "Sistema atualizado com sucesso"
}

# Instalar Docker
install_docker() {
    log "Instalando Docker..."
    
    # Remover versões antigas
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Adicionar repositório Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Iniciar e habilitar Docker
    systemctl start docker
    systemctl enable docker
    
    # Adicionar usuário ao grupo docker
    usermod -aG docker $USER || true
    
    # Verificar instalação
    docker --version
    docker compose version
    
    log "Docker instalado com sucesso"
}

# Instalar Node.js
install_nodejs() {
    log "Instalando Node.js..."
    
    # Instalar Node.js 20
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    
    # Verificar instalação
    node --version
    npm --version
    
    # Instalar PM2 globalmente
    npm install -g pm2
    
    log "Node.js instalado com sucesso"
}

# Instalar Nginx
install_nginx() {
    log "Instalando Nginx..."
    
    apt-get install -y nginx nginx-extras
    
    # Parar nginx padrão
    systemctl stop nginx
    
    # Habilitar nginx
    systemctl enable nginx
    
    # Criar backup da configuração padrão
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    
    log "Nginx instalado com sucesso"
}

# Configurar firewall
configure_firewall() {
    log "Configurando firewall..."
    
    # Reset UFW
    ufw --force reset
    
    # Regras básicas
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH
    ufw allow ssh
    ufw allow 22/tcp
    
    # Permitir HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Permitir APIs (interno)
    ufw allow from 10.0.0.0/8 to any port 3001,3002,3003
    ufw allow from 172.16.0.0/12 to any port 3001,3002,3003
    ufw allow from 192.168.0.0/16 to any port 3001,3002,3003
    
    # Permitir PostgreSQL (interno)
    ufw allow from 10.0.0.0/8 to any port 5432
    ufw allow from 172.16.0.0/12 to any port 5432
    ufw allow from 192.168.0.0/16 to any port 5432
    
    # Habilitar firewall
    ufw --force enable
    
    log "Firewall configurado com sucesso"
}

# Configurar fail2ban
configure_fail2ban() {
    log "Configurando fail2ban..."
    
    # Criar configuração customizada
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 7200

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
bantime = 600
EOF
    
    # Reiniciar fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "Fail2ban configurado com sucesso"
}

# Criar estrutura de diretórios
create_directories() {
    log "Criando estrutura de diretórios..."
    
    # Diretórios principais
    mkdir -p $APP_DIR
    mkdir -p $APP_DIR/backups
    mkdir -p $APP_DIR/logs
    mkdir -p $APP_DIR/ssl
    mkdir -p $APP_DIR/scripts
    
    # Diretórios para instâncias
    mkdir -p /opt/supabase-instances
    
    # Diretórios de log
    mkdir -p /var/log/supabase-baas
    mkdir -p /var/log/nginx
    
    # Diretório web
    mkdir -p /var/www/html
    
    # Definir permissões
    chown -R $USER:$USER $APP_DIR
    chmod -R 755 $APP_DIR
    
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    
    log "Estrutura de diretórios criada"
}

# Configurar SSL auto-assinado (desenvolvimento)
setup_ssl() {
    log "Configurando SSL auto-assinado..."
    
    # Criar certificado auto-assinado
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout $APP_DIR/ssl/nginx-selfsigned.key \
        -out $APP_DIR/ssl/nginx-selfsigned.crt \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=SupabaseBaaS/CN=localhost"
    
    # Criar parâmetros DH
    openssl dhparam -out $APP_DIR/ssl/dhparam.pem 2048
    
    # Definir permissões
    chmod 600 $APP_DIR/ssl/nginx-selfsigned.key
    chmod 644 $APP_DIR/ssl/nginx-selfsigned.crt
    chmod 644 $APP_DIR/ssl/dhparam.pem
    
    log "SSL configurado (certificado auto-assinado)"
}

# Configurar logrotate
configure_logrotate() {
    log "Configurando logrotate..."
    
    cat > /etc/logrotate.d/supabase-baas << EOF
/var/log/supabase-baas/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log "Logrotate configurado"
}

# Configurar cron jobs básicos
configure_cron() {
    log "Configurando cron jobs básicos..."
    
    # Backup automático de logs
    (crontab -l 2>/dev/null; echo "0 2 * * * find /var/log/supabase-baas -name '*.log' -mtime +7 -delete") | crontab -
    
    # Limpeza de containers órfãos
    (crontab -l 2>/dev/null; echo "0 3 * * 0 docker system prune -f") | crontab -
    
    # Update automático de segurança
    (crontab -l 2>/dev/null; echo "0 4 * * 1 apt-get update && apt-get upgrade -y --security") | crontab -
    
    log "Cron jobs configurados"
}

# Otimizar sistema
optimize_system() {
    log "Otimizando sistema..."
    
    # Configurar limites do sistema
    cat >> /etc/security/limits.conf << EOF

# Supabase BaaS limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
    
    # Configurar kernel parameters
    cat >> /etc/sysctl.conf << EOF

# Supabase BaaS optimizations
vm.max_map_count = 262144
net.core.somaxconn = 1024
net.ipv4.ip_local_port_range = 1024 65535
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
EOF
    
    # Aplicar configurações
    sysctl -p
    
    log "Sistema otimizado"
}

# Criar página de status
create_status_page() {
    log "Criando página de status..."
    
    cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Supabase BaaS - Server Status</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .status { padding: 15px; border-radius: 5px; margin: 10px 0; }
        .status.success { background: #d4edda; border-left: 4px solid #28a745; }
        .status.warning { background: #fff3cd; border-left: 4px solid #ffc107; }
        .status.error { background: #f8d7da; border-left: 4px solid #dc3545; }
        .info { background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0; }
        h1 { color: #333; }
        code { background: #f8f9fa; padding: 2px 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Supabase BaaS Server</h1>
        
        <div class="status success">
            <strong>✅ Server Setup Complete</strong><br>
            O servidor foi configurado com sucesso e está pronto para deployment.
        </div>
        
        <div class="info">
            <h3>Próximos Passos:</h3>
            <ol>
                <li>Configure as secrets no GitHub: <code>VPS_PASSWORD</code></li>
                <li>Ajuste o domínio no workflow: <code>.github/workflows/deploy.yml</code></li>
                <li>Faça push para a branch <code>main</code> para deploy automático</li>
            </ol>
        </div>
        
        <div class="info">
            <h3>Informações do Sistema:</h3>
            <p><strong>Setup Date:</strong> $(date)</p>
            <p><strong>Docker:</strong> $(docker --version 2>/dev/null || echo "Not installed")</p>
            <p><strong>Node.js:</strong> $(node --version 2>/dev/null || echo "Not installed")</p>
            <p><strong>Nginx:</strong> $(nginx -v 2>&1 || echo "Not installed")</p>
        </div>
        
        <div class="status warning">
            <strong>⚠️ Configuração SSL</strong><br>
            Usando certificado auto-assinado. Configure SSL válido para produção.
        </div>
    </div>
</body>
</html>
EOF
    
    log "Página de status criada"
}

# Função principal
main() {
    log "=== Iniciando setup do servidor VPS ==="
    
    check_root
    update_system
    install_docker
    install_nodejs
    install_nginx
    configure_firewall
    configure_fail2ban
    create_directories
    setup_ssl
    configure_logrotate
    configure_cron
    optimize_system
    create_status_page
    
    log "=== Setup concluído com sucesso! ==="
    log ""
    log "Próximos passos:"
    log "1. Configure as secrets no GitHub (VPS_PASSWORD)"
    log "2. Ajuste o domínio no workflow de deploy"
    log "3. Faça push para main para iniciar deploy automático"
    log ""
    log "Acesse: http://$(hostname -I | awk '{print $1}') para ver a página de status"
    log ""
}

# Executar script
main "$@"