#!/bin/bash
# setup_simple_monitoring.sh - Configuração simplificada baseada na especificação
# Uso: ./setup_simple_monitoring.sh [--start] [--stop] [--install-cron]

MONITORING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="start"

# Parse argumentos
case $1 in
    --start) ACTION="start" ;;
    --stop) ACTION="stop" ;;
    --install-cron) ACTION="cron" ;;
    *) ACTION="start" ;;
esac

echo "🔧 Configurando Monitoramento Supabase BaaS (Versão Simplificada)"
echo "   Ação: $ACTION"
echo "   Diretório: $MONITORING_DIR"

# Função para iniciar serviços
start_services() {
    echo "🚀 Iniciando stack de monitoramento..."
    
    cd "$MONITORING_DIR"
    
    # Verificar se Docker está rodando
    if ! docker ps > /dev/null 2>&1; then
        echo "❌ Docker não está rodando"
        exit 1
    fi
    
    # Criar diretórios necessários
    mkdir -p status
    
    # Executar discovery inicial
    echo "🔍 Executando discovery inicial..."
    chmod +x update_monitoring_simple.sh
    ./update_monitoring_simple.sh
    
    # Copiar configuração simples se não existir
    if [ ! -f prometheus.yml ]; then
        cp prometheus.simple.yml prometheus.yml
        echo "📄 Usando configuração simplificada do Prometheus"
    fi
    
    # Iniciar containers de monitoramento
    echo "📊 Iniciando Prometheus + Grafana..."
    docker-compose -f docker-compose.simple.yml up -d
    
    # Aguardar serviços
    echo "⏳ Aguardando serviços ficarem prontos..."
    sleep 15
    
    # Verificar status
    echo "📋 Status dos serviços:"
    docker-compose -f docker-compose.simple.yml ps
    
    # Executar health check inicial
    echo "🔍 Executando health check inicial..."
    chmod +x health_monitor_simple.sh
    ./health_monitor_simple.sh
    
    echo ""
    echo "🎉 Monitoramento iniciado com sucesso!"
    echo ""
    echo "🌐 URLs de acesso:"
    echo "   Grafana:      http://localhost:3000 (admin/admin123)"
    echo "   Prometheus:   http://localhost:9090"
    echo "   Alertmanager: http://localhost:9093"
    echo "   Status Page:  file://$MONITORING_DIR/status/index.html"
    echo ""
    echo "💡 Para configurar cron jobs:"
    echo "   sudo $0 --install-cron"
}

# Função para parar serviços
stop_services() {
    echo "🛑 Parando serviços de monitoramento..."
    
    cd "$MONITORING_DIR"
    docker-compose -f docker-compose.simple.yml down
    
    echo "✅ Serviços parados"
}

# Função para configurar cron
install_cron() {
    echo "🕒 Configurando cron jobs..."
    
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Execute como root para configurar cron"
        echo "💡 Use: sudo $0 --install-cron"
        exit 1
    fi
    
    # Criar arquivo de cron
    cat > /etc/cron.d/supabase-monitoring-simple << EOF
# Supabase Monitoring - Auto-discovery e Health Check
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SHELL=/bin/bash

# Auto-discovery de instâncias (a cada 1 minuto)
*/1 * * * * root $MONITORING_DIR/update_monitoring_simple.sh >/dev/null 2>&1

# Health monitoring (a cada 30 segundos usando offset)
* * * * * root $MONITORING_DIR/health_monitor_simple.sh >/dev/null 2>&1
* * * * * root sleep 30; $MONITORING_DIR/health_monitor_simple.sh >/dev/null 2>&1
EOF
    
    chmod 644 /etc/cron.d/supabase-monitoring-simple
    
    # Recarregar cron
    if command -v systemctl > /dev/null 2>&1; then
        systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
    fi
    
    echo "✅ Cron jobs configurados:"
    echo "   Auto-discovery: a cada 1 minuto"
    echo "   Health check: a cada 30 segundos"
    echo ""
    echo "📄 Arquivo: /etc/cron.d/supabase-monitoring-simple"
}

# Configurar nginx para status page (opcional)
setup_nginx_status() {
    if [ -d "/etc/nginx/sites-available" ] && [ "$EUID" -eq 0 ]; then
        echo "🌐 Configurando nginx para status page..."
        
        cat > /etc/nginx/sites-available/supabase-status << EOF
server {
    listen 8080;
    server_name _;
    
    location /status {
        alias $MONITORING_DIR/status;
        index index.html;
        try_files \$uri \$uri/ =404;
        
        # CORS para API JSON
        add_header Access-Control-Allow-Origin *;
    }
    
    location /status/api {
        alias $MONITORING_DIR/status;
        try_files \$uri \$uri.json =404;
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
    }
}
EOF
        
        ln -sf /etc/nginx/sites-available/supabase-status /etc/nginx/sites-enabled/
        
        if nginx -t > /dev/null 2>&1; then
            nginx -s reload > /dev/null 2>&1
            echo "✅ Status page disponível em: http://localhost:8080/status"
        fi
    fi
}

# Executar ação
case $ACTION in
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "cron")
        install_cron
        setup_nginx_status
        echo ""
        echo "🎉 Configuração de cron concluída!"
        echo ""
        echo "📊 Monitoramento agora executará automaticamente:"
        echo "   - Discovery de instâncias: a cada 1 minuto"
        echo "   - Health checks: a cada 30 segundos"
        echo "   - Status page: atualizada automaticamente"
        ;;
esac