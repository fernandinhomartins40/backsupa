#!/bin/bash
# create_instance.sh - Automação completa para criação de instâncias Supabase
# Uso: ./create_instance.sh --project="app1" --org-id="123" --template="blank"

set -e

PROJECT_NAME=""
ORG_ID=""
TEMPLATE="blank"
DOCKER_DIR="/opt/supabase-instances"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Parse argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --project=*) PROJECT_NAME="${1#*=}"; shift ;;
    --org-id=*) ORG_ID="${1#*=}"; shift ;;
    --template=*) TEMPLATE="${1#*=}"; shift ;;
    *) echo "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

# Validar inputs
[[ -z "$PROJECT_NAME" ]] && { echo "Erro: --project é obrigatório"; exit 1; }
[[ -z "$ORG_ID" ]] && { echo "Erro: --org-id é obrigatório"; exit 1; }

echo "🚀 Criando instância Supabase..."
echo "   Projeto: $PROJECT_NAME"
echo "   Organização: $ORG_ID"
echo "   Template: $TEMPLATE"

# Gerar configurações únicas
INSTANCE_ID="${ORG_ID}_${PROJECT_NAME}_$(date +%s)"
SUBDOMAIN="${PROJECT_NAME}-${ORG_ID}"
PORT=$(shuf -i 8000-9000 -n 1)
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo "   Instance ID: $INSTANCE_ID"
echo "   Subdomínio: $SUBDOMAIN"
echo "   Porta: $PORT"

# Verificar se subdomínio já existe
if [ -f "$NGINX_ENABLED_DIR/$SUBDOMAIN" ]; then
    echo "❌ Erro: Subdomínio '$SUBDOMAIN' já existe"
    exit 1
fi

# Criar diretório da instância
INSTANCE_DIR="$DOCKER_DIR/$INSTANCE_ID"
mkdir -p "$INSTANCE_DIR"
cd "$INSTANCE_DIR"

echo "📁 Criando estrutura da instância em $INSTANCE_DIR..."

# Executar generate.bash original do Supabase
echo "🔧 Executando generate.bash..."
cd "$(dirname "$0")/.."
./generate.bash --project="$PROJECT_NAME" --org-id="$ORG_ID" --subdomain="$SUBDOMAIN" --port="$PORT"

# Aplicar configurações personalizadas
echo "⚙️ Aplicando configurações personalizadas..."

# Criar docker-compose personalizado
cat > "$INSTANCE_DIR/docker-compose.yml" << EOF
version: "3.8"
services:
  studio:
    container_name: ${INSTANCE_ID}_studio
    image: supabase/studio:20240101-5cc5b93
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/api/profile', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"]
      timeout: 5s
      interval: 5s
      retries: 3
    depends_on:
      analytics:
        condition: service_healthy
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      DEFAULT_ORGANIZATION_NAME: "${PROJECT_NAME}"
      DEFAULT_PROJECT_NAME: "${PROJECT_NAME}"
      SUPABASE_URL: http://kong:8000
      SUPABASE_REST_URL: http://kong:8000/rest/v1/
      SUPABASE_ANON_KEY: \${ANON_KEY}
      SUPABASE_SERVICE_KEY: \${SERVICE_ROLE_KEY}
      LOGFLARE_API_KEY: \${LOGFLARE_API_KEY}
      LOGFLARE_URL: http://analytics:4000
      NEXT_PUBLIC_ENABLE_LOGS: true
      NEXT_ANALYTICS_BACKEND_PROVIDER: postgres
    ports:
      - "${PORT}:3000"

  kong:
    container_name: ${INSTANCE_ID}_kong
    image: kong:2.8.1
    restart: unless-stopped
    entrypoint: bash -c 'eval "echo \"\$\$(cat ~/temp.yml)\"" > ~/kong.yml && /docker-entrypoint.sh kong docker-start'
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /home/kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth
      KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
      KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
    volumes:
      - ./volumes/api/kong.yml:/home/kong/temp.yml:ro

  db:
    container_name: ${INSTANCE_ID}_db
    image: supabase/postgres:15.1.1.78
    healthcheck:
      test: pg_isready -U postgres -h localhost
      interval: 5s
      timeout: 5s
      retries: 10
    depends_on:
      vector:
        condition: service_healthy
    command:
      - postgres
      - -c
      - config_file=/etc/postgresql/postgresql.conf
      - -c
      - log_min_messages=fatal
    restart: unless-stopped
    environment:
      POSTGRES_HOST: /var/run/postgresql
      PGPORT: 5432
      POSTGRES_PORT: 5432
      PGPASSWORD: ${DB_PASSWORD}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      PGDATABASE: postgres
      POSTGRES_DB: postgres
    volumes:
      - ${INSTANCE_ID}_db_data:/var/lib/postgresql/data/:Z
      - ./volumes/db/realtime.sql:/docker-entrypoint-initdb.d/migrations/99-realtime.sql:Z
      - ./volumes/db/webhooks.sql:/docker-entrypoint-initdb.d/init-scripts/98-webhooks.sql:Z
      - ./volumes/db/roles.sql:/docker-entrypoint-initdb.d/init-scripts/99-roles.sql:Z
      - ./volumes/db/jwt.sql:/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql:Z
      - ./volumes/db/logs.sql:/docker-entrypoint-initdb.d/migrations/99-logs.sql:Z
      - /etc/postgresql/postgresql.conf:/etc/postgresql/postgresql.conf
      - ./volumes/db/init:/docker-entrypoint-initdb.d/migrations/99-init:Z

