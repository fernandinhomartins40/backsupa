/**
 * Rotas de organizações
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const { authenticateToken, requireOrgPermission } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');
const logger = require('../utils/logger');

// Validações
const paramValidation = [
  param('orgId').isInt({ min: 1 }).withMessage('Organization ID must be a positive integer')
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
 * @route GET /api/organizations
 * @desc Listar organizações do usuário
 * @access Private
 */
router.get('/',
  authenticateToken,
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    
    const result = await query(`
      SELECT 
        o.id,
        o.name,
        o.slug,
        o.logo_url,
        o.billing_plan,
        o.status,
        o.created_at,
        uo.role,
        uo.joined_at,
        COUNT(p.id) as project_count
      FROM organizations o
      JOIN user_organizations uo ON uo.organization_id = o.id
      LEFT JOIN projects p ON p.organization_id = o.id AND p.deleted_at IS NULL
      WHERE uo.user_id = $1 AND uo.status = 'active' AND o.status = 'active'
      GROUP BY o.id, uo.role, uo.joined_at
      ORDER BY uo.joined_at DESC
    `, [userId]);
    
    res.json({
      success: true,
      organizations: result.rows
    });
  })
);

/**
 * @route GET /api/organizations/:orgId
 * @desc Obter detalhes de uma organização
 * @access Private (Member+)
 */
router.get('/:orgId',
  paramValidation,
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner', 'admin', 'member']),
  asyncHandler(async (req, res) => {
    const { orgId } = req.params;
    
    // Buscar dados da organização
    const orgResult = await query(`
      SELECT 
        o.*,
        COUNT(DISTINCT p.id) as project_count,
        COUNT(DISTINCT uo.user_id) as member_count
      FROM organizations o
      LEFT JOIN projects p ON p.organization_id = o.id AND p.deleted_at IS NULL
      LEFT JOIN user_organizations uo ON uo.organization_id = o.id AND uo.status = 'active'
      WHERE o.id = $1
      GROUP BY o.id
    `, [orgId]);
    
    if (orgResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Organization not found',
        code: 'ORG_NOT_FOUND'
      });
    }
    
    const organization = orgResult.rows[0];
    
    // Buscar membros se for admin/owner
    let members = [];
    if (['owner', 'admin'].includes(req.orgRole)) {
      const membersResult = await query(`
        SELECT 
          u.id,
          u.email,
          u.first_name,
          u.last_name,
          u.avatar_url,
          uo.role,
          uo.joined_at
        FROM users u
        JOIN user_organizations uo ON uo.user_id = u.id
        WHERE uo.organization_id = $1 AND uo.status = 'active'
        ORDER BY uo.joined_at ASC
      `, [orgId]);
      
      members = membersResult.rows;
    }
    
    res.json({
      success: true,
      organization,
      members: members.length > 0 ? members : undefined,
      user_role: req.orgRole
    });
  })
);

/**
 * @route PUT /api/organizations/:orgId
 * @desc Atualizar organização
 * @access Private (Owner/Admin)
 */
router.put('/:orgId',
  paramValidation,
  [
    body('name').optional().trim().isLength({ min: 1, max: 255 }),
    body('logoUrl').optional().isURL(),
    body('domain').optional().isFQDN()
  ],
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner', 'admin']),
  asyncHandler(async (req, res) => {
    const { orgId } = req.params;
    const { name, logoUrl, domain } = req.body;
    const userId = req.user.id;
    
    const result = await query(`
      UPDATE organizations 
      SET 
        name = COALESCE($1, name),
        logo_url = COALESCE($2, logo_url),
        domain = COALESCE($3, domain),
        updated_at = NOW()
      WHERE id = $4
      RETURNING *
    `, [name, logoUrl, domain, orgId]);
    
    logger.audit('organization_updated', {
      organizationId: orgId,
      changes: { name, logoUrl, domain }
    }, userId);
    
    res.json({
      success: true,
      organization: result.rows[0]
    });
  })
);

/**
 * @route GET /api/organizations/:orgId/members
 * @desc Listar membros da organização
 * @access Private (Owner/Admin)
 */
router.get('/:orgId/members',
  paramValidation,
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner', 'admin']),
  asyncHandler(async (req, res) => {
    const { orgId } = req.params;
    
    const result = await query(`
      SELECT 
        u.id,
        u.email,
        u.first_name,
        u.last_name,
        u.avatar_url,
        u.last_sign_in_at,
        uo.role,
        uo.joined_at,
        uo.status,
        invited_by_user.first_name || ' ' || invited_by_user.last_name as invited_by_name
      FROM users u
      JOIN user_organizations uo ON uo.user_id = u.id
      LEFT JOIN users invited_by_user ON invited_by_user.id = uo.invited_by
      WHERE uo.organization_id = $1
      ORDER BY uo.joined_at ASC
    `, [orgId]);
    
    res.json({
      success: true,
      members: result.rows
    });
  })
);

