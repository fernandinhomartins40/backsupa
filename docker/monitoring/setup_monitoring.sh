#!/bin/bash
# setup_monitoring.sh - Configurar e iniciar stack de monitoramento
# Uso: ./setup_monitoring.sh [--start] [--stop] [--restart]

MONITORING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="setup"

# Parse argumentos
case $1 in
    --start) ACTION="start" ;;
    --stop) ACTION="stop" ;;
    --restart) ACTION="restart" ;;
    --setup|"") ACTION="setup" ;;
    *) echo "Uso: $0 [--start|--stop|--restart|--setup]"; exit 1 ;;
esac

echo "🔧 Configurando Monitoramento Supabase BaaS"
echo "   Ação: $ACTION"
echo "   Diretório: $MONITORING_DIR"

# Verificar se Docker está rodando
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker não está rodando ou não está acessível"
    exit 1
fi

# Função para aplicar permissões
setup_permissions() {
    echo "🔐 Configurando permissões..."
    
    # Scripts executáveis
    chmod +x "$MONITORING_DIR"/*.sh
    chmod +x "$MONITORING_DIR/exporter"/*.py
    
    # Criar diretórios se não existirem
    mkdir -p "$MONITORING_DIR/status"
    mkdir -p "/var/log"
    
    # Permissões para logs
    touch /var/log/supabase-monitoring.log
    touch /var/log/supabase-health.log
    chmod 644 /var/log/supabase-*.log
    
    echo "   ✅ Permissões configuradas"
}

# Função para verificar dependências
check_dependencies() {
    echo "📋 Verificando dependências..."
    
    local missing_deps=()
    
    # Verificar comandos necessários
    for cmd in docker jq curl; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Dependências faltando: ${missing_deps[*]}"
        echo "💡 Instale com: apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    echo "   ✅ Dependências verificadas"
}

# Função para configurar arquivos
setup_files() {
    echo "📄 Configurando arquivos de configuração..."
    
    # Verificar se arquivo instances.json existe
    if [ ! -f "$MONITORING_DIR/instances.json" ]; then
        echo '[]' > "$MONITORING_DIR/instances.json"
    fi
    
    # Criar arquivo de environment para docker-compose
    cat > "$MONITORING_DIR/.env" << EOF
# Configurações do Monitoring Stack
MASTER_DB_URL=${MASTER_DB_URL:-postgresql://postgres:postgres@host.docker.internal:5432/supabase_master}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-}
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@localhost}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
EOF
    
    echo "   ✅ Arquivos configurados"
}

# Função para configurar cron jobs
setup_cron() {
    echo "🕒 Configurando cron jobs..."
    
    local cron_file="/etc/cron.d/supabase-monitoring"
    
    # Verificar se é root
    if [ "$EUID" -ne 0 ]; then
        echo "⚠️  Aviso: Execute como root para configurar cron jobs automaticamente"
        echo "💡 Adicione manualmente ao crontab:"
        echo "   */1 * * * * $MONITORING_DIR/update_monitoring.sh"
        echo "   */1 * * * * $MONITORING_DIR/health_monitor.sh"
        return
    fi
    
    # Criar arquivo de cron
    cat > "$cron_file" << EOF
# Supabase Monitoring Jobs
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SHELL=/bin/bash

# Auto-discovery de instâncias (a cada 1 minuto)
*/1 * * * * root $MONITORING_DIR/update_monitoring.sh >/dev/null 2>&1

# Health monitoring (a cada 30 segundos - usando sleep para offset)
* * * * * root $MONITORING_DIR/health_monitor.sh >/dev/null 2>&1
* * * * * root sleep 30; $MONITORING_DIR/health_monitor.sh >/dev/null 2>&1
EOF
    
    chmod 644 "$cron_file"
    
    # Recarregar cron
    if command -v systemctl > /dev/null 2>&1; then
        systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
    elif command -v service > /dev/null 2>&1; then
        service cron reload 2>/dev/null || service crond reload 2>/dev/null || true
    fi
    
    echo "   ✅ Cron jobs configurados"
}

