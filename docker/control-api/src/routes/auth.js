/**
 * Rotas de autenticação
 */

const express = require('express');
const { body } = require('express-validator');
const router = express.Router();

const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');

// Validações
const loginValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  body('password')
    .isLength({ min: 1 })
    .withMessage('Password is required')
];

const registerValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters'),
  body('firstName')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('First name is required and must be less than 100 characters'),
  body('lastName')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Last name is required and must be less than 100 characters')
];

const changePasswordValidation = [
  body('currentPassword')
    .isLength({ min: 1 })
    .withMessage('Current password is required'),
  body('newPassword')
    .isLength({ min: 8 })
    .withMessage('New password must be at least 8 characters')
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
 * @route POST /api/auth/login
 * @desc Login do usuário
 * @access Public
 */
router.post('/login', 
  loginValidation,
  validateRequest,
  asyncHandler(authController.login)
);

/**
 * @route POST /api/auth/register
 * @desc Registro de novo usuário
 * @access Public
 */
router.post('/register',
  registerValidation,
  validateRequest,
  asyncHandler(authController.register)
);

/**
 * @route POST /api/auth/refresh
 * @desc Renovar access token
 * @access Public
 */
router.post('/refresh',
  body('refresh_token').isLength({ min: 1 }).withMessage('Refresh token is required'),
  validateRequest,
  asyncHandler(authController.refreshToken)
);

/**
 * @route POST /api/auth/logout
 * @desc Logout do usuário
 * @access Private
 */
router.post('/logout',
  authenticateToken,
  asyncHandler(authController.logout)
);

/**
 * @route GET /api/auth/profile
 * @desc Obter perfil do usuário logado
 * @access Private
 */
router.get('/profile',
  authenticateToken,
  asyncHandler(authController.getProfile)
);

/**
 * @route PUT /api/auth/profile
 * @desc Atualizar perfil do usuário
 * @access Private
 */
router.put('/profile',
  authenticateToken,
  [
    body('firstName').optional().trim().isLength({ max: 100 }),
    body('lastName').optional().trim().isLength({ max: 100 }),
    body('avatarUrl').optional().isURL()
  ],
  validateRequest,
  asyncHandler(authController.updateProfile)
);

/**
 * @route PUT /api/auth/password
 * @desc Alterar senha do usuário
 * @access Private
 */
router.put('/password',
  authenticateToken,
  changePasswordValidation,
  validateRequest,
  asyncHandler(authController.changePassword)
);

module.exports = router;