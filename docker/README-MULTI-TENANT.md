# Supabase Multi-Tenant BaaS

Sistema de multi-tenancy para Supabase que permite criar instâncias isoladas por subdomínio.

## 🎯 Características

- **Instâncias Isoladas**: Cada projeto tem seu próprio conjunto de containers
- **Portas Dinâmicas**: Geração automática de portas únicas baseadas em hash
- **Configurações Únicas**: JWT secrets, senhas e chaves únicos por instância
- **Proxy Reverso**: Roteamento automático por subdomínio via Nginx + Lua
- **Gerenciamento Simplificado**: Scripts automatizados para criação e gerenciamento

## 📋 Pré-requisitos

- Ubuntu/Debian Linux
- Docker e Docker Compose
- Nginx com suporte Lua
- jq, openssl
- Acesso root para configuração inicial

## 🚀 Instalação

### 1. Instalação Automática

```bash
# Executar como root
sudo ./install-multi-tenant.sh
```

### 2. Instalação Manual

```bash
# Instalar dependências
sudo apt update
sudo apt install -y nginx nginx-extras lua-cjson jq openssl docker.io docker-compose

# Criar estrutura de diretórios
sudo mkdir -p /opt/supabase-instances

# Copiar scripts
sudo cp nginx-manager.sh /opt/supabase-instances/
sudo chmod +x /opt/supabase-instances/nginx-manager.sh

# Configurar Nginx
sudo cp nginx-config/supabase-baas /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/supabase-baas /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 📝 Uso

### Criar Nova Instância

```bash
./generate.bash --project="meu-app" --org-id="123" --subdomain="app-org123"
```

**Parâmetros:**
- `--project`: Nome do projeto
- `--org-id`: ID da organização
- `--subdomain`: Subdomínio para acesso (sem o domínio base)

### Gerenciar Rotas

```bash
# Listar todas as rotas
supabase-routes list_routes

# Verificar saúde das instâncias
supabase-routes health_check

# Adicionar rota manualmente
supabase-routes add_route app-org123 15001

# Remover rota
supabase-routes remove_route app-org123

# Limpar rotas órfãs
supabase-routes cleanup
```

### Gerenciar Instâncias

```bash
# Parar instância
cd /opt/supabase-instances/{INSTANCE_ID}
docker compose down

# Iniciar instância
docker compose up -d

# Ver logs
docker compose logs -f

# Remover instância completamente
docker compose down -v
rm -rf /opt/supabase-instances/{INSTANCE_ID}
supabase-routes remove_route {SUBDOMAIN}
```

## 🗂️ Estrutura de Arquivos

```
docker/
├── generate.bash              # Script principal de criação
├── nginx-manager.sh           # Gerenciador de rotas Nginx
├── nginx-config/
│   └── supabase-baas         # Template de configuração Nginx
├── install-multi-tenant.sh   # Script de instalação
├── routes.json.template       # Template do arquivo de rotas
├── .env.template             # Template de variáveis de ambiente
└── docker-compose.yml        # Configuração Docker multi-tenant

/opt/supabase-instances/
├── nginx-manager.sh          # Script de gerenciamento
├── routes.json              # Mapeamento subdomain->porta
├── backups/                 # Backups automáticos do routes.json
└── {INSTANCE_ID}/           # Diretório de cada instância
    ├── config.json          # Configuração da instância
    ├── .env                 # Variáveis específicas
    ├── docker-compose.yml   # Docker Compose da instância
    └── volumes/             # Volumes persistentes
```

## 🔧 Configuração Avançada

### Personalizar Domínio Base

1. Editar `/etc/nginx/sites-available/supabase-baas`
2. Substituir `yourdomain.com` pelo seu domínio
3. Recarregar Nginx: `sudo systemctl reload nginx`

### Configurar SSL

**Para desenvolvimento (auto-assinado):**
```bash
# Já configurado pelo install-multi-tenant.sh
ls /etc/ssl/supabase/
```

**Para produção (Let's Encrypt):**
```bash
# Instalar certbot
sudo apt install certbot python3-certbot-nginx

# Obter certificado wildcard
sudo certbot --nginx -d *.yourdomain.com
```

### Configurar DNS

Para cada subdomínio, criar registro DNS:
```
app-org123.yourdomain.com  IN  A  SEU_IP_SERVIDOR
```

Ou usar wildcard:
```
*.yourdomain.com  IN  A  SEU_IP_SERVIDOR
```

## 📊 Monitoramento

### Health Check das Instâncias

```bash
# Verificar todas as instâncias
supabase-routes health_check

# Verificar instância específica
curl -f http://127.0.0.1:PORTA/health
```

### Logs do Sistema

```bash
# Logs do Nginx
sudo tail -f /var/log/nginx/supabase-baas-access.log
sudo tail -f /var/log/nginx/supabase-baas-error.log

# Logs de uma instância específica
cd /opt/supabase-instances/{INSTANCE_ID}
docker compose logs -f
```

### Métricas das Instâncias

Cada instância expõe métricas em:
- Analytics: `https://subdomain.yourdomain.com/analytics`
- Health: `https://subdomain.yourdomain.com/health`

## 🔐 Segurança

### Isolamento por Instância

- **Banco de Dados**: PostgreSQL isolado por container
- **JWT Secrets**: Únicos por instância
- **Senhas**: Geradas aleatoriamente
- **Portas**: Ranges não conflitantes
- **Volumes**: Isolados por instância

### Rate Limiting

Configurado no Nginx:
- API geral: 30 req/min
- Autenticação: 5 req/min

### Headers de Segurança

- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Strict-Transport-Security

## 🐛 Troubleshooting

### Instância não responde

```bash
# Verificar status dos containers
cd /opt/supabase-instances/{INSTANCE_ID}
docker compose ps

# Verificar logs
docker compose logs

# Reiniciar instância
docker compose restart
```

### Erro de rota no Nginx

```bash
# Verificar rotas
supabase-routes list_routes

# Verificar configuração Nginx
sudo nginx -t

# Verificar logs do Nginx
sudo tail -f /var/log/nginx/supabase-baas-error.log
```

### Porta em uso

```bash
# Verificar portas em uso
netstat -tulpn | grep :PORTA

# Gerar nova instância (portas são dinâmicas)
./generate.bash --project="novo-nome" --org-id="123" --subdomain="novo-sub"
```

## 📚 Exemplos de Uso

### Cenário 1: SaaS com Múltiplos Clientes

```bash
# Cliente A
./generate.bash --project="crm" --org-id="cliente-a" --subdomain="crm-clientea"

# Cliente B  
./generate.bash --project="crm" --org-id="cliente-b" --subdomain="crm-clienteb"

# Acessos:
# https://crm-clientea.yourdomain.com
# https://crm-clienteb.yourdomain.com
```

### Cenário 2: Ambientes por Projeto

```bash
# Produção
./generate.bash --project="app" --org-id="123" --subdomain="app-prod"

# Staging
./generate.bash --project="app" --org-id="123" --subdomain="app-staging"

# Desenvolvimento
./generate.bash --project="app" --org-id="123" --subdomain="app-dev"
```

### Cenário 3: Multi-Regional

```bash
# Região US
./generate.bash --project="app" --org-id="123" --subdomain="us-app-org123"

# Região EU
./generate.bash --project="app" --org-id="123" --subdomain="eu-app-org123"
```

## 🤝 Contribuição

Para contribuir com melhorias:

1. Fork do repositório
2. Criar branch de feature
3. Fazer alterações
4. Testar com múltiplas instâncias
5. Submeter Pull Request

## 📄 Licença

Mesmo licenciamento do projeto Supabase original.