# Função para iniciar serviços
start_services() {
    echo "🚀 Iniciando serviços de monitoramento..."
    
    cd "$MONITORING_DIR"
    
    # Verificar se já está rodando
    if docker-compose -f docker-compose.monitoring.yml ps | grep "Up" > /dev/null; then
        echo "⚠️  Alguns serviços já estão rodando"
    fi
    
    # Construir e iniciar serviços
    if docker-compose -f docker-compose.monitoring.yml up -d --build; then
        echo "   ✅ Serviços iniciados"
        
        # Aguardar serviços ficarem prontos
        echo "⏳ Aguardando serviços ficarem prontos..."
        sleep 10
        
        # Verificar status
        echo "📊 Status dos serviços:"
        docker-compose -f docker-compose.monitoring.yml ps
        
        # URLs de acesso
        echo ""
        echo "🌐 URLs de acesso:"
        echo "   Grafana:      http://localhost:3001 (admin/admin123)"
        echo "   Prometheus:   http://localhost:9090"
        echo "   Alertmanager: http://localhost:9093"
        echo "   Status Page:  http://localhost:8080/status"
        echo "   Node Export:  http://localhost:9100/metrics"
        echo "   Custom Export: http://localhost:9200/metrics"
        
    else
        echo "❌ Erro ao iniciar serviços"
        return 1
    fi
}

# Função para parar serviços
stop_services() {
    echo "🛑 Parando serviços de monitoramento..."
    
    cd "$MONITORING_DIR"
    
    if docker-compose -f docker-compose.monitoring.yml down; then
        echo "   ✅ Serviços parados"
    else
        echo "❌ Erro ao parar serviços"
        return 1
    fi
}

# Função para executar discovery inicial
run_initial_discovery() {
    echo "🔍 Executando discovery inicial..."
    
    if [ -x "$MONITORING_DIR/update_monitoring.sh" ]; then
        "$MONITORING_DIR/update_monitoring.sh"
        echo "   ✅ Discovery executado"
    else
        echo "⚠️  Script de discovery não encontrado ou não executável"
    fi
}

# Função para configurar nginx (opcional)
setup_nginx() {
    echo "🌐 Configurando nginx para status page..."
    
    if [ ! -d "/etc/nginx/sites-available" ]; then
        echo "⚠️  Nginx não detectado, pulando configuração"
        return
    fi
    
    # Verificar se é root
    if [ "$EUID" -ne 0 ]; then
        echo "⚠️  Execute como root para configurar nginx automaticamente"
        return
    fi
    
    # Criar configuração do nginx
    cat > "/etc/nginx/sites-available/supabase-monitoring" << EOF
server {
    listen 8080;
    server_name _;
    
    location /status {
        alias $MONITORING_DIR/status;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    location /status/api {
        alias $MONITORING_DIR/status;
        try_files \$uri \$uri.json =404;
        add_header Content-Type application/json;
    }
    
    location /metrics {
        proxy_pass http://localhost:9200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
    
    # Habilitar site
    ln -sf "/etc/nginx/sites-available/supabase-monitoring" "/etc/nginx/sites-enabled/"
    
    # Testar e recarregar nginx
    if nginx -t > /dev/null 2>&1; then
        nginx -s reload > /dev/null 2>&1
        echo "   ✅ Nginx configurado"
    else
        echo "❌ Erro na configuração do nginx"
    fi
}

# Função principal
main() {
    case $ACTION in
        "setup")
            check_dependencies
            setup_permissions
            setup_files
            setup_cron
            start_services
            run_initial_discovery
            setup_nginx
            
            echo ""
            echo "🎉 Setup do monitoramento concluído!"
            echo ""
            echo "📊 Dashboards configurados:"
            echo "   - Supabase Overview"
            echo "   - System Resources"
            echo "   - Container Metrics"
            echo ""
            echo "🔔 Alertas configurados:"
            echo "   - Instance Down"
            echo "   - High Resource Usage"
            echo "   - Container Issues"
            echo ""
            echo "💡 Próximos passos:"
            echo "   1. Acesse Grafana: http://localhost:3001"
            echo "   2. Configure webhooks de notificação"
            echo "   3. Monitore logs: tail -f /var/log/supabase-*.log"
            ;;
            
        "start")
            start_services
            ;;
            
        "stop")
            stop_services
            ;;
            
        "restart")
            stop_services
            sleep 2
            start_services
            ;;
    esac
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi