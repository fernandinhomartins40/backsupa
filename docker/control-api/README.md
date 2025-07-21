# Supabase Multi-Tenant BaaS - Control API

API de controle para gerenciamento de instâncias Supabase multi-tenant. Esta API **NÃO modifica** o Supabase Studio/UI existente.

## 🎯 Características

- **Autenticação JWT** com refresh tokens
- **Rate limiting** para segurança
- **Logging estruturado** com Winston
- **Validação de dados** com Joi e express-validator
- **Monitoramento** de saúde e métricas
- **Integração** com scripts Docker e Nginx
- **Auditoria completa** de ações

## 🚀 Instalação

### Pré-requisitos

- Node.js 16+
- PostgreSQL 12+
- Redis (opcional, para cache)
- Docker (para gerenciar instâncias)

### Setup Rápido

```bash
# 1. Instalar dependências
cd control-api
npm install

# 2. Configurar ambiente
cp .env.example .env
# Editar .env com suas configurações

# 3. Configurar banco master
../setup-master-db.sh

# 4. Iniciar API
npm start
```

### Setup com Docker

```bash
# Subir todos os serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Ver logs
docker-compose logs -f control-api
```

## 📋 Endpoints da API

### Autenticação

#### POST /api/auth/login
Fazer login do usuário.

**Request:**
```json
{
  "email": "admin@localhost",
  "password": "admin123"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "email": "admin@localhost",
    "first_name": "Admin",
    "last_name": "User"
  },
  "tokens": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_in": "24h"
  }
}
```

#### POST /api/auth/register
Registrar novo usuário.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "secretpassword",
  "firstName": "John",
  "lastName": "Doe"
}
```

#### POST /api/auth/refresh
Renovar access token.

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### GET /api/auth/profile
Obter perfil do usuário logado.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "email": "admin@localhost",
    "first_name": "Admin",
    "last_name": "User",
    "email_confirmed": true,
    "created_at": "2024-01-01T00:00:00Z"
  },
  "organizations": [
    {
      "id": 1,
      "name": "Default Organization",
      "slug": "default",
      "role": "owner"
    }
  ]
}
```

### Organizações

#### GET /api/organizations
Listar organizações do usuário.

#### GET /api/organizations/:orgId
Obter detalhes de uma organização.

#### GET /api/organizations/:orgId/members
Listar membros da organização (Admin+).

#### POST /api/organizations/:orgId/members
Convidar novo membro (Admin+).

**Request:**
```json
{
  "email": "user@example.com",
  "role": "member"
}
```

### Projetos

#### POST /api/organizations/:orgId/projects
Criar novo projeto/instância.

**Request:**
```json
{
  "name": "My App",
  "description": "Description of my app",
  "environment": "production"
}
```

