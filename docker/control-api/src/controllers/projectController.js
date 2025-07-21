/**
 * Controller para gerenciamento de projetos/instâncias
 */

const { exec } = require('child_process');
const { promisify } = require('util');
const path = require('path');
const fs = require('fs').promises;
const { query, transaction } = require('../config/database');
const logger = require('../utils/logger');
const { createError } = require('../middleware/errorHandler');

const execAsync = promisify(exec);

/**
 * Criar nova instância de projeto
 */
async function createProject(req, res) {
  const startTime = Date.now();
  
  try {
    const { orgId } = req.params;
    const { name, description, environment = 'production' } = req.body;
    const userId = req.user.id;
    
    // Validações
    if (!name || name.trim().length === 0) {
      throw createError('Project name is required', 400, 'VALIDATION_ERROR');
    }
    
    if (name.length > 255) {
      throw createError('Project name too long (max 255 characters)', 400, 'VALIDATION_ERROR');
    }
    
    if (!/^[a-zA-Z0-9\s\-_.]+$/.test(name)) {
      throw createError('Project name contains invalid characters', 400, 'VALIDATION_ERROR');
    }
    
    logger.info('Creating new project', {
      orgId,
      projectName: name,
      userId,
      environment
    });
    
    // Usar transação para criar projeto no banco
    const result = await transaction(async (client) => {
      // Criar projeto no banco usando function
      const projectResult = await client.query(
        'SELECT create_project_instance($1, $2, $3, $4, $5) as result',
        [parseInt(orgId), name, userId, description, environment]
      );
      
      const createResult = projectResult.rows[0].result;
      
      if (!createResult.success) {
        throw createError(createResult.error, 400, 'PROJECT_CREATION_FAILED');
      }
      
      return createResult.project;
    });
    
    const project = result;
    
    logger.audit('project_create_db_success', {
      projectId: project.id,
      instanceId: project.instance_id,
      subdomain: project.subdomain
    }, userId);
    
    // Executar script de geração de instância em background
    setImmediate(async () => {
      try {
        await createDockerInstance(project, userId);
      } catch (error) {
        logger.error('Failed to create Docker instance:', {
          projectId: project.id,
          instanceId: project.instance_id,
          error: error.message
        });
        
        // Marcar projeto como failed
        await query(
          'UPDATE projects SET status = $1, updated_at = NOW() WHERE id = $2',
          ['error', project.id]
        );
      }
    });
    
    const duration = Date.now() - startTime;
    logger.performance('create_project', duration, {
      projectId: project.id,
      instanceId: project.instance_id
    });
    
    res.status(201).json({
      success: true,
      project: {
        id: project.id,
        name: project.name,
        slug: project.slug,
        subdomain: project.subdomain,
        status: project.status,
        api_url: project.api_url,
        studio_url: project.studio_url,
        environment: project.environment,
        created_at: project.created_at
      }
    });
    
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.performance('create_project_failed', duration, {
      error: error.message
    });
    
    throw error;
  }
}

/**
 * Função auxiliar para criar instância Docker
 */
async function createDockerInstance(project, userId) {
  try {
    logger.info('Starting Docker instance creation', {
      projectId: project.id,
      instanceId: project.instance_id,
      subdomain: project.subdomain
    });
    
    // Preparar comando do script
    const scriptPath = process.env.GENERATE_SCRIPT_PATH || path.join(__dirname, '../../../generate.bash');
    const cmd = `bash "${scriptPath}" --project="${project.slug}" --org-id="${project.organization_id}" --subdomain="${project.subdomain}"`;
    
    logger.debug('Executing generate script', { command: cmd });
    
    // Executar script com timeout de 5 minutos
    const { stdout, stderr } = await execAsync(cmd, {
      timeout: 300000, // 5 minutos
      cwd: path.dirname(scriptPath)
    });
    
    logger.info('Generate script output', {
      projectId: project.id,
      stdout: stdout.substring(0, 1000),
      stderr: stderr.substring(0, 1000)
    });
    
    // Verificar se a criação foi bem-sucedida
    if (stderr && stderr.includes('❌')) {
      throw new Error(`Script failed: ${stderr}`);
    }
    
    // Aguardar um pouco para containers iniciarem
    await new Promise(resolve => setTimeout(resolve, 10000));
    
    // Ler configuração gerada pelo script
    await updateProjectFromConfig(project);
    
    logger.audit('docker_instance_created', {
      projectId: project.id,
      instanceId: project.instance_id,
      subdomain: project.subdomain
    }, userId);
    
  } catch (error) {
    logger.error('Docker instance creation failed:', {
      projectId: project.id,
      instanceId: project.instance_id,
      error: error.message
    });
    
    throw error;
  }
}

