# Guia de Deploy - Supabase BaaS

## 🚀 Solução para o Erro de Deploy

O erro original ocorreu porque:
1. O diretório `/opt/backsupa` não existia na VPS
2. O comando `docker-compose` não estava disponível (versão antiga)
3. O repositório não estava clonado na VPS

## 📋 Passos para Corrigir o Deploy

### 1. Configuração Inicial da VPS (Executar uma única vez)

Conecte-se à sua VPS e execute:

```bash
# Como root, execute:
curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/scripts/deploy/first-time-setup.sh | bash
```

Este script irá:
- Instalar Docker e Docker Compose
- Criar a estrutura de diretórios correta (`/opt/supabase-baas`)
- Clonar o repositório
- Criar um arquivo `.env` básico
- Preparar tudo para o deploy

### 2. Configurar Secrets no GitHub

Vá para Settings > Secrets and variables > Actions no seu repositório e adicione:

- `VPS_PASSWORD`: Senha do usuário root da VPS (82.25.69.57)

### 3. Ajustar Configurações (Opcional)

Edite o arquivo `.env` criado na VPS:

```bash
cd /opt/supabase-baas
nano .env
```

Configure as senhas seguras e o domínio correto.

### 4. Deploy Automático

Após configurar o secret, qualquer push para a branch `main` irá:
- Conectar via SSH à VPS
- Atualizar o código
- Rebuildar e reiniciar os containers
- Verificar o status

### 5. Verificação Manual

Para verificar o deploy manualmente:

```bash
# Conectar na VPS
ssh root@82.25.69.57

# Verificar status
cd /opt/supabase-baas
docker compose ps

# Ver logs
docker compose logs --tail=50

# Ver página de status
curl http://localhost
```

## 🔧 Solução de Problemas

### Docker Compose não encontrado
O workflow agora usa `docker compose` (v2) e tem fallback para instalação automática.

### Diretório não encontrado
O workflow cria o diretório automaticamente se não existir.

### Repositório não é Git
O workflow clona o repositório automaticamente se necessário.

## 📊 Status do Deploy

Após a correção, o workflow irá:
1. ✅ Criar diretório automaticamente
2. ✅ Instalar Docker Compose se necessário
3. ✅ Clonar repositório se necessário
4. ✅ Atualizar código
5. ✅ Build e deploy dos containers
6. ✅ Verificar status e logs

## 📝 Notas Importantes

- O diretório correto agora é `/opt/supabase-baas` (não `/opt/backsupa`)
- O workflow usa `docker compose` (v2) em vez de `docker-compose` (v1)
- Certifique-se de configurar o secret `VPS_PASSWORD` no GitHub
- Execute o script de setup inicial antes do primeiro deploy