**Response:**
```json
{
  "success": true,
  "project": {
    "id": 1,
    "name": "My App",
    "slug": "my-app",
    "subdomain": "my-app-default",
    "status": "creating",
    "api_url": "https://my-app-default.yourdomain.com",
    "studio_url": "https://my-app-default.yourdomain.com",
    "environment": "production",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

#### GET /api/organizations/:orgId/projects
Listar projetos da organização.

**Response:**
```json
{
  "success": true,
  "projects": [
    {
      "id": 1,
      "name": "My App",
      "slug": "my-app",
      "subdomain": "my-app-default",
      "status": "active",
      "health_status": "healthy",
      "api_url": "https://my-app-default.yourdomain.com",
      "studio_url": "https://my-app-default.yourdomain.com",
      "environment": "production",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### GET /api/organizations/:orgId/projects/:projectId
Obter detalhes de um projeto.

#### GET /api/organizations/:orgId/projects/:projectId/status
Verificar status de um projeto.

**Response:**
```json
{
  "success": true,
  "status": {
    "overall": "healthy",
    "containers": {
      "healthy": true,
      "total": 12,
      "healthy_count": 12,
      "containers": [...]
    },
    "http": {
      "healthy": true,
      "status_code": 200,
      "port": 15001
    },
    "last_check": "2024-01-01T00:00:00Z"
  }
}
```

#### DELETE /api/organizations/:orgId/projects/:projectId
Deletar projeto (Admin+).

### Sistema

#### GET /api/system/status
Status detalhado do sistema (Admin+).

**Response:**
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "response_time_ms": 45,
  "services": {
    "database": {
      "healthy": true,
      "timestamp": "2024-01-01T00:00:00Z",
      "poolStats": {
        "total": 5,
        "idle": 3,
        "waiting": 0
      }
    },
    "docker": {
      "healthy": true,
      "version": "24.0.7",
      "total_containers": 15,
      "supabase_containers": 12
    },
    "nginx": {
      "healthy": true,
      "status": "active",
      "routes_count": 3
    }
  },
  "system": {
    "hostname": "baas-server",
    "platform": "linux",
    "uptime": 86400,
    "memory": {
      "total": 8589934592,
      "used": 4294967296,
      "free": 4294967296,
      "usage_percent": 50
    }
  },
  "instances": {
    "total": 5,
    "active": 4,
    "creating": 1,
    "error": 0,
    "healthy": 4
  }
}
```

#### GET /health
Health check básico (público).

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "uptime": 86400,
  "environment": "production",
  "version": "1.0.0"
}
```

## 🔒 Autenticação

A API usa JWT (JSON Web Tokens) para autenticação. Inclua o token no header:

```
Authorization: Bearer <access_token>
```

### Tokens

- **Access Token**: Válido por 24h (configurável)
- **Refresh Token**: Válido por 7 dias (configurável)

### Renovação

Quando o access token expira, use o refresh token:

```bash
curl -X POST http://localhost:3001/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "..."}'
```

## 🛡️ Segurança

### Rate Limiting

- **Geral**: 100 requests/15min por IP
- **Autenticação**: 5 attempts/15min por IP

### Headers de Segurança

- Helmet.js para headers padrão
- CORS configurável
- Content Security Policy

### Validação

- Validação de entrada com express-validator
- Sanitização de dados
- Proteção contra SQL injection

## 📊 Monitoramento

### Logs

Logs estruturados com níveis:
- **error**: Erros críticos
- **warn**: Avisos e problemas
- **info**: Informações gerais
- **debug**: Debug detalhado

### Métricas

- `/metrics`: Métricas básicas (Prometheus-like)
- `/api/system/status`: Status detalhado
- Health checks automáticos

### Auditoria

Todas as ações são auditadas:
- Login/logout de usuários
- Criação/deleção de projetos
- Alterações de configuração
- Convites de membros

## 🔧 Configuração

### Variáveis de Ambiente

```bash
# Servidor
NODE_ENV=production
PORT=3001
HOST=0.0.0.0

# Banco de dados master
DATABASE_URL=postgresql://postgres:password@localhost:5433/supabase_master

# JWT
JWT_SECRET=your-super-secret-jwt-key
JWT_EXPIRES_IN=24h

# Rate limiting
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_AUTH_MAX_REQUESTS=5

# Configurações do sistema
BASE_DOMAIN=yourdomain.com
INSTANCES_DIR=/opt/supabase-instances
GENERATE_SCRIPT_PATH=/path/to/generate.bash
NGINX_MANAGER_SCRIPT=/opt/supabase-instances/nginx-manager.sh
```

### Integração com Scripts

A API integra com os scripts existentes:

- **generate.bash**: Para criar instâncias
- **nginx-manager.sh**: Para gerenciar rotas
- **Docker**: Para monitorar containers

## 🚨 Troubleshooting

### Erro de Conexão com Banco

```bash
# Verificar se banco está rodando
docker-compose ps master-db

# Verificar logs
docker-compose logs master-db

# Recriar banco
docker-compose down -v
docker-compose up -d master-db
```

### Falha na Criação de Instância

```bash
# Verificar logs da API
docker-compose logs control-api

# Verificar script generate.bash
bash generate.bash --project="test" --org-id="1" --subdomain="test"

# Verificar Docker
docker ps | grep supabase
```

### Rate Limiting

Se receber erro 429:

```bash
# Aguardar 15 minutos ou
# Ajustar configuração no .env
RATE_LIMIT_MAX_REQUESTS=200
```

## 📚 Desenvolvimento

### Executar em Modo de Desenvolvimento

```bash
npm run dev
```

### Executar Testes

```bash
npm test
```

### Linting

```bash
npm run lint
npm run lint:fix
```

### Estrutura do Projeto

```
control-api/
├── src/
│   ├── config/          # Configurações (DB, etc)
│   ├── controllers/     # Lógica de negócio
│   ├── middleware/      # Middlewares (auth, error, etc)
│   ├── routes/          # Definição de rotas
│   ├── services/        # Serviços auxiliares
│   └── utils/           # Utilitários (logger, etc)
├── logs/                # Logs da aplicação
├── .env.example         # Exemplo de configuração
├── Dockerfile           # Container da API
├── docker-compose.yml   # Stack completa
└── package.json         # Dependências
```

## 🤝 Contribuição

1. Fork do repositório
2. Criar branch de feature
3. Implementar mudanças
4. Adicionar testes
5. Submeter Pull Request

## 📄 Licença

Mesmo licenciamento do projeto Supabase original.