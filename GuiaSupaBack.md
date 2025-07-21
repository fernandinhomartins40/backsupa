# FASE 1: Infraestrutura Base - BaaS Supabase Clone

## 🎯 OBJETIVO
Modificar apenas os arquivos de infraestrutura do Supabase para suportar multi-tenancy, SEM alterar o design/UI existente.

## 📋 PROMPT 1.1 - Script Multi-Tenant

```
IMPORTANTE: Modifique APENAS o arquivo `docker/generate.bash` existente do Supabase para criar instâncias isoladas. NÃO altere nenhuma interface ou design.

Requisitos:
1. **Aceitar parâmetros:** PROJECT_NAME, ORG_ID, SUBDOMAIN
2. **Gerar configs únicos:** senhas, JWT secrets, portas dinâmicas  
3. **Criar estrutura isolada:** `/opt/supabase-instances/{INSTANCE_ID}/`
4. **Manter compatibilidade total** com todos os serviços existentes

Modificações no generate.bash:
- Aceitar flags: `--project`, `--org-id`, `--subdomain`
- Gerar INSTANCE_ID único: `${ORG_ID}_${PROJECT_NAME}_$(date +%s)`
- Portas dinâmicas baseadas em hash do INSTANCE_ID
- Salvar configurações em: `/opt/supabase-instances/{INSTANCE_ID}/config.json`

Exemplo de uso:
```bash
./generate.bash --project="app1" --org-id="123" --subdomain="app1-org123"
```

Mantenha TODOS os serviços originais: Studio, Kong, PostgreSQL, Auth, Storage, Realtime, Analytics.
```

## 📋 PROMPT 1.2 - Proxy Reverso Nginx

