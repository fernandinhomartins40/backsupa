# Guia de Deploy para Windows

## Problemas Identificados e Soluções

### 1. Erro de Host SSH
**Erro:** `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`

**Solução:** Execute este comando no PowerShell para remover a chave antiga:
```powershell
ssh-keygen -R 82.25.69.57
```

### 2. Erro do Comando curl
**Erro:** `Invoke-WebRequest : Não é possível localizar um parâmetro que coincida com o nome de parâmetro 'fsSL'`

**Solução:** No Windows PowerShell, use `Invoke-WebRequest` em vez de `curl`.

## Instruções de Deploy para Windows

### Opção 1: PowerShell (Recomendado)
```powershell
# 1. Limpar chave SSH antiga
ssh-keygen -R 82.25.69.57

# 2. Baixar script de instalação
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh" -OutFile "install-vps.sh"

# 3. Conectar via SSH e executar script
ssh root@82.25.69.57 "bash -s" < install-vps.sh
```

### Opção 2: Usando o arquivo fix-deploy-issues.sh
Execute o script criado:
```bash
bash fix-deploy-issues.sh
```

### Opção 3: Comando único
```powershell
ssh-keygen -R 82.25.69.57; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh" -OutFile "install-vps.sh"; ssh root@82.25.69.57 "bash -s" < install-vps.sh
```

## Verificação
Após executar os comandos acima, você deve conseguir:
1. Conectar via SSH sem erros de host
2. Executar o script de instalação remotamente

## Notas Importantes
- O comando `ssh-keygen -R` remove apenas a entrada específica do host
- O script `install-vps.sh` será executado automaticamente no servidor remoto
- Certifique-se de ter o OpenSSH instalado no Windows
