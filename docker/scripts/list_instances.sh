#!/bin/bash
# list_instances.sh - Listar todas as instâncias Supabase
# Uso: ./list_instances.sh [--running|--stopped|--all]

FILTER="all"
DOCKER_DIR="/opt/supabase-instances"

# Parse argumentos
case $1 in
    --running) FILTER="running" ;;
    --stopped) FILTER="stopped" ;;
    --all|"") FILTER="all" ;;
    *) echo "Uso: $0 [--running|--stopped|--all]"; exit 1 ;;
esac

echo "📋 Lista de Instâncias Supabase"
echo "================================"

if [ ! -d "$DOCKER_DIR" ]; then
    echo "❌ Diretório de instâncias não encontrado: $DOCKER_DIR"
    exit 1
fi

# Obter lista de instâncias
INSTANCES=($(ls -1 "$DOCKER_DIR" 2>/dev/null | grep -E "^[0-9]+_.*_[0-9]+$" | sort))

if [ ${#INSTANCES[@]} -eq 0 ]; then
    echo "📭 Nenhuma instância encontrada"
    echo ""
    echo "💡 Para criar uma nova instância:"
    echo "   ./create_instance.sh --project=\"meu-app\" --org-id=\"123\" --template=\"blank\""
    exit 0
fi

# Cabeçalho da tabela
printf "%-20s %-15s %-10s %-15s %-25s\n" "INSTANCE ID" "STATUS" "PORTA" "PROJETO" "CRIADO"
echo "----------------------------------------------------------------------------------------"

for instance in "${INSTANCES[@]}"; do
    INSTANCE_DIR="$DOCKER_DIR/$instance"
    
    # Verificar se diretório existe
    if [ ! -d "$INSTANCE_DIR" ]; then
        continue
    fi
    
    # Extrair informações do docker-compose.yml
    COMPOSE_FILE="$INSTANCE_DIR/docker-compose.yml"
    if [ -f "$COMPOSE_FILE" ]; then
        PROJECT_NAME=$(grep "DEFAULT_PROJECT_NAME:" "$COMPOSE_FILE" | sed 's/.*: *"\?//' | sed 's/"\?$//')
        PORT=$(grep -A5 "studio:" "$COMPOSE_FILE" | grep "ports:" -A1 | grep -o "[0-9]*:3000" | cut -d: -f1)
    else
        PROJECT_NAME="N/A"
        PORT="N/A"
    fi
    
    # Verificar status
    STATUS="stopped"
    if [ -f "$COMPOSE_FILE" ]; then
        cd "$INSTANCE_DIR"
        if docker-compose ps studio 2>/dev/null | grep "Up" > /dev/null; then
            STATUS="running"
        fi
    fi
    
    # Obter data de criação
    if [ -d "$INSTANCE_DIR" ]; then
        CREATED=$(stat -c %y "$INSTANCE_DIR" 2>/dev/null | cut -d' ' -f1 | tr -d '\n')
    else
        CREATED="N/A"
    fi
    
    # Aplicar filtro
    case $FILTER in
        "running") [ "$STATUS" != "running" ] && continue ;;
        "stopped") [ "$STATUS" != "stopped" ] && continue ;;
    esac
    
    # Colorir status
    case $STATUS in
        "running") STATUS_COLORED="\033[32m$STATUS\033[0m" ;;
        "stopped") STATUS_COLORED="\033[31m$STATUS\033[0m" ;;
        *) STATUS_COLORED="$STATUS" ;;
    esac
    
    # Truncar instance ID se muito longo
    INSTANCE_SHORT="$instance"
    if [ ${#instance} -gt 20 ]; then
        INSTANCE_SHORT="${instance:0:17}..."
    fi
    
    printf "%-20s %-24s %-10s %-15s %-25s\n" "$INSTANCE_SHORT" "$STATUS_COLORED" "$PORT" "$PROJECT_NAME" "$CREATED"
done

echo ""

# Estatísticas resumidas
TOTAL_INSTANCES=${#INSTANCES[@]}
RUNNING_COUNT=0
STOPPED_COUNT=0

for instance in "${INSTANCES[@]}"; do
    INSTANCE_DIR="$DOCKER_DIR/$instance"
    if [ -f "$INSTANCE_DIR/docker-compose.yml" ]; then
        cd "$INSTANCE_DIR"
        if docker-compose ps studio 2>/dev/null | grep "Up" > /dev/null; then
            ((RUNNING_COUNT++))
        else
            ((STOPPED_COUNT++))
        fi
    else
        ((STOPPED_COUNT++))
    fi
done

echo "📊 Resumo:"
echo "   Total: $TOTAL_INSTANCES instâncias"
echo "   🟢 Rodando: $RUNNING_COUNT"
echo "   🔴 Paradas: $STOPPED_COUNT"

# Mostrar uso de recursos
if command -v docker > /dev/null 2>&1; then
    echo ""
    echo "💾 Uso de recursos Docker:"
    echo "   Containers: $(docker ps -a | grep -E "_studio|_db|_kong" | wc -l) total"
    echo "   Volumes: $(docker volume ls | grep -E "^[0-9]+_.*_[0-9]+_" | wc -l) volumes de dados"
    
    # Mostrar espaço em disco usado pelos volumes
    TOTAL_SIZE=$(docker system df --format "table {{.Size}}" | tail -n +2 | grep -o "[0-9.]*[GMK]B" | head -1)
    if [ -n "$TOTAL_SIZE" ]; then
        echo "   Espaço usado: $TOTAL_SIZE"
    fi
fi

echo ""
echo "💡 Comandos úteis:"
echo "   Iniciar instância:  ./start_instance.sh <instance_id>"
echo "   Parar instância:    ./stop_instance.sh <instance_id>"
echo "   Deletar instância:  ./delete_instance.sh <instance_id>"
echo "   Backup instância:   ./backup_instance.sh <instance_id>"