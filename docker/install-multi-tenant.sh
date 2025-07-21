#!/bin/bash

# Script de Instalação - Supabase Multi-Tenant BaaS
# Este script configura o ambiente para suporte multi-tenant

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações padrão
INSTANCES_DIR="/opt/supabase-instances"
NGINX_CONFIG_SOURCE="$(dirname "$0")/nginx-config/supabase-baas"
NGINX_MANAGER_SOURCE="$(dirname "$0")/nginx-manager.sh"

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log_step() {
    echo -e "${BLUE}[STEP] $1${NC}"
}

# Verificar se está rodando como root para algumas operações
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script precisa ser executado como root para configurar o Nginx"
        log "Execute: sudo $0"
        exit 1
    fi
}

# Instalar dependências necessárias
install_dependencies() {
    log_step "Verificando e instalando dependências..."
    
    # Lista de pacotes necessários
    local packages=("nginx" "jq" "openssl" "docker.io" "docker-compose")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! command -v "$package" &> /dev/null && ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log "Instalando pacotes faltantes: ${missing_packages[*]}"
        apt-get update
        apt-get install -y "${missing_packages[@]}"
        
        if [ $? -ne 0 ]; then
            log_error "Falha ao instalar dependências"
            exit 1
        fi
    else
        log "Todas as dependências já estão instaladas"
    fi
}

# Verificar se Nginx suporta Lua
check_nginx_lua() {
    log_step "Verificando suporte Lua no Nginx..."
    
    if nginx -V 2>&1 | grep -q "lua"; then
        log "Nginx com suporte Lua detectado"
        return 0
    else
        log_warning "Nginx sem suporte Lua detectado"
        log "Instalando nginx-extras com suporte Lua..."
        
        apt-get install -y nginx-extras lua-cjson
        
        if [ $? -eq 0 ]; then
            log "Nginx com Lua instalado com sucesso"
            return 0
        else
            log_error "Falha ao instalar Nginx com Lua"
            return 1
        fi
    fi
}

# Criar estrutura de diretórios
create_directories() {
    log_step "Criando estrutura de diretórios..."
    
    # Criar diretório principal das instâncias
    mkdir -p "$INSTANCES_DIR"
    mkdir -p "$INSTANCES_DIR/backups"
    
    # Definir permissões
    chown -R root:root "$INSTANCES_DIR"
    chmod -R 755 "$INSTANCES_DIR"
    
    log "Diretórios criados em: $INSTANCES_DIR"
}

# Copiar e configurar nginx-manager.sh
setup_nginx_manager() {
    log_step "Configurando nginx-manager.sh..."
    
    if [ -f "$NGINX_MANAGER_SOURCE" ]; then
        cp "$NGINX_MANAGER_SOURCE" "$INSTANCES_DIR/nginx-manager.sh"
        chmod +x "$INSTANCES_DIR/nginx-manager.sh"
        
        # Criar symlink para facilitar o uso
        ln -sf "$INSTANCES_DIR/nginx-manager.sh" /usr/local/bin/supabase-routes
        
        log "nginx-manager.sh instalado em: $INSTANCES_DIR/nginx-manager.sh"
        log "Comando disponível: supabase-routes"
    else
        log_error "Arquivo nginx-manager.sh não encontrado: $NGINX_MANAGER_SOURCE"
        return 1
    fi
}

# Configurar Nginx
setup_nginx() {
    log_step "Configurando Nginx..."
    
    if [ -f "$NGINX_CONFIG_SOURCE" ]; then
        # Instalar configuração
        "$INSTANCES_DIR/nginx-manager.sh" install_config "$NGINX_CONFIG_SOURCE"
        
        if [ $? -eq 0 ]; then
            log "Configuração do Nginx instalada com sucesso"
        else
            log_error "Falha ao instalar configuração do Nginx"
            return 1
        fi
    else
        log_error "Arquivo de configuração do Nginx não encontrado: $NGINX_CONFIG_SOURCE"
        return 1
    fi
}

# Inicializar arquivo de rotas
init_routes_file() {
    log_step "Inicializando arquivo de rotas..."
    
    echo '{}' > "$INSTANCES_DIR/routes.json"
    chmod 644 "$INSTANCES_DIR/routes.json"
    
    log "Arquivo de rotas inicializado: $INSTANCES_DIR/routes.json"
}

