#!/usr/bin/env node
/**
 * Marketplace API - Sistema de marketplace de templates para BaaS Supabase
 * API independente para gerenciar templates, downloads e instalações
 */

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const crypto = require('crypto');
const archiver = require('archiver');
const unzipper = require('unzipper');
const helmet = require('helmet');
const compression = require('compression');

const app = express();
const PORT = process.env.MARKETPLACE_PORT || 3003;

// Database connection
const masterDb = new Pool({
    connectionString: process.env.MASTER_DB_URL || 'postgresql://postgres:postgres@localhost:5432/supabase_master',
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Storage configuration
const UPLOADS_DIR = process.env.UPLOADS_DIR || path.join(__dirname, 'uploads');
const TEMPLATES_DIR = path.join(UPLOADS_DIR, 'templates');
const THUMBNAILS_DIR = path.join(UPLOADS_DIR, 'thumbnails');

// Ensure upload directories exist
const ensureDirectories = async () => {
    for (const dir of [UPLOADS_DIR, TEMPLATES_DIR, THUMBNAILS_DIR]) {
        try {
            await fs.mkdir(dir, { recursive: true });
        } catch (error) {
            console.error(`Error creating directory ${dir}:`, error);
        }
    }
};

// Multer configuration for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const uploadPath = file.fieldname === 'thumbnail' ? THUMBNAILS_DIR : TEMPLATES_DIR;
        cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: {
        fileSize: 50 * 1024 * 1024, // 50MB max
    },
    fileFilter: (req, file, cb) => {
        if (file.fieldname === 'thumbnail') {
            const allowedTypes = /jpeg|jpg|png|gif|webp/;
            const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
            const mimetype = allowedTypes.test(file.mimetype);
            
            if (mimetype && extname) {
                return cb(null, true);
            } else {
                cb(new Error('Apenas imagens são permitidas para thumbnail'));
            }
        } else if (file.fieldname === 'template_package') {
            const allowedTypes = /zip/;
            const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
            const mimetype = allowedTypes.test(file.mimetype);
            
            if (mimetype && extname || file.mimetype === 'application/zip') {
                return cb(null, true);
            } else {
                cb(new Error('Apenas arquivos ZIP são permitidos para templates'));
            }
        } else {
            cb(new Error('Campo de arquivo não reconhecido'));
        }
    }
});

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Serve static files
app.use('/uploads', express.static(UPLOADS_DIR));

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        name: 'Supabase Marketplace API',
        version: '1.0.0',
        description: 'Sistema de marketplace de templates para BaaS Supabase',
        endpoints: {
            health: '/health',
            categories: '/api/categories', 
            templates: '/api/templates',
            templates_detail: '/api/templates/:templateId',
            templates_download: '/api/templates/:templateId/download',
            templates_install: '/api/templates/:templateId/install'
        },
        status: 'running',
        timestamp: new Date().toISOString()
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        service: 'marketplace-api',
        version: '1.0.0'
    });
});

// Obter categorias
app.get('/api/categories', async (req, res) => {
    try {
        const result = await masterDb.query(`
            SELECT id, name, description, icon, sort_order
            FROM template_categories 
            WHERE is_active = true 
            ORDER BY sort_order ASC, name ASC
        `);

        res.json({
            success: true,
            categories: result.rows
        });
    } catch (error) {
        console.error('Error fetching categories:', error);
        res.status(500).json({ error: 'Failed to fetch categories' });
    }
});

