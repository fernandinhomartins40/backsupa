# Dockerfile para Supabase Custom Exporter
FROM python:3.11-slim

WORKDIR /app

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    curl \
    docker.io \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY exporter.py .
COPY metrics/ ./metrics/

# Criar usuário não-root
RUN groupadd -r exporter && useradd -r -g exporter exporter
RUN chown -R exporter:exporter /app
USER exporter

# Expor porta
EXPOSE 9200

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9200/health || exit 1

# Comando principal
CMD ["python", "exporter.py"]