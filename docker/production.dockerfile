# Multi-stage build para produção otimizada
FROM node:20-alpine AS base
WORKDIR /app

# Instalar dependências do sistema
RUN apk add --no-cache \
    libc6-compat \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# Stage 1: Dependencies
FROM base AS deps
COPY package*.json ./
RUN npm ci --production --silent

# Stage 2: Build
FROM base AS builder
COPY package*.json ./
RUN npm ci --silent

COPY . .
RUN npm run build

# Stage 3: Production
FROM node:20-alpine AS production

# Criar usuário não-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S supabase -u 1001

WORKDIR /app

# Copiar node_modules das dependências
COPY --from=deps --chown=supabase:nodejs /app/node_modules ./node_modules

# Copiar aplicação buildada
COPY --from=builder --chown=supabase:nodejs /app/.next ./.next
COPY --from=builder --chown=supabase:nodejs /app/public ./public
COPY --from=builder --chown=supabase:nodejs /app/package*.json ./
COPY --from=builder --chown=supabase:nodejs /app/next.config.js ./

# Adicionar healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

USER supabase

EXPOSE 3000

ENV NODE_ENV=production
ENV PORT=3000

CMD ["npm", "start"]