/**
 * @route POST /api/organizations/:orgId/members
 * @desc Convidar novo membro
 * @access Private (Owner/Admin)
 */
router.post('/:orgId/members',
  paramValidation,
  [
    body('email').isEmail().normalizeEmail(),
    body('role').isIn(['member', 'admin']).withMessage('Role must be member or admin')
  ],
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner', 'admin']),
  asyncHandler(async (req, res) => {
    const { orgId } = req.params;
    const { email, role } = req.body;
    const userId = req.user.id;
    
    // Verificar se usuário existe
    const userResult = await query(
      'SELECT id, email, first_name, last_name FROM users WHERE email = $1',
      [email]
    );
    
    if (userResult.rows.length === 0) {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }
    
    const invitedUser = userResult.rows[0];
    
    // Verificar se já é membro
    const existingResult = await query(
      'SELECT id FROM user_organizations WHERE user_id = $1 AND organization_id = $2',
      [invitedUser.id, orgId]
    );
    
    if (existingResult.rows.length > 0) {
      return res.status(409).json({
        error: 'User is already a member',
        code: 'USER_ALREADY_MEMBER'
      });
    }
    
    // Adicionar membro
    await query(`
      INSERT INTO user_organizations (user_id, organization_id, role, invited_by, status)
      VALUES ($1, $2, $3, $4, 'active')
    `, [invitedUser.id, orgId, role, userId]);
    
    logger.audit('member_invited', {
      organizationId: orgId,
      invitedUserId: invitedUser.id,
      invitedEmail: email,
      role
    }, userId);
    
    res.status(201).json({
      success: true,
      message: 'Member added successfully',
      member: {
        id: invitedUser.id,
        email: invitedUser.email,
        first_name: invitedUser.first_name,
        last_name: invitedUser.last_name,
        role
      }
    });
  })
);

/**
 * @route PUT /api/organizations/:orgId/members/:memberId
 * @desc Atualizar role do membro
 * @access Private (Owner)
 */
router.put('/:orgId/members/:memberId',
  [
    param('orgId').isInt({ min: 1 }),
    param('memberId').isInt({ min: 1 }),
    body('role').isIn(['member', 'admin', 'owner'])
  ],
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner']),
  asyncHandler(async (req, res) => {
    const { orgId, memberId } = req.params;
    const { role } = req.body;
    const userId = req.user.id;
    
    // Não pode alterar próprio role
    if (userId === parseInt(memberId)) {
      return res.status(400).json({
        error: 'Cannot change your own role',
        code: 'CANNOT_CHANGE_OWN_ROLE'
      });
    }
    
    await query(`
      UPDATE user_organizations 
      SET role = $1, updated_at = NOW()
      WHERE user_id = $2 AND organization_id = $3
    `, [role, memberId, orgId]);
    
    logger.audit('member_role_updated', {
      organizationId: orgId,
      targetUserId: memberId,
      newRole: role
    }, userId);
    
    res.json({
      success: true,
      message: 'Member role updated successfully'
    });
  })
);

/**
 * @route DELETE /api/organizations/:orgId/members/:memberId
 * @desc Remover membro
 * @access Private (Owner/Admin)
 */
router.delete('/:orgId/members/:memberId',
  [
    param('orgId').isInt({ min: 1 }),
    param('memberId').isInt({ min: 1 })
  ],
  validateRequest,
  authenticateToken,
  requireOrgPermission(['owner', 'admin']),
  asyncHandler(async (req, res) => {
    const { orgId, memberId } = req.params;
    const userId = req.user.id;
    
    // Não pode remover a si mesmo
    if (userId === parseInt(memberId)) {
      return res.status(400).json({
        error: 'Cannot remove yourself',
        code: 'CANNOT_REMOVE_SELF'
      });
    }
    
    await query(`
      UPDATE user_organizations 
      SET status = 'removed', updated_at = NOW()
      WHERE user_id = $1 AND organization_id = $2
    `, [memberId, orgId]);
    
    logger.audit('member_removed', {
      organizationId: orgId,
      removedUserId: memberId
    }, userId);
    
    res.json({
      success: true,
      message: 'Member removed successfully'
    });
  })
);

module.exports = router;