```
Crie sistema de proxy reverso Nginx para roteamento automático por subdomínio. NÃO altere nenhum código frontend existente.

Arquivos a criar:
1. `/etc/nginx/sites-available/supabase-baas` - Template principal
2. `/opt/supabase-instances/nginx-manager.sh` - Script de gerenciamento
3. `/opt/supabase-instances/routes.json` - Mapeamento subdomínio->porta

Nginx template:
```nginx
server {
    server_name ~^(?<subdomain>.+)\.yourdomain\.com$;
    
    location / {
        set $backend "";
        access_by_lua_block {
            local json = require "cjson"
            local file = io.open("/opt/supabase-instances/routes.json", "r")
            local routes = json.decode(file:read("*all"))
            ngx.var.backend = routes[ngx.var.subdomain]
        }
        
        proxy_pass http://127.0.0.1:$backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Script manager funções:
- `add_route(subdomain, port)` - Adicionar rota
- `remove_route(subdomain)` - Remover rota  
- `reload_nginx()` - Recarregar sem downtime

Integrar com o generate.bash para auto-registrar rotas.
```
# FASE 2: Database Master + API Central - BaaS Supabase Clone

## 🎯 OBJETIVO
Criar banco master e API de controle SEM tocar no código do Studio/UI existente.

## 📋 PROMPT 2.1 - Database Master

```
Crie banco PostgreSQL master para controlar instâncias. NÃO modifique nada do Supabase Studio atual.

Schema necessário:
```sql
-- Database: supabase_master
CREATE DATABASE supabase_master;

-- Tables
CREATE TABLE organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    instance_id VARCHAR(255) UNIQUE NOT NULL,
    subdomain VARCHAR(255) UNIQUE NOT NULL,
    database_url VARCHAR(500) NOT NULL,
    api_url VARCHAR(500) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    port INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    encrypted_password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_organizations (
    user_id INTEGER REFERENCES users(id),
    organization_id INTEGER REFERENCES organizations(id),
    role VARCHAR(50) DEFAULT 'member',
    PRIMARY KEY (user_id, organization_id)
);
```

Functions essenciais:
- `create_project_instance(org_id, project_name, user_id)` 
- `get_user_projects(user_id)`
- `delete_project_instance(project_id)`

Criar arquivo: `/opt/supabase-instances/master-db-setup.sql`
```

## 📋 PROMPT 2.2 - API de Controle

```
Desenvolva API Node.js/Express para gerenciar instâncias. NÃO altere o frontend existente do Supabase.

Estrutura da API (`/opt/supabase-instances/control-api/`):
```javascript
// server.js
const express = require('express');
const { exec } = require('child_process');
const app = express();

// Endpoints essenciais
app.post('/api/projects', async (req, res) => {
  const { orgId, projectName, userId } = req.body;
  
  // 1. Validar dados
  // 2. Gerar subdomain único
  // 3. Executar generate.bash
  // 4. Registrar no master DB
  // 5. Adicionar rota no nginx
});

app.delete('/api/projects/:id', async (req, res) => {
  // 1. Parar containers
  // 2. Remover dados
  // 3. Remover rota nginx
  // 4. Atualizar master DB
});

app.get('/api/organizations/:orgId/projects', async (req, res) => {
  // Listar projetos da organização
});

app.get('/api/projects/:id/status', async (req, res) => {
  // Status da instância (containers rodando?)
});
```

Middlewares necessários:
- Autenticação JWT
- Rate limiting
- Logging
- Error handling

Integração com scripts:
- Executar `generate.bash` via child_process
- Monitorar containers Docker
- Gerenciar nginx routes

Porta da API: 3001 (não conflitar com Studio)
```
# FASE 3: Interface Multi-Tenant - BaaS Supabase Clone

## 🎯 OBJETIVO
Modificar MINIMAMENTE o Supabase Studio para adicionar seleção de projetos. MANTER design atual.

## 📋 PROMPT 3.1 - Dashboard de Organizações

```
CRÍTICO: Modifique APENAS os arquivos necessários do Studio. PRESERVE todo o design/UI existente do Supabase.

Modificações mínimas no Studio (`studio/`):

1. **Adicionar seletor de projeto na sidebar** (apps/studio/components/layouts/):
```tsx
// components/ProjectSelector.tsx
export const ProjectSelector = () => {
  const [projects, setProjects] = useState([]);
  
  return (
    <div className="border-b border-gray-200 p-4">
      <Select value={currentProject} onValueChange={switchProject}>
        <SelectTrigger>
          <SelectValue placeholder="Selecionar projeto" />
        </SelectTrigger>
        <SelectContent>
          {projects.map(project => (
            <SelectItem key={project.id} value={project.id}>
              {project.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Button onClick={createNewProject} className="mt-2 w-full">
        + Novo Projeto
      </Button>
    </div>
  );
};
```

2. **Adicionar à sidebar principal** (components/layouts/ProjectLayout/):
```tsx
// Adicionar antes do menu principal
<ProjectSelector />
{/* Menu existente do Studio não modificar */}
```

3. **Context para projeto atual**:
```tsx
// contexts/ProjectContext.tsx
export const ProjectContext = createContext();
export const useProject = () => useContext(ProjectContext);
```

4. **Modal de criação de projeto**:
- Usar components/ui existentes do Supabase
- Manter styling atual
- Integrar com API de controle

IMPORTANTE: NÃO altere rotas, páginas ou funcionalidades existentes do Studio.
```

## 📋 PROMPT 3.2 - Sistema de Onboarding

```
Crie páginas de onboarding SEPARADAS do Studio atual. Não modificar autenticação existente.

Estrutura (`studio/pages/onboarding/`):

1. **Página de registro** (`/onboarding/signup`):
```tsx
// pages/onboarding/signup.tsx
export default function SignUp() {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="max-w-md w-full space-y-8">
        {/* Usar componentes UI existentes do Supabase */}
        <div className="text-center">
          <img src="/supabase-logo.svg" className="mx-auto h-12 w-auto" />
          <h2 className="mt-6 text-3xl font-extrabold text-gray-900">
            Criar conta
          </h2>
        </div>
        <form onSubmit={handleSignup}>
          <Input placeholder="Email" />
          <Input type="password" placeholder="Senha" />
          <Button type="submit">Criar conta</Button>
        </form>
      </div>
    </div>
  );
}
```

2. **Criação de organização** (`/onboarding/organization`):
- Formulário simples com nome da org
- Usar design system existente
- Redirect para criação do primeiro projeto

3. **Primeiro projeto** (`/onboarding/first-project`):
- Wizard com templates básicos
- Integração com API de controle
- Redirect para Studio com projeto criado

4. **Rotas de onboarding**:
```tsx
// pages/_app.tsx - adicionar rotas
const onboardingRoutes = ['/onboarding/signup', '/onboarding/organization', '/onboarding/first-project'];
```

IMPORTANTE: Estas páginas são NOVAS, não modificam o Studio existente.
```
# FASE 4: Automação e Scripts - BaaS Supabase Clone

## 🎯 OBJETIVO
Criar scripts de automação para gerenciar ciclo de vida das instâncias. NÃO alterar código existente.

## 📋 PROMPT 4.1 - Scripts de Automação

```
Crie scripts de gerenciamento em `/opt/supabase-instances/scripts/`. NÃO modificar arquivos do Supabase.

Scripts necessários:

1. **create_instance.sh** - Automação completa:
```bash
#!/bin/bash
# create_instance.sh --project="app1" --org-id="123" --template="blank"

set -e

PROJECT_NAME=""
ORG_ID=""
TEMPLATE="blank"

# Parse argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --project=*) PROJECT_NAME="${1#*=}"; shift ;;
    --org-id=*) ORG_ID="${1#*=}"; shift ;;
    --template=*) TEMPLATE="${1#*=}"; shift ;;
  esac
done

# Validar inputs
[[ -z "$PROJECT_NAME" ]] && { echo "Error: --project required"; exit 1; }
[[ -z "$ORG_ID" ]] && { echo "Error: --org-id required"; exit 1; }

# Gerar configurações
INSTANCE_ID="${ORG_ID}_${PROJECT_NAME}_$(date +%s)"
SUBDOMAIN="${PROJECT_NAME}-${ORG_ID}"
PORT=$(shuf -i 8000-9000 -n 1)

# Executar generate.bash original
cd /path/to/supabase/docker
./generate.bash --project="$PROJECT_NAME" --org-id="$ORG_ID" --subdomain="$SUBDOMAIN"

# Adicionar ao nginx
/opt/supabase-instances/nginx-manager.sh add_route "$SUBDOMAIN" "$PORT"

# Registrar no master DB
psql $MASTER_DB_URL -c "INSERT INTO projects (organization_id, name, instance_id, subdomain, port) VALUES ($ORG_ID, '$PROJECT_NAME', '$INSTANCE_ID', '$SUBDOMAIN', $PORT)"

echo "Instance created: $SUBDOMAIN.yourdomain.com"
```

2. **Scripts de gerenciamento**:
```bash
# stop_instance.sh
docker-compose -f /opt/supabase-instances/$INSTANCE_ID/docker-compose.yml stop

# start_instance.sh  
docker-compose -f /opt/supabase-instances/$INSTANCE_ID/docker-compose.yml start

# delete_instance.sh
# 1. Stop containers
# 2. Backup data
# 3. Remove files
# 4. Update nginx
# 5. Update master DB
```

3. **Templates de projeto**:
```bash
# apply_template.sh
case $TEMPLATE in
  "todo")
    psql $PROJECT_DB_URL -f /opt/templates/todo-schema.sql
    ;;
  "blog")
    psql $PROJECT_DB_URL -f /opt/templates/blog-schema.sql
    ;;
esac
```

Diretório: `/opt/supabase-instances/templates/` com schemas SQL pré-definidos.
```

## 📋 PROMPT 4.2 - Sistema de Backup

```
Implementar backup automático. NÃO modificar configurações existentes do Supabase.

Scripts de backup (`/opt/supabase-instances/backup/`):

1. **backup_instance.sh**:
```bash
#!/bin/bash
INSTANCE_ID=$1
BACKUP_DIR="/opt/backups/instances/$INSTANCE_ID"
DATE=$(date +%Y%m%d_%H%M%S)

# Criar diretório
mkdir -p "$BACKUP_DIR/$DATE"

# Backup PostgreSQL
docker exec ${INSTANCE_ID}_db pg_dump -U postgres postgres > "$BACKUP_DIR/$DATE/database.sql"

# Backup volumes
docker run --rm -v ${INSTANCE_ID}_storage_data:/data -v $BACKUP_DIR/$DATE:/backup alpine tar czf /backup/storage.tar.gz -C /data .

# Backup configurações
cp -r /opt/supabase-instances/$INSTANCE_ID/config "$BACKUP_DIR/$DATE/"

# Compactar e criptografar
tar czf "$BACKUP_DIR/${INSTANCE_ID}_${DATE}.tar.gz" -C "$BACKUP_DIR" "$DATE"
rm -rf "$BACKUP_DIR/$DATE"

echo "Backup completed: $BACKUP_DIR/${INSTANCE_ID}_${DATE}.tar.gz"
```

2. **backup_all.sh** - Backup de todas as instâncias:
```bash
#!/bin/bash
# Executar diariamente via cron
for instance in $(docker ps --format "table {{.Names}}" | grep "_studio" | sed 's/_studio//'); do
  ./backup_instance.sh "$instance"
done

# Cleanup backups antigos (> 30 dias)
find /opt/backups/instances -name "*.tar.gz" -mtime +30 -delete
```

3. **restore_instance.sh**:
```bash
#!/bin/bash
INSTANCE_ID=$1
BACKUP_FILE=$2

# Parar instância
./stop_instance.sh "$INSTANCE_ID"

# Restaurar dados
tar xzf "$BACKUP_FILE" -C /tmp/
docker exec ${INSTANCE_ID}_db psql -U postgres -d postgres < /tmp/database.sql

# Reiniciar
./start_instance.sh "$INSTANCE_ID"
```

4. **Cron job** (`/etc/cron.d/supabase-backup`):
```
0 2 * * * root /opt/supabase-instances/backup/backup_all.sh
```

Integrar logs com journald para monitoramento.
```
# FASE 5: Monitoramento e Scaling - BaaS Supabase Clone

## 🎯 OBJETIVO
Implementar monitoramento sem alterar containers/configurações existentes do Supabase.

## 📋 PROMPT 5.1 - Stack de Monitoramento

```
Instalar Prometheus + Grafana como containers SEPARADOS. NÃO modificar containers do Supabase.

Configuração (`/opt/monitoring/`):

1. **docker-compose.monitoring.yml**:
```yaml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports: ['9090:9090']
    volumes:
      - './prometheus.yml:/etc/prometheus/prometheus.yml'
      - 'prometheus_data:/prometheus'
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'

  grafana:
    image: grafana/grafana:latest
    ports: ['3000:3000']
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - 'grafana_data:/var/lib/grafana'
      - './grafana/dashboards:/etc/grafana/provisioning/dashboards'

  node-exporter:
    image: prom/node-exporter:latest
    ports: ['9100:9100']
    volumes:
      - '/proc:/host/proc:ro'
      - '/sys:/host/sys:ro'
      - '/:/rootfs:ro'
```

2. **prometheus.yml** - Auto-discovery de instâncias:
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  
  - job_name: 'supabase-instances'
    file_sd_configs:
      - files: ['/etc/prometheus/instances.json']
        refresh_interval: 30s
```

3. **Script de discovery** (`update_monitoring.sh`):
```bash
#!/bin/bash
# Gerar instances.json baseado em containers rodando
docker ps --format "{{.Names}}" | grep "_kong" | while read container; do
  instance=${container%_kong}
  port=$(docker port "$container" 8000/tcp | cut -d: -f2)
  echo "{\"targets\": [\"localhost:$port\"], \"labels\": {\"instance\": \"$instance\"}}"
done | jq -s . > /opt/monitoring/instances.json
```

4. **Dashboards Grafana** (pré-configurados):
- Overview de todas as instâncias
- Detalhes por projeto
- Alertas de recursos

Executar via cron a cada 1 minuto para auto-discovery.
```

## 📋 PROMPT 5.2 - Sistema de Alertas

```
Configurar alertas sem modificar aplicações existentes. Monitorar apenas métricas externas.

Configuração de alertas (`/opt/monitoring/alerts/`):

1. **alerting_rules.yml**:
```yaml
groups:
- name: supabase_instances
  rules:
  - alert: InstanceDown
    expr: up{job="supabase-instances"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Instance {{ $labels.instance }} is down"
      
  - alert: HighCPUUsage
    expr: rate(cpu_usage_total[5m]) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"

  - alert: HighMemoryUsage
    expr: memory_usage_percent > 90
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
```

2. **alertmanager.yml**:
```yaml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@yourdomain.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@yourdomain.com'
    subject: 'Supabase BaaS Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Instance: {{ .Labels.instance }}
      {{ end }}
```

3. **Script de health check** (`health_monitor.sh`):
```bash
#!/bin/bash
# Executar a cada 30 segundos
for instance in $(docker ps --format "{{.Names}}" | grep "_studio" | sed 's/_studio//'); do
  # Check containers
  if ! docker ps | grep -q "${instance}_"; then
    curl -X POST http://alertmanager:9093/api/v1/alerts -d "[{
      \"labels\": {\"alertname\": \"InstanceDown\", \"instance\": \"$instance\"},
      \"annotations\": {\"summary\": \"Instance $instance containers are down\"}
    }]"
  fi
  
  # Check HTTP response
  subdomain=$(psql $MASTER_DB_URL -t -c "SELECT subdomain FROM projects WHERE instance_id='$instance'")
  if ! curl -s -o /dev/null -w "%{http_code}" "http://$subdomain.yourdomain.com" | grep -q "200\|302"; then
    # Send alert
  fi
done
```

4. **Dashboard de status**:
- Página HTML simples em `/opt/monitoring/status/`
- Atualizada pelo health_monitor.sh
- Acessível via nginx

Integrar com Slack/Discord via webhooks para notificações em tempo real.
```
# FASE 6: Billing e Marketplace - BaaS Supabase Clone

## 🎯 OBJETIVO
Adicionar sistema de billing e marketplace como módulos INDEPENDENTES. Não modificar core do Supabase.

## 📋 PROMPT 6.1 - Sistema de Billing

```
Criar módulo de billing independente. NÃO alterar funcionalidades existentes do Supabase.

Estrutura (`/opt/billing-system/`):

1. **Schema de billing** (adicionar ao master DB):
```sql
-- Adicionar ao master database
CREATE TABLE plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    price_monthly DECIMAL(10,2),
    price_yearly DECIMAL(10,2),
    limits JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE subscriptions (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id),
    plan_id INTEGER REFERENCES plans(id),
    status VARCHAR(50) DEFAULT 'active',
    current_period_start TIMESTAMP,
    current_period_end TIMESTAMP,
    stripe_subscription_id VARCHAR(255)
);

