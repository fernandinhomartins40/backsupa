/**
 * Middleware de autenticação JWT
 */

const jwt = require('jsonwebtoken');
const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * Middleware para verificar JWT
 */
async function authenticateToken(req, res, next) {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
      logger.security('Missing JWT token', {}, req);
      return res.status(401).json({
        error: 'Access token required',
        code: 'MISSING_TOKEN'
      });
    }
    
    // Verificar token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Buscar usuário no banco
    const result = await query(
      'SELECT id, email, first_name, last_name, status FROM users WHERE id = $1 AND status = $2',
      [decoded.userId, 'active']
    );
    
    if (result.rows.length === 0) {
      logger.security('Invalid user in JWT', { userId: decoded.userId }, req);
      return res.status(401).json({
        error: 'Invalid token',
        code: 'INVALID_TOKEN'
      });
    }
    
    req.user = result.rows[0];
    req.tokenExp = decoded.exp;
    
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      logger.security('Invalid JWT token', { error: error.message }, req);
      return res.status(401).json({
        error: 'Invalid token',
        code: 'INVALID_TOKEN'
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      logger.security('Expired JWT token', {}, req);
      return res.status(401).json({
        error: 'Token expired',
        code: 'TOKEN_EXPIRED'
      });
    }
    
    logger.error('Auth middleware error:', error);
    return res.status(500).json({
      error: 'Authentication error',
      code: 'AUTH_ERROR'
    });
  }
}

/**
 * Middleware para verificar permissões da organização
 */
function requireOrgPermission(requiredRoles = ['owner', 'admin']) {
  return async (req, res, next) => {
    try {
      const { orgId } = req.params;
      const userId = req.user.id;
      
      if (!orgId) {
        return res.status(400).json({
          error: 'Organization ID required',
          code: 'MISSING_ORG_ID'
        });
      }
      
      // Verificar permissão na organização
      const result = await query(`
        SELECT uo.role, o.name as org_name 
        FROM user_organizations uo
        JOIN organizations o ON o.id = uo.organization_id
        WHERE uo.user_id = $1 AND uo.organization_id = $2 AND uo.status = 'active'
      `, [userId, orgId]);
      
      if (result.rows.length === 0) {
        logger.security('Access denied to organization', {
          userId,
          orgId,
          requiredRoles
        }, req);
        
        return res.status(403).json({
          error: 'Access denied to organization',
          code: 'ORG_ACCESS_DENIED'
        });
      }
      
      const userRole = result.rows[0].role;
      
      if (!requiredRoles.includes(userRole)) {
        logger.security('Insufficient organization permissions', {
          userId,
          orgId,
          userRole,
          requiredRoles
        }, req);
        
        return res.status(403).json({
          error: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS',
          required: requiredRoles,
          current: userRole
        });
      }
      
      req.orgRole = userRole;
      req.orgName = result.rows[0].org_name;
      
      next();
    } catch (error) {
      logger.error('Organization permission check error:', error);
      return res.status(500).json({
        error: 'Permission check failed',
        code: 'PERMISSION_CHECK_ERROR'
      });
    }
  };
}

/**
 * Middleware para verificar permissões do projeto
 */
function requireProjectPermission(requiredRoles = ['owner', 'admin']) {
  return async (req, res, next) => {
    try {
      const { projectId } = req.params;
      const userId = req.user.id;
      
      if (!projectId) {
        return res.status(400).json({
          error: 'Project ID required',
          code: 'MISSING_PROJECT_ID'
        });
      }
      
      // Verificar permissão no projeto via organização
      const result = await query(`
        SELECT uo.role, p.name as project_name, p.organization_id, o.name as org_name
        FROM projects p
        JOIN organizations o ON o.id = p.organization_id
        JOIN user_organizations uo ON uo.organization_id = p.organization_id
        WHERE p.id = $1 AND uo.user_id = $2 AND uo.status = 'active' AND p.deleted_at IS NULL
      `, [projectId, userId]);
      
      if (result.rows.length === 0) {
        logger.security('Access denied to project', {
          userId,
          projectId,
          requiredRoles
        }, req);
        
        return res.status(403).json({
          error: 'Access denied to project',
          code: 'PROJECT_ACCESS_DENIED'
        });
      }
      
      const userRole = result.rows[0].role;
      
      if (!requiredRoles.includes(userRole)) {
        logger.security('Insufficient project permissions', {
          userId,
          projectId,
          userRole,
          requiredRoles
        }, req);
        
        return res.status(403).json({
          error: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS',
          required: requiredRoles,
          current: userRole
        });
      }
      
      req.projectRole = userRole;
      req.projectName = result.rows[0].project_name;
      req.projectOrgId = result.rows[0].organization_id;
      req.orgName = result.rows[0].org_name;
      
      next();
    } catch (error) {
      logger.error('Project permission check error:', error);
      return res.status(500).json({
        error: 'Permission check failed',
        code: 'PERMISSION_CHECK_ERROR'
      });
    }
  };
}

/**
 * Middleware opcional de autenticação (para endpoints públicos com dados opcionais)
 */
async function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
      return next();
    }
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const result = await query(
      'SELECT id, email, first_name, last_name, status FROM users WHERE id = $1 AND status = $2',
      [decoded.userId, 'active']
    );
    
    if (result.rows.length > 0) {
      req.user = result.rows[0];
      req.tokenExp = decoded.exp;
    }
    
    next();
  } catch (error) {
    // Ignorar erros de token em auth opcional
    next();
  }
}

module.exports = {
  authenticateToken,
  requireOrgPermission,
  requireProjectPermission,
  optionalAuth
};