/**
 * Rotas do sistema
 */

const express = require('express');
const router = express.Router();

const { authenticateToken, requireOrgPermission } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const systemController = require('../controllers/systemController');

/**
 * @route GET /api/system/status
 * @desc Status detalhado do sistema
 * @access Private (Admin+)
 */
router.get('/status',
  authenticateToken,
  asyncHandler(systemController.getSystemStatus)
);

/**
 * @route GET /api/system/health
 * @desc Health check dos serviços
 * @access Private
 */
router.get('/health',
  authenticateToken,
  asyncHandler(systemController.getHealthCheck)
);

/**
 * @route GET /api/system/stats
 * @desc Estatísticas gerais do sistema
 * @access Private (Admin+)
 */
router.get('/stats',
  authenticateToken,
  asyncHandler(systemController.getSystemStats)
);

/**
 * @route GET /api/system/logs
 * @desc Logs do sistema
 * @access Private (Admin+)
 */
router.get('/logs',
  authenticateToken,
  asyncHandler(systemController.getSystemLogs)
);

module.exports = router;