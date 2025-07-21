FROM node:18-alpine

# Instalar dependências do sistema
RUN apk add --no-cache \
    postgresql-client \
    curl

# Criar usuário não-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S billing -u 1001

# Diretório de trabalho
WORKDIR /app

# Copiar package.json e package-lock.json
COPY package*.json ./

# Instalar dependências
RUN npm ci --only=production && \
    npm cache clean --force

# Copiar código da aplicação
COPY --chown=billing:nodejs . .

# Mudar para usuário não-root
USER billing

# Expor porta
EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3002/health || exit 1

# Comando de início
CMD ["node", "server.js"]