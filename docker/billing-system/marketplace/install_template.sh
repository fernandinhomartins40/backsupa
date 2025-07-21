#!/bin/bash
# install_template.sh - Instalação automática de templates no marketplace
# Uso: ./install_template.sh TEMPLATE_ID PROJECT_ID INSTANCE_ID

set -euo pipefail

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
MARKETPLACE_DIR="${SCRIPT_DIR}"
LOG_FILE="${SCRIPT_DIR}/logs/install_template.log"
MASTER_DB_URL="${MASTER_DB_URL:-postgresql://postgres:postgres@localhost:5432/supabase_master}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função de log
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp ERROR]${NC} $message" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    local message="$1" 
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" | tee -a "$LOG_FILE"
}

# Validar parâmetros
if [ $# -ne 3 ]; then
    log_error "Uso: $0 TEMPLATE_ID PROJECT_ID INSTANCE_ID"
    exit 1
fi

TEMPLATE_ID="$1"
PROJECT_ID="$2"
INSTANCE_ID="$3"

# Criar diretório de logs se não existir
mkdir -p "$(dirname "$LOG_FILE")"

log "🚀 Iniciando instalação do template '$TEMPLATE_ID' no projeto $PROJECT_ID"

# Função para rollback em caso de erro
rollback() {
    log_error "❌ Instalação falhou. Iniciando rollback..."
    
    # Criar backup de emergência se possível
    if command -v docker >/dev/null 2>&1; then
        log "Criando backup de emergência..."
        docker exec "${INSTANCE_ID}_db" pg_dump -U postgres postgres > "/tmp/emergency_backup_${INSTANCE_ID}_$(date +%s).sql" 2>/dev/null || true
    fi
    
    # Restaurar do backup se existir
    if [ -f "/tmp/pre_install_backup_${INSTANCE_ID}.sql" ]; then
        log "Restaurando backup pré-instalação..."
        docker exec -i "${INSTANCE_ID}_db" psql -U postgres -d postgres < "/tmp/pre_install_backup_${INSTANCE_ID}.sql" || {
            log_error "Falha ao restaurar backup. Intervenção manual necessária."
        }
        rm -f "/tmp/pre_install_backup_${INSTANCE_ID}.sql"
    fi
    
    # Atualizar status no banco master
    psql "$MASTER_DB_URL" -c "UPDATE template_installations SET installation_status = 'failed', error_message = 'Installation failed with rollback' WHERE template_id = (SELECT id FROM templates WHERE slug = '$TEMPLATE_ID') AND project_id = $PROJECT_ID;" 2>/dev/null || true
    
    exit 1
}

# Configurar trap para rollback automático
trap rollback ERR

# Validar se o template existe
log "🔍 Verificando se o template '$TEMPLATE_ID' existe..."
TEMPLATE_INFO=$(psql "$MASTER_DB_URL" -t -c "SELECT id, name, schema_sql, seed_data_sql, edge_functions FROM templates WHERE slug = '$TEMPLATE_ID' AND status = 'published';" 2>/dev/null || echo "")

if [ -z "$TEMPLATE_INFO" ]; then
    log_error "Template '$TEMPLATE_ID' não encontrado ou não está publicado"
    exit 1
fi

# Extrair informações do template
IFS='|' read -r TEMPLATE_DB_ID TEMPLATE_NAME SCHEMA_SQL SEED_SQL EDGE_FUNCTIONS <<< "$TEMPLATE_INFO"
TEMPLATE_DB_ID=$(echo "$TEMPLATE_DB_ID" | xargs)
TEMPLATE_NAME=$(echo "$TEMPLATE_NAME" | xargs)

log "✅ Template encontrado: $TEMPLATE_NAME"

# Verificar se o projeto existe e obter informações
log "🔍 Verificando projeto $PROJECT_ID..."
PROJECT_INFO=$(psql "$MASTER_DB_URL" -t -c "SELECT instance_id, name, organization_id FROM projects WHERE id = $PROJECT_ID AND status != 'deleted';" 2>/dev/null || echo "")

if [ -z "$PROJECT_INFO" ]; then
    log_error "Projeto $PROJECT_ID não encontrado"
    exit 1
fi

IFS='|' read -r DB_INSTANCE_ID PROJECT_NAME ORG_ID <<< "$PROJECT_INFO"
DB_INSTANCE_ID=$(echo "$DB_INSTANCE_ID" | xargs)
PROJECT_NAME=$(echo "$PROJECT_NAME" | xargs) 
ORG_ID=$(echo "$ORG_ID" | xargs)

# Verificar se instance_id passado confere
if [ "$DB_INSTANCE_ID" != "$INSTANCE_ID" ]; then
    log_error "Instance ID não confere. Esperado: $DB_INSTANCE_ID, Recebido: $INSTANCE_ID"
    exit 1
fi

log "✅ Projeto encontrado: $PROJECT_NAME (Org: $ORG_ID)"

# Verificar se já está instalado
log "🔍 Verificando se o template já está instalado..."
EXISTING_INSTALL=$(psql "$MASTER_DB_URL" -t -c "SELECT installation_status FROM template_installations WHERE template_id = $TEMPLATE_DB_ID AND project_id = $PROJECT_ID;" 2>/dev/null | xargs || echo "")

if [ "$EXISTING_INSTALL" = "completed" ]; then
    log_warning "Template já está instalado neste projeto. Use --force para reinstalar."
    exit 0
elif [ "$EXISTING_INSTALL" = "pending" ]; then
    log "Instalação anterior estava pendente. Continuando..."
fi

# Verificar se os containers estão rodando
log "🔍 Verificando se os containers estão rodando..."
if ! docker ps --format "{{.Names}}" | grep -q "^${INSTANCE_ID}_db$"; then
    log_error "Container de banco '${INSTANCE_ID}_db' não está rodando"
    exit 1
fi

if ! docker ps --format "{{.Names}}" | grep -q "^${INSTANCE_ID}_studio$"; then
    log_error "Container do Studio '${INSTANCE_ID}_studio' não está rodando"
    exit 1
fi

log "✅ Containers verificados e rodando"

# Testar conectividade com o banco
log "🔍 Testando conectividade com o banco..."
if ! docker exec "${INSTANCE_ID}_db" pg_isready -U postgres >/dev/null 2>&1; then
    log_error "Banco de dados não está acessível"
    exit 1
fi

log "✅ Conectividade com banco confirmada"

# Criar backup pré-instalação
log "💾 Criando backup pré-instalação..."
docker exec "${INSTANCE_ID}_db" pg_dump -U postgres postgres > "/tmp/pre_install_backup_${INSTANCE_ID}.sql" || {
    log_error "Falha ao criar backup pré-instalação"
    exit 1
}

log "✅ Backup pré-instalação criado"

# Registrar instalação como pendente
log "📝 Registrando instalação no banco master..."
psql "$MASTER_DB_URL" -c "
INSERT INTO template_installations (template_id, project_id, organization_id, installed_version, installation_status)
VALUES ($TEMPLATE_DB_ID, $PROJECT_ID, $ORG_ID, '1.0.0', 'pending')
ON CONFLICT (template_id, project_id) DO UPDATE SET
    installation_status = 'pending',
    error_message = NULL,
    installed_at = NOW();
" || {
    log_error "Falha ao registrar instalação no banco master"
    exit 1
}