CREATE TABLE usage_metrics (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id),
    metric_type VARCHAR(50), -- 'api_requests', 'storage_used', 'bandwidth'
    value BIGINT,
    recorded_at TIMESTAMP DEFAULT NOW()
);

-- Seed plans
INSERT INTO plans (name, price_monthly, price_yearly, limits) VALUES
('Free', 0, 0, '{"projects": 2, "storage_gb": 0.1, "requests_hour": 1000}'),
('Starter', 20, 200, '{"projects": 10, "storage_gb": 1, "requests_hour": 10000}'),
('Pro', 100, 1000, '{"projects": 50, "storage_gb": 10, "requests_hour": 100000}');
```

2. **API de billing** (`billing-api/server.js`):
```javascript
const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const app = express();

// Middleware rate limiting por projeto
app.use('/api/projects/:projectId/*', async (req, res, next) => {
  const usage = await getCurrentUsage(req.params.projectId);
  const limits = await getProjectLimits(req.params.projectId);
  
  if (usage.api_requests_hour >= limits.api_requests_hour) {
    return res.status(429).json({error: 'Rate limit exceeded. Upgrade plan.'});
  }
  
  // Incrementar contador
  await incrementUsage(req.params.projectId, 'api_requests');
  next();
});

// Endpoints
app.get('/billing/usage/:projectId', async (req, res) => {
  const usage = await getUsageStats(req.params.projectId);
  res.json(usage);
});

