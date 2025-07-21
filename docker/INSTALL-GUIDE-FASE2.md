# Guia de Instalação - FASE 2: Database Master + API Central

Este guia mostra como instalar e configurar o banco master e API de controle para o sistema Supabase Multi-Tenant BaaS.

## 🎯 O que foi implementado

### 📊 Database Master PostgreSQL
- Schema completo com tabelas de organizações, usuários, projetos
- Functions SQL para operações essenciais
- Auditoria e logs de sistema
- Estatísticas de uso
- Sistema de permissões multi-tenant

### 🚀 API de Controle Node.js
- Endpoints REST para gerenciar instâncias
- Autenticação JWT com refresh tokens
- Rate limiting e segurança
- Integração com scripts Docker
- Monitoramento e métricas
- Logs estruturados

## 📋 Pré-requisitos

- Docker e Docker Compose
- Node.js 16+ (se executar fora do Docker)
- PostgreSQL 12+ (para banco master)
- Redis (opcional, para cache)
- Nginx configurado da FASE 1

## 🚀 Instalação Rápida

### 1. Configurar Banco Master

```bash
# Navegar para diretório
cd docker

# Configurar banco master
./setup-master-db.sh
```

### 2. Configurar API de Controle

```bash
# Navegar para API
cd control-api

# Copiar configuração
cp .env.example .env

# Editar configurações necessárias
nano .env
```

### 3. Iniciar Serviços

```bash
# Subir todos os serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Ver logs
docker-compose logs -f control-api
```

## 🔧 Configuração Detalhada

### Banco Master

O arquivo `.env` principal deve conter:

```bash
# Banco Master
MASTER_DB_PASSWORD=sua_senha_segura
DB_HOST=localhost
DB_PORT=5433
DB_NAME=supabase_master
```

### API de Controle

Editar `control-api/.env`:

```bash
# Servidor
NODE_ENV=production
PORT=3001

# Banco master
DATABASE_URL=postgresql://postgres:sua_senha@localhost:5433/supabase_master

# JWT (IMPORTANTE: Trocar em produção)
JWT_SECRET=sua-chave-jwt-super-secreta-de-32-caracteres-min
JWT_EXPIRES_IN=24h

# Sistema
BASE_DOMAIN=yourdomain.com
INSTANCES_DIR=/opt/supabase-instances
GENERATE_SCRIPT_PATH=/opt/supabase-instances/../generate.bash
NGINX_MANAGER_SCRIPT=/opt/supabase-instances/nginx-manager.sh

# Rate Limiting
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_AUTH_MAX_REQUESTS=5
```

## 🧪 Teste da Instalação

### 1. Verificar Banco Master

```bash
# Conectar ao banco
psql postgresql://postgres:sua_senha@localhost:5433/supabase_master

# Verificar tabelas
\dt

# Verificar usuário admin padrão
SELECT email FROM users WHERE email = 'admin@localhost';
```

### 2. Testar API

```bash
# Health check
curl http://localhost:3001/health

# Login com usuário padrão
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@localhost",
    "password": "admin123"
  }'
```

### 3. Criar Primeira Instância

```bash
# 1. Fazer login e pegar token
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@localhost","password":"admin123"}' | \
  jq -r '.tokens.access_token')

# 2. Criar projeto
curl -X POST http://localhost:3001/api/organizations/1/projects \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Teste App",
    "description": "Primeira instância de teste",
    "environment": "development"
  }'
```

## 📊 Como Usar

### Fluxo Básico

1. **Login na API**: Obter token JWT
2. **Criar Projeto**: Via endpoint `/api/organizations/1/projects`
3. **Aguardar Criação**: Status muda de `creating` para `active`
4. **Acessar Instância**: Via subdomain gerado
5. **Monitorar**: Via endpoints de status e métricas

### Exemplo Completo

```bash
#!/bin/bash

# 1. Login
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@localhost","password":"admin123"}' | \
  jq -r '.tokens.access_token')

echo "Token obtido: ${TOKEN:0:20}..."

# 2. Listar organizações
echo "Organizações disponíveis:"
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:3001/api/organizations | jq '.organizations'

# 3. Criar projeto
echo "Criando novo projeto..."
PROJECT=$(curl -s -X POST http://localhost:3001/api/organizations/1/projects \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Minha App",
    "description": "Aplicação de exemplo",
    "environment": "production"
  }')

echo "Projeto criado:"
echo $PROJECT | jq '.'

PROJECT_ID=$(echo $PROJECT | jq -r '.project.id')
SUBDOMAIN=$(echo $PROJECT | jq -r '.project.subdomain')

echo "ID do projeto: $PROJECT_ID"
echo "Subdomínio: $SUBDOMAIN"

# 4. Aguardar criação (verificar status)
echo "Verificando status da criação..."
for i in {1..30}; do
  STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "http://localhost:3001/api/organizations/1/projects/$PROJECT_ID/status" | \
    jq -r '.status.overall')
  
  echo "Status ($i/30): $STATUS"
  
  if [ "$STATUS" = "healthy" ]; then
    echo "✅ Instância criada com sucesso!"
    echo "🌐 Acesse: https://$SUBDOMAIN.yourdomain.com"
    break
  fi
  
  sleep 10
done

# 5. Listar todos os projetos
echo "Projetos na organização:"
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:3001/api/organizations/1/projects | jq '.projects'
```

