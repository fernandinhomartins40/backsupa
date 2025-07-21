// Supabase BaaS Dashboard JavaScript
const API_BASE = window.location.hostname === 'localhost' ? 'http://localhost/api/control' : '/api/control';
const API_BILLING = window.location.hostname === 'localhost' ? 'http://localhost/api/billing' : '/api/billing';
const API_MARKETPLACE = window.location.hostname === 'localhost' ? 'http://localhost/api/marketplace' : '/api/marketplace';
const STUDIO_URL = window.location.hostname === 'localhost' ? 'http://localhost/studio' : '/studio';

// State management
let currentView = 'dashboard';
let authToken = localStorage.getItem('auth_token');
let currentUser = null;
let organizations = [];
let projects = [];

// Initialize app
document.addEventListener('DOMContentLoaded', async () => {
    setupThemeToggle();
    await checkServiceStatus();
    await loadDashboardData();
    
    // Auto-refresh every 30 seconds
    setInterval(checkServiceStatus, 30000);
});

// Theme toggle
function setupThemeToggle() {
    const themeToggle = document.getElementById('theme-toggle');
    const html = document.documentElement;
    
    themeToggle.addEventListener('click', () => {
        html.classList.toggle('dark');
        localStorage.setItem('theme', html.classList.contains('dark') ? 'dark' : 'light');
    });
    
    // Load saved theme
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'light') {
        html.classList.remove('dark');
    }
}

