/**
 * Sistema de logging usando Winston
 */

const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');
const fs = require('fs');

// Configurações
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const LOG_DIR = process.env.LOG_DIR || './logs';
const NODE_ENV = process.env.NODE_ENV || 'development';

// Criar diretório de logs se não existir
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

// Formato personalizado
const customFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss'
  }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ level, message, timestamp, stack, ...meta }) => {
    let log = `${timestamp} [${level.toUpperCase()}]: ${message}`;
    
    // Adicionar metadados se existirem
    if (Object.keys(meta).length > 0) {
      log += ` ${JSON.stringify(meta)}`;
    }
    
    // Adicionar stack trace para erros
    if (stack) {
      log += `\n${stack}`;
    }
    
    return log;
  })
);

// Formato para console (colorido em desenvolvimento)
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({
    format: 'HH:mm:ss'
  }),
  winston.format.printf(({ level, message, timestamp, ...meta }) => {
    let log = `${timestamp} ${level}: ${message}`;
    
    if (Object.keys(meta).length > 0) {
      log += ` ${JSON.stringify(meta, null, 2)}`;
    }
    
    return log;
  })
);

// Configurar transports
const transports = [];

// Console transport
transports.push(
  new winston.transports.Console({
    level: NODE_ENV === 'production' ? 'info' : 'debug',
    format: NODE_ENV === 'production' ? customFormat : consoleFormat,
    handleExceptions: true,
    handleRejections: true
  })
);

// File transports para produção
if (NODE_ENV === 'production') {
  // Log combinado (todos os logs)
  transports.push(
    new DailyRotateFile({
      filename: path.join(LOG_DIR, 'combined-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: process.env.LOG_MAX_SIZE || '20m',
      maxFiles: process.env.LOG_MAX_FILES || '30d',
      format: customFormat,
      level: LOG_LEVEL
    })
  );
  
  // Log de erros separado
  transports.push(
    new DailyRotateFile({
      filename: path.join(LOG_DIR, 'error-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: process.env.LOG_MAX_SIZE || '20m',
      maxFiles: process.env.LOG_MAX_FILES || '30d',
      format: customFormat,
      level: 'error'
    })
  );
  
  // Log de sistema (info level)
  transports.push(
    new DailyRotateFile({
      filename: path.join(LOG_DIR, 'system-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: process.env.LOG_MAX_SIZE || '20m',
      maxFiles: process.env.LOG_MAX_FILES || '30d',
      format: customFormat,
      level: 'info'
    })
  );
}

// Criar logger
const logger = winston.createLogger({
  level: LOG_LEVEL,
  format: customFormat,
  transports,
  exitOnError: false,
  handleExceptions: true,
  handleRejections: true
});

// Adicionar métodos de conveniência
logger.request = (req, message = 'Request') => {
  logger.info(message, {
    method: req.method,
    url: req.originalUrl,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    requestId: req.requestId
  });
};

logger.response = (req, res, message = 'Response') => {
  logger.info(message, {
    method: req.method,
    url: req.originalUrl,
    statusCode: res.statusCode,
    responseTime: res.responseTime,
    requestId: req.requestId
  });
};

logger.error = (message, error) => {
  if (error instanceof Error) {
    winston.loggers.get('default').error(message, {
      error: error.message,
      stack: error.stack,
      ...error
    });
  } else if (typeof error === 'object') {
    winston.loggers.get('default').error(message, error);
  } else {
    winston.loggers.get('default').error(message, { details: error });
  }
};

logger.audit = (action, details, userId = null, projectId = null) => {
  logger.info('AUDIT', {
    action,
    userId,
    projectId,
    timestamp: new Date().toISOString(),
    ...details
  });
};

logger.security = (event, details, req = null) => {
  const logData = {
    event,
    timestamp: new Date().toISOString(),
    ...details
  };
  
  if (req) {
    logData.ip = req.ip;
    logData.userAgent = req.get('User-Agent');
    logData.requestId = req.requestId;
  }
  
  logger.warn('SECURITY', logData);
};

logger.performance = (operation, duration, details = {}) => {
  logger.info('PERFORMANCE', {
    operation,
    duration: `${duration}ms`,
    timestamp: new Date().toISOString(),
    ...details
  });
};

module.exports = logger;