volumes:
  ${INSTANCE_ID}_db_data:
  ${INSTANCE_ID}_storage_data:

networks:
  default:
    external: false
    name: ${INSTANCE_ID}_network
EOF

# Copiar volumes necessários
cp -r "../volumes" "$INSTANCE_DIR/"

# Aplicar template específico
echo "📋 Aplicando template: $TEMPLATE..."
"$(dirname "$0")/apply_template.sh" "$TEMPLATE" "$INSTANCE_DIR" "$DB_PASSWORD"

# Configurar nginx
echo "🌐 Configurando nginx..."
"$(dirname "$0")/../nginx-manager.sh" add_route "$SUBDOMAIN" "$PORT"

# Registrar no banco master
echo "💾 Registrando no banco master..."
if [ -n "$MASTER_DB_URL" ]; then
    psql "$MASTER_DB_URL" -c "
        INSERT INTO projects (organization_id, name, instance_id, subdomain, port, created_at, status) 
        VALUES ($ORG_ID, '$PROJECT_NAME', '$INSTANCE_ID', '$SUBDOMAIN', $PORT, NOW(), 'creating')
    "
fi

# Iniciar a instância
echo "🚀 Iniciando a instância..."
cd "$INSTANCE_DIR"
docker-compose up -d

# Aguardar a instância ficar pronta
echo "⏳ Aguardando instância ficar pronta..."
for i in {1..60}; do
    if curl -s "http://localhost:$PORT" > /dev/null 2>&1; then
        echo "✅ Instância está pronta!"
        break
    fi
    echo "   Tentativa $i/60..."
    sleep 5
done

# Atualizar status no banco master
if [ -n "$MASTER_DB_URL" ]; then
    psql "$MASTER_DB_URL" -c "
        UPDATE projects 
        SET status = 'running', updated_at = NOW() 
        WHERE instance_id = '$INSTANCE_ID'
    "
fi

echo ""
echo "🎉 Instância criada com sucesso!"
echo "   URL: http://$SUBDOMAIN.localhost:$PORT"
echo "   Instance ID: $INSTANCE_ID"
echo "   Banco: postgresql://postgres:$DB_PASSWORD@localhost:5432/postgres"
echo ""
echo "📝 Para gerenciar a instância:"
echo "   Parar:    ./stop_instance.sh $INSTANCE_ID"
echo "   Iniciar:  ./start_instance.sh $INSTANCE_ID"
echo "   Deletar:  ./delete_instance.sh $INSTANCE_ID"
echo ""