// Navigation
function showView(viewName) {
    // Hide all views
    document.querySelectorAll('.view').forEach(view => view.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
    
    // Show selected view
    document.getElementById(`${viewName}-view`).classList.add('active');
    document.getElementById(`nav-${viewName}`).classList.add('active');
    
    currentView = viewName;
}

function showDashboard() {
    showView('dashboard');
    loadDashboardData();
}

function showProjects() {
    showView('projects');
    loadProjects();
}

function showOrganizations() {
    showView('organizations');
    loadOrganizations();
}

function showBilling() {
    showView('billing');
    loadBilling();
}

function showMarketplace() {
    showView('marketplace');
    loadMarketplace();
}

function showSettings() {
    showView('settings');
}

function showDocs() {
    showView('docs');
}

// Service status checking
async function checkServiceStatus() {
    const services = [
        { id: 'status-control', url: `${API_BASE}/health`, name: 'Control API' },
        { id: 'status-billing', url: `${API_BILLING}/health`, name: 'Billing API' },
        { id: 'status-marketplace', url: `${API_MARKETPLACE}/health`, name: 'Marketplace API' },
        { id: 'status-studio', url: `${STUDIO_URL}`, name: 'Studio' }
    ];

    for (const service of services) {
        const element = document.getElementById(service.id);
        if (!element) continue;
        
        try {
            const response = await fetch(service.url, { 
                method: 'GET', 
                mode: 'no-cors',
                timeout: 5000 
            });
            
            element.textContent = 'Online';
            element.className = 'status-badge status-online';
        } catch (error) {
            element.textContent = 'Offline';
            element.className = 'status-badge status-offline';
        }
    }
}

// Dashboard data loading
async function loadDashboardData() {
    try {
        // Load organizations
        await loadOrganizations();
        
        // Load projects  
        await loadProjects();
        
        // Update stats
        updateDashboardStats();
        
        // Load recent projects
        updateRecentProjects();
        
    } catch (error) {
        console.error('Error loading dashboard data:', error);
        showError('Failed to load dashboard data');
    }
}

function updateDashboardStats() {
    document.getElementById('stat-projects').textContent = projects.length;
    document.getElementById('stat-orgs').textContent = organizations.length;
    document.getElementById('stat-requests').textContent = '24.5K';
    document.getElementById('stat-status').textContent = 'Healthy';
}

function updateRecentProjects() {
    const recentProjectsEl = document.getElementById('recent-projects');
    
    if (projects.length === 0) {
        recentProjectsEl.innerHTML = `
            <p class="text-gray-500 dark:text-gray-400 text-center py-8">
                No projects yet. Create your first project to get started!
            </p>
        `;
        return;
    }
    
    const recentProjects = projects.slice(0, 5); // Show 5 most recent
    recentProjectsEl.innerHTML = recentProjects.map(project => `
        <div class="flex items-center justify-between py-3 border-b border-gray-200 dark:border-gray-700 last:border-b-0">
            <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-supabase bg-opacity-10 rounded-lg flex items-center justify-center">
                    <i class="fas fa-database text-supabase"></i>
                </div>
                <div>
                    <h4 class="font-medium">${project.name}</h4>
                    <p class="text-sm text-gray-500 dark:text-gray-400">${project.instance_id || 'No instance'}</p>
                </div>
            </div>
            <div class="flex items-center space-x-2">
                <span class="status-badge ${getStatusClass(project.status)}">${project.status}</span>
                <button onclick="openProjectStudio('${project.instance_id}')" class="text-gray-400 hover:text-supabase">
                    <i class="fas fa-external-link-alt"></i>
                </button>
            </div>
        </div>
    `).join('');
}

function getStatusClass(status) {
    switch (status) {
        case 'active': return 'status-online';
        case 'error': return 'status-offline';
        default: return 'status-checking';
    }
}

// API calls
async function apiCall(url, options = {}) {
    const config = {
        headers: {
            'Content-Type': 'application/json',
            ...(authToken && { 'Authorization': `Bearer ${authToken}` })
        },
        ...options
    };
    
    try {
        const response = await fetch(url, config);
        
        if (!response.ok) {
            if (response.status === 401) {
                // Handle authentication error
                showError('Authentication required. Please login.');
                return null;
            }
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        return await response.json();
    } catch (error) {
        console.error('API call failed:', error);
        showError(`API Error: ${error.message}`);
        return null;
    }
}

// Organizations
async function loadOrganizations() {
    try {
        const data = await apiCall(`${API_BASE}/api/organizations`);
        if (data && data.success) {
            organizations = data.organizations || [];
        } else {
            // Mock data for demo
            organizations = [
                { id: 1, name: 'Default Organization', description: 'Your default organization' }
            ];
        }
        updateOrganizationsList();
    } catch (error) {
        console.error('Error loading organizations:', error);
        organizations = [
            { id: 1, name: 'Default Organization', description: 'Your default organization' }
        ];
        updateOrganizationsList();
    }
}

function updateOrganizationsList() {
    const orgListEl = document.getElementById('organizations-list');
    if (!orgListEl) return;
    
    if (organizations.length === 0) {
        orgListEl.innerHTML = `
            <div class="text-center py-12">
                <i class="fas fa-building text-6xl text-gray-300 dark:text-gray-600 mb-4"></i>
                <h3 class="text-xl font-semibold mb-2">No organizations yet</h3>
                <p class="text-gray-500 dark:text-gray-400 mb-4">Create your first organization to get started</p>
                <button onclick="createOrgModal()" class="btn btn-primary">
                    <i class="fas fa-plus mr-2"></i>Create Organization
                </button>
            </div>
        `;
        return;
    }
    
    orgListEl.innerHTML = organizations.map(org => `
        <div class="flex items-center justify-between py-4 border-b border-gray-200 dark:border-gray-700 last:border-b-0">
            <div class="flex items-center space-x-4">
                <div class="w-12 h-12 bg-blue-100 dark:bg-blue-900 rounded-lg flex items-center justify-center">
                    <i class="fas fa-building text-blue-600 dark:text-blue-400"></i>
                </div>
                <div>
                    <h3 class="font-semibold">${org.name}</h3>
                    <p class="text-sm text-gray-500 dark:text-gray-400">${org.description || 'No description'}</p>
                </div>
            </div>
            <div class="flex items-center space-x-2">
                <button onclick="viewOrgProjects(${org.id})" class="btn btn-outline btn-sm">
                    <i class="fas fa-layer-group mr-1"></i>Projects
                </button>
                <button onclick="editOrg(${org.id})" class="text-gray-400 hover:text-supabase">
                    <i class="fas fa-edit"></i>
                </button>
            </div>
        </div>
    `).join('');
}

// Projects
async function loadProjects() {
    try {
        // Try to load projects from all organizations
        projects = [];
        for (const org of organizations) {
            const data = await apiCall(`${API_BASE}/api/organizations/${org.id}/projects`);
            if (data && data.success && data.projects) {
                projects.push(...data.projects.map(p => ({ ...p, org_id: org.id, org_name: org.name })));
            }
        }
        updateProjectsList();
    } catch (error) {
        console.error('Error loading projects:', error);
        projects = [];
        updateProjectsList();
    }
}

function updateProjectsList() {
    const projectsListEl = document.getElementById('projects-list');
    if (!projectsListEl) return;
    
    if (projects.length === 0) {
        projectsListEl.innerHTML = `
            <div class="text-center py-12">
                <i class="fas fa-layer-group text-6xl text-gray-300 dark:text-gray-600 mb-4"></i>
                <h3 class="text-xl font-semibold mb-2">No projects yet</h3>
                <p class="text-gray-500 dark:text-gray-400 mb-4">Create your first Supabase project to get started</p>
                <button onclick="createProjectModal()" class="btn btn-primary">
                    <i class="fas fa-plus mr-2"></i>Create Project
                </button>
            </div>
        `;
        return;
    }
    
    projectsListEl.innerHTML = `
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            ${projects.map(project => `
                <div class="card">
                    <div class="card-body">
                        <div class="flex items-center justify-between mb-4">
                            <div class="w-12 h-12 bg-supabase bg-opacity-10 rounded-lg flex items-center justify-center">
                                <i class="fas fa-database text-supabase"></i>
                            </div>
                            <span class="status-badge ${getStatusClass(project.status)}">${project.status}</span>
                        </div>
                        <h3 class="font-semibold mb-2">${project.name}</h3>
                        <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">${project.description || 'No description'}</p>
                        <p class="text-xs text-gray-400 mb-4">Organization: ${project.org_name}</p>
                        <div class="flex space-x-2">
                            <button onclick="openProjectStudio('${project.instance_id}')" class="btn btn-primary btn-sm flex-1">
                                <i class="fas fa-external-link-alt mr-1"></i>Open
                            </button>
                            <button onclick="manageProject('${project.id}')" class="btn btn-outline btn-sm">
                                <i class="fas fa-cog"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

// Modal functions
function createProjectModal() {
    if (organizations.length === 0) {
        showError('You need to create an organization first');
        createOrgModal();
        return;
    }
    
    document.getElementById('modal-title').textContent = 'Create New Project';
    document.getElementById('modal-body').innerHTML = `
        <form onsubmit="createProject(event)">
            <div class="space-y-4">
                <div>
                    <label class="block text-sm font-medium mb-2">Project Name</label>
                    <input type="text" id="project-name" required class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 focus:ring-2 focus:ring-supabase focus:border-transparent">
                </div>
                <div>
                    <label class="block text-sm font-medium mb-2">Description</label>
                    <textarea id="project-description" rows="3" class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 focus:ring-2 focus:ring-supabase focus:border-transparent"></textarea>
                </div>
                <div>
                    <label class="block text-sm font-medium mb-2">Organization</label>
                    <select id="project-org" required class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 focus:ring-2 focus:ring-supabase focus:border-transparent">
                        ${organizations.map(org => `<option value="${org.id}">${org.name}</option>`).join('')}
                    </select>
                </div>
                <div>
                    <label class="block text-sm font-medium mb-2">Environment</label>
                    <select id="project-environment" class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 focus:ring-2 focus:ring-supabase focus:border-transparent">
                        <option value="production">Production</option>
                        <option value="staging">Staging</option>
                        <option value="development">Development</option>
                    </select>
                </div>
            </div>
            <div class="flex justify-end space-x-3 mt-6">
                <button type="button" onclick="closeModal()" class="btn btn-secondary">Cancel</button>
                <button type="submit" class="btn btn-primary">Create Project</button>
            </div>
        </form>
    `;
    showModal();
}

function createOrgModal() {
    document.getElementById('modal-title').textContent = 'Create New Organization';
    document.getElementById('modal-body').innerHTML = `
        <form onsubmit="createOrganization(event)">
            <div class="space-y-4">
                <div>
                    <label class="block text-sm font-medium mb-2">Organization Name</label>
                    <input type="text" id="org-name" required class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 focus:ring-2 focus:ring-supabase focus:border-transparent">
                </div>
                <div>
                    <label class="block text-sm font-medium mb-2">Description</label>
                    <textarea id="org-description" rows="3" class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 focus:ring-2 focus:ring-supabase focus:border-transparent"></textarea>
                </div>
            </div>
            <div class="flex justify-end space-x-3 mt-6">
                <button type="button" onclick="closeModal()" class="btn btn-secondary">Cancel</button>
                <button type="submit" class="btn btn-primary">Create Organization</button>
            </div>
        </form>
    `;
    showModal();
}

function showModal() {
    document.getElementById('modal-overlay').classList.remove('hidden');
}

function closeModal() {
    document.getElementById('modal-overlay').classList.add('hidden');
}

// Form submissions
async function createProject(event) {
    event.preventDefault();
    
    const name = document.getElementById('project-name').value;
    const description = document.getElementById('project-description').value;
    const orgId = document.getElementById('project-org').value;
    const environment = document.getElementById('project-environment').value;
    
    try {
        showLoading('Creating project...');
        
        const data = await apiCall(`${API_BASE}/api/organizations/${orgId}/projects`, {
            method: 'POST',
            body: JSON.stringify({
                name,
                description,
                environment
            })
        });
        
        if (data && data.success) {
            showSuccess('Project created successfully!');
            closeModal();
            await loadProjects();
            await loadDashboardData();
        } else {
            showError(data?.error || 'Failed to create project');
        }
    } catch (error) {
        showError('Failed to create project: ' + error.message);
    } finally {
        hideLoading();
    }
}

async function createOrganization(event) {
    event.preventDefault();
    
    const name = document.getElementById('org-name').value;
    const description = document.getElementById('org-description').value;
    
    try {
        showLoading('Creating organization...');
        
        const data = await apiCall(`${API_BASE}/api/organizations`, {
            method: 'POST',
            body: JSON.stringify({
                name,
                description
            })
        });
        
        if (data && data.success) {
            showSuccess('Organization created successfully!');
            closeModal();
            await loadOrganizations();
            await loadDashboardData();
        } else {
            showError(data?.error || 'Failed to create organization');
        }
    } catch (error) {
        showError('Failed to create organization: ' + error.message);
    } finally {
        hideLoading();
    }
}

// Utility functions
function openStudio() {
    window.open(STUDIO_URL, '_blank');
}

function openProjectStudio(instanceId) {
    if (instanceId) {
        window.open(`${STUDIO_URL}?instance=${instanceId}`, '_blank');
    } else {
        window.open(STUDIO_URL, '_blank');
    }
}

function showError(message) {
    // Simple alert for now - could be improved with toast notifications
    alert('Error: ' + message);
}

function showSuccess(message) {
    // Simple alert for now - could be improved with toast notifications
    alert('Success: ' + message);
}

function showLoading(message) {
    // Simple implementation - could be improved
    console.log('Loading:', message);
}

function hideLoading() {
    // Simple implementation - could be improved
    console.log('Loading finished');
}

// Placeholder functions
async function loadBilling() {
    // Placeholder
    console.log('Load billing data');
}

async function loadMarketplace() {
    // Placeholder
    console.log('Load marketplace data');
}

function viewOrgProjects(orgId) {
    showProjects();
}

function editOrg(orgId) {
    showError('Edit organization feature coming soon');
}

function manageProject(projectId) {
    showError('Manage project feature coming soon');
}