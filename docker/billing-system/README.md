# FASE 6: Billing e Marketplace - BaaS Supabase Clone

Sistema completo de billing com integração Stripe e marketplace de templates para o BaaS Supabase Clone.

## 🚀 Quick Start

### 1. Configurar Banco Master

```bash
# Executar schemas no banco master
psql $MASTER_DB_URL -f billing-schema.sql
psql $MASTER_DB_URL -f marketplace/marketplace-schema.sql
psql $MASTER_DB_URL -f marketplace/seed-templates.sql
```

### 2. Configurar Stripe

```bash
# Configurar variáveis do Stripe
export STRIPE_SECRET_KEY="sk_test_your_key_here"
export STRIPE_WEBHOOK_SECRET="whsec_your_webhook_secret"

# Criar produtos no Stripe Dashboard
# - Free: $0/mês
# - Starter: $20/mês, $200/ano  
# - Pro: $100/mês, $1000/ano
# - Enterprise: $500/mês, $5000/ano
```

### 3. Iniciar APIs

```bash
# Billing API
cd billing-api/
npm install
cp .env.example .env
# Configurar variáveis no .env
npm start  # Porta 3002

# Marketplace API  
cd ../marketplace/
npm install
npm start  # Porta 3003
```

### 4. Configurar Coleta de Métricas

```bash
# Configurar cron para coleta de métricas
chmod +x metrics-collector.sh

# Adicionar ao crontab (a cada 5 minutos)
*/5 * * * * /path/to/metrics-collector.sh

# Executar coleta manual para teste
./metrics-collector.sh
```

## 📊 Sistema de Billing

### Funcionalidades

- ✅ **Planos de Assinatura**: Free, Starter, Pro, Enterprise
- ✅ **Integração Stripe**: Checkout, webhooks, portal do cliente
- ✅ **Rate Limiting**: Baseado em uso real por organização
- ✅ **Métricas de Uso**: API requests, storage, bandwidth, conexões DB
- ✅ **Faturas Automáticas**: Geração e cobrança via Stripe
- ✅ **Enforcement**: Bloqueio automático ao exceder limites

### Endpoints da API

```http
# Planos disponíveis
GET http://localhost:3002/api/plans

# Subscription atual (requer X-Org-Id header)
GET http://localhost:3002/api/subscription

# Estatísticas de uso
GET http://localhost:3002/api/usage?period=current_month

# Criar checkout Stripe
POST http://localhost:3002/api/checkout
{
  "plan_id": 2,
  "billing_cycle": "monthly",
  "org_id": 123
}

# Portal do cliente
POST http://localhost:3002/api/customer-portal
```

### Rate Limiting

O sistema implementa rate limiting automático baseado no plano:

```javascript
// Headers necessários
X-Org-Id: 123

// Limites por plano (requests/hora)
Free: 1,000
Starter: 10,000  
Pro: 100,000
Enterprise: Ilimitado
```

### Webhooks Stripe

Configure no Stripe Dashboard:

```
Endpoint: https://yourdomain.com/webhook/stripe
Events: 
- checkout.session.completed
- invoice.payment_succeeded
- invoice.payment_failed
- customer.subscription.updated
- customer.subscription.deleted
```

## 🏪 Marketplace de Templates

### Funcionalidades

- ✅ **Catálogo Completo**: Templates organizados por categoria
- ✅ **Busca e Filtros**: Por categoria, preço, popularidade
- ✅ **Sistema de Reviews**: Avaliações verificadas
- ✅ **Downloads Tracking**: Contadores e analytics
- ✅ **Templates Gratuitos e Pagos**: Monetização opcional
- ✅ **Instalação Automática**: Deploy direto nas instâncias

### Templates Incluídos

1. **Todo App** (Gratuito) - Lista de tarefas com real-time
2. **Blog CMS** (Gratuito) - Sistema de blog completo
3. **E-commerce Store** ($49.99) - Loja virtual completa
4. **Chat App** (Gratuito) - Aplicativo de mensagens
5. **SaaS Dashboard** ($79.99) - Painel administrativo
6. **REST API** (Gratuito) - API completa com documentação

### Endpoints da API

```http
# Listar categorias
GET http://localhost:3003/api/categories

# Listar templates
GET http://localhost:3003/api/templates?category=Blog&free_only=true

# Detalhes do template  
GET http://localhost:3003/api/templates/todo-app

# Download/instalação
POST http://localhost:3003/api/templates/todo-app/download
{
  "project_id": 456,
  "organization_id": 123
}

# Adicionar review
POST http://localhost:3003/api/templates/todo-app/reviews
{
  "user_email": "user@example.com",
  "rating": 5,
  "review_text": "Excelente template!"
}
```

## 📈 Coleta de Métricas

### Métricas Coletadas

O `metrics-collector.sh` coleta automaticamente:

- **API Requests**: Via logs do Kong
- **Storage Usage**: Tamanho do banco PostgreSQL  
- **Bandwidth**: Estimativa via logs do Nginx
- **DB Connections**: Conexões ativas no PostgreSQL

### Configuração

```bash
# Executar a cada 5 minutos
*/5 * * * * /path/to/metrics-collector.sh

# Cleanup diário (reter 30 dias)
0 3 * * * /path/to/metrics-collector.sh --cleanup

# Gerar relatório
./metrics-collector.sh --report [org_id]
```

### Dados Coletados

