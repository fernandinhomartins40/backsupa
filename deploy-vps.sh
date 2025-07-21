#!/bin/bash
# Script de Auto-Hospedagem Supabase BaaS Multi-Tenant
# VPS: root@82.25.69.57
# Autor: Sistema BaaS Supabase Clone

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
DOMAIN="${DOMAIN:-82.25.69.57.sslip.io}"
EMAIL="${EMAIL:-admin@82.25.69.57.sslip.io}"
INSTALL_DIR="/opt/supabase-baas"
BACKUP_DIR="/opt/supabase-baas/backups"
LOG_FILE="/var/log/supabase-baas-deploy.log"

# Funções auxiliares
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERRO] $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[AVISO] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

# Verificar se está rodando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script deve ser executado como root"
    fi
}

# Verificar conectividade
check_connectivity() {
    log "Verificando conectividade com a internet..."
    if ! ping -c 1 google.com &> /dev/null; then
        error "Sem conectividade com a internet"
    fi
}

# Atualizar sistema
update_system() {
    log "Atualizando sistema..."
    apt update && apt upgrade -y
    apt install -y curl wget git vim htop ufw fail2ban
}

# Instalar Docker
install_docker() {
    log "Instalando Docker..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
        usermod -aG docker root
    else
        info "Docker já está instalado"
    fi
}

# Instalar Docker Compose
install_docker_compose() {
    log "Instalando Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        info "Docker Compose já está instalado"
    fi
}

# Configurar firewall
setup_firewall() {
    log "Configurando firewall..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 3000/tcp  # Control API
    ufw allow 3001/tcp  # Studio
    ufw allow 3002/tcp  # Billing API
    ufw allow 3003/tcp  # Marketplace API
    ufw allow 9090/tcp  # Prometheus
    ufw allow 3004/tcp  # Grafana
    ufw --force enable
}

# Instalar Nginx
install_nginx() {
    log "Instalando Nginx..."
    apt install -y nginx nginx-extras lua-cjson
    
    # Configurar Nginx para otimização
    cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml;

    # Rate Limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=30r/m;
    limit_req_zone \$binary_remote_addr zone=auth:10m rate=5r/m;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
}

# Instalar dependências
install_dependencies() {
    log "Instalando dependências..."
    apt install -y jq openssl certbot python3-certbot-nginx
}

# Criar estrutura de diretórios
create_directories() {
    log "Criando estrutura de diretórios..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/instances"
    mkdir -p "$INSTALL_DIR/backups"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$INSTALL_DIR/ssl"
    mkdir -p "$INSTALL_DIR/monitoring"
}

# Configurar SSL com Let's Encrypt
setup_ssl() {
    log "Configurando SSL..."
    
    # Aguardar Nginx iniciar
    systemctl start nginx
    
    # Obter certificado SSL
    if ! certbot --nginx -d "$DOMAIN" -d "*.$DOMAIN" --agree-tos --email "$EMAIL" --non-interactive; then
        warning "Falha ao obter certificado SSL. Usando certificado auto-assinado."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$INSTALL_DIR/ssl/supabase.key" \
            -out "$INSTALL_DIR/ssl/supabase.crt" \
            -subj "/C=BR/ST=SP/L=SaoPaulo/O=SupabaseBaaS/CN=$DOMAIN"
    fi
    
    # Configurar renovação automática
    echo "0 12 * * * root certbot renew --quiet" >> /etc/crontab
}

# Copiar arquivos do projeto
copy_project_files() {
    log "Copiando arquivos do projeto..."
    
    # Copiar scripts e configurações
    cp -r docker/* "$INSTALL_DIR/"
    cp -r scripts/* "$INSTALL_DIR/scripts/"
    
    # Tornar scripts executáveis
    chmod +x "$INSTALL_DIR"/*.bash
    chmod +x "$INSTALL_DIR"/*.sh
    chmod +x "$INSTALL_DIR/scripts"/*.sh
    
    # Criar link simbólico para comandos
    ln -sf "$INSTALL_DIR/generate.bash" /usr/local/bin/supabase-create
    ln -sf "$INSTALL_DIR/nginx-manager.sh" /usr/local/bin/supabase-routes
}

# Configurar Nginx para multi-tenant
configure_nginx() {
    log "Configurando Nginx para multi-tenant..."
    
    cat > /etc/nginx/sites-available/supabase-baas << EOF
server {
    listen 80;
    server_name $DOMAIN *.$DOMAIN;
    
    # Redirect to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN *.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Rate limiting
    limit_req zone=api burst=20 nodelay;
    
    # Lua routing
    location / {
        set \$target '';
        access_by_lua_block {
            local cjson = require "cjson"
            local subdomain = ngx.var.host:match("^([^%.]+)%.")
            
            if subdomain then
                local routes_file = "/opt/supabase-baas/routes.json"
                local file = io.open(routes_file, "r")
                if file then
                    local content = file:read("*all")
                    file:close()
                    local routes = cjson.decode(content)
                    if routes[subdomain] then
                        ngx.var.target = "127.0.0.1:" .. routes[subdomain]
                    end
                end
            end
            
            if ngx.var.target == '' then
                ngx.var.target = "127.0.0.1:3001"
            end
        }
        
        proxy_pass http://\$target;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/supabase-baas /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
}

# Configurar monitoramento
setup_monitoring() {
    log "Configurando monitoramento..."
    
    # Copiar configurações de monitoramento
    cp -r docker/monitoring/* "$INSTALL_DIR/monitoring/"
    
    # Iniciar stack de monitoramento
    cd "$INSTALL_DIR/monitoring"
    docker-compose -f docker-compose.simple.yml up -d
    
    # Configurar health checks
    cat > "$INSTALL_DIR/scripts/health_check.sh" << 'EOF'
#!/bin/bash
# Health check para todas as instâncias

ROUTES_FILE="/opt/supabase-baas/routes.json"
LOG_FILE="/opt/supabase-baas/logs/health.log"

check_instance() {
    local subdomain=$1
    local port=$2
    
    if curl -f -s "http://127.0.0.1:$port/health" > /dev/null; then
        echo "$(date): $subdomain - OK" >> "$LOG_FILE"
        return 0
    else
        echo "$(date): $subdomain - FAIL" >> "$LOG_FILE"
        return 1
    fi
}

# Verificar todas as instâncias
if [[ -f "$ROUTES_FILE" ]]; then
    jq -r 'to_entries[] | "\(.key) \(.value)"' "$ROUTES_FILE" | while read -r subdomain port; do
        check_instance "$subdomain" "$port"
    done
fi
EOF
    
    chmod +x "$INSTALL_DIR/scripts/health_check.sh"
    
    # Adicionar ao cron
    echo "*/5 * * * * root $INSTALL_DIR/scripts/health_check.sh" >> /etc/crontab
}

