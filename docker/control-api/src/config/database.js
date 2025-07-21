/**
 * Configuração do banco de dados PostgreSQL
 */

const { Pool } = require('pg');
const logger = require('../utils/logger');

let pool;

// Configuração do pool de conexões
const poolConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'supabase_master',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  min: parseInt(process.env.DB_POOL_MIN) || 2,
  max: parseInt(process.env.DB_POOL_MAX) || 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  statement_timeout: 60000,
  query_timeout: 60000,
};

// Usar DATABASE_URL se disponível
if (process.env.DATABASE_URL) {
  poolConfig.connectionString = process.env.DATABASE_URL;
}

/**
 * Conectar ao banco de dados
 */
async function connectDB() {
  try {
    pool = new Pool(poolConfig);
    
    // Testar conexão
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    
    logger.info('Database connection established', {
      host: poolConfig.host,
      port: poolConfig.port,
      database: poolConfig.database,
      timestamp: result.rows[0].now
    });
    
    // Event listeners para o pool
    pool.on('error', (err) => {
      logger.error('Database pool error:', err);
    });
    
    pool.on('connect', () => {
      logger.debug('New database client connected');
    });
    
    pool.on('remove', () => {
      logger.debug('Database client removed from pool');
    });
    
    return pool;
  } catch (error) {
    logger.error('Database connection failed:', error);
    throw error;
  }
}

/**
 * Fechar conexões do banco
 */
async function closeDB() {
  if (pool) {
    try {
      await pool.end();
      logger.info('Database connections closed');
    } catch (error) {
      logger.error('Error closing database connections:', error);
      throw error;
    }
  }
}

/**
 * Obter client do pool
 */
async function getClient() {
  if (!pool) {
    throw new Error('Database not connected');
  }
  return pool.connect();
}

/**
 * Executar query
 */
async function query(text, params = []) {
  if (!pool) {
    throw new Error('Database not connected');
  }
  
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    
    logger.debug('Query executed', {
      query: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
      duration: `${duration}ms`,
      rows: result.rowCount
    });
    
    return result;
  } catch (error) {
    logger.error('Query error:', {
      query: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
      params,
      error: error.message
    });
    throw error;
  }
}

/**
 * Executar transação
 */
async function transaction(callback) {
  const client = await getClient();
  
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Verificar saúde do banco
 */
async function healthCheck() {
  try {
    const result = await query('SELECT 1 as healthy, NOW() as timestamp');
    return {
      healthy: true,
      timestamp: result.rows[0].timestamp,
      poolStats: {
        total: pool.totalCount,
        idle: pool.idleCount,
        waiting: pool.waitingCount
      }
    };
  } catch (error) {
    return {
      healthy: false,
      error: error.message
    };
  }
}

module.exports = {
  connectDB,
  closeDB,
  getClient,
  query,
  transaction,
  healthCheck,
  get pool() {
    return pool;
  }
};