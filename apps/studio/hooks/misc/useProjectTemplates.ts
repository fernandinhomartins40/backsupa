import { useCallback, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

import { controlApiTemplates, type MarketplaceTemplate } from 'lib/api/controlApi'

export interface UseProjectTemplatesProps {
  filters?: {
    category?: string
    search?: string
    featured?: boolean
  }
}

export const useProjectTemplates = ({ filters }: UseProjectTemplatesProps = {}) => {
  const queryClient = useQueryClient()
  const [installing, setInstalling] = useState<string | null>(null)
  const [installationProgress, setInstallationProgress] = useState<Record<string, number>>({})

  // Query para listar templates
  const {
    data: templatesData,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ['marketplace', 'templates', filters],
    queryFn: () => controlApiTemplates.list(filters),
    staleTime: 5 * 60 * 1000, // 5 minutos
  })

  // Mutation para instalar template
  const installTemplateMutation = useMutation({
    mutationFn: ({ 
      templateSlug, 
      projectId, 
      organizationId 
    }: { 
      templateSlug: string
      projectId: number
      organizationId: number 
    }) => controlApiTemplates.install(templateSlug, projectId, organizationId),
    onSuccess: async (data, variables) => {
      const { installation_id } = data
      const { templateSlug } = variables
      
      setInstalling(templateSlug)
      setInstallationProgress(prev => ({ ...prev, [templateSlug]: 0 }))

      // Polling para status de instalação
      const checkStatus = async () => {
        try {
          const statusData = await controlApiTemplates.getInstallationStatus(installation_id)
          
          setInstallationProgress(prev => ({ 
            ...prev, 
            [templateSlug]: statusData.progress 
          }))

          if (statusData.status === 'completed') {
            setInstalling(null)
            setInstallationProgress(prev => {
              const newProgress = { ...prev }
              delete newProgress[templateSlug]
              return newProgress
            })
            toast.success('Template instalado com sucesso!')
            
            // Invalidar queries relacionadas aos projetos
            queryClient.invalidateQueries({ queryKey: ['projects'] })
            
          } else if (statusData.status === 'failed') {
            setInstalling(null)
            setInstallationProgress(prev => {
              const newProgress = { ...prev }
              delete newProgress[templateSlug]
              return newProgress
            })
            toast.error(`Falha na instalação: ${statusData.error_message || 'Erro desconhecido'}`)
            
          } else {
            // Continuar polling se ainda instalando
            setTimeout(checkStatus, 2000) // Check a cada 2 segundos
          }
        } catch (error: any) {
          setInstalling(null)
          setInstallationProgress(prev => {
            const newProgress = { ...prev }
            delete newProgress[templateSlug]
            return newProgress
          })
          toast.error(`Erro ao verificar status: ${error.message}`)
        }
      }

      // Iniciar polling
      setTimeout(checkStatus, 1000)
    },
    onError: (error: any) => {
      toast.error(`Erro ao iniciar instalação: ${error.message}`)
      setInstalling(null)
    },
  })

  // Função para instalar template
  const installTemplate = useCallback((
    templateSlug: string,
    projectId: number,
    organizationId: number
  ) => {
    if (installing) {
      toast.warning('Aguarde a instalação atual terminar')
      return
    }

    installTemplateMutation.mutate({
      templateSlug,
      projectId,
      organizationId,
    })
  }, [installing, installTemplateMutation])

  // Função para buscar template específico
  const getTemplate = useCallback(async (templateSlug: string): Promise<MarketplaceTemplate | null> => {
    try {
      const { template } = await controlApiTemplates.get(templateSlug)
      return template
    } catch (error) {
      console.error('Error fetching template:', error)
      return null
    }
  }, [])

  // Templates organizados por categoria
  const templatesByCategory = templatesData?.templates.reduce((acc, template) => {
    if (!acc[template.category]) {
      acc[template.category] = []
    }
    acc[template.category].push(template)
    return acc
  }, {} as Record<string, MarketplaceTemplate[]>) || {}

  // Templates em destaque
  const featuredTemplates = templatesData?.templates.filter(t => t.downloads > 100) || []

  // Templates populares
  const popularTemplates = [...(templatesData?.templates || [])]
    .sort((a, b) => b.downloads - a.downloads)
    .slice(0, 6)

  return {
    // Data
    templates: templatesData?.templates || [],
    templatesByCategory,
    featuredTemplates,
    popularTemplates,
    
    // Loading states
    isLoading,
    isInstalling: !!installing,
    currentlyInstalling: installing,
    installationProgress,
    
    // Error states
    error,
    
    // Actions
    installTemplate,
    getTemplate,
    refetch,
    
    // Computed
    hasTemplates: (templatesData?.templates.length || 0) > 0,
    categories: Object.keys(templatesByCategory),
  }
}

export default useProjectTemplates