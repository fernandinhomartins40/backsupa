/**
 * Seletor de projetos multi-tenant
 * Mantém o design system existente do Supabase
 */

import { useState } from 'react'
import { ChevronDown, Plus, Building, Loader2, ExternalLink } from 'lucide-react'
import { useMultiTenantProject } from './MultiTenantProjectContext'
import {
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Badge,
  cn,
} from 'ui'

export function ProjectSelector() {
  const {
    organizations,
    selectedOrganization,
    projects,
    selectedProject,
    isLoading,
    selectOrganization,
    switchToProject,
  } = useMultiTenantProject()

  const [isOpen, setIsOpen] = useState(false)
  const [showNewProjectModal, setShowNewProjectModal] = useState(false)

  // Status badge component
  function StatusBadge({ status }: { status: string }) {
    const statusConfig = {
      creating: { color: 'yellow', text: 'Criando' },
      active: { color: 'green', text: 'Ativo' },
      paused: { color: 'gray', text: 'Pausado' },
      error: { color: 'red', text: 'Erro' },
      deleting: { color: 'red', text: 'Deletando' },
    }

    const config = statusConfig[status as keyof typeof statusConfig] || statusConfig.error

    return (
      <Badge
        variant={config.color === 'green' ? 'default' : 'secondary'}
        className={cn(
          'text-xs',
          config.color === 'yellow' && 'bg-yellow-100 text-yellow-800',
          config.color === 'red' && 'bg-red-100 text-red-800',
          config.color === 'gray' && 'bg-gray-100 text-gray-800'
        )}
      >
        {config.text}
      </Badge>
    )
  }

  if (isLoading) {
    return (
      <div className="border-b border-gray-200 p-4">
        <div className="flex items-center space-x-2">
          <Loader2 className="h-4 w-4 animate-spin" />
          <span className="text-sm text-gray-500">Carregando projetos...</span>
        </div>
      </div>
    )
  }

  if (!selectedOrganization) {
    return (
      <div className="border-b border-gray-200 p-4">
        <div className="text-sm text-gray-500">Nenhuma organização selecionada</div>
      </div>
    )
  }

  return (
    <>
      <div className="border-b border-gray-200 p-4 space-y-3">
        {/* Seletor de organização */}
        <div>
          <label className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2 block">
            Organização
          </label>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button 
                variant="outline" 
                className="w-full justify-between h-9 px-3"
                size="sm"
              >
                <div className="flex items-center space-x-2">
                  <Building className="h-4 w-4 text-gray-400" />
                  <span className="truncate">{selectedOrganization.name}</span>
                </div>
                <ChevronDown className="h-4 w-4 text-gray-400" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="w-64">
              {organizations.map((org) => (
                <DropdownMenuItem
                  key={org.id}
                  onClick={() => selectOrganization(org)}
                  className={cn(
                    'flex items-center justify-between',
                    selectedOrganization?.id === org.id && 'bg-gray-50'
                  )}
                >
                  <div className="flex items-center space-x-2">
                    <Building className="h-4 w-4 text-gray-400" />
                    <span>{org.name}</span>
                  </div>
                  <Badge variant="secondary" className="text-xs">
                    {org.project_count} projeto{org.project_count !== 1 ? 's' : ''}
                  </Badge>
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {/* Seletor de projeto */}
        <div>
          <label className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2 block">
            Projeto
          </label>
          
          {projects.length === 0 ? (
            <div className="text-center py-4">
              <p className="text-sm text-gray-500 mb-3">
                Nenhum projeto nesta organização
              </p>
              <Button 
                onClick={() => setShowNewProjectModal(true)}
                size="sm"
                className="w-full"
              >
                <Plus className="h-4 w-4 mr-2" />
                Criar primeiro projeto
              </Button>
            </div>
          ) : (
            <>
              <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
                <DropdownMenuTrigger asChild>
                  <Button 
                    variant="outline" 
                    className="w-full justify-between h-auto p-3"
                  >
                    {selectedProject ? (
                      <div className="flex items-center justify-between w-full">
                        <div className="text-left">
                          <div className="font-medium text-sm">{selectedProject.name}</div>
                          <div className="text-xs text-gray-500 flex items-center space-x-2">
                            <span>{selectedProject.subdomain}</span>
                            <StatusBadge status={selectedProject.status} />
                          </div>
                        </div>
                        <ChevronDown className="h-4 w-4 text-gray-400 flex-shrink-0" />
                      </div>
                    ) : (
                      <div className="flex items-center justify-between w-full">
                        <span className="text-gray-500">Selecionar projeto</span>
                        <ChevronDown className="h-4 w-4 text-gray-400" />
                      </div>
                    )}
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent className="w-80">
                  {projects.map((project) => (
                    <DropdownMenuItem
                      key={project.id}
                      onClick={() => {
                        switchToProject(project.ref)
                        setIsOpen(false)
                      }}
                      className={cn(
                        'flex items-center justify-between p-3',
                        selectedProject?.id === project.id && 'bg-gray-50'
                      )}
                    >
                      <div className="flex-1">
                        <div className="font-medium text-sm">{project.name}</div>
                        <div className="text-xs text-gray-500 flex items-center space-x-2 mt-1">
                          <span>{project.subdomain}</span>
                          <StatusBadge status={project.status} />
                        </div>
                        <div className="text-xs text-gray-400 mt-1">
                          {project.environment}
                        </div>
                      </div>
                      <ExternalLink className="h-3 w-3 text-gray-400 ml-2" />
                    </DropdownMenuItem>
                  ))}
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    onClick={() => {
                      setShowNewProjectModal(true)
                      setIsOpen(false)
                    }}
                    className="text-green-600"
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    Novo projeto
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>

              {/* Botão de novo projeto */}
              <Button 
                onClick={() => setShowNewProjectModal(true)}
                variant="outline"
                size="sm"
                className="w-full mt-2"
              >
                <Plus className="h-4 w-4 mr-2" />
                Novo projeto
              </Button>
            </>
          )}
        </div>
      </div>

      {/* Modal de novo projeto */}
      {showNewProjectModal && (
        <NewProjectModal
          isOpen={showNewProjectModal}
          onClose={() => setShowNewProjectModal(false)}
        />
      )}
    </>
  )
}

/**
 * Modal para criar novo projeto
 */
function NewProjectModal({ 
  isOpen, 
  onClose 
}: { 
  isOpen: boolean
  onClose: () => void 
}) {
  const { createProject, isCreatingProject } = useMultiTenantProject()
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    environment: 'production' as 'production' | 'staging' | 'development',
  })

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    
    if (!formData.name.trim()) return

    const success = await createProject(formData)
    if (success) {
      onClose()
      setFormData({ name: '', description: '', environment: 'production' })
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div className="p-6">
          <h2 className="text-lg font-semibold mb-4">Criar novo projeto</h2>
          
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Nome do projeto *
              </label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="Ex: Minha App"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                required
                disabled={isCreatingProject}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Descrição (opcional)
              </label>
              <textarea
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="Descreva o que seu projeto faz..."
                rows={3}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                disabled={isCreatingProject}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Ambiente
              </label>
              <select
                value={formData.environment}
                onChange={(e) => setFormData({ 
                  ...formData, 
                  environment: e.target.value as 'production' | 'staging' | 'development' 
                })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                disabled={isCreatingProject}
              >
                <option value="production">Produção</option>
                <option value="staging">Staging</option>
                <option value="development">Desenvolvimento</option>
              </select>
            </div>

            <div className="flex space-x-3 pt-4">
              <Button
                type="button"
                variant="outline"
                onClick={onClose}
                disabled={isCreatingProject}
                className="flex-1"
              >
                Cancelar
              </Button>
              <Button
                type="submit"
                disabled={!formData.name.trim() || isCreatingProject}
                className="flex-1"
              >
                {isCreatingProject ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Criando...
                  </>
                ) : (
                  'Criar projeto'
                )}
              </Button>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}