app.post('/billing/create-checkout', async (req, res) => {
  const { planId, organizationId } = req.body;
  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    mode: 'subscription',
    success_url: `${req.headers.origin}/billing/success`,
    cancel_url: `${req.headers.origin}/billing/cancel`,
    metadata: { organizationId, planId }
  });
  res.json({ checkoutUrl: session.url });
});
```

3. **Collector de métricas** (`metrics-collector.sh`):
```bash
#!/bin/bash
# Executar a cada hora via cron

for project in $(psql $MASTER_DB_URL -t -c "SELECT instance_id FROM projects WHERE status='active'"); do
  # Coletar métricas dos logs do Kong
  requests=$(docker logs ${project}_kong 2>&1 | grep "$(date +%Y-%m-%d\ %H)" | wc -l)
  
  # Storage usado
  storage=$(docker exec ${project}_db psql -U postgres -t -c "SELECT pg_database_size('postgres')")
  
  # Inserir no banco
  psql $MASTER_DB_URL -c "INSERT INTO usage_metrics (project_id, metric_type, value) 
    SELECT id, 'api_requests', $requests FROM projects WHERE instance_id='$project'"
done
```

4. **Interface de billing** (adicionar ao Studio):
```tsx
// studio/pages/billing/index.tsx
export default function BillingPage() {
  const [usage, setUsage] = useState(null);
  const [plans, setPlans] = useState([]);
  
  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Billing & Usage</h1>
      
      {/* Cards de uso atual */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        <UsageCard title="API Requests" usage={usage?.api_requests} limit={usage?.limits?.requests_hour} />
        <UsageCard title="Storage" usage={usage?.storage_used} limit={usage?.limits?.storage_gb} />
        <UsageCard title="Projects" usage={usage?.projects_count} limit={usage?.limits?.projects} />
      </div>
      
      {/* Plans disponíveis */}
      <PlanSelector plans={plans} onUpgrade={handleUpgrade} />
    </div>
  );
}
```

Integrar webhook do Stripe para atualizar subscriptions automaticamente.
```

