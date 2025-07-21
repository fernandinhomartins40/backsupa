/**
 * Integração com a API de controle multi-tenant
 * Esta API gerencia os projetos Supabase multi-tenant
 */

const CONTROL_API_URL = process.env.NEXT_PUBLIC_CONTROL_API_URL || 'http://localhost:3001'

// Tipos para a API de controle
export interface ControlApiProject {
  id: number
  name: string
  slug: string
  subdomain: string
  api_url: string
  studio_url: string
  status: 'creating' | 'active' | 'paused' | 'error' | 'deleting'
  health_status: 'healthy' | 'unhealthy' | 'unknown'
  environment: 'production' | 'staging' | 'development'
  created_at: string
  organization: {
    id: number
    name: string
    slug: string
  }
}

export interface ControlApiOrganization {
  id: number
  name: string
  slug: string
  logo_url?: string
  role: 'owner' | 'admin' | 'member'
  project_count: number
}

export interface ControlApiUser {
  id: number
  email: string
  first_name: string
  last_name: string
}

export interface AuthTokens {
  access_token: string
  refresh_token: string
  expires_in: string
}

export interface LoginResponse {
  success: true
  user: ControlApiUser
  tokens: AuthTokens
}

// Classe para gerenciar autenticação
class ControlApiAuth {
  private static instance: ControlApiAuth
  private accessToken: string | null = null
  private refreshToken: string | null = null

  static getInstance(): ControlApiAuth {
    if (!ControlApiAuth.instance) {
      ControlApiAuth.instance = new ControlApiAuth()
    }
    return ControlApiAuth.instance
  }

  constructor() {
    // Carregar tokens do localStorage se disponível
    if (typeof window !== 'undefined') {
      this.accessToken = localStorage.getItem('control_api_access_token')
      this.refreshToken = localStorage.getItem('control_api_refresh_token')
    }
  }

  setTokens(tokens: AuthTokens) {
    this.accessToken = tokens.access_token
    this.refreshToken = tokens.refresh_token
    
    if (typeof window !== 'undefined') {
      localStorage.setItem('control_api_access_token', tokens.access_token)
      localStorage.setItem('control_api_refresh_token', tokens.refresh_token)
    }
  }

  getAccessToken(): string | null {
    return this.accessToken
  }

  clearTokens() {
    this.accessToken = null
    this.refreshToken = null
    
    if (typeof window !== 'undefined') {
      localStorage.removeItem('control_api_access_token')
      localStorage.removeItem('control_api_refresh_token')
    }
  }

  async refreshAccessToken(): Promise<boolean> {
    if (!this.refreshToken) return false

    try {
      const response = await fetch(`${CONTROL_API_URL}/api/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          refresh_token: this.refreshToken,
        }),
      })

      if (response.ok) {
        const data = await response.json()
        this.setTokens(data.tokens)
        return true
      }
    } catch (error) {
      console.error('Error refreshing token:', error)
    }

    return false
  }

  isAuthenticated(): boolean {
    return !!this.accessToken
  }
}

// Instância global de autenticação
const auth = ControlApiAuth.getInstance()

// Função auxiliar para fazer requisições autenticadas
async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${CONTROL_API_URL}${endpoint}`
  
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  }

  // Adicionar token de acesso se disponível
  const accessToken = auth.getAccessToken()
  if (accessToken) {
    headers['Authorization'] = `Bearer ${accessToken}`
  }

  let response = await fetch(url, {
    ...options,
    headers,
  })

  // Se token expirado, tentar renovar
  if (response.status === 401 && auth.isAuthenticated()) {
    const refreshed = await auth.refreshAccessToken()
    if (refreshed) {
      // Repetir requisição com novo token
      headers['Authorization'] = `Bearer ${auth.getAccessToken()}`
      response = await fetch(url, {
        ...options,
        headers,
      })
    }
  }

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}))
    throw new Error(errorData.error || `HTTP ${response.status}`)
  }

  return response.json()
}

// API de autenticação
export const controlApiAuth = {
  /**
   * Login do usuário
   */
  async login(email: string, password: string): Promise<LoginResponse> {
    const data = await apiRequest<LoginResponse>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })

    auth.setTokens(data.tokens)
    return data
  },

  /**
   * Logout do usuário
   */
  async logout(): Promise<void> {
    try {
      if (auth.isAuthenticated()) {
        await apiRequest('/api/auth/logout', {
          method: 'POST',
        })
      }
    } finally {
      auth.clearTokens()
    }
  },

  /**
   * Obter perfil do usuário
   */
  async getProfile(): Promise<{ user: ControlApiUser; organizations: ControlApiOrganization[] }> {
    return apiRequest('/api/auth/profile')
  },

  /**
   * Verificar se usuário está autenticado
   */
  isAuthenticated(): boolean {
    return auth.isAuthenticated()
  },
}

