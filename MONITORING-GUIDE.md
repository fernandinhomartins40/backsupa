# 📊 Guia Completo de Monitoramento - Supabase BaaS Clone

## 🎯 Visão Geral

O sistema de monitoramento do Supabase BaaS Clone oferece **visibilidade completa** de todas as instâncias multi-tenant através de uma stack moderna baseada em **Prometheus + Grafana**.

### ✨ Principais Recursos

- 🔍 **Auto-discovery** de instâncias em tempo real
- 📊 **Dashboards** visuais com métricas em tempo real  
- 🚨 **Alertas** automáticos para problemas críticos
- 📈 **Métricas customizadas** específicas do Supabase
- 🌐 **Status page** público com saúde das instâncias
- 💬 **Notificações** via Slack, Discord, Email
- 🐋 **Monitoramento Docker** completo
- 📦 **Exporter customizado** para métricas específicas

## 🚀 Instalação Rápida

### 1. Setup Automático

```bash
# Navegar para diretório de monitoramento
cd docker/monitoring/

# Executar setup completo (requer sudo para cron)
sudo ./setup_monitoring.sh

# Aguardar inicialização (30-60 segundos)
```

### 2. Verificar Instalação

```bash
# Verificar status dos serviços
docker-compose -f docker-compose.monitoring.yml ps

# Testar acesso aos dashboards
curl -s http://localhost:3001 | grep -q "Grafana" && echo "✅ Grafana OK"
curl -s http://localhost:9090 | grep -q "Prometheus" && echo "✅ Prometheus OK"
curl -s http://localhost:9093 | grep -q "Alertmanager" && echo "✅ Alertmanager OK"
```

### 3. Configurar Credenciais (Opcional)

```bash
# Configurar notificações Slack
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Configurar email de admin
export ADMIN_EMAIL="admin@yourdomain.com"

# Aplicar configurações
./setup_monitoring.sh --restart
```

## 🔍 Auto-Discovery de Instâncias

### Como Funciona

O sistema automaticamente descobre novas instâncias através de:

1. **Scanner Docker**: Busca containers com padrões `*_studio`, `*_kong`, `*_db`
2. **Extração de Metadata**: Obtém instance_id, portas e serviços
3. **Consulta Master DB**: Enriquece dados com informações de projeto/org
4. **Health Checks**: Verifica saúde HTTP e conectividade
5. **Update Prometheus**: Atualiza targets automaticamente

### Executar Discovery Manual

```bash
# Executar discovery agora
./update_monitoring.sh

# Verificar targets descobertos
cat instances.json | jq '.[] | {targets, labels}'

# Ver logs de discovery
tail -f /var/log/supabase-monitoring.log
```

### Exemplo de Output

```json
[
  {
    "targets": ["host.docker.internal:8001"],
    "labels": {
      "job": "supabase-kong",
      "instance_id": "123_myapp_1640995200",
      "project_name": "MyApp",
      "org_id": "123",
      "service": "kong",
      "port": "8001"
    }
  }
]
```

## 📊 Dashboards Disponíveis

### 1. Supabase Overview
**URL**: http://localhost:3001/d/supabase-overview

**Métricas**:
- 🎯 Total de instâncias ativas
- 📊 Targets sendo monitorados  
- ⚡ Uso de CPU/Memória do sistema
- 📋 Status detalhado por instância
- 🐳 Containers Docker ativos

### 2. System Resources  
**URL**: http://localhost:3001/d/system-resources

**Métricas**:
- 💻 CPU Usage (total, system, user)
- 🧠 Memory Usage (total, used, available)
- 💾 Disk Usage por partição
- 🌐 Network I/O por interface
- 🐋 Docker containers com stats

### 3. Instance Details (Auto-criado)
**URL**: http://localhost:3001/d/instance-details

**Métricas por instância**:
- 🚀 Performance da API
- 🔗 Conexões ativas do banco
- 📊 Throughput de requests
- ⚠️ Logs de erros
- 📈 Latência de resposta

## 🚨 Sistema de Alertas

### Alertas Críticos (Notificação Imediata)

| Alerta | Trigger | Duração | Ação |
|--------|---------|---------|------|
| **SupabaseInstanceDown** | Instância não responde | 1min | Verificar containers |
| **SupabaseKongDown** | Kong API fora do ar | 2min | Restart da instância |
| **CriticalMemoryUsage** | Memória > 95% | 1min | Escalar recursos |
| **CriticalDiskSpace** | Disco > 90% | 2min | Limpar dados/escalar |