// Obter templates (com filtros e paginação)
app.get('/api/templates', async (req, res) => {
    try {
        const {
            category,
            search,
            featured,
            free_only,
            sort = 'downloads',
            limit = 20,
            offset = 0
        } = req.query;

        let query = `
            SELECT 
                t.id, t.name, t.slug, t.description, t.thumbnail_url,
                t.is_free, t.price_usd, t.downloads_count, t.rating_average, t.rating_count,
                t.tags, t.created_at, t.is_featured,
                tc.name as category_name, tc.icon as category_icon
            FROM templates t
            JOIN template_categories tc ON t.category_id = tc.id
            WHERE t.status = 'published'
        `;

        const params = [];
        let paramCount = 0;

        if (category) {
            paramCount++;
            query += ` AND tc.name = $${paramCount}`;
            params.push(category);
        }

        if (search) {
            if (search.length >= 3) {
                // Use full text search for longer queries
                paramCount++;
                query += ` AND (
                    to_tsvector('portuguese', t.name || ' ' || t.description) @@ plainto_tsquery('portuguese', $${paramCount})
                    OR t.name ILIKE $${paramCount + 1}
                    OR t.description ILIKE $${paramCount + 1}
                )`;
                params.push(search, `%${search}%`);
                paramCount++;
            } else {
                // Use ILIKE for short queries
                paramCount++;
                query += ` AND (t.name ILIKE $${paramCount} OR t.description ILIKE $${paramCount})`;
                params.push(`%${search}%`);
            }
        }

        if (featured === 'true') {
            query += ` AND t.is_featured = true`;
        }

        if (free_only === 'true') {
            query += ` AND t.is_free = true`;
        }

        // Sort options
        switch (sort) {
            case 'name':
                query += ` ORDER BY t.name ASC`;
                break;
            case 'rating':
                query += ` ORDER BY t.rating_average DESC, t.rating_count DESC`;
                break;
            case 'newest':
                query += ` ORDER BY t.created_at DESC`;
                break;
            case 'price_low':
                query += ` ORDER BY t.price_usd ASC, t.name ASC`;
                break;
            case 'price_high':
                query += ` ORDER BY t.price_usd DESC, t.name ASC`;
                break;
            case 'downloads':
            default:
                query += ` ORDER BY t.downloads_count DESC, t.rating_average DESC`;
                break;
        }

        // Add pagination
        paramCount++;
        query += ` LIMIT $${paramCount}`;
        params.push(parseInt(limit));

        paramCount++;
        query += ` OFFSET $${paramCount}`;
        params.push(parseInt(offset));

        const result = await masterDb.query(query, params);

        // Get total count for pagination
        let countQuery = `
            SELECT COUNT(*) as total
            FROM templates t
            JOIN template_categories tc ON t.category_id = tc.id
            WHERE t.status = 'published'
        `;
        const countParams = [];
        let countParamCount = 0;

        if (category) {
            countParamCount++;
            countQuery += ` AND tc.name = $${countParamCount}`;
            countParams.push(category);
        }

        if (search) {
            if (search.length >= 3) {
                countParamCount++;
                countQuery += ` AND (
                    to_tsvector('portuguese', t.name || ' ' || t.description) @@ plainto_tsquery('portuguese', $${countParamCount})
                    OR t.name ILIKE $${countParamCount + 1}
                    OR t.description ILIKE $${countParamCount + 1}
                )`;
                countParams.push(search, `%${search}%`);
                countParamCount++;
            } else {
                countParamCount++;
                countQuery += ` AND (t.name ILIKE $${countParamCount} OR t.description ILIKE $${countParamCount})`;
                countParams.push(`%${search}%`);
            }
        }

        if (featured === 'true') {
            countQuery += ` AND t.is_featured = true`;
        }

        if (free_only === 'true') {
            countQuery += ` AND t.is_free = true`;
        }

        const countResult = await masterDb.query(countQuery, countParams);

        res.json({
            success: true,
            templates: result.rows,
            pagination: {
                total: parseInt(countResult.rows[0].total),
                limit: parseInt(limit),
                offset: parseInt(offset),
                has_more: parseInt(offset) + parseInt(limit) < parseInt(countResult.rows[0].total)
            }
        });
    } catch (error) {
        console.error('Error fetching templates:', error);
        res.status(500).json({ error: 'Failed to fetch templates' });
    }
});

// Obter template por slug
app.get('/api/templates/:slug', async (req, res) => {
    try {
        const { slug } = req.params;

        const result = await masterDb.query(`
            SELECT 
                t.*,
                tc.name as category_name,
                tc.icon as category_icon
            FROM templates t
            JOIN template_categories tc ON t.category_id = tc.id
            WHERE t.slug = $1 AND t.status = 'published'
        `, [slug]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Template not found' });
        }

        const template = result.rows[0];

        // Get template files
        const filesResult = await masterDb.query(`
            SELECT file_path, file_type, file_size
            FROM template_files
            WHERE template_id = $1
            ORDER BY file_path ASC
        `, [template.id]);

        // Get recent reviews
        const reviewsResult = await masterDb.query(`
            SELECT user_name, rating, review_text, created_at
            FROM template_reviews
            WHERE template_id = $1
            ORDER BY created_at DESC
            LIMIT 10
        `, [template.id]);

        res.json({
            success: true,
            template: {
                ...template,
                files: filesResult.rows,
                reviews: reviewsResult.rows
            }
        });
    } catch (error) {
        console.error('Error fetching template:', error);
        res.status(500).json({ error: 'Failed to fetch template' });
    }
});

