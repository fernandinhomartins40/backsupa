# 🚀 Deploy Guide - Supabase BaaS Clone

Este guia explica como fazer o deploy completo da aplicação Supabase BaaS Clone em sua VPS da Hostinger usando GitHub Actions.

## 📋 Pré-requisitos

### VPS Requirements
- **OS**: Ubuntu 20.04+ / Debian 11+
- **RAM**: Mínimo 4GB (recomendado 8GB+)
- **Storage**: Mínimo 50GB SSD
- **CPU**: 2+ cores
- **Network**: Conexão estável

### Credenciais Necessárias
- SSH access: `ssh root@82.25.69.57`
- Password da VPS (será configurado como secret)

## 🔧 Passo 1: Configurar VPS Inicial

### 1.1 Conectar na VPS
```bash
ssh root@82.25.69.57
```

### 1.2 Executar Setup Inicial
```bash
# Download do script de setup
curl -fsSL https://raw.githubusercontent.com/seu-usuario/backsupa/main/scripts/deploy/setup-vps.sh -o setup-vps.sh

# Dar permissão de execução
chmod +x setup-vps.sh

# Executar setup (como root)
./setup-vps.sh
```

Este script irá:
- ✅ Atualizar o sistema
- ✅ Instalar Docker & Docker Compose
- ✅ Instalar Node.js 20
- ✅ Instalar Nginx
- ✅ Configurar firewall (UFW)
- ✅ Configurar fail2ban
- ✅ Criar estrutura de diretórios
- ✅ Configurar SSL auto-assinado
- ✅ Configurar logrotate e cron jobs
- ✅ Otimizar sistema

### 1.3 Verificar Setup
```bash
# Verificar serviços
systemctl status docker
systemctl status nginx

# Verificar versões
docker --version
node --version
nginx -v

# Testar página de status
curl http://localhost
```

## 🔐 Passo 2: Configurar GitHub Secrets

### 2.1 Acessar GitHub Repository Settings
1. Vá para seu repositório no GitHub
2. Clique em **Settings** → **Secrets and variables** → **Actions**

### 2.2 Adicionar Secret
Clique em **New repository secret** e adicione:

- **Name**: `VPS_PASSWORD`
- **Value**: `sua_senha_da_vps`

## ⚙️ Passo 3: Configurar Deployment

### 3.1 Ajustar Domínio (Opcional)
Edite `.github/workflows/deploy.yml` e substitua `yourdomain.com` pelo seu domínio:

```yaml
# Linha 13
APP_URL: https://app.seudominio.com
API_URL: https://api.seudominio.com

# Linha 104 e outras
server_name seudominio.com *.seudominio.com;
```

### 3.2 Configurar DNS (Se usando domínio personalizado)
Configure os seguintes registros DNS:

```
A     seudominio.com          → 82.25.69.57
A     www.seudominio.com      → 82.25.69.57
A     app.seudominio.com      → 82.25.69.57
A     api.seudominio.com      → 82.25.69.57
A     staging.seudominio.com  → 82.25.69.57
```

## 🚀 Passo 4: Deploy Automático

### 4.1 Trigger Deploy
Para fazer deploy, simplesmente:

```bash
# Deploy para staging
git push origin main

# Deploy para produção  
git push origin production
```

### 4.2 Monitorar Deploy
1. Vá para **Actions** no GitHub
2. Clique no workflow em execução
3. Acompanhe os logs em tempo real

## 📊 Passo 5: Verificar Deploy

### 5.1 Verificar via Script
```bash
# Na VPS, executar health check
cd /opt/supabase-baas/current
./scripts/deploy/health-check.sh --verbose
```

### 5.2 Verificar Endpoints
```bash
# Health checks básicos
curl http://82.25.69.57/health
curl http://82.25.69.57:3001/health  # Control API
curl http://82.25.69.57:3002/health  # Billing API
curl http://82.25.69.57:3003/health  # Marketplace API

# Verificar containers
docker ps

# Verificar logs
docker-compose -f docker-compose.master.yml logs --tail=20
```

### 5.3 Acessar Aplicação
- **Staging**: `http://82.25.69.57` ou `https://staging.seudominio.com`
- **Production**: `https://app.seudominio.com` (branch production)
- **APIs**: Porta 3001, 3002, 3003

