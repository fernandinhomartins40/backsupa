/**
 * Context para gerenciar projetos multi-tenant
 * Integra com a API de controle sem modificar o ProjectContext existente
 */

import { createContext, useContext, useEffect, useState, ReactNode } from 'react'
import { useRouter } from 'next/router'
import { toast } from 'react-hot-toast'

import {
  controlApiAuth,
  controlApiOrganizations,
  controlApiProjects,
  ControlApiProject,
  ControlApiOrganization,
  convertControlApiProjectToStudioProject,
} from 'lib/api/controlApi'

interface MultiTenantProject extends ControlApiProject {
  // Campos convertidos para compatibilidade com Studio
  ref: string
  restUrl: string
  graphqlUrl: string
  realtimeUrl: string
  storageUrl: string
}

interface MultiTenantProjectContextValue {
  // Estado de autenticação
  isAuthenticated: boolean
  user: any | null
  
  // Estado das organizações
  organizations: ControlApiOrganization[]
  selectedOrganization: ControlApiOrganization | null
  
  // Estado dos projetos
  projects: MultiTenantProject[]
  selectedProject: MultiTenantProject | null
  currentProjectRef: string | null
  
  // Estado de carregamento
  isLoading: boolean
  isCreatingProject: boolean
  
  // Ações
  login: (email: string, password: string) => Promise<boolean>
  logout: () => Promise<void>
  selectOrganization: (org: ControlApiOrganization) => void
  selectProject: (project: MultiTenantProject) => void
  createProject: (data: { name: string; description?: string; environment?: string }) => Promise<boolean>
  deleteProject: (projectId: number) => Promise<boolean>
  refreshProjects: () => Promise<void>
  switchToProject: (projectRef: string) => void
}

const MultiTenantProjectContext = createContext<MultiTenantProjectContextValue | undefined>(undefined)

interface MultiTenantProjectProviderProps {
  children: ReactNode
}