## 📋 PROMPT 6.2 - Marketplace de Templates

```
Criar marketplace como módulo independente. NÃO modificar estrutura de arquivos do Supabase.

Estrutura (`/opt/marketplace/`):

1. **Templates predefinidos** (`templates/`):
```yaml
# templates/todo-app/template.yaml
name: "Todo App"
description: "Complete todo list with user authentication"
category: "productivity"
author: "Supabase Team"
version: "1.0.0"
preview_image: "todo-preview.png"
demo_url: "https://demo-todo.supabase.com"

schema_files:
  - "schema.sql"
  - "seed.sql"

edge_functions:
  - "send-notification"

frontend_examples:
  react: "https://github.com/supabase/todo-react"
  vue: "https://github.com/supabase/todo-vue"
```

2. **Schema SQL** (`templates/todo-app/schema.sql`):
```sql
-- Todo App Template Schema
CREATE TABLE todos (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    is_complete BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own todos" ON todos FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own todos" ON todos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own todos" ON todos FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own todos" ON todos FOR DELETE USING (auth.uid() = user_id);
```

3. **API de marketplace** (`marketplace-api/server.js`):
```javascript
const express = require('express');
const fs = require('fs');
const path = require('path');
const app = express();

app.get('/api/templates', (req, res) => {
  const templatesDir = '/opt/marketplace/templates';
  const templates = fs.readdirSync(templatesDir).map(dir => {
    const templatePath = path.join(templatesDir, dir, 'template.yaml');
    if (fs.existsSync(templatePath)) {
      const template = yaml.load(fs.readFileSync(templatePath, 'utf8'));
      return { ...template, id: dir };
    }
  }).filter(Boolean);
  
  res.json(templates);
});

app.post('/api/projects/:projectId/apply-template', async (req, res) => {
  const { templateId } = req.body;
  const { projectId } = req.params;
  
  try {
    // 1. Get project database URL
    const project = await getProject(projectId);
    
    // 2. Apply schema
    const schemaPath = `/opt/marketplace/templates/${templateId}/schema.sql`;
    await execSql(project.database_url, fs.readFileSync(schemaPath, 'utf8'));
    
    // 3. Apply seed data if exists
    const seedPath = `/opt/marketplace/templates/${templateId}/seed.sql`;
    if (fs.existsSync(seedPath)) {
      await execSql(project.database_url, fs.readFileSync(seedPath, 'utf8'));
    }
    
    // 4. Deploy edge functions if any
    const functionsDir = `/opt/marketplace/templates/${templateId}/functions`;
    if (fs.existsSync(functionsDir)) {
      await deployEdgeFunctions(projectId, functionsDir);
    }
    
    res.json({ success: true, message: 'Template applied successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

4. **Interface do marketplace** (adicionar ao Studio):
```tsx
// studio/pages/marketplace/index.tsx
export default function MarketplacePage() {
  const [templates, setTemplates] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('all');
  
  return (
    <div className="container mx-auto p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Template Marketplace</h1>
        <div className="flex gap-2">
          <Select value={selectedCategory} onValueChange={setSelectedCategory}>
            <SelectTrigger className="w-48">
              <SelectValue placeholder="Categoria" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Todas</SelectItem>
              <SelectItem value="productivity">Produtividade</SelectItem>
              <SelectItem value="ecommerce">E-commerce</SelectItem>
              <SelectItem value="social">Social</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {templates.map(template => (
          <TemplateCard 
            key={template.id} 
            template={template} 
            onInstall={() => handleInstallTemplate(template.id)}
          />
        ))}
      </div>
    </div>
  );
}

const TemplateCard = ({ template, onInstall }) => (
  <div className="border rounded-lg p-4 hover:shadow-lg transition-shadow">
    <img src={template.preview_image} className="w-full h-32 object-cover rounded mb-3" />
    <h3 className="font-semibold text-lg mb-2">{template.name}</h3>
    <p className="text-gray-600 text-sm mb-3">{template.description}</p>
    <div className="flex justify-between items-center">
      <span className="text-xs bg-gray-100 px-2 py-1 rounded">{template.category}</span>
      <Button onClick={onInstall} size="sm">
        Instalar
      </Button>
    </div>
  </div>
);
```

5. **Mais templates predefinidos**:
```yaml
# templates/blog/template.yaml
name: "Blog System"
description: "Complete blog with posts, comments and categories"
category: "content"
schema_files: ["blog-schema.sql"]

# templates/ecommerce/template.yaml  
name: "E-commerce Starter"
description: "Product catalog with cart and orders"
category: "ecommerce"
schema_files: ["ecommerce-schema.sql"]

# templates/chat/template.yaml
name: "Real-time Chat"
description: "Chat app with rooms and real-time messages"
category: "social"
schema_files: ["chat-schema.sql"]
edge_functions: ["realtime-handler"]
```

6. **Script de instalação de template** (`install_template.sh`):
```bash
#!/bin/bash
TEMPLATE_ID=$1
PROJECT_ID=$2
INSTANCE_ID=$3

TEMPLATE_DIR="/opt/marketplace/templates/$TEMPLATE_ID"
PROJECT_DB_URL=$(psql $MASTER_DB_URL -t -c "SELECT database_url FROM projects WHERE id=$PROJECT_ID")

# Apply schema
if [ -f "$TEMPLATE_DIR/schema.sql" ]; then
  docker exec ${INSTANCE_ID}_db psql -U postgres -d postgres -f "/tmp/schema.sql" < "$TEMPLATE_DIR/schema.sql"
fi

# Apply seed data
if [ -f "$TEMPLATE_DIR/seed.sql" ]; then
  docker exec ${INSTANCE_ID}_db psql -U postgres -d postgres -f "/tmp/seed.sql" < "$TEMPLATE_DIR/seed.sql"
fi

# Deploy edge functions
if [ -d "$TEMPLATE_DIR/functions" ]; then
  for func in "$TEMPLATE_DIR/functions"/*; do
    cp -r "$func" "/opt/supabase-instances/$INSTANCE_ID/supabase/functions/"
  done
  docker exec ${INSTANCE_ID}_studio supabase functions deploy
fi

echo "Template $TEMPLATE_ID installed successfully on project $PROJECT_ID"
```

7. **Integração com criação de projeto**:
```javascript
// Modificar create_instance.sh para aceitar template
if [ ! -z "$TEMPLATE" ] && [ "$TEMPLATE" != "blank" ]; then
  /opt/marketplace/install_template.sh "$TEMPLATE" "$PROJECT_ID" "$INSTANCE_ID"
fi
```

O marketplace permite:
- Browsing de templates por categoria
- Preview e demo de cada template
- Instalação one-click
- Templates customizados pela comunidade
- Versionamento de templates
- Frontend examples para cada template

IMPORTANTE: Todo o sistema é modular e NÃO altera o core do Supabase.