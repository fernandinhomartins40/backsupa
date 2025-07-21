/**
 * Rotas principais da API
 */

const express = require('express');
const router = express.Router();

// Importar rotas específicas
const authRoutes = require('./auth');
const organizationRoutes = require('./organizations');
const projectRoutes = require('./projects');
const systemRoutes = require('./system');

// Middleware de logging para todas as rotas da API
router.use((req, res, next) => {
  const logger = require('../utils/logger');
  
  // Log da requisição
  logger.request(req);
  
  // Capturar tempo de resposta
  const startTime = Date.now();
  
  // Override do res.json para log da resposta
  const originalJson = res.json;
  res.json = function(data) {
    res.responseTime = Date.now() - startTime;
    logger.response(req, res);
    return originalJson.call(this, data);
  };
  
  next();
});

// Informações da API
router.get('/', (req, res) => {
  res.json({
    name: 'Supabase Multi-Tenant BaaS Control API',
    version: '1.0.0',
    description: 'API para gerenciamento de instâncias Supabase multi-tenant',
    endpoints: {
      auth: '/api/auth',
      organizations: '/api/organizations',
      projects: '/api/organizations/:orgId/projects',
      system: '/api/system'
    },
    documentation: '/api/docs',
    health: '/health',
    timestamp: new Date().toISOString()
  });
});

// Rotas de autenticação
router.use('/auth', authRoutes);

// Rotas de organizações
router.use('/organizations', organizationRoutes);

// Rotas de projetos (nested em organizações)
router.use('/organizations/:orgId/projects', projectRoutes);

// Rotas do sistema
router.use('/system', systemRoutes);

module.exports = router;