// API de organizações
export const controlApiOrganizations = {
  /**
   * Listar organizações do usuário
   */
  async list(): Promise<{ organizations: ControlApiOrganization[] }> {
    return apiRequest('/api/organizations')
  },

  /**
   * Obter detalhes de uma organização
   */
  async get(orgId: number): Promise<{ organization: ControlApiOrganization }> {
    return apiRequest(`/api/organizations/${orgId}`)
  },

  /**
   * Criar nova organização
   */
  async create(data: {
    name: string
    slug: string
    description?: string
  }): Promise<{ organization: ControlApiOrganization }> {
    return apiRequest('/api/organizations', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  },

  /**
   * Atualizar organização
   */
  async update(orgId: number, data: {
    name?: string
    logo_url?: string
    description?: string
  }): Promise<{ organization: ControlApiOrganization }> {
    return apiRequest(`/api/organizations/${orgId}`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    })
  },
}

// API de projetos
export const controlApiProjects = {
  /**
   * Listar projetos de uma organização
   */
  async list(orgId: number): Promise<{ projects: ControlApiProject[] }> {
    return apiRequest(`/api/organizations/${orgId}/projects`)
  },

  /**
   * Criar novo projeto
   */
  async create(
    orgId: number,
    data: {
      name: string
      description?: string
      environment?: 'production' | 'staging' | 'development'
      template_id?: string
    }
  ): Promise<{ project: ControlApiProject }> {
    return apiRequest(`/api/organizations/${orgId}/projects`, {
      method: 'POST',
      body: JSON.stringify(data),
    })
  },

  /**
   * Obter detalhes de um projeto
   */
  async get(orgId: number, projectId: number): Promise<{ project: ControlApiProject }> {
    return apiRequest(`/api/organizations/${orgId}/projects/${projectId}`)
  },

  /**
   * Verificar status de um projeto
   */
  async getStatus(orgId: number, projectId: number): Promise<{ status: any }> {
    return apiRequest(`/api/organizations/${orgId}/projects/${projectId}/status`)
  },

  /**
   * Deletar projeto
   */
  async delete(orgId: number, projectId: number): Promise<void> {
    return apiRequest(`/api/organizations/${orgId}/projects/${projectId}`, {
      method: 'DELETE',
    })
  },
}

// Helper para converter projeto da Control API para formato do Studio
export function convertControlApiProjectToStudioProject(
  controlProject: ControlApiProject
): any {
  return {
    id: controlProject.id,
    ref: controlProject.slug,
    name: controlProject.name,
    status: mapControlApiStatusToStudio(controlProject.status),
    organization_id: controlProject.organization.id,
    cloud_provider: 'FLY', // Manter compatibilidade
    region: 'fly-local', // Manter compatibilidade
    inserted_at: controlProject.created_at,
    // URLs específicas do projeto
    restUrl: `${controlProject.api_url}/rest/v1`,
    graphqlUrl: `${controlProject.api_url}/graphql/v1`,
    realtimeUrl: `${controlProject.api_url}/realtime/v1`,
    storageUrl: `${controlProject.api_url}/storage/v1`,
    // Manter campos necessários para o Studio
    subscription_tier: 'pro',
    subscription_tier_prod_id: 'tier_pro',
  }
}

function mapControlApiStatusToStudio(status: ControlApiProject['status']): string {
  const statusMap = {
    creating: 'COMING_UP',
    active: 'ACTIVE_HEALTHY',
    paused: 'PAUSED',
    error: 'INACTIVE',
    deleting: 'REMOVING',
  }
  return statusMap[status] || 'INACTIVE'
}

// API de billing multi-tenant
export interface MultiTenantSubscription {
  id: number
  plan_name: string
  plan_id: string
  status: 'active' | 'cancelled' | 'past_due' | 'unpaid'
  current_period_start: string
  current_period_end: string
  usage: {
    api_requests: number
    storage_gb: number
    bandwidth_gb: number
  }
  limits: {
    api_requests: number
    storage_gb: number
    bandwidth_gb: number
  }
  billing_email: string
}

