# Sistema de Monitoramento - Supabase Multi-Tenant

Sistema completo de monitoramento baseado em **Prometheus + Grafana** para o BaaS Supabase Clone, com auto-discovery de instâncias e alertas automáticos.

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                 Supabase Instances                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │Instance 1│ │Instance 2│ │Instance N│           │
│  │Kong:8001 │ │Kong:8002 │ │Kong:800N │           │
│  │Studio:3k │ │Studio:3k │ │Studio:3k │           │
│  └──────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────┘
                        │
                   Auto-Discovery
                        │
┌─────────────────────────────────────────────────────┐
│              Monitoring Stack                       │
│  ┌─────────────┐ ┌─────────────┐ ┌───────────────┐  │
│  │ Prometheus  │ │   Grafana   │ │ Alertmanager  │  │
│  │   :9090     │ │    :3001    │ │     :9093     │  │
│  └─────────────┘ └─────────────┘ └───────────────┘  │
│                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌───────────────┐  │
│  │Node Exporter│ │  cAdvisor   │ │Custom Exporter│  │
│  │   :9100     │ │    :8080    │ │     :9200     │  │
│  └─────────────┘ └─────────────┘ └───────────────┘  │
└─────────────────────────────────────────────────────┘
                        │
              ┌─────────────────────┐
              │    Notifications    │
              │  Slack / Discord    │
              │  Email / Webhooks   │
              └─────────────────────┘
```

## 🚀 Quick Start

### 1. Configuração Inicial

```bash
# Navegar para diretório de monitoramento
cd docker/monitoring/

# Configurar e iniciar tudo
sudo ./setup_monitoring.sh

# Ou configurar manualmente step-by-step
sudo ./setup_monitoring.sh --setup
```

### 2. Acesso aos Dashboards

- **Grafana**: http://localhost:3001 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **Status Page**: http://localhost:8080/status
- **Custom Metrics**: http://localhost:9200/metrics

### 3. Configurar Notificações (Opcional)

```bash
# Configurar variáveis de ambiente
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export ADMIN_EMAIL="admin@yourdomain.com"

# Recriar stack com configurações
./setup_monitoring.sh --restart
```

## 📊 Dashboards Disponíveis

### 1. Supabase Overview
- **Instâncias ativas** e status geral
- **Targets monitorados** pelo Prometheus
- **Status detalhado** por instância
- **Uso de recursos** do sistema
- **Containers Docker** e seu status

### 2. System Resources
- **CPU Usage** detalhado (total, system, user)
- **Memory Usage** (total, used, available)
- **Disk Usage** por partition
- **Network I/O** por interface
- **Docker Containers** com estatísticas

### 3. Instance Details (Auto-criado)
- Métricas específicas por instância
- Performance de APIs
- Conexões de banco
- Logs de erros

## 🔔 Sistema de Alertas

### Alertas Configurados

#### Críticos
- **SupabaseInstanceDown**: Instância não responsiva (1min)
- **SupabaseKongDown**: Kong API Gateway fora do ar (2min)
- **CriticalMemoryUsage**: Memória > 95% (1min)
- **CriticalDiskSpace**: Disco > 90% (2min)

#### Warnings
- **SupabaseStudioDown**: Studio não acessível (3min)
- **HighCPUUsage**: CPU > 80% (5min)
- **HighMemoryUsage**: Memória > 85% (3min)
- **LowDiskSpace**: Disco > 80% (5min)
- **ContainerRestartingFrequently**: Container reiniciando >3x/15min

### Configurar Notificações

```bash
# Slack
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"

# Email SMTP
export SMTP_HOST="smtp.gmail.com:587"
export SMTP_USER="alerts@yourdomain.com"
export SMTP_PASS="senha"

# Discord
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

## 🔍 Auto-Discovery

O sistema descobre automaticamente novas instâncias através de:

### 1. Container Discovery
- Busca containers com padrão `*_studio`, `*_kong`, `*_db`
- Extrai instance_id do nome do container
- Detecta portas expostas automaticamente

### 2. Database Integration
- Consulta banco master para metadados
- Obtém informações de projeto e organização
- Verifica status das instâncias

### 3. Health Checks
- Verificação HTTP dos endpoints
- Teste de conectividade PostgreSQL
- Monitoramento de containers Docker

## 📈 Métricas Customizadas

### Métricas de Instância
```promql
# Total de instâncias
supabase_instances_total

# Instâncias por organização
supabase_instances_by_org{org_id="123", org_name="MinhaOrg"}

# Status da instância (1=running, 0=stopped)
supabase_instance_status{instance_id="123_app_456", project_name="MeuApp"}

# Uptime da instância
supabase_instance_uptime_seconds{instance_id="123_app_456"}
```

