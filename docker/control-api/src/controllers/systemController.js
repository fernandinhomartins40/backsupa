/**
 * Controller para funcionalidades do sistema
 */

const { exec } = require('child_process');
const { promisify } = require('util');
const os = require('os');
const fs = require('fs').promises;
const path = require('path');

const { query, healthCheck } = require('../config/database');
const logger = require('../utils/logger');
const { createError } = require('../middleware/errorHandler');

const execAsync = promisify(exec);

/**
 * Status detalhado do sistema
 */
async function getSystemStatus(req, res) {
  try {
    const startTime = Date.now();
    
    // Status do banco de dados
    const dbHealth = await healthCheck();
    
    // Status do Docker
    const dockerStatus = await checkDockerStatus();
    
    // Status do Nginx
    const nginxStatus = await checkNginxStatus();
    
    // Status do sistema
    const systemStats = await getSystemMetrics();
    
    // Status das instâncias ativas
    const instancesStatus = await getInstancesStatus();
    
    const responseTime = Date.now() - startTime;
    
    const overallHealth = 
      dbHealth.healthy && 
      dockerStatus.healthy && 
      nginxStatus.healthy;
    
    res.json({
      success: true,
      status: overallHealth ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      response_time_ms: responseTime,
      services: {
        database: dbHealth,
        docker: dockerStatus,
        nginx: nginxStatus
      },
      system: systemStats,
      instances: instancesStatus
    });
    
  } catch (error) {
    logger.error('System status check failed:', error);
    throw error;
  }
}

/**
 * Health check simples
 */