### Alertas de Warning (Monitoramento)

| Alerta | Trigger | Duração | Ação |
|--------|---------|---------|------|
| **HighCPUUsage** | CPU > 80% | 5min | Monitorar performance |
| **HighMemoryUsage** | Memória > 85% | 3min | Investigar vazamentos |
| **LowDiskSpace** | Disco > 80% | 5min | Planejar limpeza |
| **ContainerRestarting** | >3 restarts/15min | 5min | Verificar logs |

### Configurar Notificações

#### Slack
```bash
# Obter webhook URL do Slack
# https://api.slack.com/messaging/webhooks

export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXX"

# Testar notificação
curl -X POST $SLACK_WEBHOOK_URL -d '{"text":"🧪 Teste de monitoramento Supabase BaaS"}'
```

#### Discord
```bash
# Obter webhook URL do Discord
# Server Settings > Integrations > Webhooks

export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/123456789/abcdefgh"

# Testar notificação  
curl -X POST $DISCORD_WEBHOOK_URL -d '{"content":"🧪 Teste de monitoramento Supabase BaaS"}'
```

#### Email SMTP
```bash
# Configurar SMTP
export SMTP_HOST="smtp.gmail.com:587"
export SMTP_USER="alerts@yourdomain.com" 
export SMTP_PASS="your-app-password"
export ADMIN_EMAIL="admin@yourdomain.com"
```

## 📈 Métricas Customizadas

### Métricas de Instância

```promql
# Total de instâncias Supabase
supabase_instances_total

# Instâncias rodando
supabase_instances_running  

# Status por instância (1=up, 0=down)
supabase_instance_status{instance_id="123_app_456", project_name="MyApp"}

# Uptime em segundos
supabase_instance_uptime_seconds{instance_id="123_app_456"}

# Instâncias por organização
supabase_instances_by_org{org_id="123", org_name="MyOrg"}
```

### Métricas de Performance

```promql
# CPU por instância
supabase_instance_cpu_usage_percent{instance_id="123_app_456"}

# Memória por instância  
supabase_instance_memory_usage_bytes{instance_id="123_app_456"}

# Conexões de banco ativas
supabase_database_connections{instance_id="123_app_456"}

# Tamanho do banco em bytes
supabase_database_size_bytes{instance_id="123_app_456"}
```

### Métricas de API

```promql
# Total de requests API
supabase_api_requests_total{instance_id="123_app_456", method="GET", status="200"}

# Tempo de resposta da API
supabase_api_response_time_seconds{instance_id="123_app_456"}

# Rate de requests por minuto
rate(supabase_api_requests_total[1m])
```

## 🌐 Status Page Público

### Acessar Status Page
**URL**: http://localhost:8080/status

### Features da Status Page
- 📊 **Overview visual** de todas as instâncias
- 🎯 **Status em tempo real** (saudável/com problemas)
- 📈 **Métricas resumidas** (total, saudáveis, problemas)
- 🔄 **Auto-refresh** a cada 30 segundos
- 📱 **Design responsivo** para mobile
- 🌙 **Dark theme** seguindo padrão Supabase

### API JSON
```bash
# Status em formato JSON
curl http://localhost:8080/status/api/status.json

# Exemplo de resposta
{
  "timestamp": "2024-01-15 14:30:00",
  "summary": {
    "total": 5,
    "healthy": 4, 
    "unhealthy": 1
  },
  "last_check": "2024-01-15T14:30:00Z"
}
```

## 🛠️ Comandos de Operação

### Gerenciar Stack de Monitoramento

```bash
# Iniciar todos os serviços
./setup_monitoring.sh --start

# Parar todos os serviços  
./setup_monitoring.sh --stop

# Reiniciar stack completa
./setup_monitoring.sh --restart

# Setup completo (inclui cron jobs)
sudo ./setup_monitoring.sh --setup
```

### Verificar Saúde do Sistema

```bash
# Status dos serviços Docker
docker-compose -f docker-compose.monitoring.yml ps

# Logs de todos os serviços
docker-compose -f docker-compose.monitoring.yml logs -f

# Verificar discovery
./update_monitoring.sh && cat instances.json | jq .

# Executar health check manual
./health_monitor.sh
```

### Debugging de Problemas