// Download template
app.post('/api/templates/:slug/download', async (req, res) => {
    try {
        const { slug } = req.params;
        const { project_id, organization_id } = req.body;

        if (!project_id || !organization_id) {
            return res.status(400).json({ error: 'project_id and organization_id are required' });
        }

        // Get template
        const templateResult = await masterDb.query(`
            SELECT id, name, slug, schema_sql, seed_data_sql, edge_functions, api_config
            FROM templates
            WHERE slug = $1 AND status = 'published'
        `, [slug]);

        if (templateResult.rows.length === 0) {
            return res.status(404).json({ error: 'Template not found' });
        }

        const template = templateResult.rows[0];

        // Check if already installed
        const existingInstall = await masterDb.query(`
            SELECT id FROM template_installations
            WHERE template_id = $1 AND project_id = $2
        `, [template.id, project_id]);

        if (existingInstall.rows.length > 0) {
            return res.status(409).json({ error: 'Template already installed in this project' });
        }

        // Record installation
        await masterDb.query(`
            INSERT INTO template_installations (template_id, project_id, organization_id, installed_version, installation_status)
            VALUES ($1, $2, $3, '1.0.0', 'pending')
        `, [template.id, project_id, organization_id]);

        // Increment download count
        await masterDb.query('SELECT increment_template_downloads($1)', [template.id]);

        // Return template data for installation
        res.json({
            success: true,
            template: {
                id: template.id,
                name: template.name,
                slug: template.slug,
                schema_sql: template.schema_sql,
                seed_data_sql: template.seed_data_sql,
                edge_functions: template.edge_functions,
                api_config: template.api_config
            },
            installation: {
                project_id,
                organization_id,
                status: 'pending'
            }
        });
    } catch (error) {
        console.error('Error downloading template:', error);
        res.status(500).json({ error: 'Failed to download template' });
    }
});

// Update installation status
app.patch('/api/installations/:project_id/:template_id', async (req, res) => {
    try {
        const { project_id, template_id } = req.params;
        const { status, error_message } = req.body;

        const validStatuses = ['pending', 'completed', 'failed', 'rolled_back'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ error: 'Invalid status' });
        }

        await masterDb.query(`
            UPDATE template_installations
            SET installation_status = $1, error_message = $2
            WHERE template_id = $3 AND project_id = $4
        `, [status, error_message, template_id, project_id]);

        res.json({ success: true });
    } catch (error) {
        console.error('Error updating installation:', error);
        res.status(500).json({ error: 'Failed to update installation' });
    }
});

// Add review
app.post('/api/templates/:slug/reviews', async (req, res) => {
    try {
        const { slug } = req.params;
        const { user_email, user_name, rating, review_text } = req.body;

        if (!user_email || !rating || rating < 1 || rating > 5) {
            return res.status(400).json({ error: 'Valid user_email and rating (1-5) are required' });
        }

        // Get template ID
        const templateResult = await masterDb.query(`
            SELECT id FROM templates WHERE slug = $1 AND status = 'published'
        `, [slug]);

        if (templateResult.rows.length === 0) {
            return res.status(404).json({ error: 'Template not found' });
        }

        const templateId = templateResult.rows[0].id;

        // Check if user actually downloaded the template
        const installationResult = await masterDb.query(`
            SELECT id FROM template_installations ti
            JOIN projects p ON ti.project_id = p.id
            JOIN organizations o ON ti.organization_id = o.id
            WHERE ti.template_id = $1 AND (o.created_by = $2 OR p.created_by = $2)
            AND ti.installation_status = 'completed'
        `, [templateId, user_email]);

        const isVerified = installationResult.rows.length > 0;

        // Insert review
        await masterDb.query(`
            INSERT INTO template_reviews (template_id, user_email, user_name, rating, review_text, is_verified)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (template_id, user_email) DO UPDATE SET
                rating = EXCLUDED.rating,
                review_text = EXCLUDED.review_text,
                user_name = EXCLUDED.user_name,
                updated_at = NOW()
        `, [templateId, user_email, user_name, rating, review_text, isVerified]);

        res.json({ success: true, verified: isVerified });
    } catch (error) {
        console.error('Error adding review:', error);
        res.status(500).json({ error: 'Failed to add review' });
    }
});