```sql
-- Tabela usage_metrics
project_id | organization_id | metric_type    | value  | period_start        | period_end
456        | 123            | api_requests   | 1250   | 2024-01-01 10:00:00 | 2024-01-01 10:05:00
456        | 123            | storage_bytes  | 524288 | 2024-01-01 10:00:00 | 2024-01-01 10:05:00
```

## 🐳 Docker Setup

### Billing API

```bash
cd billing-api/
docker build -t supabase-billing-api .
docker run -p 3002:3002 --env-file .env supabase-billing-api
```

### Marketplace API

```bash
cd marketplace/
docker build -t supabase-marketplace-api .
docker run -p 3003:3003 --env-file .env supabase-marketplace-api
```

### Docker Compose

```yaml
version: '3.8'
services:
  billing-api:
    build: ./billing-api
    ports: ["3002:3002"]
    environment:
      - MASTER_DB_URL=${MASTER_DB_URL}
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}

  marketplace-api:
    build: ./marketplace  
    ports: ["3003:3003"]
    environment:
      - MASTER_DB_URL=${MASTER_DB_URL}
      - UPLOADS_DIR=/app/uploads
    volumes:
      - ./uploads:/app/uploads
```

## ⚙️ Configuração de Ambiente

### Variáveis Necessárias

```bash
# Database
MASTER_DB_URL=postgresql://postgres:postgres@localhost:5432/supabase_master

# Stripe (Billing)
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret  

# APIs
BILLING_PORT=3002
MARKETPLACE_PORT=3003
CORS_ORIGIN=http://localhost:3000,http://localhost:3001

# Storage (Marketplace)
UPLOADS_DIR=/opt/supabase/uploads
```

## 🔧 Integração com Studio

### Headers Necessários

Para todas as requests das APIs, o Studio deve enviar:

```javascript
// Headers obrigatórios
headers: {
  'X-Org-Id': currentOrganization.id,
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${userToken}` // Opcional
}
```

### Exemplo de Integração

```javascript
// Verificar limites antes de criar projeto
const checkLimits = async (orgId) => {
  const response = await fetch(`${BILLING_API}/api/usage`, {
    headers: { 'X-Org-Id': orgId }
  });
  
  const { usage, limits } = await response.json();
  
  if (usage.projects >= limits.projects) {
    throw new Error('Limite de projetos atingido');
  }
};

// Instalar template
const installTemplate = async (templateSlug, projectId) => {
  const response = await fetch(`${MARKETPLACE_API}/api/templates/${templateSlug}/download`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Org-Id': currentOrg.id
    },
    body: JSON.stringify({
      project_id: projectId,
      organization_id: currentOrg.id
    })
  });
  
  const template = await response.json();
  
  // Executar SQL do template na instância
  await executeTemplateSQL(template.schema_sql, template.seed_data_sql);
};
```

## 📝 Logs e Monitoramento

### Logs das APIs

```bash
# Billing API logs
tail -f billing-api/logs/billing.log

# Marketplace API logs  
tail -f marketplace/logs/marketplace.log

# Metrics collector logs
tail -f logs/metrics-collector.log
```

### Health Checks

```bash
# Verificar APIs
curl http://localhost:3002/health
curl http://localhost:3003/health

# Verificar métricas
./metrics-collector.sh --health
```

## 🚀 Próximos Passos

1. **Integrar no Studio**: Adicionar páginas de billing e marketplace
2. **Personalizar Templates**: Criar templates específicos para seu domínio
3. **Configurar Produção**: Deploy das APIs em ambiente de produção
4. **Monitoramento**: Configurar alertas para limites e falhas
5. **Analytics**: Dashboards para métricas de negócio

## 🔒 Segurança

### Rate Limiting

- Implementado por organização
- Baseado em métricas reais de uso
- Bloqueio automático ao exceder limites

### Validação de Dados

- Sanitização de inputs
- Validação de tipos e formatos
- Proteção contra SQL injection

### Autenticação

- JWT tokens para APIs
- Webhooks com verificação de assinatura
- Headers obrigatórios para identificação

## 📊 Schema do Banco

### Tabelas Principais

```sql
-- Billing
plans                 -- Planos de assinatura
subscriptions        -- Assinaturas ativas  
usage_metrics       -- Métricas de uso
invoices            -- Faturas
rate_limits         -- Rate limiting

-- Marketplace  
template_categories  -- Categorias de templates
templates           -- Templates disponíveis
template_files      -- Arquivos dos templates
template_reviews    -- Avaliações
template_installations -- Histórico de instalações
```

### Funções Úteis

```sql
-- Verificar limites
SELECT check_organization_limits(123, 'projects', 5);

-- Incrementar uso de API
SELECT increment_api_usage(123);

-- Buscar templates
SELECT * FROM search_templates('todo app', 10);

-- Estatísticas do usuário
SELECT * FROM get_user_todo_stats('uuid-here');
```

---

## ✅ Checklist de Instalação

- [ ] Executar schemas SQL no banco master
- [ ] Configurar conta Stripe e produtos
- [ ] Instalar dependências das APIs (`npm install`)
- [ ] Configurar variáveis de ambiente
- [ ] Iniciar APIs de billing e marketplace
- [ ] Configurar cron job para coleta de métricas
- [ ] Testar integração com webhooks Stripe
- [ ] Verificar rate limiting funcionando
- [ ] Validar instalação de templates
- [ ] Configurar monitoramento e logs

O **sistema de billing e marketplace** está completo e pronto para uso! 🎉

Este sistema fornece uma base sólida para monetização e crescimento do seu BaaS, com funcionalidades enterprise-grade de billing, rate limiting inteligente e um marketplace extensível para templates e extensões.