/**
 * Controller para autenticação
 */

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { query, transaction } = require('../config/database');
const logger = require('../utils/logger');
const { createError } = require('../middleware/errorHandler');

/**
 * Login do usuário
 */
async function login(req, res) {
  try {
    const { email, password } = req.body;
    
    // Validações básicas
    if (!email || !password) {
      throw createError('Email and password are required', 400, 'VALIDATION_ERROR');
    }
    
    // Buscar usuário
    const result = await query(
      'SELECT id, email, encrypted_password, first_name, last_name, status FROM users WHERE email = $1',
      [email.toLowerCase()]
    );
    
    if (result.rows.length === 0) {
      logger.security('Login attempt with invalid email', { email }, req);
      throw createError('Invalid credentials', 401, 'INVALID_CREDENTIALS');
    }
    
    const user = result.rows[0];
    
    // Verificar se usuário está ativo
    if (user.status !== 'active') {
      logger.security('Login attempt with inactive user', { 
        userId: user.id, 
        status: user.status 
      }, req);
      throw createError('Account is not active', 401, 'ACCOUNT_INACTIVE');
    }
    
    // Verificar senha
    const isValidPassword = await bcrypt.compare(password, user.encrypted_password);
    
    if (!isValidPassword) {
      logger.security('Login attempt with invalid password', { 
        userId: user.id,
        email: user.email 
      }, req);
      throw createError('Invalid credentials', 401, 'INVALID_CREDENTIALS');
    }
    
    // Atualizar último login
    await query(
      'UPDATE users SET last_sign_in_at = NOW() WHERE id = $1',
      [user.id]
    );
    
    // Gerar tokens JWT
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);
    
    logger.audit('user_login', {
      userId: user.id,
      email: user.email,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });
    
    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name
      },
      tokens: {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: process.env.JWT_EXPIRES_IN || '24h'
      }
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Registro de novo usuário
 */
async function register(req, res) {
  try {
    const { email, password, firstName, lastName } = req.body;
    
    // Validações
    if (!email || !password || !firstName || !lastName) {
      throw createError('All fields are required', 400, 'VALIDATION_ERROR');
    }
    
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw createError('Invalid email format', 400, 'INVALID_EMAIL');
    }
    
    if (password.length < 8) {
      throw createError('Password must be at least 8 characters', 400, 'WEAK_PASSWORD');
    }
    
    // Hash da senha
    const hashedPassword = await bcrypt.hash(password, parseInt(process.env.BCRYPT_ROUNDS) || 12);
    
    const result = await transaction(async (client) => {
      // Criar usuário
      const userResult = await client.query(`
        INSERT INTO users (email, encrypted_password, first_name, last_name, email_confirmed)
        VALUES ($1, $2, $3, $4, true)
        RETURNING id, email, first_name, last_name
      `, [email.toLowerCase(), hashedPassword, firstName, lastName]);
      
      const newUser = userResult.rows[0];
      
      // Associar à organização padrão se for o primeiro usuário
      const userCount = await client.query('SELECT COUNT(*) FROM users');
      
      if (userCount.rows[0].count === '1') {
        // Primeiro usuário vira owner da organização default
        await client.query(`
          INSERT INTO user_organizations (user_id, organization_id, role, status)
          SELECT $1, id, 'owner', 'active' 
          FROM organizations 
          WHERE slug = 'default'
        `, [newUser.id]);
      }
      
      return newUser;
    });
    
    logger.audit('user_registered', {
      userId: result.id,
      email: result.email
    });
    
    // Gerar tokens
    const accessToken = generateAccessToken(result);
    const refreshToken = generateRefreshToken(result);
    
    res.status(201).json({
      success: true,
      user: result,
      tokens: {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: process.env.JWT_EXPIRES_IN || '24h'
      }
    });
    
  } catch (error) {
    if (error.code === '23505') { // unique violation
      throw createError('Email already exists', 409, 'EMAIL_EXISTS');
    }
    throw error;
  }
}

/**
 * Refresh token
 */