### Métricas de Docker
```promql
# Total de containers Supabase
supabase_docker_containers_total

# Status do container
supabase_docker_container_status{container_name="123_app_456_studio"}

# Reinicializações do container
supabase_docker_container_restarts_total{container_name="123_app_456_kong"}
```

### Métricas de Recursos
```promql
# CPU por instância
supabase_instance_cpu_usage_percent{instance_id="123_app_456"}

# Memória por instância
supabase_instance_memory_usage_bytes{instance_id="123_app_456"}

# Conexões de banco
supabase_database_connections{instance_id="123_app_456"}
```

## 🛠️ Comandos Úteis

### Gerenciar Stack
```bash
# Iniciar monitoramento
./setup_monitoring.sh --start

# Parar monitoramento
./setup_monitoring.sh --stop

# Reiniciar stack
./setup_monitoring.sh --restart

# Reconfigurar tudo
./setup_monitoring.sh --setup
```

### Auto-Discovery Manual
```bash
# Executar discovery
./update_monitoring.sh

# Verificar instances.json
cat instances.json | jq .

# Recarregar Prometheus
curl -X POST http://localhost:9090/-/reload
```

### Health Monitoring
```bash
# Executar health check manual
./health_monitor.sh

# Ver status page
curl http://localhost:8080/status/api/status.json | jq .

# Verificar logs de saúde
tail -f /var/log/supabase-health.log
```

## 📁 Estrutura de Arquivos

```
monitoring/
├── docker-compose.monitoring.yml    # Stack principal
├── prometheus.yml                   # Config Prometheus
├── instances.json                   # Auto-discovery targets
├── update_monitoring.sh             # Script de discovery
├── health_monitor.sh               # Health checks
├── setup_monitoring.sh             # Setup automático
├── alerts/
│   ├── alerting_rules.yml          # Regras de alerta
│   └── alertmanager.yml            # Config notificações
├── grafana/
│   ├── provisioning/               # Auto-provision Grafana
│   └── dashboards/                 # Dashboards JSON
├── exporter/                       # Custom exporter
│   ├── Dockerfile
│   ├── exporter.py                 # Métricas customizadas
│   └── requirements.txt
└── status/                         # Status page HTML
    ├── index.html                  # Dashboard visual
    └── status.json                 # API JSON
```

## 🔧 Configuração Avançada

### Variáveis de Ambiente

```bash
# Banco master
export MASTER_DB_URL="postgresql://user:pass@host:5432/db"

# Notificações
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export ADMIN_EMAIL="admin@domain.com"

# Alertmanager
export ALERTMANAGER_URL="http://localhost:9093"

# Intervalos
export SCRAPE_INTERVAL="30"           # Prometheus scrape
export DISCOVERY_INTERVAL="60"        # Auto-discovery
export HEALTH_CHECK_INTERVAL="30"     # Health checks
```

### Personalizar Alertas

```yaml
# alerts/custom_rules.yml
groups:
  - name: custom_alerts
    rules:
      - alert: CustomAlert
        expr: your_metric > threshold
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Custom alert triggered"
```

### Adicionar Dashboards

1. Criar dashboard no Grafana UI
2. Exportar JSON
3. Salvar em `grafana/dashboards/`
4. Reiniciar Grafana

## 🚨 Troubleshooting

### Serviços não iniciam
```bash
# Verificar logs
docker-compose -f docker-compose.monitoring.yml logs

# Verificar portas
netstat -tlnp | grep -E "(3001|9090|9093)"

# Verificar permissões
ls -la /var/log/supabase-*.log
```

### Auto-discovery não funciona
```bash
# Verificar script
./update_monitoring.sh

# Verificar arquivo gerado
cat instances.json | jq .

# Verificar logs
tail -f /var/log/supabase-monitoring.log
```

### Alertas não chegam
```bash
# Testar Alertmanager
curl -X POST http://localhost:9093/api/v1/alerts -d '[...]'

# Verificar configuração
docker exec supabase_alertmanager amtool config show

# Verificar webhooks
curl -X POST $SLACK_WEBHOOK_URL -d '{"text":"teste"}'
```

## 📚 Recursos Adicionais

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Guide](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## 🤝 Contribuição

Para adicionar novas métricas ou dashboards:

1. Implemente no `exporter/exporter.py`
2. Adicione queries no dashboard
3. Configure alertas se necessário
4. Teste com instâncias reais
5. Documente as mudanças

## 📝 Licença

Distribuído sob a mesma licença do projeto Supabase.