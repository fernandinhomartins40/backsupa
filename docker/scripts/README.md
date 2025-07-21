# Scripts de Automação - Supabase Multi-Tenant

Este diretório contém scripts de automação para gerenciar o ciclo de vida das instâncias Supabase multi-tenant.

## 📁 Estrutura

```
scripts/
├── README.md                    # Este arquivo
├── create_instance.sh          # 🚀 Criar nova instância
├── start_instance.sh           # ▶️  Iniciar instância
├── stop_instance.sh            # ⏹️  Parar instância
├── delete_instance.sh          # 🗑️  Deletar instância
├── list_instances.sh           # 📋 Listar instâncias
├── apply_template.sh           # 📋 Aplicar templates
├── setup_cron.sh              # 🕒 Configurar backup automático
├── templates/                  # 📄 Templates de schema SQL
│   ├── todo-schema.sql
│   ├── webapp-schema.sql
│   └── ecommerce-schema.sql
└── backup/                     # 💾 Scripts de backup
    ├── backup_instance.sh      # Backup individual
    ├── backup_all.sh           # Backup de todas as instâncias
    ├── restore_instance.sh     # Restaurar instância
    ├── cleanup_backups.sh      # Limpar backups antigos
    └── check_disk_space.sh     # Verificar espaço em disco
```

## 🚀 Uso Básico

### Criar Nova Instância

```bash
# Instância básica
./create_instance.sh --project="meu-app" --org-id="123" --template="blank"

# Instância com template específico
./create_instance.sh --project="loja-online" --org-id="456" --template="ecommerce"

# Templates disponíveis:
# - blank: Projeto em branco
# - todo: App de lista de tarefas
# - webapp: Aplicação web com perfis e posts
# - ecommerce: Loja online completa
# - mobile-app: App mobile
# - saas: Plataforma SaaS
```

### Gerenciar Instâncias

```bash
# Listar todas as instâncias
./list_instances.sh

# Listar apenas instâncias rodando
./list_instances.sh --running

# Iniciar instância
./start_instance.sh 123_meuapp_1640995200

# Parar instância
./stop_instance.sh 123_meuapp_1640995200

# Deletar instância (com confirmação)
./delete_instance.sh 123_meuapp_1640995200

# Deletar instância sem confirmação
./delete_instance.sh 123_meuapp_1640995200 --force
```

## 💾 Sistema de Backup

### Backup Manual

```bash
# Backup simples
./backup/backup_instance.sh 123_meuapp_1640995200

# Backup compactado
./backup/backup_instance.sh 123_meuapp_1640995200 --compress

# Backup compactado e criptografado
./backup/backup_instance.sh 123_meuapp_1640995200 --compress --encrypt

# Backup de todas as instâncias
./backup/backup_all.sh --compress --parallel=4
```

### Backup Automático

```bash
# Configurar backup automático (requer sudo)
sudo ./setup_cron.sh

# Personalizar horário e retenção
sudo ./setup_cron.sh --backup-time="03:00" --cleanup-days=45

# Verificar configuração
cat /etc/cron.d/supabase-backup

# Monitorar logs
tail -f /var/log/supabase-backup.log
```

### Restauração

```bash
# Restaurar instância
./backup/restore_instance.sh 123_meuapp_1640995200 /opt/backups/instances/backup.tar.gz

# Restaurar forçando sobrescrita
./backup/restore_instance.sh 123_meuapp_1640995200 /opt/backups/instances/backup.tar.gz --force
```

### Limpeza de Backups

```bash
# Simular limpeza (dry-run)
./backup/cleanup_backups.sh --days=30 --dry-run

# Limpar backups antigos
./backup/cleanup_backups.sh --days=30

# Limpar backups de instância específica
./backup/cleanup_backups.sh --days=30 --instance=123_meuapp_1640995200
```

## 📄 Templates Disponíveis

### 1. Todo App (`todo`)
- Sistema de listas de tarefas
- Perfis de usuário
- Tags e categorias
- Row Level Security (RLS)

### 2. Web App (`webapp`)
- Sistema de posts/artigos
- Comentários e reações
- Seguidores e notificações
- Categorias e tags

