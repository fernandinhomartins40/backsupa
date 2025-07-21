#!/bin/bash

# Multi-Tenant Supabase Instance Generator
# Usage: ./generate.bash --project="app1" --org-id="123" --subdomain="app1-org123"

# Default values
PROJECT_NAME=""
ORG_ID=""
SUBDOMAIN=""
BASE_DOMAIN="yourdomain.com"
INSTANCES_DIR="/opt/supabase-instances"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --project=*)
      PROJECT_NAME="${1#*=}"
      shift
      ;;
    --org-id=*)
      ORG_ID="${1#*=}"
      shift
      ;;
    --subdomain=*)
      SUBDOMAIN="${1#*=}"
      shift
      ;;
    --domain=*)
      BASE_DOMAIN="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$PROJECT_NAME" || -z "$ORG_ID" || -z "$SUBDOMAIN" ]]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 --project=\"app1\" --org-id=\"123\" --subdomain=\"app1-org123\""
    exit 1
fi

# Generate unique instance identifier
TIMESTAMP=$(date +%s)
export INSTANCE_ID="${ORG_ID}_${PROJECT_NAME}_${TIMESTAMP}"

echo "🚀 Creating Supabase instance: $INSTANCE_ID"
echo "📁 Project: $PROJECT_NAME"
echo "🏢 Organization: $ORG_ID"
echo "🌐 Subdomain: $SUBDOMAIN.$BASE_DOMAIN"

# Create instance directory structure
INSTANCE_DIR="$INSTANCES_DIR/$INSTANCE_ID"
mkdir -p "$INSTANCE_DIR"

# Generate deterministic ports based on INSTANCE_ID hash
HASH=$(echo -n "$INSTANCE_ID" | md5sum | cut -c1-8)
HASH_DEC=$((0x$HASH))

# Generate non-conflicting ports (range 10000-65000)
export POSTGRES_PORT=5432 # Internal port remains the same
export POSTGRES_PORT_EXT=$((10000 + ($HASH_DEC % 50000)))
export KONG_HTTP_PORT=$((15000 + ($HASH_DEC % 45000)))
export KONG_HTTPS_PORT=$((20000 + ($HASH_DEC % 40000)))
export ANALYTICS_PORT=$((25000 + ($HASH_DEC % 35000)))

# Generate secure credentials
export POSTGRES_PASSWORD=$(openssl rand -hex 16)
export DASHBOARD_USERNAME="admin"
export DASHBOARD_PASSWORD=$(openssl rand -hex 8)
export POSTGRES_DB="postgres"

# Generate JWT keys dynamically para cada instância
export JWT_SECRET=$(openssl rand -hex 32)

# Gerar tokens JWT dinâmicos para cada instância usando o JWT_SECRET específico
# Payload para anon role
ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1701388800,"exp":1909478400}'
# Payload para service_role
SERVICE_PAYLOAD='{"role":"service_role","iss":"supabase","iat":1701388800,"exp":1909478400}'