## 🏗️ Arquitetura de Deploy

### Serviços Deployados
```
📦 Supabase BaaS Stack
├── 🌐 Nginx Proxy (80, 443)
├── 🔧 Control API (3001)
├── 💳 Billing API (3002)  
├── 🏪 Marketplace API (3003)
├── 🐘 PostgreSQL Master (5432)
├── 📊 Monitoring Stack
│   ├── Prometheus (9090)
│   ├── Grafana (3000)
│   └── Alertmanager (9093)
└── 🔄 Multi-Tenant Instances (dynamic ports)
```

### Estrutura de Arquivos na VPS
```
/opt/supabase-baas/
├── current/                 # Versão ativa
│   ├── .env                # Environment variables
│   ├── docker-compose.*.yml
│   ├── nginx/              # Configurações Nginx
│   ├── control-api/        # Control API
│   ├── billing-system/     # Billing & Marketplace
│   └── scripts/            # Scripts de manutenção
├── backup-*/               # Backups de versões anteriores
├── backups/                # Backups de dados
├── logs/                   # Logs da aplicação
└── ssl/                    # Certificados SSL
```

## 🔧 Manutenção e Troubleshooting

### Health Check
```bash
# Health check completo
/opt/supabase-baas/current/scripts/deploy/health-check.sh --verbose

# Health check JSON (para integração)
/opt/supabase-baas/current/scripts/deploy/health-check.sh --json
```

### Logs Importantes
```bash
# Logs do deploy
tail -f /var/log/supabase-setup.log

# Logs do Nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Logs dos containers
docker logs supabase_control_api
docker logs supabase_master_db
docker logs supabase_nginx
```

### Comandos Úteis
```bash
# Restart todos os serviços
cd /opt/supabase-baas/current
docker-compose -f docker-compose.master.yml restart

# Rebuild com novas mudanças
docker-compose -f docker-compose.master.yml up --build -d

# Verificar recursos
htop
df -h
free -h

# Verificar portas
netstat -tlnp | grep -E ":80|:443|:3001|:3002|:3003|:5432"
```

### Backup Manual
```bash
# Backup do banco master
docker exec supabase_master_db pg_dump -U postgres supabase_master > backup_$(date +%Y%m%d).sql

# Backup de configurações
tar -czf config_backup_$(date +%Y%m%d).tar.gz /opt/supabase-baas/current/.env /opt/supabase-baas/current/docker-compose.*.yml
```

## 🔒 Segurança

### Firewall Status
```bash
ufw status verbose
```

### Fail2ban Status
```bash
fail2ban-client status
fail2ban-client status sshd
```

### SSL Certificate (Produção)
Para produção, substitua o certificado auto-assinado:

```bash
# Instalar certbot
apt install certbot python3-certbot-nginx

# Obter certificado Let's Encrypt
certbot --nginx -d seudominio.com -d www.seudominio.com -d app.seudominio.com

# Renovação automática
crontab -e
# Adicionar: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 📞 Suporte

### Troubleshooting Comum

#### ❌ Deploy Falha na Conexão SSH
```bash
# Verificar se SSH está rodando
systemctl status ssh

# Verificar porta SSH
netstat -tlnp | grep :22

# Testar conexão
ssh -v root@82.25.69.57
```

#### ❌ Containers não Iniciam
```bash
# Verificar logs do Docker
journalctl -u docker --since "10 minutes ago"

# Verificar recursos
df -h  # Verificar espaço em disco
free -h  # Verificar memória

# Limpar containers órfãos
docker system prune -f
```

#### ❌ APIs não Respondem
```bash
# Verificar se containers estão rodando
docker ps

# Verificar logs específicos
docker logs supabase_control_api --tail=50

# Restart API específica
docker-compose -f docker-compose.master.yml restart control-api
```

Para suporte adicional, verifique os logs detalhados ou crie uma issue no repositório.

## 🎉 Conclusão

Após seguir este guia, você terá:
- ✅ VPS configurada e otimizada
- ✅ Deploy automático via GitHub Actions
- ✅ Sistema de monitoramento ativo
- ✅ Backups automáticos
- ✅ SSL configurado
- ✅ Sistema multi-tenant funcional

Seu Supabase BaaS Clone estará pronto para produção! 🚀