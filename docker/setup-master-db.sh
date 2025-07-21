#!/bin/bash

# Script para configurar o banco master PostgreSQL
# Este script inicializa o banco de dados master para o controle das instâncias

# Configurações
DB_NAME="supabase_master"
DB_USER="postgres"
DB_PASSWORD="${MASTER_DB_PASSWORD:-masterpassword}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5433}"
SCRIPT_DIR="$(dirname "$0")"
SQL_SCRIPT="$SCRIPT_DIR/master-db-setup.sql"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Verificar se PostgreSQL está disponível
check_postgres() {
    log "Verificando conexão com PostgreSQL..."
    
    for i in {1..30}; do
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c '\q' > /dev/null 2>&1; then
            log "PostgreSQL está disponível"
            return 0
        fi
        
        log "Aguardando PostgreSQL... ($i/30)"
        sleep 2
    done
    
    log_error "Não foi possível conectar ao PostgreSQL após 60 segundos"
    return 1
}

# Criar banco de dados master se não existir
create_database() {
    log "Verificando se banco '$DB_NAME' existe..."
    
    # Verificar se banco existe
    DB_EXISTS=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
    
    if [ "$DB_EXISTS" = "1" ]; then
        log "Banco '$DB_NAME' já existe"
        return 0
    fi
    
    log "Criando banco '$DB_NAME'..."
    PGPASSWORD="$DB_PASSWORD" createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
    
    if [ $? -eq 0 ]; then
        log "Banco '$DB_NAME' criado com sucesso"
    else
        log_error "Falha ao criar banco '$DB_NAME'"
        return 1
    fi
}

# Executar script SQL
run_sql_script() {
    if [ ! -f "$SQL_SCRIPT" ]; then
        log_error "Script SQL não encontrado: $SQL_SCRIPT"
        return 1
    fi
    
    log "Executando script de configuração..."
    
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_SCRIPT"
    
    if [ $? -eq 0 ]; then
        log "Script executado com sucesso"
    else
        log_error "Falha ao executar script SQL"
        return 1
    fi
}

# Verificar configuração
verify_setup() {
    log "Verificando configuração..."
    
    # Verificar se tabelas foram criadas
    TABLES=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name IN ('organizations', 'users', 'projects', 'user_organizations')
    ")
    
    if [ "$TABLES" = "4" ]; then
        log "✅ Todas as tabelas principais foram criadas"
    else
        log_error "❌ Nem todas as tabelas foram criadas (encontradas: $TABLES/4)"
        return 1
    fi
    
    # Verificar dados iniciais
    ORG_COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM organizations")
    USER_COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM users")
    
    log "📊 Organizações criadas: $ORG_COUNT"
    log "👥 Usuários criados: $USER_COUNT"
    
    if [ "$ORG_COUNT" -gt "0" ] && [ "$USER_COUNT" -gt "0" ]; then
        log "✅ Dados iniciais inseridos com sucesso"
    else
        log_warning "⚠️ Dados iniciais podem não ter sido inseridos"
    fi
}

# Mostrar informações de conexão
show_connection_info() {
    log "📋 Informações de conexão:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Password: $DB_PASSWORD"
    echo ""
    log "📝 String de conexão:"
    echo "  postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
    echo ""
    log "🔐 Credenciais padrão do admin:"
    echo "  Email: admin@localhost"
    echo "  Senha: admin123"
}

# Função principal
main() {
    log "🚀 Configurando banco master do Supabase BaaS..."
    echo ""
    
    if ! check_postgres; then
        exit 1
    fi
    
    if ! create_database; then
        exit 1
    fi
    
    if ! run_sql_script; then
        exit 1
    fi
    
    verify_setup
    
    echo ""
    show_connection_info
    
    echo ""
    log "✅ Configuração do banco master concluída!"
    log "🎉 Você pode agora iniciar a Control API"
}

# Verificar argumentos
case "$1" in
    --help|-h)
        echo "Uso: $0 [opções]"
        echo ""
        echo "Opções:"
        echo "  --help, -h     Mostrar esta ajuda"
        echo "  --verify       Apenas verificar configuração existente"
        echo ""
        echo "Variáveis de ambiente:"
        echo "  DB_HOST              Host do PostgreSQL (padrão: localhost)"
        echo "  DB_PORT              Porta do PostgreSQL (padrão: 5433)"
        echo "  MASTER_DB_PASSWORD   Senha do PostgreSQL (padrão: masterpassword)"
        exit 0
        ;;
    --verify)
        if check_postgres && verify_setup; then
            log "✅ Configuração está válida"
            exit 0
        else
            log_error "❌ Problemas encontrados na configuração"
            exit 1
        fi
        ;;
    "")
        main
        ;;
    *)
        log_error "Opção inválida: $1"
        echo "Use --help para ver as opções disponíveis"
        exit 1
        ;;
esac