/**
 * Atualizar projeto com configurações do arquivo gerado
 */
async function updateProjectFromConfig(project) {
  try {
    const instanceDir = path.join(
      process.env.INSTANCES_DIR || '/opt/supabase-instances',
      project.instance_id
    );
    
    const configPath = path.join(instanceDir, 'config.json');
    
    // Aguardar arquivo de configuração aparecer
    let attempts = 0;
    while (attempts < 30) { // 30 tentativas = 30 segundos
      try {
        await fs.access(configPath);
        break;
      } catch {
        await new Promise(resolve => setTimeout(resolve, 1000));
        attempts++;
      }
    }
    
    if (attempts >= 30) {
      throw new Error('Configuration file not found after 30 seconds');
    }
    
    const configData = await fs.readFile(configPath, 'utf8');
    const config = JSON.parse(configData);
    
    // Atualizar projeto no banco com as configurações reais
    const updateResult = await query(
      'SELECT update_project_config($1, $2, $3, $4, $5, $6, $7, $8, $9) as result',
      [
        project.instance_id,
        config.ports.kong_http,
        config.ports.postgres_external,
        config.ports.analytics,
        config.credentials.postgres_password,
        config.credentials.jwt_secret,
        'anon_key_placeholder', // será atualizado depois
        'service_role_key_placeholder', // será atualizado depois
        config.credentials.dashboard_password
      ]
    );
    
    const result = updateResult.rows[0].result;
    
    if (!result.success) {
      throw new Error(result.error);
    }
    
    logger.info('Project configuration updated', {
      projectId: project.id,
      instanceId: project.instance_id,
      ports: config.ports
    });
    
  } catch (error) {
    logger.error('Failed to update project from config:', {
      projectId: project.id,
      instanceId: project.instance_id,
      error: error.message
    });
    
    throw error;
  }
}

/**
 * Listar projetos da organização
 */