export interface Usage {
  period_start: string
  period_end: string
  api_requests: number
  storage_gb: number
  bandwidth_gb: number
  overage_costs: number
}

export const controlApiBilling = {
  /**
   * Obter assinatura de uma organização
   */
  async getSubscription(orgId: number): Promise<MultiTenantSubscription> {
    return apiRequest(`/api/organizations/${orgId}/billing/subscription`)
  },

  /**
   * Atualizar plano de uma organização
   */
  async updatePlan(orgId: number, planId: string): Promise<void> {
    return apiRequest(`/api/organizations/${orgId}/billing/subscription`, {
      method: 'PATCH',
      body: JSON.stringify({ plan_id: planId }),
    })
  },

  /**
   * Obter métricas de uso
   */
  async getUsage(orgId: number, period: string = 'current'): Promise<Usage> {
    return apiRequest(`/api/organizations/${orgId}/billing/usage?period=${period}`)
  },

  /**
   * Obter histórico de faturas
   */
  async getInvoices(orgId: number): Promise<{ invoices: any[] }> {
    return apiRequest(`/api/organizations/${orgId}/billing/invoices`)
  },

  /**
   * Criar sessão de checkout Stripe
   */
  async createCheckoutSession(orgId: number, planId: string): Promise<{ checkout_url: string }> {
    return apiRequest(`/api/organizations/${orgId}/billing/checkout`, {
      method: 'POST',
      body: JSON.stringify({ plan_id: planId }),
    })
  },
}

// API de templates do marketplace
export interface MarketplaceTemplate {
  id: number
  name: string
  slug: string
  description: string
  category: string
  author: string
  version: string
  downloads: number
  rating: number
  screenshots: string[]
  features: string[]
  tags: string[]
}

export const controlApiTemplates = {
  /**
   * Listar templates do marketplace
   */
  async list(filters?: {
    category?: string
    search?: string
    featured?: boolean
  }): Promise<{ templates: MarketplaceTemplate[] }> {
    const params = new URLSearchParams()
    if (filters?.category) params.append('category', filters.category)
    if (filters?.search) params.append('search', filters.search)
    if (filters?.featured) params.append('featured', 'true')

    const query = params.toString() ? `?${params}` : ''
    return apiRequest(`/api/marketplace/templates${query}`)
  },

  /**
   * Obter template específico
   */
  async get(templateSlug: string): Promise<{ template: MarketplaceTemplate }> {
    return apiRequest(`/api/marketplace/templates/${templateSlug}`)
  },

  /**
   * Instalar template em um projeto
   */
  async install(templateSlug: string, projectId: number, organizationId: number): Promise<{ installation_id: string }> {
    return apiRequest(`/api/marketplace/templates/${templateSlug}/install`, {
      method: 'POST',
      body: JSON.stringify({
        project_id: projectId,
        organization_id: organizationId,
      }),
    })
  },

  /**
   * Verificar status de instalação
   */
  async getInstallationStatus(installationId: string): Promise<{
    status: 'pending' | 'installing' | 'completed' | 'failed'
    progress: number
    error_message?: string
  }> {
    return apiRequest(`/api/marketplace/installations/${installationId}/status`)
  },
}

// API de health e status
export const controlApiSystem = {
  /**
   * Status geral do sistema
   */
  async getStatus(): Promise<{
    status: 'operational' | 'degraded' | 'major_outage'
    services: Record<string, 'operational' | 'degraded' | 'down'>
  }> {
    return apiRequest('/api/system/status')
  },

  /**
   * Status específico de um projeto
   */
  async getProjectHealth(orgId: number, projectId: number): Promise<{
    overall_health: 'healthy' | 'degraded' | 'unhealthy'
    services: {
      database: 'healthy' | 'degraded' | 'unhealthy'
      api: 'healthy' | 'degraded' | 'unhealthy'
      storage: 'healthy' | 'degraded' | 'unhealthy'
      realtime: 'healthy' | 'degraded' | 'unhealthy'
    }
    last_updated: string
  }> {
    return apiRequest(`/api/organizations/${orgId}/projects/${projectId}/health`)
  },
}

export default {
  auth: controlApiAuth,
  organizations: controlApiOrganizations,
  projects: controlApiProjects,
  billing: controlApiBilling,
  templates: controlApiTemplates,
  system: controlApiSystem,
  convertControlApiProjectToStudioProject,
}