# Guia de Deploy com MobaXterm para VPS Ubuntu 22.04 (Hostinger)

## Problemas Comuns e Soluções

### 1. Erro de Host SSH
**Mensagem:** `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`

**Solução no MobaXterm:**
```bash
# No terminal do MobaXterm, execute:
ssh-keygen -R 82.25.69.57
```

### 2. Erro de Permissão ou Conexão
**Verificações prévias:**
```bash
# Testar conexão SSH básica
ssh root@82.25.69.57

# Verificar se a porta 22 está aberta
telnet 82.25.69.57 22
```

## Instruções de Deploy para MobaXterm

### Método 1: Direto no Terminal (Recomendado)
1. **Abra o terminal do MobaXterm**
2. **Execute os comandos na ordem:**

```bash
# 1. Limpar chave SSH antiga
ssh-keygen -R 82.25.69.57

# 2. Conectar via SSH e executar script diretamente
ssh root@82.25.69.57 "curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh | bash"
```

### Método 2: Passo a Passo
```bash
# 1. Limpar chave SSH
ssh-keygen -R 82.25.69.57

# 2. Conectar na VPS
ssh root@82.25.69.57

# 3. Uma vez dentro da VPS, execute:
curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh | bash
```

### Método 3: Se o Método 1 falhar
```bash
# 1. Baixar script localmente
curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh -o install-vps.sh

# 2. Tornar executável
chmod +x install-vps.sh

# 3. Executar no servidor
scp install-vps.sh root@82.25.69.57:/tmp/
ssh root@82.25.69.57 "cd /tmp && chmod +x install-vps.sh && ./install-vps.sh"
```

## Verificação de Erros Comuns

### Verificar logs do SSH (na VPS)
```bash
# Dentro da VPS, verificar logs
sudo tail -f /var/log/auth.log

# Verificar se o SSH está rodando
sudo systemctl status ssh
```

### Verificar firewall
```bash
# Verificar regras do firewall
sudo ufw status
sudo iptables -L
```

### Verificar espaço em disco
```bash
df -h
```

## Credenciais Hostinger
Para VPS Hostinger Ubuntu 22.04:
- **Usuário padrão:** root
- **Senha:** Fornecida no email da Hostinger
- **Porta SSH:** 22 (padrão)

## Solução de Problemas

### Se continuar com erro de host:
```bash
# Remover completamente todas as chaves do host
rm ~/.ssh/known_hosts
# Ou edite manualmente:
nano ~/.ssh/known_hosts
```

### Se a conexão falhar:
1. **Verifique IP e credenciais** no painel da Hostinger
2. **Reinicie a VPS** pelo painel da Hostinger
3. **Verifique se a VPS está online:**
   ```bash
   ping 82.25.69.57
   ```

### Se o script falhar:
```bash
# Execute com debug
bash -x <(curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh)
```

## Comando Final Testado
```bash
# Use este comando completo no MobaXterm:
ssh-keygen -R 82.25.69.57 && ssh root@82.25.69.57 "curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh | bash"