export function MultiTenantProjectProvider({ children }: MultiTenantProjectProviderProps) {
  const router = useRouter()
  
  // Estados
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [user, setUser] = useState(null)
  const [organizations, setOrganizations] = useState<ControlApiOrganization[]>([])
  const [selectedOrganization, setSelectedOrganization] = useState<ControlApiOrganization | null>(null)
  const [projects, setProjects] = useState<MultiTenantProject[]>([])
  const [selectedProject, setSelectedProject] = useState<MultiTenantProject | null>(null)
  const [currentProjectRef, setCurrentProjectRef] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isCreatingProject, setIsCreatingProject] = useState(false)

  // Inicialização
  useEffect(() => {
    initializeAuth()
  }, [])

  // Atualizar projeto selecionado quando ref muda na URL
  useEffect(() => {
    const { ref } = router.query
    if (ref && typeof ref === 'string') {
      setCurrentProjectRef(ref)
      
      // Encontrar projeto pelo ref
      const project = projects.find(p => p.ref === ref)
      if (project && project !== selectedProject) {
        setSelectedProject(project)
      }
    }
  }, [router.query.ref, projects])

  async function initializeAuth() {
    setIsLoading(true)
    
    try {
      if (controlApiAuth.isAuthenticated()) {
        const profileData = await controlApiAuth.getProfile()
        setUser(profileData.user)
        setOrganizations(profileData.organizations)
        setIsAuthenticated(true)
        
        // Selecionar primeira organização se não há uma selecionada
        if (profileData.organizations.length > 0 && !selectedOrganization) {
          const firstOrg = profileData.organizations[0]
          setSelectedOrganization(firstOrg)
          await loadProjects(firstOrg.id)
        }
      }
    } catch (error) {
      console.error('Error initializing auth:', error)
      // Se falhar, limpar auth
      await logout()
    } finally {
      setIsLoading(false)
    }
  }

  async function login(email: string, password: string): Promise<boolean> {
    try {
      const response = await controlApiAuth.login(email, password)
      setUser(response.user)
      setIsAuthenticated(true)
      
      // Carregar organizações
      const orgsData = await controlApiOrganizations.list()
      setOrganizations(orgsData.organizations)
      
      // Selecionar primeira organização
      if (orgsData.organizations.length > 0) {
        const firstOrg = orgsData.organizations[0]
        setSelectedOrganization(firstOrg)
        await loadProjects(firstOrg.id)
      }
      
      return true
    } catch (error) {
      console.error('Login error:', error)
      toast.error('Erro ao fazer login')
      return false
    }
  }

  async function logout(): Promise<void> {
    try {
      await controlApiAuth.logout()
    } catch (error) {
      console.error('Logout error:', error)
    } finally {
      setIsAuthenticated(false)
      setUser(null)
      setOrganizations([])
      setSelectedOrganization(null)
      setProjects([])
      setSelectedProject(null)
      setCurrentProjectRef(null)
    }
  }

  async function loadProjects(orgId: number) {
    try {
      const projectsData = await controlApiProjects.list(orgId)
      
      // Converter projetos para formato compatível com Studio
      const convertedProjects: MultiTenantProject[] = projectsData.projects.map(project => ({
        ...project,
        ref: project.slug,
        restUrl: `${project.api_url}/rest/v1`,
        graphqlUrl: `${project.api_url}/graphql/v1`,
        realtimeUrl: `${project.api_url}/realtime/v1`,
        storageUrl: `${project.api_url}/storage/v1`,
      }))
      
      setProjects(convertedProjects)
      
      // Se há um projeto na URL, selecioná-lo
      if (currentProjectRef) {
        const project = convertedProjects.find(p => p.ref === currentProjectRef)
        if (project) {
          setSelectedProject(project)
        }
      }
      
    } catch (error) {
      console.error('Error loading projects:', error)
      toast.error('Erro ao carregar projetos')
    }
  }

  function selectOrganization(org: ControlApiOrganization) {
    setSelectedOrganization(org)
    setProjects([])
    setSelectedProject(null)
    loadProjects(org.id)
  }

  function selectProject(project: MultiTenantProject) {
    setSelectedProject(project)
    setCurrentProjectRef(project.ref)
  }

  async function createProject(data: { 
    name: string; 
    description?: string; 
    environment?: string 
  }): Promise<boolean> {
    if (!selectedOrganization) return false
    
    setIsCreatingProject(true)
    
    try {
      const response = await controlApiProjects.create(selectedOrganization.id, data)
      
      toast.success('Projeto criado com sucesso! Aguarde a configuração...')
      
      // Recarregar lista de projetos
      await refreshProjects()
      
      // Navegar para o novo projeto
      const newProject = projects.find(p => p.id === response.project.id)
      if (newProject) {
        switchToProject(newProject.ref)
      }
      
      return true
    } catch (error) {
      console.error('Error creating project:', error)
      toast.error('Erro ao criar projeto')
      return false
    } finally {
      setIsCreatingProject(false)
    }
  }

  async function deleteProject(projectId: number): Promise<boolean> {
    if (!selectedOrganization) return false
    
    try {
      await controlApiProjects.delete(selectedOrganization.id, projectId)
      toast.success('Projeto deletado com sucesso')
      
      // Recarregar lista de projetos
      await refreshProjects()
      
      // Se o projeto deletado estava selecionado, limpar seleção
      if (selectedProject?.id === projectId) {
        setSelectedProject(null)
        setCurrentProjectRef(null)
        router.push('/projects')
      }
      
      return true
    } catch (error) {
      console.error('Error deleting project:', error)
      toast.error('Erro ao deletar projeto')
      return false
    }
  }

  async function refreshProjects() {
    if (selectedOrganization) {
      await loadProjects(selectedOrganization.id)
    }
  }

  function switchToProject(projectRef: string) {
    router.push(`/project/${projectRef}`)
  }

  const value: MultiTenantProjectContextValue = {
    isAuthenticated,
    user,
    organizations,
    selectedOrganization,
    projects,
    selectedProject,
    currentProjectRef,
    isLoading,
    isCreatingProject,
    login,
    logout,
    selectOrganization,
    selectProject,
    createProject,
    deleteProject,
    refreshProjects,
    switchToProject,
  }

  return (
    <MultiTenantProjectContext.Provider value={value}>
      {children}
    </MultiTenantProjectContext.Provider>
  )
}

export function useMultiTenantProject() {
  const context = useContext(MultiTenantProjectContext)
  if (context === undefined) {
    throw new Error('useMultiTenantProject must be used within a MultiTenantProjectProvider')
  }
  return context
}

// Hook para compatibilidade com componentes existentes que usam useSelectedProject
export function useSelectedProjectMultiTenant() {
  const { selectedProject } = useMultiTenantProject()
  
  if (!selectedProject) return undefined
  
  // Converter para formato esperado pelo Studio
  return convertControlApiProjectToStudioProject(selectedProject)
}