# Aplicar schema SQL
if [ -n "$SCHEMA_SQL" ] && [ "$SCHEMA_SQL" != " " ]; then
    log "📋 Aplicando schema SQL..."
    echo "$SCHEMA_SQL" | docker exec -i "${INSTANCE_ID}_db" psql -U postgres -d postgres || {
        log_error "Falha ao aplicar schema SQL"
        exit 1
    }
    log "✅ Schema SQL aplicado com sucesso"
fi

# Aplicar dados de seed
if [ -n "$SEED_SQL" ] && [ "$SEED_SQL" != " " ]; then
    log "🌱 Aplicando dados de seed..."
    echo "$SEED_SQL" | docker exec -i "${INSTANCE_ID}_db" psql -U postgres -d postgres || {
        log_error "Falha ao aplicar dados de seed"
        exit 1
    }
    log "✅ Dados de seed aplicados com sucesso"
fi

# Aplicar Edge Functions se existirem
if [ -n "$EDGE_FUNCTIONS" ] && [ "$EDGE_FUNCTIONS" != "[]" ] && [ "$EDGE_FUNCTIONS" != " " ]; then
    log "⚡ Aplicando Edge Functions..."
    
    # Parse JSON array simples (assumindo formato ["func1", "func2"])
    FUNCTIONS=$(echo "$EDGE_FUNCTIONS" | sed 's/\[\|\]//g' | sed 's/"//g' | tr ',' '\n')
    
    for func in $FUNCTIONS; do
        func=$(echo "$func" | xargs) # Remove whitespace
        if [ -n "$func" ]; then
            log "Aplicando Edge Function: $func"
            
            # Verificar se a função existe nos arquivos do template
            FUNC_DIR="${TEMPLATES_DIR}/${TEMPLATE_ID}/functions/${func}"
            if [ -d "$FUNC_DIR" ]; then
                # Copiar função para o diretório do projeto
                SUPABASE_FUNCTIONS_DIR="/opt/supabase-instances/${INSTANCE_ID}/supabase/functions"
                mkdir -p "$SUPABASE_FUNCTIONS_DIR"
                cp -r "$FUNC_DIR" "$SUPABASE_FUNCTIONS_DIR/" || {
                    log_warning "Falha ao copiar Edge Function $func"
                }
                log "✅ Edge Function $func copiada"
            else
                log_warning "Edge Function $func não encontrada em $FUNC_DIR"
            fi
        fi
    done
    
    # Tentar fazer deploy das funções
    if docker exec "${INSTANCE_ID}_studio" sh -c "cd /app && npx supabase functions deploy" >/dev/null 2>&1; then
        log "✅ Edge Functions deployadas com sucesso"
    else
        log_warning "Falha ao fazer deploy das Edge Functions. Deploy manual pode ser necessário."
    fi