async function refreshToken(req, res) {
  try {
    const { refresh_token } = req.body;
    
    if (!refresh_token) {
      throw createError('Refresh token is required', 400, 'MISSING_REFRESH_TOKEN');
    }
    
    // Verificar refresh token
    const decoded = jwt.verify(refresh_token, process.env.JWT_SECRET);
    
    if (decoded.type !== 'refresh') {
      throw createError('Invalid token type', 400, 'INVALID_TOKEN_TYPE');
    }
    
    // Buscar usuário
    const result = await query(
      'SELECT id, email, first_name, last_name, status FROM users WHERE id = $1 AND status = $2',
      [decoded.userId, 'active']
    );
    
    if (result.rows.length === 0) {
      throw createError('User not found or inactive', 401, 'INVALID_USER');
    }
    
    const user = result.rows[0];
    
    // Gerar novos tokens
    const accessToken = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken(user);
    
    logger.audit('token_refreshed', { userId: user.id });
    
    res.json({
      success: true,
      tokens: {
        access_token: accessToken,
        refresh_token: newRefreshToken,
        expires_in: process.env.JWT_EXPIRES_IN || '24h'
      }
    });
    
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      throw createError('Invalid refresh token', 401, 'INVALID_REFRESH_TOKEN');
    }
    throw error;
  }
}

/**
 * Logout
 */
async function logout(req, res) {
  try {
    logger.audit('user_logout', { userId: req.user.id });
    
    res.json({
      success: true,
      message: 'Logged out successfully'
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Obter perfil do usuário
 */
async function getProfile(req, res) {
  try {
    const userId = req.user.id;
    
    // Buscar dados completos do usuário
    const userResult = await query(`
      SELECT 
        id, email, first_name, last_name, avatar_url, 
        email_confirmed, last_sign_in_at, created_at
      FROM users 
      WHERE id = $1
    `, [userId]);
    
    if (userResult.rows.length === 0) {
      throw createError('User not found', 404, 'USER_NOT_FOUND');
    }
    
    // Buscar organizações do usuário
    const orgsResult = await query(`
      SELECT 
        o.id, o.name, o.slug, uo.role, uo.joined_at
      FROM organizations o
      JOIN user_organizations uo ON uo.organization_id = o.id
      WHERE uo.user_id = $1 AND uo.status = 'active'
      ORDER BY uo.joined_at DESC
    `, [userId]);
    
    res.json({
      success: true,
      user: userResult.rows[0],
      organizations: orgsResult.rows
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Atualizar perfil
 */
async function updateProfile(req, res) {
  try {
    const userId = req.user.id;
    const { firstName, lastName, avatarUrl } = req.body;
    
    const result = await query(`
      UPDATE users 
      SET 
        first_name = COALESCE($1, first_name),
        last_name = COALESCE($2, last_name),
        avatar_url = COALESCE($3, avatar_url),
        updated_at = NOW()
      WHERE id = $4
      RETURNING id, email, first_name, last_name, avatar_url
    `, [firstName, lastName, avatarUrl, userId]);
    
    logger.audit('profile_updated', { userId });
    
    res.json({
      success: true,
      user: result.rows[0]
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Alterar senha
 */
async function changePassword(req, res) {
  try {
    const userId = req.user.id;
    const { currentPassword, newPassword } = req.body;
    
    if (!currentPassword || !newPassword) {
      throw createError('Current and new passwords are required', 400, 'VALIDATION_ERROR');
    }
    
    if (newPassword.length < 8) {
      throw createError('New password must be at least 8 characters', 400, 'WEAK_PASSWORD');
    }
    
    // Verificar senha atual
    const userResult = await query(
      'SELECT encrypted_password FROM users WHERE id = $1',
      [userId]
    );
    
    const isValidPassword = await bcrypt.compare(currentPassword, userResult.rows[0].encrypted_password);
    
    if (!isValidPassword) {
      logger.security('Invalid current password in change attempt', { userId }, req);
      throw createError('Current password is incorrect', 400, 'INVALID_CURRENT_PASSWORD');
    }
    
    // Atualizar senha
    const hashedPassword = await bcrypt.hash(newPassword, parseInt(process.env.BCRYPT_ROUNDS) || 12);
    
    await query(
      'UPDATE users SET encrypted_password = $1, updated_at = NOW() WHERE id = $2',
      [hashedPassword, userId]
    );
    
    logger.audit('password_changed', { userId });
    
    res.json({
      success: true,
      message: 'Password changed successfully'
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Gerar access token
 */
function generateAccessToken(user) {
  return jwt.sign(
    {
      userId: user.id,
      email: user.email,
      type: 'access'
    },
    process.env.JWT_SECRET,
    { 
      expiresIn: process.env.JWT_EXPIRES_IN || '24h',
      issuer: 'supabase-baas-api'
    }
  );
}

/**
 * Gerar refresh token
 */
function generateRefreshToken(user) {
  return jwt.sign(
    {
      userId: user.id,
      type: 'refresh'
    },
    process.env.JWT_SECRET,
    { 
      expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
      issuer: 'supabase-baas-api'
    }
  );
}

module.exports = {
  login,
  register,
  refreshToken,
  logout,
  getProfile,
  updateProfile,
  changePassword
};