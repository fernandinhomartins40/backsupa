/**
 * Supabase Multi-Tenant BaaS - Control API
 * 
 * Esta API gerencia instâncias Supabase sem modificar o Studio/UI existente.
 * Porta: 3001 (não conflita com Studio)
 */

require('dotenv').config();
require('express-async-errors');

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

// Importar módulos locais (com fallbacks)
const logger = console; // Fallback para console se logger não existir
// const { connectDB, closeDB } = require('./src/config/database'); // Comentado temporariamente
const routes = require('./src/routes');

// Configurações
const PORT = process.env.PORT || 3001;
const HOST = process.env.HOST || '0.0.0.0';
const NODE_ENV = process.env.NODE_ENV || 'development';

// Criar app Express
const app = express();

// ===============================================
// MIDDLEWARE DE SEGURANÇA
// ===============================================

// Helmet para headers de segurança
app.use(helmet({
  contentSecurityPolicy: false, // Desabilitar CSP para APIs
  crossOriginEmbedderPolicy: false
}));

// CORS
const corsOptions = {
  origin: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : '*',
  credentials: true,
  optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

// Compression
app.use(compression());

// Rate limiting geral
const generalLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutos
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', generalLimiter);

// Rate limiting para autenticação
const authLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_AUTH_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_AUTH_MAX_REQUESTS) || 5,
  message: {
    error: 'Too many authentication attempts, please try again later.',
    retryAfter: '15 minutes'
  },
  skipSuccessfulRequests: true,
});
app.use('/api/auth/', authLimiter);

// ===============================================
// MIDDLEWARE DE PARSING E LOGGING
// ===============================================

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging HTTP
if (NODE_ENV === 'production') {
  app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
} else {
  app.use(morgan('dev'));
}

// Trust proxy se necessário
if (process.env.TRUST_PROXY === 'true') {
  app.set('trust proxy', 1);
}

// ===============================================
// HEALTH CHECK E MÉTRICAS
// ===============================================

// Health check básico
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: NODE_ENV,
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Status detalhado do sistema
app.get('/api/system/status', (req, res) => {
  res.json({
    success: true,
    status: 'operational',
    timestamp: new Date().toISOString(),
    services: {
      api: 'healthy',
      database: 'unknown',
      storage: 'unknown'
    }
  });
});

// Métricas básicas
app.get('/metrics', (req, res) => {
  if (process.env.ENABLE_METRICS !== 'true') {
    return res.status(404).json({ error: 'Metrics disabled' });
  }
  
  res.json({
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    timestamp: new Date().toISOString()
  });
});

// ===============================================
// ROTAS PRINCIPAIS
// ===============================================

// Middleware para adicionar request ID
app.use((req, res, next) => {
  req.requestId = require('uuid').v4();
  res.setHeader('X-Request-ID', req.requestId);
  next();
});

// Rotas da API
app.use('/api', routes);

// Rota de fallback para 404
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    method: req.method,
    timestamp: new Date().toISOString()
  });
});

// ===============================================
// ERROR HANDLING
// ===============================================

// Middleware de tratamento de erros
app.use((error, req, res, next) => {
  console.error('API Error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : undefined
  });
});

// ===============================================
// GRACEFUL SHUTDOWN
// ===============================================

let server;

async function startServer() {
  try {
    // Conectar ao banco de dados (skip por agora)
    // await connectDB();
    console.log('Database connection skipped for demo');
    
    // Iniciar servidor
    server = app.listen(PORT, HOST, () => {
      console.log(`🚀 Supabase BaaS Control API running on http://${HOST}:${PORT}`);
      console.log(`📊 Environment: ${NODE_ENV}`);
      console.log(`🔒 CORS origins: ${corsOptions.origin}`);
      console.log(`📝 Log level: ${process.env.LOG_LEVEL || 'info'}`);
    });
    
    // Configurar timeout do servidor
    server.timeout = 30000; // 30 segundos
    
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

async function gracefulShutdown(signal) {
  console.log(`Received ${signal}. Starting graceful shutdown...`);
  
  if (server) {
    server.close(async () => {
      logger.info('HTTP server closed');
      
      try {
        await closeDB();
        logger.info('Database connections closed');
        
        logger.info('Graceful shutdown completed');
        process.exit(0);
      } catch (error) {
        logger.error('Error during shutdown:', error);
        process.exit(1);
      }
    });
    
    // Force close after 10 seconds
    setTimeout(() => {
      logger.error('Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000);
  } else {
    process.exit(0);
  }
}

// Event listeners para graceful shutdown
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

// Iniciar servidor
if (require.main === module) {
  startServer();
}

module.exports = app;