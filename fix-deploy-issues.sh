#!/bin/bash
# Script para corrigir problemas de deploy

echo "=== Corrigindo problemas de deploy ==="

# 1. Corrigir o erro de host SSH
echo "Para corrigir o erro de host SSH, execute no PowerShell:"
echo "ssh-keygen -R 82.25.69.57"
echo ""

# 2. Comando correto para Windows PowerShell
echo "Comando correto para Windows PowerShell:"
echo 'Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh" -OutFile "install-vps.sh"; bash install-vps.sh'
echo ""

# 3. Comando alternativo usando WSL ou Git Bash
echo "Se estiver usando WSL ou Git Bash:"
echo "curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh | bash"
echo ""

# 4. Comando para limpar known_hosts
echo "Para limpar o known_hosts manualmente:"
echo "Remove-Item -Path '$env:USERPROFILE\.ssh\known_hosts' -Force"
echo ""

# 5. Script completo para Windows
echo "=== Script completo para Windows ==="
cat > deploy-windows.ps1 << 'EOF'
# Script de deploy para Windows PowerShell

# Limpar chave do host
ssh-keygen -R 82.25.69.57

# Baixar e executar script de instalação
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh" -OutFile "install-vps.sh"

# Conectar via SSH e executar script
ssh root@82.25.69.57 "bash -s" < install-vps.sh
EOF

echo "Script 'deploy-windows.ps1' criado!"
echo "Execute: .\deploy-windows.ps1"