async function getHealthCheck(req, res) {
  try {
    const dbHealth = await healthCheck();
    
    res.json({
      status: dbHealth.healthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      database: dbHealth.healthy,
      uptime: process.uptime()
    });
    
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
}

/**
 * Estatísticas gerais do sistema
 */
async function getSystemStats(req, res) {
  try {
    // Estatísticas do banco
    const dbStats = await getDatabaseStats();
    
    // Estatísticas de uso
    const usageStats = await getUsageStats();
    
    // Estatísticas do sistema
    const systemStats = await getSystemMetrics();
    
    res.json({
      success: true,
      stats: {
        database: dbStats,
        usage: usageStats,
        system: systemStats
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Logs do sistema
 */
async function getSystemLogs(req, res) {
  try {
    const { 
      level = 'info',
      service,
      limit = 100,
      offset = 0,
      start_date,
      end_date
    } = req.query;
    
    let whereClause = 'WHERE level >= $1';
    let params = [level];
    let paramIndex = 2;
    
    if (service) {
      whereClause += ` AND service = $${paramIndex}`;
      params.push(service);
      paramIndex++;
    }
    
    if (start_date) {
      whereClause += ` AND created_at >= $${paramIndex}`;
      params.push(start_date);
      paramIndex++;
    }
    
    if (end_date) {
      whereClause += ` AND created_at <= $${paramIndex}`;
      params.push(end_date);
      paramIndex++;
    }
    
    const result = await query(`
      SELECT 
        id, level, service, message, details, 
        user_id, project_id, organization_id,
        created_at
      FROM system_logs
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `, [...params, parseInt(limit), parseInt(offset)]);
    
    // Contar total
    const countResult = await query(`
      SELECT COUNT(*) as total
      FROM system_logs
      ${whereClause}
    `, params);
    
    res.json({
      success: true,
      logs: result.rows,
      pagination: {
        total: parseInt(countResult.rows[0].total),
        limit: parseInt(limit),
        offset: parseInt(offset)
      }
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Verificar status do Docker
 */
async function checkDockerStatus() {
  try {
    const { stdout } = await execAsync('docker info --format "{{.ServerVersion}}"');
    const version = stdout.trim();
    
    // Verificar containers ativos
    const { stdout: containersOutput } = await execAsync('docker ps --format "{{.Names}},{{.Status}}"');
    const containers = containersOutput.trim().split('\n').filter(line => line);
    
    const supabaseContainers = containers.filter(line => 
      line.includes('supabase-') || line.includes('realtime-')
    );
    
    return {
      healthy: true,
      version,
      total_containers: containers.length,
      supabase_containers: supabaseContainers.length,
      details: {
        containers: supabaseContainers.slice(0, 10) // Mostrar só os primeiros 10
      }
    };
    
  } catch (error) {
    return {
      healthy: false,
      error: error.message
    };
  }
}

/**
 * Verificar status do Nginx
 */
async function checkNginxStatus() {
  try {
    // Verificar se Nginx está rodando
    await execAsync('systemctl is-active nginx');
    
    // Verificar configuração
    await execAsync('nginx -t');
    
    // Verificar arquivo de rotas
    const routesFile = path.join(
      process.env.INSTANCES_DIR || '/opt/supabase-instances',
      'routes.json'
    );
    
    let routesCount = 0;
    try {
      const routesData = await fs.readFile(routesFile, 'utf8');
      const routes = JSON.parse(routesData);
      routesCount = Object.keys(routes).length;
    } catch {
      // Arquivo não existe ou está vazio
    }
    
    return {
      healthy: true,
      status: 'active',
      routes_count: routesCount
    };
    
  } catch (error) {
    return {
      healthy: false,
      error: error.message
    };
  }
}

/**
 * Métricas do sistema
 */
async function getSystemMetrics() {
  const cpus = os.cpus();
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;
  
  return {
    hostname: os.hostname(),
    platform: os.platform(),
    arch: os.arch(),
    uptime: os.uptime(),
    load_average: os.loadavg(),
    cpu: {
      count: cpus.length,
      model: cpus[0]?.model,
      speed: cpus[0]?.speed
    },
    memory: {
      total: totalMem,
      used: usedMem,
      free: freeMem,
      usage_percent: Math.round((usedMem / totalMem) * 100)
    },
    disk: await getDiskUsage()
  };
}

/**
 * Status das instâncias
 */
async function getInstancesStatus() {
  try {
    // Buscar todas as instâncias ativas
    const result = await query(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN status = 'active' THEN 1 END) as active,
        COUNT(CASE WHEN status = 'creating' THEN 1 END) as creating,
        COUNT(CASE WHEN status = 'error' THEN 1 END) as error,
        COUNT(CASE WHEN health_status = 'healthy' THEN 1 END) as healthy
      FROM projects 
      WHERE deleted_at IS NULL
    `);
    
    const stats = result.rows[0];
    
    return {
      total: parseInt(stats.total),
      active: parseInt(stats.active),
      creating: parseInt(stats.creating),
      error: parseInt(stats.error),
      healthy: parseInt(stats.healthy)
    };
    
  } catch (error) {
    logger.error('Failed to get instances status:', error);
    return {
      error: error.message
    };
  }
}

/**
 * Estatísticas do banco de dados
 */
async function getDatabaseStats() {
  try {
    const results = await Promise.all([
      query('SELECT COUNT(*) as count FROM organizations WHERE status = $1', ['active']),
      query('SELECT COUNT(*) as count FROM users WHERE status = $1', ['active']),
      query('SELECT COUNT(*) as count FROM projects WHERE deleted_at IS NULL'),
      query('SELECT COUNT(*) as count FROM project_audit_log WHERE created_at > NOW() - INTERVAL \'24 hours\''),
      query(`
        SELECT 
          pg_database_size(current_database()) as db_size,
          pg_size_pretty(pg_database_size(current_database())) as db_size_pretty
      `)
    ]);
    
    return {
      organizations: parseInt(results[0].rows[0].count),
      users: parseInt(results[1].rows[0].count),
      projects: parseInt(results[2].rows[0].count),
      audit_logs_24h: parseInt(results[3].rows[0].count),
      database_size: parseInt(results[4].rows[0].db_size),
      database_size_pretty: results[4].rows[0].db_size_pretty
    };
    
  } catch (error) {
    logger.error('Failed to get database stats:', error);
    return {
      error: error.message
    };
  }
}

/**
 * Estatísticas de uso
 */
async function getUsageStats() {
  try {
    const result = await query(`
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as projects_created
      FROM projects 
      WHERE created_at > NOW() - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY date DESC
      LIMIT 30
    `);
    
    return {
      projects_created_last_30_days: result.rows
    };
    
  } catch (error) {
    logger.error('Failed to get usage stats:', error);
    return {
      error: error.message
    };
  }
}

/**
 * Uso do disco
 */
async function getDiskUsage() {
  try {
    const { stdout } = await execAsync('df -h / --output=size,used,avail,pcent | tail -1');
    const [size, used, avail, percent] = stdout.trim().split(/\s+/);
    
    return {
      size,
      used,
      available: avail,
      usage_percent: percent
    };
    
  } catch (error) {
    return {
      error: error.message
    };
  }
}

module.exports = {
  getSystemStatus,
  getHealthCheck,
  getSystemStats,
  getSystemLogs
};