async function listProjects(req, res) {
  try {
    const { orgId } = req.params;
    const userId = req.user.id;
    
    // Buscar projetos da organização
    const result = await query(`
      SELECT 
        p.id,
        p.name,
        p.slug,
        p.description,
        p.subdomain,
        p.api_url,
        p.studio_url,
        p.status,
        p.health_status,
        p.environment,
        p.created_at,
        p.updated_at,
        u.first_name || ' ' || u.last_name as created_by_name
      FROM projects p
      JOIN users u ON u.id = p.created_by
      JOIN user_organizations uo ON uo.organization_id = p.organization_id
      WHERE p.organization_id = $1 
        AND uo.user_id = $2 
        AND uo.status = 'active'
        AND p.deleted_at IS NULL
      ORDER BY p.created_at DESC
    `, [orgId, userId]);
    
    res.json({
      success: true,
      projects: result.rows
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Obter detalhes de um projeto
 */
async function getProject(req, res) {
  try {
    const { projectId } = req.params;
    
    const result = await query(`
      SELECT 
        p.*,
        o.name as organization_name,
        u.first_name || ' ' || u.last_name as created_by_name
      FROM projects p
      JOIN organizations o ON o.id = p.organization_id
      JOIN users u ON u.id = p.created_by
      WHERE p.id = $1 AND p.deleted_at IS NULL
    `, [projectId]);
    
    if (result.rows.length === 0) {
      throw createError('Project not found', 404, 'PROJECT_NOT_FOUND');
    }
    
    const project = result.rows[0];
    
    // Remover dados sensíveis da resposta
    delete project.postgres_password;
    delete project.jwt_secret;
    delete project.anon_key;
    delete project.service_role_key;
    delete project.dashboard_password;
    
    res.json({
      success: true,
      project
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Verificar status de um projeto
 */
async function getProjectStatus(req, res) {
  try {
    const { projectId } = req.params;
    
    // Buscar dados do projeto
    const projectResult = await query(
      'SELECT instance_id, subdomain, port, status FROM projects WHERE id = $1 AND deleted_at IS NULL',
      [projectId]
    );
    
    if (projectResult.rows.length === 0) {
      throw createError('Project not found', 404, 'PROJECT_NOT_FOUND');
    }
    
    const project = projectResult.rows[0];
    
    // Verificar containers Docker
    const containerStatus = await checkDockerContainers(project.instance_id);
    
    // Verificar conectividade HTTP
    const httpStatus = await checkHttpConnectivity(project.subdomain, project.port);
    
    // Atualizar health status no banco se necessário
    const newHealthStatus = containerStatus.healthy && httpStatus.healthy ? 'healthy' : 'unhealthy';
    
    if (newHealthStatus !== project.status) {
      await query(
        'UPDATE projects SET health_status = $1, last_health_check = NOW() WHERE id = $2',
        [newHealthStatus, projectId]
      );
    }
    
    res.json({
      success: true,
      status: {
        overall: newHealthStatus,
        containers: containerStatus,
        http: httpStatus,
        last_check: new Date().toISOString()
      }
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Deletar projeto
 */
async function deleteProject(req, res) {
  try {
    const { projectId } = req.params;
    const userId = req.user.id;
    
    logger.info('Starting project deletion', {
      projectId,
      userId
    });
    
    // Marcar projeto como sendo deletado
    const result = await query(
      'SELECT delete_project_instance($1, $2) as result',
      [parseInt(projectId), userId]
    );
    
    const deleteResult = result.rows[0].result;
    
    if (!deleteResult.success) {
      throw createError(deleteResult.error, 400, 'PROJECT_DELETION_FAILED');
    }
    
    const project = deleteResult.project;
    
    // Executar remoção em background
    setImmediate(async () => {
      try {
        await removeDockerInstance(project, userId);
        
        // Marcar como deletado definitivamente
        await query(
          'UPDATE projects SET deleted_at = NOW() WHERE id = $1',
          [projectId]
        );
        
        logger.audit('project_deleted', {
          projectId,
          instanceId: project.instance_id
        }, userId);
        
      } catch (error) {
        logger.error('Failed to remove Docker instance:', {
          projectId,
          instanceId: project.instance_id,
          error: error.message
        });
        
        // Reverter status se remoção falhou
        await query(
          'UPDATE projects SET status = $1 WHERE id = $2',
          ['error', projectId]
        );
      }
    });
    
    res.json({
      success: true,
      message: 'Project deletion started',
      project: {
        id: projectId,
        instance_id: project.instance_id,
        status: 'deleting'
      }
    });
    
  } catch (error) {
    throw error;
  }
}

/**
 * Função auxiliar para verificar containers Docker
 */
async function checkDockerContainers(instanceId) {
  try {
    const { stdout } = await execAsync(`docker ps --filter "name=${instanceId}" --format "{{.Names}},{{.Status}}"`);
    
    const containers = stdout.trim().split('\n').filter(line => line);
    const containerStats = containers.map(line => {
      const [name, status] = line.split(',');
      return {
        name,
        status,
        healthy: status.includes('Up')
      };
    });
    
    const totalContainers = containerStats.length;
    const healthyContainers = containerStats.filter(c => c.healthy).length;
    
    return {
      healthy: totalContainers > 0 && healthyContainers === totalContainers,
      total: totalContainers,
      healthy_count: healthyContainers,
      containers: containerStats
    };
    
  } catch (error) {
    logger.error('Error checking Docker containers:', error);
    return {
      healthy: false,
      error: error.message
    };
  }
}

/**
 * Função auxiliar para verificar conectividade HTTP
 */
async function checkHttpConnectivity(subdomain, port) {
  try {
    const { stdout } = await execAsync(`curl -f -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/health || echo "000"`);
    
    const statusCode = parseInt(stdout.trim());
    
    return {
      healthy: statusCode >= 200 && statusCode < 400,
      status_code: statusCode,
      port
    };
    
  } catch (error) {
    return {
      healthy: false,
      error: error.message
    };
  }
}

/**
 * Função auxiliar para remover instância Docker
 */
async function removeDockerInstance(project, userId) {
  try {
    logger.info('Starting Docker instance removal', {
      projectId: project.id,
      instanceId: project.instance_id
    });
    
    const instanceDir = path.join(
      process.env.INSTANCES_DIR || '/opt/supabase-instances',
      project.instance_id
    );
    
    // Parar e remover containers
    const stopCmd = `cd "${instanceDir}" && docker compose down -v`;
    await execAsync(stopCmd, { timeout: 60000 });
    
    // Remover diretório da instância
    await fs.rm(instanceDir, { recursive: true, force: true });
    
    // Remover rota do nginx
    const nginxManagerScript = process.env.NGINX_MANAGER_SCRIPT || '/opt/supabase-instances/nginx-manager.sh';
    const removeRouteCmd = `bash "${nginxManagerScript}" remove_route "${project.subdomain}"`;
    await execAsync(removeRouteCmd, { timeout: 30000 });
    
    logger.info('Docker instance removed successfully', {
      projectId: project.id,
      instanceId: project.instance_id
    });
    
  } catch (error) {
    logger.error('Failed to remove Docker instance:', error);
    throw error;
  }
}

module.exports = {
  createProject,
  listProjects,
  getProject,
  getProjectStatus,
  deleteProject
};