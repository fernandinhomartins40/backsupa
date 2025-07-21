# 🚀 Deploy Supabase BaaS Multi-Tenant - VPS 82.25.69.57

## 📋 Resumo do Deploy

Sistema **BaaS Multi-Tenant** baseado no Supabase, pronto para produção na VPS com IP `82.25.69.57`.

## 🎯 O que foi criado

### Scripts de Deploy
- **`deploy-vps.sh`** - Script completo de auto-hospedagem
- **`install-vps.sh`** - Script simplificado de instalação
- **`GUIA-DEPLOY-VPS.md`** - Guia completo passo a passo

### Arquitetura Implementada
- ✅ **Multi-tenancy completo** com isolamento por instância
- ✅ **Proxy reverso Nginx** com roteamento dinâmico via Lua
- ✅ **SSL/TLS automático** com Let's Encrypt
- ✅ **Monitoramento** Prometheus + Grafana
- ✅ **Backup automático** diário
- ✅ **Firewall UFW** configurado
- ✅ **Instância demo** pré-configurada

## 🚀 Como fazer o deploy

### Opção 1: Comando único (Recomendado)
```bash
ssh root@82.25.69.57
curl -fsSL https://raw.githubusercontent.com/fernandinhomartins40/backsupa/main/install-vps.sh | bash
```

### Opção 2: Passo a passo
```bash
ssh root@82.25.69.57
git clone https://github.com/fernandinhomartins40/backsupa.git
cd backsupa
chmod +x deploy-vps.sh
./deploy-vps.sh
```

## 🌐 Acessos após o deploy

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| **Demo** | `https://demo.82.25.69.57.sslip.io` | - |
| **Grafana** | `https://82.25.69.57.sslip.io:3004` | admin/admin |
| **API Control** | `https://82.25.69.57.sslip.io:3000` | - |

## 🎯 Comandos principais

### Criar nova instância
```bash
supabase-create --project="meu-app" --org-id="empresa1" --subdomain="app-empresa1"
```

### Gerenciar instâncias
```bash
# Listar todas
supabase-routes list_routes

# Verificar saúde
supabase-routes health_check

# Ver logs
cd /opt/supabase-baas/instances/app-empresa1 && docker-compose logs -f
```

## 📊 Monitoramento

### Health Checks
```bash
# Verificar todas as instâncias
curl https://82.25.69.57.sslip.io/api/system/status

# Verificar específica
curl https://app-empresa1.82.25.69.57.sslip.io/health
```

### Logs do sistema
```bash
# Logs de deploy
tail -f /var/log/supabase-baas-deploy.log

# Logs de backup
tail -f /opt/supabase-baas/logs/health.log
```

## 💾 Backup

### Backup automático
- **Local**: `/opt/supabase-baas/backups/`
- **Frequência**: Diariamente às 2h
- **Retenção**: 7 dias

### Backup manual
```bash
/opt/supabase-baas/scripts/backup.sh
```

## 🔧 Manutenção

### Atualizar sistema
```bash
# Atualizar código
cd /opt/supabase-baas
git pull origin main

# Reiniciar serviços
systemctl restart supabase-baas
```

### Verificar status
```bash
systemctl status supabase-baas
docker ps
```

## 🐛 Troubleshooting

### Problemas comuns

1. **Porta já em uso**
   ```bash
   netstat -tulpn | grep :3000
   ```

2. **SSL expirado**
   ```bash
   certbot renew --force-renewal
   ```

3. **Nginx não inicia**
   ```bash
   nginx -t
   systemctl restart nginx
   ```

4. **Docker não inicia**
   ```bash
   systemctl restart docker
   ```

## 📞 Suporte

Em caso de problemas:
1. Verificar logs: `tail -f /var/log/supabase-baas-deploy.log`
2. Verificar status: `systemctl status supabase-baas`
3. Verificar portas: `netstat -tulpn`

## 🎯 Próximos passos

1. **Criar sua primeira instância** com seu próprio subdomínio
2. **Configurar domínio personalizado** (se desejar)
3. **Adicionar templates** ao marketplace
4. **Configurar alertas** de monitoramento
5. **Testar APIs** e integrações

## 📋 Checklist de verificação

Após o deploy, verifique:
- [ ] Acesso ao demo: `https://demo.82.25.69.57.sslip.io`
- [ ] Grafana funcionando: `https://82.25.69.57.sslip.io:3004`
- [ ] SSL válido (cadeado verde)
- [ ] Firewall ativo: `ufw status`
- [ ] Backup configurado: `ls /opt/supabase-baas/backups/`
- [ ] Instância demo criada: `supabase-routes list_routes`

---

**Deploy concluído!** 🎉
Seu sistema BaaS Multi-Tenant está pronto para uso.
