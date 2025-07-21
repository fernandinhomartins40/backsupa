# Deploy Automático via GitHub Actions

## Configuração Simples

### 1. Preparar a VPS (apenas uma vez)

Conecte-se à VPS via SSH e execute:

```bash
# Conectar na VPS
ssh root@82.25.69.57

# Instalar git se não estiver instalado
apt update && apt install -y git

# Criar diretório e clonar repositório
mkdir -p /opt/backsupa
cd /opt/backsupa
git clone https://github.com/fernandinhomartins40/backsupa.git .

# Ou usar o script de setup
chmod +x scripts/setup-vps-repo.sh
./scripts/setup-vps-repo.sh
```

### 2. Verificar Configuração

O workflow já está criado em `.github/workflows/deploy.yml` e usará automaticamente a secret `VPS_PASSWORD` que já existe no repositório.

### 3. Ativar Deploy

O deploy automático será ativado quando:
- Você fizer push para a branch `main`
- Ou manualmente via GitHub Actions > Deploy to VPS > Run workflow

### 4. Verificar Status do Deploy

Você pode acompanhar o progresso em:
- GitHub > Actions > Deploy to VPS

### 5. Verificar na VPS (opcional)

```bash
# Conectar na VPS
ssh root@82.25.69.57

# Verificar status
cd /opt/backsupa
docker-compose ps
docker-compose logs --tail=50
```

## Estrutura do Workflow

O workflow `.github/workflows/deploy.yml` faz:
1. Para os containers existentes
2. Atualiza o código via git pull
3. Reconstrói e reinicia os containers
4. Mostra o status final

## Requisitos

- VPS Ubuntu 22.04 com Docker e Docker Compose instalados
- Git configurado
- Secret `VPS_PASSWORD` já criada no GitHub
- Repositório clonado em `/opt/backsupa`

## Solução de Problemas

Se o deploy falhar:
1. Verifique os logs no GitHub Actions
2. Conecte na VPS e verifique manualmente
3. Certifique-se de que o diretório `/opt/backsupa` existe e tem as permissões corretas
