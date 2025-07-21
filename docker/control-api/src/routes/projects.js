/**
 * Rotas de projetos
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router({ mergeParams: true });

const projectController = require('../controllers/projectController');
const { authenticateToken, requireOrgPermission, requireProjectPermission } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');

// Validações
const createProjectValidation = [
  body('name')
    .trim()
    .isLength({ min: 1, max: 255 })
    .withMessage('Project name is required and must be less than 255 characters')
    .matches(/^[a-zA-Z0-9\s\-_.]+$/)
    .withMessage('Project name contains invalid characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Description must be less than 1000 characters'),
  body('environment')
    .optional()
    .isIn(['production', 'staging', 'development'])
    .withMessage('Environment must be production, staging, or development')
];

const paramValidation = [
  param('orgId').isInt({ min: 1 }).withMessage('Organization ID must be a positive integer'),
  param('projectId').optional().isInt({ min: 1 }).withMessage('Project ID must be a positive integer')
];

// Middleware para validar dados
function validateRequest(req, res, next) {
  const { validationResult } = require('express-validator');
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: errors.array()
    });
  }
  
  next();
}

/**
 * @route POST /api/organizations/:orgId/projects
 * @desc Criar novo projeto
 * @access Private (Owner/Admin)
 */
router.post('/',
  paramValidation,
  createProjectValidation,
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner', 'admin']),
  asyncHandler(projectController.createProject)
);

/**
 * @route GET /api/organizations/:orgId/projects
 * @desc Listar projetos da organização
 * @access Private (Member+)
 */
router.get('/',
  paramValidation,
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner', 'admin', 'member']),
  asyncHandler(projectController.listProjects)
);

/**
 * @route GET /api/organizations/:orgId/projects/:projectId
 * @desc Obter detalhes de um projeto
 * @access Private (Member+)
 */
router.get('/:projectId',
  paramValidation,
  validateRequest,
  authenticateToken,
  requireProjectPermission(['owner', 'admin', 'member']),
  asyncHandler(projectController.getProject)
);

/**
 * @route GET /api/organizations/:orgId/projects/:projectId/status
 * @desc Verificar status de um projeto
 * @access Private (Member+)
 */
router.get('/:projectId/status',
  paramValidation,
  validateRequest,
  authenticateToken,
  requireProjectPermission(['owner', 'admin', 'member']),
  asyncHandler(projectController.getProjectStatus)
);

/**
 * @route DELETE /api/organizations/:orgId/projects/:projectId
 * @desc Deletar projeto
 * @access Private (Owner/Admin)
 */
router.delete('/:projectId',
  paramValidation,
  validateRequest,
  authenticateToken,
  requireProjectPermission(['owner', 'admin']),
  asyncHandler(projectController.deleteProject)
);

module.exports = router;