## 🔍 Monitoramento

### Dashboards Disponíveis

1. **API Health**: `http://localhost:3001/health`
2. **Status do Sistema**: `http://localhost:3001/api/system/status` (requer auth)
3. **Métricas**: `http://localhost:3001/metrics`

### Logs

```bash
# Logs da API
docker-compose logs -f control-api

# Logs do banco master
docker-compose logs -f master-db

# Logs específicos
tail -f control-api/logs/combined-$(date +%Y-%m-%d).log
```

### Status das Instâncias

```bash
# Via API
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3001/api/system/status | jq '.instances'

# Via scripts diretos
/opt/supabase-instances/nginx-manager.sh list_routes
/opt/supabase-instances/nginx-manager.sh health_check
```

## 🛠️ Manutenção

### Backup do Banco Master

```bash
# Backup completo
pg_dump postgresql://postgres:senha@localhost:5433/supabase_master > master_backup_$(date +%Y%m%d).sql

# Backup apenas schema
pg_dump --schema-only postgresql://postgres:senha@localhost:5433/supabase_master > master_schema.sql
```

### Limpeza de Dados Antigos

```bash
# Logs mais antigos que 30 dias
DELETE FROM system_logs WHERE created_at < NOW() - INTERVAL '30 days';

# Audit logs mais antigos que 90 dias
DELETE FROM project_audit_log WHERE created_at < NOW() - INTERVAL '90 days';
```

### Atualização da API

```bash
# Parar API
docker-compose stop control-api

# Atualizar código
git pull

# Rebuildar imagem
docker-compose build control-api

# Reiniciar
docker-compose up -d control-api
```

## 🚨 Troubleshooting

### API não inicia

```bash
# Verificar logs
docker-compose logs control-api

# Verificar variáveis de ambiente
docker-compose exec control-api env | grep -E "(DB_|JWT_|PORT)"

# Testar conexão com banco
docker-compose exec control-api node -e "
  const { query } = require('./src/config/database');
  query('SELECT NOW()').then(r => console.log(r.rows[0]));
"
```

### Banco Master não conecta

```bash
# Verificar se está rodando
docker-compose ps master-db

# Verificar logs
docker-compose logs master-db

# Recriar banco
docker-compose down master-db
docker volume rm control-api_master-db-data
docker-compose up -d master-db
./setup-master-db.sh
```

### Falha na criação de projetos

```bash
# Verificar generate.bash
bash ../generate.bash --project="test" --org-id="1" --subdomain="test-debug"

# Verificar nginx-manager
/opt/supabase-instances/nginx-manager.sh list_routes

# Verificar permissões
ls -la /opt/supabase-instances/
```

### Rate limiting muito restritivo

Editar `control-api/.env`:
```bash
RATE_LIMIT_MAX_REQUESTS=200
RATE_LIMIT_AUTH_MAX_REQUESTS=10
```

Depois reiniciar:
```bash
docker-compose restart control-api
```

## 🔐 Segurança

### Credenciais Padrão

**IMPORTANTE**: Altere em produção!

- **Admin padrão**: `admin@localhost` / `admin123`
- **Banco master**: `postgres` / `masterpassword`
- **JWT Secret**: Definir no `.env`

### Hardening

```bash
# 1. Alterar senha do admin
UPDATE users SET encrypted_password = hash_password('nova_senha_segura') 
WHERE email = 'admin@localhost';

# 2. Alterar senha do banco
ALTER USER postgres PASSWORD 'nova_senha_db';

# 3. Configurar firewall
ufw allow 3001/tcp  # API
ufw allow 5433/tcp  # Banco master (se necessário)

# 4. SSL/TLS
# Configurar certificados válidos no Nginx
```

## 📈 Próximos Passos

Com a FASE 2 concluída, você tem:

- ✅ Banco master funcionando
- ✅ API de controle completa
- ✅ Integração com scripts da FASE 1
- ✅ Monitoramento e logs
- ✅ Sistema de permissões

**Próximas fases possíveis**:
- Dashboard web de gerenciamento
- Billing e limites de uso
- Multi-região
- Backups automáticos
- Integrações (GitHub, Vercel, etc)

## 🤝 Suporte

Para problemas específicos:

1. Verificar logs: `docker-compose logs`
2. Consultar documentação: `control-api/README.md`
3. Verificar issues conhecidos
4. Reportar bugs com logs completos