```bash
# Logs do auto-discovery
tail -f /var/log/supabase-monitoring.log

# Logs dos health checks  
tail -f /var/log/supabase-health.log

# Verificar targets do Prometheus
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, lastError}'

# Verificar alertas ativos
curl -s http://localhost:9093/api/v1/alerts | jq '.data[] | {labels, state}'
```

## 🔧 Configuração Avançada

### Personalizar Intervalos

```bash
# Editar prometheus.yml
nano prometheus.yml

# Alterar scrape_interval global
global:
  scrape_interval: 15s  # Padrão: 15s

# Alterar intervalo específico por job
scrape_configs:
  - job_name: 'supabase-instances'
    scrape_interval: 30s  # Override para este job
```

### Adicionar Métricas Customizadas

```python
# Editar exporter/exporter.py
from prometheus_client import Gauge

# Criar nova métrica
custom_metric = Gauge('supabase_custom_metric', 'Description', ['label1', 'label2'])

# Em update_metrics()
custom_metric.labels(label1='value1', label2='value2').set(123)
```

### Configurar Retenção de Dados

```bash
# Editar docker-compose.monitoring.yml
services:
  prometheus:
    command:
      - '--storage.tsdb.retention.time=30d'  # Padrão: 15d
      - '--storage.tsdb.retention.size=10GB' # Limite de tamanho
```

## 📱 Integração com Mobile/Webhooks

### Webhook para Apps Externos

```bash
# Configurar webhook customizado
export CUSTOM_WEBHOOK_URL="https://api.yourdomain.com/supabase-alerts"

# O payload será enviado como:
{
  "alert": "SupabaseInstanceDown",
  "instance_id": "123_app_456",
  "project_name": "MyApp", 
  "severity": "critical",
  "timestamp": "2024-01-15T14:30:00Z",
  "description": "Instance não está respondendo"
}
```

### Integração com PagerDuty

```yaml
# Adicionar ao alertmanager.yml
receivers:
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_SERVICE_KEY'
        description: 'Supabase BaaS Alert: {{ .GroupLabels.alertname }}'
```

## 📊 Métricas de Negócio

### Dashboard de KPIs

```promql
# Tempo médio de uptime
avg(supabase_instance_uptime_seconds) / 3600

# Taxa de disponibilidade (últimas 24h)
avg_over_time(supabase_instance_status[24h]) * 100

# Instâncias por organização (top 10)
topk(10, sum by (org_name) (supabase_instances_by_org))

# Crescimento de instâncias (últimos 7 dias)
increase(supabase_instances_total[7d])
```

## 🔐 Segurança

### Configurar HTTPS (Produção)

```nginx
# /etc/nginx/sites-available/monitoring
server {
    listen 443 ssl;
    server_name monitoring.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Configurar Autenticação

```bash
# Configurar OAuth no Grafana
export GF_AUTH_GOOGLE_ENABLED=true
export GF_AUTH_GOOGLE_CLIENT_ID="your-client-id"
export GF_AUTH_GOOGLE_CLIENT_SECRET="your-client-secret"

# Reiniciar Grafana
docker-compose restart grafana
```

## 📚 Recursos e Links Úteis

### Documentação
- [Prometheus Queries (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/)
- [Grafana Dashboard Creation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)

### Dashboards da Comunidade
- [Node Exporter Dashboard](https://grafana.com/grafana/dashboards/1860)
- [Docker Container Dashboard](https://grafana.com/grafana/dashboards/193)
- [Postgres Dashboard](https://grafana.com/grafana/dashboards/9628)

### Ferramentas Complementares
- [Promtool](https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/) - Testing rules
- [amtool](https://github.com/prometheus/alertmanager#amtool) - Alertmanager CLI
- [Grafana CLI](https://grafana.com/docs/grafana/latest/administration/cli/) - Dashboard management

---

## 🎉 Conclusão

O sistema de monitoramento está **100% funcional** e oferece:

✅ **Visibilidade completa** de todas as instâncias  
✅ **Alertas proativos** para problemas  
✅ **Dashboards visuais** em tempo real  
✅ **Auto-discovery** sem configuração manual  
✅ **Integração** com ferramentas de comunicação  
✅ **Métricas customizadas** específicas do Supabase  
✅ **Status page** para transparência  

O **Supabase BaaS Clone** agora tem monitoramento de **nível enterprise** para garantir **alta disponibilidade** e **performance** de todas as instâncias multi-tenant! 🚀