# Configurar SSL (certificados auto-assinados para desenvolvimento)
setup_ssl() {
    log_step "Configurando SSL para desenvolvimento..."
    
    local ssl_dir="/etc/ssl/supabase"
    mkdir -p "$ssl_dir"
    
    # Gerar certificado auto-assinado para desenvolvimento
    if [ ! -f "$ssl_dir/wildcard.yourdomain.com.crt" ]; then
        log "Gerando certificado SSL auto-assinado..."
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$ssl_dir/wildcard.yourdomain.com.key" \
            -out "$ssl_dir/wildcard.yourdomain.com.crt" \
            -subj "/C=BR/ST=State/L=City/O=Organization/OU=OrgUnit/CN=*.yourdomain.com"
        
        # Atualizar configuração do Nginx com o caminho correto
        sed -i "s|/etc/ssl/certs/wildcard.yourdomain.com.crt|$ssl_dir/wildcard.yourdomain.com.crt|g" /etc/nginx/sites-available/supabase-baas
        sed -i "s|/etc/ssl/private/wildcard.yourdomain.com.key|$ssl_dir/wildcard.yourdomain.com.key|g" /etc/nginx/sites-available/supabase-baas
        
        log "Certificado SSL gerado em: $ssl_dir"
        log_warning "AVISO: Certificado auto-assinado para desenvolvimento apenas!"
        log_warning "Para produção, substitua por certificados válidos"
    else
        log "Certificado SSL já existe"
    fi
}

# Configurar systemd service (opcional)
setup_systemd_service() {
    log_step "Configurando serviço systemd (opcional)..."
    
    cat > /etc/systemd/system/supabase-baas.service << 'EOF'
[Unit]
Description=Supabase Multi-Tenant BaaS Manager
After=network.target nginx.service docker.service
Requires=nginx.service docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/supabase-instances/nginx-manager.sh health_check
ExecReload=/opt/supabase-instances/nginx-manager.sh reload_nginx
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable supabase-baas.service
    
    log "Serviço systemd configurado: supabase-baas.service"
}

# Teste final da configuração
test_configuration() {
    log_step "Testando configuração..."
    
    # Testar configuração do Nginx
    if nginx -t; then
        log "✅ Configuração do Nginx válida"
    else
        log_error "❌ Configuração do Nginx inválida"
        return 1
    fi
    
    # Testar nginx-manager
    if "$INSTANCES_DIR/nginx-manager.sh" help > /dev/null 2>&1; then
        log "✅ nginx-manager.sh funcionando"
    else
        log_error "❌ nginx-manager.sh com problemas"
        return 1
    fi
    
    # Verificar se Docker está rodando
    if systemctl is-active --quiet docker; then
        log "✅ Docker está rodando"
    else
        log_warning "⚠️ Docker não está rodando - inicie com: systemctl start docker"
    fi
    
    return 0
}

# Mostrar informações finais
show_final_info() {
    log_step "Instalação concluída!"
    echo ""
    log "📁 Diretório das instâncias: $INSTANCES_DIR"
    log "🔧 Manager de rotas: supabase-routes (ou $INSTANCES_DIR/nginx-manager.sh)"
    log "📋 Arquivo de rotas: $INSTANCES_DIR/routes.json"
    log "🌐 Configuração Nginx: /etc/nginx/sites-available/supabase-baas"
    echo ""
    log "Comandos úteis:"
    echo "  # Criar nova instância"
    echo "  ./generate.bash --project=\"app1\" --org-id=\"123\" --subdomain=\"app1-org123\""
    echo ""
    echo "  # Gerenciar rotas"
    echo "  supabase-routes list_routes"
    echo "  supabase-routes health_check"
    echo "  supabase-routes add_route <subdomain> <port>"
    echo "  supabase-routes remove_route <subdomain>"
    echo ""
    log_warning "IMPORTANTE: Atualize o domínio 'yourdomain.com' na configuração do Nginx!"
    log_warning "Arquivo: /etc/nginx/sites-available/supabase-baas"
}

# Função principal
main() {
    log "🚀 Iniciando instalação do Supabase Multi-Tenant BaaS"
    echo ""
    
    check_root
    install_dependencies
    check_nginx_lua
    create_directories
    setup_nginx_manager
    init_routes_file
    setup_nginx
    setup_ssl
    setup_systemd_service
    
    if test_configuration; then
        # Recarregar Nginx se tudo estiver OK
        systemctl reload nginx
        show_final_info
        exit 0
    else
        log_error "Instalação falhou nos testes finais"
        exit 1
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi