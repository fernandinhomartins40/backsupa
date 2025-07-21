# 🚀 Guia Completo de Deploy - Supabase BaaS Multi-Tenant na VPS

## 📋 Visão Geral

Este guia fornece instruções detalhadas para fazer o deploy completo do sistema **Supabase BaaS Multi-Tenant** na sua VPS com IP `82.25.69.57`.

## 🎯 O que será instalado

- ✅ **Sistema Multi-Tenant** com isolamento completo
- ✅ **Proxy Reverso Nginx** com roteamento dinâmico
- ✅ **SSL/TLS** com Let's Encrypt
- ✅ **Monitoramento** com Prometheus e Grafana
- ✅ **Backup Automático** diário
- ✅ **Firewall** e segurança
- ✅ **Instância de demonstração** pré-configurada

## 🔧 Pré-requisitos

### VPS Recomendada
- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 100GB SSD
- **OS**: Ubuntu 20.04/22.04 LTS
- **Network**: Portas 80, 443, 3000-3010 abertas

### Acesso Necessário
- SSH root: `root@82.25.69.57`
- Senha ou chave SSH configurada

## 🚀 Deploy Automático (Recomendado)

### 1. Conectar na VPS
```bash
ssh root@82.25.69.57
```

### 2. Baixar e executar o script
```bash
# Atualizar sistema
apt update && apt upgrade -y

# Instalar git
apt install -y git

# Clonar repositório
git clone https://github.com/fernandinhomartins40/backsupa.git
cd backsupa

# Tornar script executável
chmod +x deploy-vps.sh

# Executar deploy
./deploy-vps.sh
```

**Tempo estimado**: 15-20 minutos

## 🔧 Deploy Manual (Alternativo)

### 1. Preparação do Sistema

```bash
# Atualizar sistema
apt update && apt upgrade -y

# Instalar dependências
apt install -y curl wget git vim htop ufw fail2ban nginx nginx-extras lua-cjson jq openssl docker.io docker-compose certbot python3-certbot-nginx
```

### 2. Configurar Firewall

```bash
# Configurar UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000:3010/tcp
ufw --force enable
```

### 3. Configurar Docker

```bash
# Iniciar Docker
systemctl enable docker
systemctl start docker
usermod -aG docker root
```

### 4. Configurar SSL

```bash
# Configurar domínio (substitua pelo seu)
DOMAIN="82.25.69.57.sslip.io"
EMAIL="admin@82.25.69.57.sslip.io"

# Obter certificado SSL
certbot --nginx -d $DOMAIN -d *.$DOMAIN --agree-tos --email $EMAIL --non-interactive
```

### 5. Instalar Sistema

```bash
# Criar estrutura
mkdir -p /opt/supabase-baas/{instances,backups,logs,scripts,ssl,monitoring}

# Copiar arquivos
cp -r docker/* /opt/supabase-baas/
cp -r scripts/* /opt/supabase-baas/scripts/

# Tornar executável
chmod +x /opt/supabase-baas/*.bash
chmod +x /opt/supabase-baas/*.sh
chmod +x /opt/supabase-baas/scripts/*.sh
```

## 🌐 Configuração de Domínio

### Opção 1: Usar IP diretamente
- **Acesso**: `https://82.25.69.57.sslip.io`
- **Subdomínios**: `https://demo.82.25.69.57.sslip.io`

### Opção 2: Domínio personalizado
1. Configurar DNS:
   ```
   *.seu-dominio.com  IN  A  82.25.69.57
   seu-dominio.com    IN  A  82.25.69.57
   ```

2. Atualizar script:
   ```bash
   export DOMAIN="seu-dominio.com"
   export EMAIL="seu-email@dominio.com"
   ```

## 🎯 Comandos de Uso

### Criar Nova Instância
```bash
# Formato básico
supabase-create --project="nome-projeto" --org-id="org123" --subdomain="app-org123"

# Exemplo real
supabase-create --project="meu-app" --org-id="empresa1" --subdomain="app-empresa1"
```

### Gerenciar Instâncias
```bash
# Listar todas as instâncias
supabase-routes list_routes

# Verificar saúde
supabase-routes health_check

# Parar instância
cd /opt/supabase-baas/instances/app-empresa1
docker-compose down

# Iniciar instância
docker-compose up -d

# Ver logs
docker-compose logs -f
```

### Acessar Serviços

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **Demo** | `https://demo.82.25.69.57.sslip.io` | Instância de demonstração |
| **Studio** | `https://demo.82.25.69.57.sslip.io` | Interface do Supabase |
| **API** | `https://demo.82.25.69.57.sslip.io/rest/v1/` | API REST |
| **Auth** | `https://demo.82.25.69.57.sslip.io/auth/v1/` | Autenticação |
| **Storage** | `https://demo.82.25.69.57.sslip.io/storage/v1/` | Armazenamento |
| **Grafana** | `https://82.25.69.57.sslip.io:3004` | Monitoramento (admin/admin) |

## 📊 Monitoramento

### Dashboards Disponíveis
- **Grafana**: `https://82.25.69.57.sslip.io:3004`
  - Login: admin/admin
  - Dashboards: System Overview, Database Metrics, API Usage

### Health Checks
```bash
# Verificar todas as instâncias
curl https://82.25.69.57.sslip.io/api/system/status

# Verificar instância específica
curl https://demo.82.25.69.57.sslip.io/health
```

## 💾 Backup e Restauração

### Backup Automático
- **Frequência**: Diariamente às 2h
- **Local**: `/opt/supabase-baas/backups/`
- **Retenção**: 7 dias

### Backup Manual
```bash
# Executar backup imediato
/opt/supabase-baas/scripts/backup.sh

# Verificar backups
ls -la /opt/supabase-baas/backups/
```

### Restaurar Backup
```bash
# Restaurar banco de dados
cd /opt/supabase-baas/instances/app-empresa1
docker-compose exec -T db psql -U postgres postgres < backup.sql
```

## 🔐 Segurança

### Configurações Implementadas
- ✅ **Firewall UFW** ativo
- ✅ **Fail2ban** para proteção SSH
- ✅ **SSL/TLS** com Let's Encrypt
- ✅ **Rate limiting** nas APIs
- ✅ **Headers de segurança** no Nginx
- ✅ **Isolamento de containers**

### Atualizar segurança
```bash
# Atualizar sistema
apt update && apt upgrade -y

# Atualizar certificados SSL
certbot renew --quiet
```

## 🐛 Troubleshooting

### Problemas Comuns

#### 1. Instância não inicia
```bash
# Verificar logs
cd /opt/supabase-baas/instances/app-empresa1
docker-compose logs

# Verificar portas
netstat -tulpn | grep :3000
```

#### 2. Erro de SSL
```bash
# Verificar certificado
certbot certificates

# Renovar manualmente
certbot renew --force-renewal
```

#### 3. Nginx não roteia
```bash
# Verificar configuração
nginx -t

# Verificar rotas
cat /opt/supabase-baas/routes.json

# Reiniciar Nginx
systemctl restart nginx
```

#### 4. Docker não inicia
```bash
# Verificar status
systemctl status docker

# Reiniciar Docker
systemctl restart docker
```

## 📈 Escalabilidade

### Horizontal Scaling
```bash
# Adicionar nova instância
supabase-create --project="app2" --org-id="org2" --subdomain="app2-org2"

# Balanceamento de carga
# Configurar CDN ou load balancer externo
```

### Otimizações
- **Connection pooling**: Configurado via Supavisor
- **Cache**: Redis integrado
- **CDN**: Pronto para CloudFlare/AWS CloudFront

## 🔄 Atualização do Sistema

### Atualizar código
```bash
# Parar serviços
systemctl stop supabase-baas

# Atualizar repositório
cd /opt/supabase-baas
git pull origin main

# Reiniciar serviços
systemctl start supabase-baas
```

### Atualizar containers
```bash
# Atualizar todas as instâncias
for dir in /opt/supabase-baas/instances/*/; do
    cd "$dir"
    docker-compose pull
    docker-compose up -d
done
```

## 📞 Suporte

### Logs Importantes
```bash
# Logs do sistema
tail -f /var/log/supabase-baas-deploy.log

# Logs do Nginx
tail -f /var/log/nginx/supabase-baas-error.log

# Logs de instância
tail -f /opt/supabase-baas/instances/*/logs/*
```

### Comandos Úteis
```bash
# Status do sistema
systemctl status supabase-baas

# Espaço em disco
df -h

# Uso de memória
free -h

# Processos Docker
docker ps
```

## 🎯 Próximos Passos

1. **Criar sua primeira instância**
2. **Configurar domínio personalizado**
3. **Adicionar templates ao marketplace**
4. **Configurar alertas de monitoramento**
5. **Implementar CI/CD**

## 📋 Checklist Final

- [ ] VPS acessível via SSH
- [ ] Script de deploy executado
- [ ] SSL configurado
- [ ] Instância demo criada
- [ ] Monitoramento ativo
- [ ] Backup configurado
- [ ] Firewall ativado
- [ ] Testes de acesso realizados

---

## 🚀 Começando Agora

Execute o comando abaixo para iniciar o deploy:

```bash
ssh root@82.25.69.57
curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/deploy-vps.sh | bash
```

**Suporte**: Em caso de problemas, verifique os logs em `/var/log/supabase-baas-deploy.log`