// Upload new template (for template creators)
app.post('/api/templates', upload.fields([
    { name: 'thumbnail', maxCount: 1 },
    { name: 'template_package', maxCount: 1 }
]), async (req, res) => {
    try {
        const {
            name, description, long_description, category_id,
            author_name, author_email, tags, features,
            demo_url, github_url, documentation_url,
            is_free, price_usd
        } = req.body;

        if (!name || !description || !category_id || !author_email) {
            return res.status(400).json({ error: 'Required fields: name, description, category_id, author_email' });
        }

        // Generate slug
        const slug = name.toLowerCase()
            .replace(/[^\w\s-]/g, '')
            .replace(/[-\s]+/g, '-')
            .trim();

        // Check if slug already exists
        const existingSlug = await masterDb.query(`
            SELECT id FROM templates WHERE slug = $1
        `, [slug]);

        if (existingSlug.rows.length > 0) {
            return res.status(409).json({ error: 'Template with this name already exists' });
        }

        const thumbnailUrl = req.files.thumbnail ? `/uploads/thumbnails/${req.files.thumbnail[0].filename}` : null;

        // Insert template
        const templateResult = await masterDb.query(`
            INSERT INTO templates (
                name, slug, description, long_description, category_id,
                author_name, author_email, tags, features,
                thumbnail_url, demo_url, github_url, documentation_url,
                is_free, price_usd, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, 'draft')
            RETURNING id
        `, [
            name, slug, description, long_description, category_id,
            author_name, author_email, 
            JSON.parse(tags || '[]'), 
            JSON.parse(features || '[]'),
            thumbnailUrl, demo_url, github_url, documentation_url,
            is_free === 'true', parseFloat(price_usd) || 0
        ]);

        const templateId = templateResult.rows[0].id;

        // Process template package if uploaded
        if (req.files.template_package) {
            const packagePath = req.files.template_package[0].path;
            await processTemplatePackage(templateId, packagePath);
        }

        res.json({
            success: true,
            template_id: templateId,
            slug: slug,
            message: 'Template uploaded successfully. It will be reviewed before publication.'
        });
    } catch (error) {
        console.error('Error uploading template:', error);
        res.status(500).json({ error: 'Failed to upload template' });
    }
});

// Function to process uploaded template package
async function processTemplatePackage(templateId, packagePath) {
    const extractPath = path.join(TEMPLATES_DIR, `template-${templateId}`);
    
    try {
        // Create extraction directory
        await fs.mkdir(extractPath, { recursive: true });

        // Extract ZIP file
        await new Promise((resolve, reject) => {
            fs.createReadStream(packagePath)
                .pipe(unzipper.Extract({ path: extractPath }))
                .on('close', resolve)
                .on('error', reject);
        });

        // Process extracted files
        await processExtractedFiles(templateId, extractPath);

        // Clean up ZIP file
        await fs.unlink(packagePath);
    } catch (error) {
        console.error('Error processing template package:', error);
        throw error;
    }
}

// Process extracted template files
async function processExtractedFiles(templateId, extractPath) {
    const files = await fs.readdir(extractPath, { withFileTypes: true, recursive: true });
    
    for (const file of files) {
        if (file.isFile()) {
            const filePath = path.join(extractPath, file.name);
            const relativePath = path.relative(extractPath, filePath);
            const extension = path.extname(file.name).toLowerCase();
            
            let fileType = 'other';
            if (['.sql'].includes(extension)) fileType = 'sql';
            else if (['.js', '.ts'].includes(extension)) fileType = extension.slice(1);
            else if (['.json'].includes(extension)) fileType = 'json';
            else if (['.md', '.txt'].includes(extension)) fileType = 'text';
            
            const stats = await fs.stat(filePath);
            const content = await fs.readFile(filePath, 'utf8');
            const checksum = crypto.createHash('sha256').update(content).digest('hex');
            
            await masterDb.query(`
                INSERT INTO template_files (template_id, file_path, file_type, content, file_size, checksum)
                VALUES ($1, $2, $3, $4, $5, $6)
            `, [templateId, relativePath, fileType, content, stats.size, checksum]);
        }
    }
}

// Get installation history
app.get('/api/organizations/:org_id/installations', async (req, res) => {
    try {
        const { org_id } = req.params;

        const result = await masterDb.query(`
            SELECT 
                ti.*,
                t.name as template_name,
                t.slug as template_slug,
                t.thumbnail_url,
                p.name as project_name
            FROM template_installations ti
            JOIN templates t ON ti.template_id = t.id
            JOIN projects p ON ti.project_id = p.id
            WHERE ti.organization_id = $1
            ORDER BY ti.installed_at DESC
        `, [org_id]);

        res.json({
            success: true,
            installations: result.rows
        });
    } catch (error) {
        console.error('Error fetching installations:', error);
        res.status(500).json({ error: 'Failed to fetch installations' });
    }
});

// Initialize directories and start server
ensureDirectories().then(() => {
    app.listen(PORT, () => {
        console.log(`🚀 Marketplace API rodando na porta ${PORT}`);
        console.log(`🔗 Health check: http://localhost:${PORT}/health`);
        console.log(`📦 Templates: http://localhost:${PORT}/api/templates`);
    });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('🛑 Shutting down marketplace API...');
    await masterDb.end();
    process.exit(0);
});

module.exports = app;