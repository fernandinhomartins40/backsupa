# Dockerfile para Supabase BaaS Control API

FROM node:20-alpine

# Instalar dependências do sistema
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    openssl \
    docker-cli \
    && rm -rf /var/cache/apk/*

# Criar usuário não-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Definir diretório de trabalho
WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências
RUN npm ci --only=production && npm cache clean --force

# Copiar código da aplicação
COPY . .

# Criar diretório de logs
RUN mkdir -p logs && chown -R nodejs:nodejs logs

# Mudar para usuário nodejs
USER nodejs

# Expor porta
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

# Comando para iniciar a aplicação
CMD ["node", "server.js"]