# Função para gerar JWT (requer jq e openssl)
function generate_jwt() {
    local payload="$1"
    local secret="$2"
    
    # Encode header and payload
    local header='{"alg":"HS256","typ":"JWT"}'
    local encoded_header=$(echo -n "$header" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    local encoded_payload=$(echo -n "$payload" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    # Create signature
    local signature=$(echo -n "${encoded_header}.${encoded_payload}" | openssl dgst -sha256 -hmac "$secret" -binary | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    echo "${encoded_header}.${encoded_payload}.${signature}"
}

# Gerar tokens únicos para esta instância
export ANON_KEY=$(generate_jwt "$ANON_PAYLOAD" "$JWT_SECRET")
export SERVICE_ROLE_KEY=$(generate_jwt "$SERVICE_PAYLOAD" "$JWT_SECRET")

# Export for Kong configuration
export SUPABASE_ANON_KEY=${ANON_KEY}
export SUPABASE_SERVICE_KEY=${SERVICE_ROLE_KEY}

# Set environment URLs
export API_EXTERNAL_URL="https://${SUBDOMAIN}.${BASE_DOMAIN}"
export SITE_URL="https://${SUBDOMAIN}.${BASE_DOMAIN}"
export SUPABASE_PUBLIC_URL="https://${SUBDOMAIN}.${BASE_DOMAIN}"
export STUDIO_DEFAULT_ORGANIZATION="$PROJECT_NAME"
export STUDIO_DEFAULT_PROJECT="$PROJECT_NAME"

# Default configuration
export ENABLE_EMAIL_SIGNUP="true"
export ENABLE_EMAIL_AUTOCONFIRM="true"
export SMTP_ADMIN_EMAIL="admin@${BASE_DOMAIN}"
export SMTP_HOST="localhost"
export SMTP_PORT=2500
export SMTP_USER="supabase"
export SMTP_PASS="supabase"
export SMTP_SENDER_NAME="Supabase"
export ENABLE_ANONYMOUS_USERS="true"
export JWT_EXPIRY=3600
export DISABLE_SIGNUP="false"
export IMGPROXY_ENABLE_WEBP_DETECTION="true"
export FUNCTIONS_VERIFY_JWT="false"
export DOCKER_SOCKET_LOCATION="/var/run/docker.sock"
export LOGFLARE_API_KEY=$(openssl rand -hex 16)
export LOGFLARE_LOGGER_BACKEND_API_KEY=${LOGFLARE_API_KEY}
export PGRST_DB_SCHEMAS="public,storage,graphql_public"

# Configurações específicas da instância
export VAULT_ENC_KEY=$(openssl rand -hex 32)
export SECRET_KEY_BASE=$(openssl rand -hex 64)
export POOLER_TENANT_ID="${INSTANCE_ID}"
export POOLER_DEFAULT_POOL_SIZE=20
export POOLER_MAX_CLIENT_CONN=100
export POOLER_PROXY_PORT_TRANSACTION=$((30000 + ($HASH_DEC % 30000)))

# Portas dos serviços internos
export AUTH_PORT=9999
export REST_PORT=3000
export REALTIME_PORT=4000
export META_PORT=8080
export STUDIO_PORT=3000
export STORAGE_PORT=5000
export IMGPROXY_PORT=5001
export FUNCTIONS_PORT=8088

# Create instance configuration file
cat > "$INSTANCE_DIR/config.json" << EOF
{
  "instance_id": "$INSTANCE_ID",
  "project_name": "$PROJECT_NAME",
  "org_id": "$ORG_ID",
  "subdomain": "$SUBDOMAIN",
  "domain": "$BASE_DOMAIN",
  "created_at": "$(date -Iseconds)",
  "ports": {
    "postgres_external": $POSTGRES_PORT_EXT,
    "kong_http": $KONG_HTTP_PORT,
    "kong_https": $KONG_HTTPS_PORT,
    "analytics": $ANALYTICS_PORT
  },
  "credentials": {
    "postgres_password": "$POSTGRES_PASSWORD",
    "dashboard_username": "$DASHBOARD_USERNAME",
    "dashboard_password": "$DASHBOARD_PASSWORD",
    "jwt_secret": "$JWT_SECRET"
  },
  "urls": {
    "api_external": "$API_EXTERNAL_URL",
    "site_url": "$SITE_URL",
    "public_url": "$SUPABASE_PUBLIC_URL"
  },
  "status": "creating"
}
EOF

echo "📝 Configuration saved to: $INSTANCE_DIR/config.json"

# Generate instance-specific environment file
envsubst < .env.template > "$INSTANCE_DIR/.env"

# Generate instance-specific docker-compose file
envsubst < docker-compose.yml > "$INSTANCE_DIR/docker-compose.yml"

# Create volume directories for the instance
mkdir -p "$INSTANCE_DIR/volumes/functions"
mkdir -p "$INSTANCE_DIR/volumes/logs"
mkdir -p "$INSTANCE_DIR/volumes/db/init"
mkdir -p "$INSTANCE_DIR/volumes/api"

# Copy necessary files to volume directories
if [ -d "volumes/db/" ]; then
  cp -a volumes/db/. "$INSTANCE_DIR/volumes/db/"
fi

if [ -d "volumes/functions/" ]; then
  cp -a volumes/functions/. "$INSTANCE_DIR/volumes/functions/"
fi

# Substitute variables in configuration files
if [ -f "volumes/logs/vector.yml" ]; then
  envsubst < volumes/logs/vector.yml > "$INSTANCE_DIR/volumes/logs/vector.yml"
fi

if [ -f "volumes/api/kong.yml" ]; then
  envsubst < volumes/api/kong.yml > "$INSTANCE_DIR/volumes/api/kong.yml"
else
  echo "❌ Error: File volumes/api/kong.yml not found."
  exit 1
fi

# Update docker-compose to use instance-specific volumes
sed -i "s|volumes-\${INSTANCE_ID}|$INSTANCE_DIR/volumes|g" "$INSTANCE_DIR/docker-compose.yml"

echo "🐳 Starting Docker containers..."

# Start the instance containers
cd "$INSTANCE_DIR"
docker compose -f docker-compose.yml --env-file .env up -d

if [ $? -eq 0 ]; then
    echo "✅ Instance created successfully!"
    echo "🌐 Kong HTTP Port: $KONG_HTTP_PORT"
    echo "🔒 Kong HTTPS Port: $KONG_HTTPS_PORT"
    echo "📊 Analytics Port: $ANALYTICS_PORT"
    echo "🗄️  PostgreSQL External Port: $POSTGRES_PORT_EXT"
    
    # Update status in config
    jq '.status = "running"' "$INSTANCE_DIR/config.json" > "$INSTANCE_DIR/config.json.tmp" && mv "$INSTANCE_DIR/config.json.tmp" "$INSTANCE_DIR/config.json"
    
    # Register with Nginx proxy if nginx-manager exists
    if [ -f "$INSTANCES_DIR/nginx-manager.sh" ]; then
        echo "🔧 Registering with Nginx proxy..."
        bash "$INSTANCES_DIR/nginx-manager.sh" add_route "$SUBDOMAIN" "$KONG_HTTP_PORT"
    fi
    
    echo ""
    echo "🎉 Access your Supabase instance at: https://${SUBDOMAIN}.${BASE_DOMAIN}"
    echo "👤 Dashboard: admin / $DASHBOARD_PASSWORD"
else
    echo "❌ Failed to start instance"
    jq '.status = "failed"' "$INSTANCE_DIR/config.json" > "$INSTANCE_DIR/config.json.tmp" && mv "$INSTANCE_DIR/config.json.tmp" "$INSTANCE_DIR/config.json"
    exit 1
fi