### 3. E-commerce (`ecommerce`)
- Catálogo de produtos
- Carrinho de compras
- Sistema de pedidos
- Avaliações e wishlist
- Cupons de desconto

### 4. Blank (`blank`)
- Projeto vazio
- Apenas estrutura básica do Supabase

## 🔧 Configuração Avançada

### Variáveis de Ambiente

```bash
# Banco master para registro de instâncias
export MASTER_DB_URL="postgresql://user:pass@localhost:5432/supabase_master"

# Webhook para notificações
export BACKUP_WEBHOOK_URL="https://hooks.slack.com/services/..."

# Webhook de emergência para alertas críticos
export EMERGENCY_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Diretórios Padrão

```bash
# Instâncias
/opt/supabase-instances/

# Backups
/opt/backups/instances/

# Logs
/var/log/supabase-backup.log

# Configuração nginx
/etc/nginx/sites-available/
/etc/nginx/sites-enabled/
```

## 🔐 Segurança

### Backup Criptografado

Os backups podem ser criptografados usando GPG:

```bash
# Backup com criptografia
./backup/backup_instance.sh instance_id --encrypt

# Restaurar backup criptografado (solicitará senha)
./backup/restore_instance.sh instance_id backup.tar.gz.gpg
```

### Permissões

```bash
# Aplicar permissões corretas
chmod +x scripts/*.sh
chmod +x scripts/backup/*.sh
chmod +x scripts/templates/*.sh

# Scripts sensíveis devem ter permissões restritas
chmod 750 scripts/backup/
```

## 📊 Monitoramento

### Logs de Backup

```bash
# Ver logs em tempo real
tail -f /var/log/supabase-backup.log

# Filtrar apenas erros
grep -i error /var/log/supabase-backup.log

# Estatísticas de backup
grep "📊 Resumo" /var/log/supabase-backup.log
```

### Verificação de Integridade

```bash
# Verificar espaço em disco
./backup/check_disk_space.sh

# Verificar status das instâncias
./list_instances.sh

# Verificar logs do Docker
docker-compose -f /opt/supabase-instances/INSTANCE_ID/docker-compose.yml logs
```

## 🚨 Troubleshooting

### Problemas Comuns

1. **Erro de permissão**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Instância não inicia**
   ```bash
   # Verificar logs
   docker-compose logs
   
   # Verificar volumes
   docker volume ls | grep INSTANCE_ID
   ```

3. **Backup falha**
   ```bash
   # Verificar espaço em disco
   df -h /opt/backups
   
   # Verificar permissões
   ls -la /opt/backups/instances/
   ```

4. **Nginx não atualiza**
   ```bash
   # Recarregar configuração
   sudo nginx -t && sudo nginx -s reload
   ```

### Recuperação de Emergência

```bash
# Parar todas as instâncias
docker stop $(docker ps -q --filter name=supabase)

# Limpar volumes órfãos
docker volume prune

# Recriar instância do zero
./delete_instance.sh INSTANCE_ID --force
./create_instance.sh --project="backup" --org-id="999" --template="blank"
./backup/restore_instance.sh INSTANCE_ID /opt/backups/latest.tar.gz
```

## 🔄 Integração com CI/CD

### GitHub Actions

```yaml
name: Backup Supabase Instances
on:
  schedule:
    - cron: '0 2 * * *'  # Diário às 2h
jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - name: Run backup
        run: |
          ssh user@server "/opt/supabase-instances/scripts/backup/backup_all.sh --compress"
```

### Docker Health Checks

```yaml
# Adicionar ao docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

## 📚 Recursos Adicionais

- [Documentação do Supabase](https://supabase.com/docs)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [PostgreSQL Backup Guide](https://www.postgresql.org/docs/current/backup.html)
- [Nginx Configuration](https://nginx.org/en/docs/)

## 🤝 Contribuição

Para contribuir com melhorias nos scripts:

1. Teste em ambiente de desenvolvimento
2. Documente mudanças no README
3. Mantenha compatibilidade com versões anteriores
4. Inclua tratamento de erros adequado

## 📝 Licença

Scripts distribuídos sob a mesma licença do projeto Supabase.