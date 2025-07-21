# Monitoramento Simplificado - Supabase BaaS

Versão simplificada do monitoramento baseada na especificação, focada em **auto-discovery** e **alertas básicos**.

## 🚀 Quick Start

### 1. Iniciar Monitoramento

```bash
# Navegar para diretório
cd docker/monitoring/

# Iniciar stack completa
./setup_simple_monitoring.sh --start

# Configurar cron jobs (requer sudo)
sudo ./setup_simple_monitoring.sh --install-cron
```

### 2. Acessar Dashboards

- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **Status Page**: file://status/index.html

## 🔍 Auto-Discovery

### Como Funciona

O script `update_monitoring_simple.sh` executa **a cada 1 minuto** via cron e:

1. **Busca containers Kong** com padrão `*_kong`
2. **Extrai instance_id** removendo sufixo `_kong`
3. **Obtém porta** do Kong via `docker port`
4. **Consulta banco master** para metadados (projeto, org)
5. **Gera instances.json** para Prometheus
6. **Recarrega Prometheus** automaticamente

### Exemplo de Output

```json
[
  {
    "targets": ["localhost:8001"],
    "labels": {
      "instance": "123_myapp_1640995200",
      "project_name": "MyApp",
      "org_id": "123"
    }
  }
]
```

### Executar Manualmente

```bash
# Executar discovery agora
./update_monitoring_simple.sh

# Verificar arquivo gerado
cat instances.json | jq .
```

## 🚨 Health Monitoring

### Como Funciona

O script `health_monitor_simple.sh` executa **a cada 30 segundos** via cron e:

1. **Busca containers Studio** com padrão `*_studio`
2. **Verifica containers** (studio, kong, db) estão rodando
3. **Testa conectividade HTTP** do Kong
4. **Envia alertas** para Alertmanager se problemas
5. **Gera status page** HTML com resumo

### Alertas Enviados

- **InstanceDown**: Containers não estão rodando
- **HTTPEndpointDown**: Kong não responde HTTP

### Status Page

Página HTML simples atualizada automaticamente:

- 📊 **Resumo**: Total, saudáveis, com problemas
- 🔄 **Auto-refresh**: A cada 30 segundos
- 📱 **Responsiva**: Funciona no mobile

## ⚙️ Configuração

### Variáveis de Ambiente

```bash
# Banco master (opcional)
export MASTER_DB_URL="postgresql://user:pass@host:5432/db"

# Webhooks para notificações (opcional)
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export ADMIN_EMAIL="admin@domain.com"
```

### Cron Jobs Configurados

```bash
# Auto-discovery (1 minuto)
*/1 * * * * root /path/to/update_monitoring_simple.sh

# Health check (30 segundos com offset)
* * * * * root /path/to/health_monitor_simple.sh
* * * * * root sleep 30; /path/to/health_monitor_simple.sh
```

## 📊 Dashboards Disponíveis

### Supabase Overview Simples

- 🎯 **Instâncias Ativas**: Contador total
- 🟢 **Instâncias Online**: Contador online
- 💻 **CPU do Sistema**: Gauge de uso
- 🧠 **Memória do Sistema**: Gauge de uso
- 📋 **Status das Instâncias**: Tabela detalhada
- 🚨 **Alertas Ativos**: Lista de alertas firing

## 🔔 Sistema de Alertas

### Regras Configuradas

```yaml
# Instance Down - containers não rodando
- alert: InstanceDown
  expr: up{job="supabase-instances"} == 0
  for: 1m
  labels:
    severity: critical

# High CPU - CPU > 80%
- alert: HighCPUUsage
  expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 5m
  labels:
    severity: warning

# High Memory - Memória > 90%
- alert: HighMemoryUsage
  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
  for: 2m
  labels:
    severity: critical
```

### Notificações

Configuradas em `alerts/alertmanager.yml`:

- 📧 **Email**: Para admin@yourdomain.com
- 💬 **Slack**: Via webhook (se configurado)
- 🔗 **Webhook**: Para integração externa

## 🛠️ Comandos Úteis

### Gerenciar Stack

```bash
# Iniciar monitoramento
./setup_simple_monitoring.sh --start

# Parar monitoramento
./setup_simple_monitoring.sh --stop

# Configurar cron (requer sudo)
sudo ./setup_simple_monitoring.sh --install-cron
```

### Debug

```bash
# Testar discovery
./update_monitoring_simple.sh

# Testar health check
./health_monitor_simple.sh

# Ver status dos containers
docker-compose -f docker-compose.simple.yml ps

# Ver logs
docker-compose -f docker-compose.simple.yml logs -f
```

### Verificar Prometheus

```bash
# Targets descobertos
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, instance}'

# Alertas ativos
curl -s http://localhost:9093/api/v1/alerts | jq '.data[] | {labels, state}'

# Reload configuração
curl -X POST http://localhost:9090/-/reload
```

## 📁 Estrutura Simplificada

```
monitoring/
├── docker-compose.simple.yml      # Stack simplificada
├── prometheus.simple.yml          # Config Prometheus básica
├── instances.json                 # Targets auto-discovery
├── update_monitoring_simple.sh    # Discovery script
├── health_monitor_simple.sh       # Health check script
├── setup_simple_monitoring.sh     # Setup automático
├── alerts/
│   ├── alerting_rules.yml         # Regras básicas
│   └── alertmanager.yml           # Notificações
├── grafana/
│   └── dashboards/
│       └── supabase-simple-overview.json
└── status/
    ├── index.html                 # Status page
    └── status.json                # API JSON
```

## 🎯 Diferenças da Versão Completa

**Versão Simplificada:**
- ✅ Auto-discovery básico via containers Kong
- ✅ Health check via containers + HTTP
- ✅ Alertas essenciais (down, CPU, memória)
- ✅ Status page HTML simples
- ✅ Cron jobs automatizados

**Versão Completa:**
- 🔧 Exporter customizado Python
- 🔧 Métricas específicas do Supabase
- 🔧 Dashboard avançado com drill-down
- 🔧 Integração avançada com master DB
- 🔧 Monitoramento de performance detalhado

## 💡 Casos de Uso

**Use a versão simplificada quando:**
- Você quer monitoramento básico rapidamente
- Não precisa de métricas detalhadas
- Quer apenas saber se instâncias estão UP/DOWN
- Precisa de setup rápido sem dependências

**Use a versão completa quando:**
- Você quer métricas detalhadas de performance
- Precisa de dashboards avançados
- Quer monitoramento de nível enterprise
- Tem equipe dedicada para monitoramento

## 🚀 Próximos Passos

1. **Testar Discovery**: Criar uma instância e verificar se é descoberta
2. **Configurar Alertas**: Adicionar webhooks para notificações
3. **Personalizar Dashboards**: Ajustar painéis conforme necessidade
4. **Escalar**: Migrar para versão completa quando necessário

---

## ✅ Checklist de Instalação

- [ ] Executar `./setup_simple_monitoring.sh --start`
- [ ] Verificar Grafana em http://localhost:3000
- [ ] Testar discovery com `./update_monitoring_simple.sh`
- [ ] Configurar cron com `sudo ./setup_simple_monitoring.sh --install-cron`
- [ ] Verificar status page em `status/index.html`
- [ ] Configurar notificações (opcional)

O **monitoramento simplificado** está pronto para uso! 🎉