# Configurar backup automático
setup_backup() {
    log "Configurando backup automático..."
    
    cat > "$INSTALL_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash
# Backup automático de instâncias

BACKUP_DIR="/opt/supabase-baas/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup do arquivo de rotas
cp /opt/supabase-baas/routes.json "$BACKUP_DIR/routes_$DATE.json"

# Backup de cada instância
for instance_dir in /opt/supabase-baas/instances/*/; do
    if [[ -d "$instance_dir" ]]; then
        instance_name=$(basename "$instance_dir")
        echo "Fazendo backup da instância: $instance_name"
        
        # Backup do banco de dados
        cd "$instance_dir"
        docker-compose exec -T db pg_dump -U postgres postgres > "$BACKUP_DIR/${instance_name}_db_$DATE.sql"
        
        # Backup dos volumes
        tar -czf "$BACKUP_DIR/${instance_name}_volumes_$DATE.tar.gz" volumes/
    fi
done

# Limpar backups antigos (manter últimos 7 dias)
find "$BACKUP_DIR" -name "*.sql" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.json" -mtime +7 -delete
EOF
    
    chmod +x "$INSTALL_DIR/scripts/backup.sh"
    
    # Adicionar ao cron (diário às 2h)
    echo "0 2 * * * root $INSTALL_DIR/scripts/backup.sh" >> /etc/crontab
}

# Configurar inicialização automática
setup_autostart() {
    log "Configurando inicialização automática..."
    
    cat > /etc/systemd/system/supabase-baas.service << EOF
[Unit]
Description=Supabase BaaS Multi-Tenant
After=docker.service network.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/supabase-baas/scripts/start_all.sh
ExecStop=/opt/supabase-baas/scripts/stop_all.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    cat > "$INSTALL_DIR/scripts/start_all.sh" << 'EOF'
#!/bin/bash
# Iniciar todas as instâncias

# Iniciar monitoramento
cd /opt/supabase-baas/monitoring
docker-compose -f docker-compose.simple.yml up -d

# Iniciar cada instância
for instance_dir in /opt/supabase-baas/instances/*/; do
    if [[ -d "$instance_dir" ]]; then
        instance_name=$(basename "$instance_dir")
        echo "Iniciando instância: $instance_name"
        cd "$instance_dir"
        docker-compose up -d
    fi
done
EOF
    
    cat > "$INSTALL_DIR/scripts/stop_all.sh" << 'EOF'
#!/bin/bash
# Parar todas as instâncias

# Parar cada instância
for instance_dir in /opt/supabase-baas/instances/*/; do
    if [[ -d "$instance_dir" ]]; then
        instance_name=$(basename "$instance_dir")
        echo "Parando instância: $instance_name"
        cd "$instance_dir"
        docker-compose down
    fi
done

# Parar monitoramento
cd /opt/supabase-baas/monitoring
docker-compose -f docker-compose.simple.yml down
EOF
    
    chmod +x "$INSTALL_DIR/scripts/start_all.sh"
    chmod +x "$INSTALL_DIR/scripts/stop_all.sh"
    
    systemctl daemon-reload
    systemctl enable supabase-baas.service
}

# Criar instância de demonstração
create_demo_instance() {
    log "Criando instância de demonstração..."
    
    cd "$INSTALL_DIR"
    ./generate.bash --project="demo" --org-id="demo" --subdomain="demo"
}

# Função principal
main() {
    log "Iniciando deploy do Supabase BaaS Multi-Tenant..."
    
    check_root
    check_connectivity
    update_system
    install_docker
    install_docker_compose
    install_dependencies
    create_directories
    setup_firewall
    install_nginx
    setup_ssl
    copy_project_files
    configure_nginx
    setup_monitoring
    setup_backup
    setup_autostart
    create_demo_instance
    
    log "Deploy concluído com sucesso!"
    log "Acesse a instância de demonstração: https://demo.$DOMAIN"
    log "Painel de monitoramento: https://$DOMAIN:3004 (admin/admin)"
    log "Logs: tail -f $LOG_FILE"
}

# Executar
main "$@"
