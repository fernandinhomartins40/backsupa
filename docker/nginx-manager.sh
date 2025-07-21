#!/bin/bash

# Nginx Manager para Supabase Multi-Tenant BaaS
# Script para gerenciar rotas dinâmicas entre subdomínios e portas das instâncias

# Configurações
ROUTES_FILE="/opt/supabase-instances/routes.json"
INSTANCES_DIR="/opt/supabase-instances"
NGINX_CONFIG="/etc/nginx/sites-available/supabase-baas"
NGINX_ENABLED="/etc/nginx/sites-enabled/supabase-baas"
BACKUP_DIR="/opt/supabase-instances/backups"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING $(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Função para validar entrada
validate_input() {
    local subdomain="$1"
    local port="$2"
    
    # Validar subdomínio
    if [[ ! "$subdomain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        log_error "Subdomínio inválido: $subdomain"
        return 1
    fi
    
    # Validar porta
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        log_error "Porta inválida: $port (deve estar entre 1024-65535)"
        return 1
    fi
    
    return 0
}

# Função para criar backup do routes.json
backup_routes() {
    if [ -f "$ROUTES_FILE" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_file="$BACKUP_DIR/routes_$(date +%Y%m%d_%H%M%S).json"
        cp "$ROUTES_FILE" "$backup_file"
        log "Backup criado: $backup_file"
    fi
}

# Função para inicializar o arquivo de rotas
init_routes() {
    if [ ! -f "$ROUTES_FILE" ]; then
        mkdir -p "$(dirname "$ROUTES_FILE")"
        echo '{}' > "$ROUTES_FILE"
        log "Arquivo de rotas inicializado: $ROUTES_FILE"
    fi
}

# Função para verificar se Nginx está rodando
check_nginx() {
    if ! systemctl is-active --quiet nginx; then
        log_warning "Nginx não está rodando"
        return 1
    fi
    return 0
}

# Função para adicionar uma rota
add_route() {
    local subdomain="$1"
    local port="$2"
    
    if ! validate_input "$subdomain" "$port"; then
        return 1
    fi
    
    init_routes
    backup_routes
    
    # Verificar se a porta não está sendo usada por outra rota
    if jq -e --arg port "$port" 'to_entries[] | select(.value == ($port | tonumber))' "$ROUTES_FILE" > /dev/null 2>&1; then
        local existing_subdomain=$(jq -r --arg port "$port" 'to_entries[] | select(.value == ($port | tonumber)) | .key' "$ROUTES_FILE")
        if [ "$existing_subdomain" != "$subdomain" ]; then
            log_error "Porta $port já está sendo usada pelo subdomínio: $existing_subdomain"
            return 1
        fi
    fi
    
    # Adicionar/atualizar a rota
    local temp_file=$(mktemp)
    jq --arg subdomain "$subdomain" --argjson port "$port" '. + {($subdomain): $port}' "$ROUTES_FILE" > "$temp_file"
    
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$ROUTES_FILE"
        log "Rota adicionada: $subdomain -> porta $port"
        reload_nginx
        return 0
    else
        log_error "Falha ao adicionar rota"
        rm -f "$temp_file"
        return 1
    fi
}

# Função para remover uma rota
remove_route() {
    local subdomain="$1"
    
    if [ -z "$subdomain" ]; then
        log_error "Subdomínio não especificado"
        return 1
    fi
    
    if [ ! -f "$ROUTES_FILE" ]; then
        log_error "Arquivo de rotas não encontrado"
        return 1
    fi
    
    # Verificar se a rota existe
    if ! jq -e --arg subdomain "$subdomain" 'has($subdomain)' "$ROUTES_FILE" > /dev/null 2>&1; then
        log_warning "Rota para $subdomain não encontrada"
        return 1
    fi
    
    backup_routes
    
    # Remover a rota
    local temp_file=$(mktemp)
    jq --arg subdomain "$subdomain" 'del(.[$subdomain])' "$ROUTES_FILE" > "$temp_file"
    
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$ROUTES_FILE"
        log "Rota removida: $subdomain"
        reload_nginx
        return 0
    else
        log_error "Falha ao remover rota"
        rm -f "$temp_file"
        return 1
    fi
}

# Função para listar todas as rotas
list_routes() {
    if [ ! -f "$ROUTES_FILE" ]; then
        log "Nenhuma rota configurada"
        return 0
    fi
    
    log "Rotas configuradas:"
    jq -r 'to_entries[] | "\(.key) -> porta \(.value)"' "$ROUTES_FILE" | while read line; do
        echo "  $line"
    done
}

# Função para verificar a saúde das rotas
health_check() {
    if [ ! -f "$ROUTES_FILE" ]; then
        log "Nenhuma rota para verificar"
        return 0
    fi
    
    log "Verificando saúde das instâncias..."
    
    jq -r 'to_entries[] | "\(.key) \(.value)"' "$ROUTES_FILE" | while read subdomain port; do
        if curl -f -s "http://127.0.0.1:$port/health" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $subdomain (porta $port) - Saudável"
        else
            echo -e "  ${RED}✗${NC} $subdomain (porta $port) - Indisponível"
        fi
    done
}

# Função para recarregar Nginx
reload_nginx() {
    if check_nginx; then
        if nginx -t 2>/dev/null; then
            systemctl reload nginx
            if [ $? -eq 0 ]; then
                log "Nginx recarregado com sucesso"
                return 0
            else
                log_error "Falha ao recarregar Nginx"
                return 1
            fi
        else
            log_error "Configuração do Nginx inválida"
            return 1
        fi
    else
        log_warning "Nginx não está rodando - pulando reload"
        return 1
    fi
}

# Função para instalar configuração do Nginx
install_nginx_config() {
    local source_config="$1"
    
    if [ -z "$source_config" ]; then
        source_config="$(dirname "$0")/nginx-config/supabase-baas"
    fi
    
    if [ ! -f "$source_config" ]; then
        log_error "Arquivo de configuração não encontrado: $source_config"
        return 1
    fi
    
    # Copiar configuração
    sudo cp "$source_config" "$NGINX_CONFIG"
    
    # Habilitar site
    sudo ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED"
    
    # Testar configuração
    if sudo nginx -t; then
        log "Configuração do Nginx instalada com sucesso"
        reload_nginx
        return 0
    else
        log_error "Configuração do Nginx inválida"
        return 1
    fi
}

# Função para limpeza de rotas órfãs
cleanup_orphaned_routes() {
    if [ ! -f "$ROUTES_FILE" ]; then
        log "Nenhuma rota para limpar"
        return 0
    fi
    
    log "Verificando rotas órfãs..."
    local orphaned_count=0
    
    # Criar lista temporária de instâncias ativas
    local active_instances=$(find "$INSTANCES_DIR" -name "config.json" -exec jq -r '.instance_id' {} \; 2>/dev/null)
    
    jq -r 'to_entries[] | "\(.key) \(.value)"' "$ROUTES_FILE" | while read subdomain port; do
        # Verificar se existe uma instância correspondente
        local instance_found=false
        for instance in $active_instances; do
            local instance_config="$INSTANCES_DIR/$instance/config.json"
            if [ -f "$instance_config" ]; then
                local instance_subdomain=$(jq -r '.subdomain' "$instance_config" 2>/dev/null)
                if [ "$subdomain" = "$instance_subdomain" ]; then
                    instance_found=true
                    break
                fi
            fi
        done
        
        if [ "$instance_found" = false ]; then
            log_warning "Rota órfã detectada: $subdomain"
            orphaned_count=$((orphaned_count + 1))
        fi
    done
    
    if [ $orphaned_count -gt 0 ]; then
        log "Encontradas $orphaned_count rotas órfãs. Use 'remove_route' para limpá-las."
    else
        log "Nenhuma rota órfã encontrada"
    fi
}

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 {add_route|remove_route|list_routes|health_check|reload_nginx|install_config|cleanup|help}"
    echo ""
    echo "Comandos:"
    echo "  add_route <subdomain> <port>  - Adicionar nova rota"
    echo "  remove_route <subdomain>      - Remover rota existente"
    echo "  list_routes                   - Listar todas as rotas"
    echo "  health_check                  - Verificar saúde das instâncias"
    echo "  reload_nginx                  - Recarregar configuração do Nginx"
    echo "  install_config [arquivo]      - Instalar configuração do Nginx"
    echo "  cleanup                       - Limpar rotas órfãs"
    echo "  help                          - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 add_route app1-org123 15001"
    echo "  $0 remove_route app1-org123"
    echo "  $0 list_routes"
}

# Main script
case "$1" in
    add_route)
        if [ $# -ne 3 ]; then
            log_error "Uso: $0 add_route <subdomain> <port>"
            exit 1
        fi
        add_route "$2" "$3"
        ;;
    remove_route)
        if [ $# -ne 2 ]; then
            log_error "Uso: $0 remove_route <subdomain>"
            exit 1
        fi
        remove_route "$2"
        ;;
    list_routes)
        list_routes
        ;;
    health_check)
        health_check
        ;;
    reload_nginx)
        reload_nginx
        ;;
    install_config)
        install_nginx_config "$2"
        ;;
    cleanup)
        cleanup_orphaned_routes
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Comando inválido: $1"
        show_help
        exit 1
        ;;
esac

exit $?