fi

# Incrementar contador de downloads
log "📊 Incrementando contador de downloads..."
psql "$MASTER_DB_URL" -c "SELECT increment_template_downloads($TEMPLATE_DB_ID);" >/dev/null 2>&1 || true

# Marcar instalação como concluída
log "✅ Marcando instalação como concluída..."
psql "$MASTER_DB_URL" -c "
UPDATE template_installations 
SET installation_status = 'completed', 
    error_message = NULL,
    installed_at = NOW()
WHERE template_id = $TEMPLATE_DB_ID AND project_id = $PROJECT_ID;
" || {
    log_error "Falha ao marcar instalação como concluída"
    exit 1
}

# Limpar backup temporário
rm -f "/tmp/pre_install_backup_${INSTANCE_ID}.sql"

log "🎉 Template '$TEMPLATE_NAME' instalado com sucesso no projeto '$PROJECT_NAME'!"
log "📍 Instância: $INSTANCE_ID"
log "🏢 Organização: $ORG_ID"

# Listar próximos passos
echo ""
log "📋 Próximos passos:"
echo "  1. Acesse o Studio: https://studio.yourdomain.com"
echo "  2. Verifique as novas tabelas no Database"
echo "  3. Configure Auth se necessário"
echo "  4. Teste as funcionalidades do template"

# Log final para auditoria
log "✅ Instalação concluída com sucesso em $(date)"

# Desabilitar trap
trap - ERR

exit 0