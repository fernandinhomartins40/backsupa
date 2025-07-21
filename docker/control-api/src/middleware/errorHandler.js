/**
 * Middleware de tratamento de erros global
 */

const logger = require('../utils/logger');

/**
 * Middleware de tratamento de erros
 */
function errorHandler(err, req, res, next) {
  // Log do erro
  logger.error('Unhandled error:', {
    error: err.message,
    stack: err.stack,
    method: req.method,
    url: req.originalUrl,
    body: req.body,
    params: req.params,
    query: req.query,
    user: req.user?.id,
    requestId: req.requestId
  });
  
  // Erro de validação
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: err.details || err.message,
      requestId: req.requestId
    });
  }
  
  // Erro de banco de dados
  if (err.code && err.code.startsWith('23')) { // PostgreSQL constraint errors
    if (err.code === '23505') { // unique_violation
      return res.status(409).json({
        error: 'Resource already exists',
        code: 'DUPLICATE_RESOURCE',
        requestId: req.requestId
      });
    }
    
    if (err.code === '23503') { // foreign_key_violation
      return res.status(400).json({
        error: 'Invalid reference',
        code: 'INVALID_REFERENCE',
        requestId: req.requestId
      });
    }
    
    if (err.code === '23502') { // not_null_violation
      return res.status(400).json({
        error: 'Required field missing',
        code: 'REQUIRED_FIELD',
        requestId: req.requestId
      });
    }
  }
  
  // Erro de JWT
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      error: 'Invalid token',
      code: 'INVALID_TOKEN',
      requestId: req.requestId
    });
  }
  
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      error: 'Token expired',
      code: 'TOKEN_EXPIRED',
      requestId: req.requestId
    });
  }
  
  // Erro de sintaxe JSON
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({
      error: 'Invalid JSON format',
      code: 'INVALID_JSON',
      requestId: req.requestId
    });
  }
  
  // Erro de rate limiting
  if (err.status === 429) {
    return res.status(429).json({
      error: 'Too many requests',
      code: 'RATE_LIMIT_EXCEEDED',
      retryAfter: err.retryAfter,
      requestId: req.requestId
    });
  }
  
  // Erro de timeout
  if (err.code === 'ETIMEDOUT' || err.timeout) {
    return res.status(408).json({
      error: 'Request timeout',
      code: 'TIMEOUT',
      requestId: req.requestId
    });
  }
  
  // Erro de conexão
  if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND') {
    return res.status(503).json({
      error: 'Service unavailable',
      code: 'SERVICE_UNAVAILABLE',
      requestId: req.requestId
    });
  }
  
  // Erro customizado da aplicação
  if (err.status || err.statusCode) {
    return res.status(err.status || err.statusCode).json({
      error: err.message || 'Application error',
      code: err.code || 'APPLICATION_ERROR',
      requestId: req.requestId
    });
  }
  
  // Erro interno do servidor (padrão)
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  return res.status(500).json({
    error: 'Internal server error',
    code: 'INTERNAL_ERROR',
    requestId: req.requestId,
    ...(isDevelopment && {
      details: err.message,
      stack: err.stack
    })
  });
}

/**
 * Middleware para 404 - Not Found
 */
function notFoundHandler(req, res) {
  logger.warn('Not found:', {
    method: req.method,
    url: req.originalUrl,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    requestId: req.requestId
  });
  
  res.status(404).json({
    error: 'Endpoint not found',
    code: 'NOT_FOUND',
    path: req.originalUrl,
    method: req.method,
    requestId: req.requestId
  });
}

/**
 * Wrapper para async functions
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Criar erro customizado
 */
function createError(message, status = 500, code = 'APPLICATION_ERROR') {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  return error;
}

module.exports = {
  errorHandler,
  notFoundHandler,
  asyncHandler,
  createError
};