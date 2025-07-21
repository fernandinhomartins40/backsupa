/**
 * Página de criação do primeiro projeto
 * Wizard com templates básicos e integração com API de controle
 */

import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import Head from 'next/head'
import { 
  Database, 
  Globe, 
  Smartphone, 
  ShoppingCart, 
  Users, 
  FileText,
  ArrowRight, 
  Loader2,
  Check,
  ArrowLeft
} from 'lucide-react'
import { Button, Input, Card, Badge, cn } from 'ui'
import { useMultiTenantProject } from 'components/layouts/ProjectLayout/MultiTenantProjectContext'
import { controlApiProjects } from 'lib/api/controlApi'
import { useProjectTemplates } from 'hooks/misc/useProjectTemplates'
import { toast } from 'sonner'

// Templates de projeto disponíveis
const PROJECT_TEMPLATES = [
  {
    id: 'blank',
    name: 'Projeto em branco',
    description: 'Comece do zero com uma base de dados vazia',
    icon: Database,
    features: ['PostgreSQL database', 'Auth simples', 'APIs REST'],
    recommended: false
  },
  {
    id: 'web-app',
    name: 'Aplicação Web',
    description: 'Para aplicações web modernas com autenticação',
    icon: Globe,
    features: ['User management', 'Real-time subscriptions', 'File storage'],
    recommended: true
  },
  {
    id: 'mobile-app',
    name: 'App Mobile',
    description: 'Ideal para aplicativos iOS e Android',
    icon: Smartphone,
    features: ['Push notifications', 'Offline sync', 'Social auth'],
    recommended: false
  },
  {
    id: 'ecommerce',
    name: 'E-commerce',
    description: 'Loja online com carrinho e pagamentos',
    icon: ShoppingCart,
    features: ['Product catalog', 'Order management', 'Payment integration'],
    recommended: false
  },
  {
    id: 'cms',
    name: 'CMS/Blog',
    description: 'Sistema de gerenciamento de conteúdo',
    icon: FileText,
    features: ['Content editor', 'Media library', 'SEO tools'],
    recommended: false
  },
  {
    id: 'saas',
    name: 'SaaS Platform',
    description: 'Plataforma multi-tenant para SaaS',
    icon: Users,
    features: ['Multi-tenancy', 'Billing', 'Analytics'],
    recommended: false
  }
]

export default function FirstProjectPage() {
  const router = useRouter()
  const { 
    selectedOrganization,
    createProject,
    isAuthenticated,
    isLoading 
  } = useMultiTenantProject()

  const { templates: marketplaceTemplates, isLoading: loadingTemplates } = useProjectTemplates({
    filters: { featured: true }
  })

  const [currentStep, setCurrentStep] = useState(1)
  const [isCreatingProject, setIsCreatingProject] = useState(false)
  const [selectedTemplate, setSelectedTemplate] = useState('web-app')
  const [projectName, setProjectName] = useState('')
  const [error, setError] = useState('')
  const [useMarketplaceTemplate, setUseMarketplaceTemplate] = useState(false)

  // Verificar autenticação e organização
  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/onboarding/login')
    } else if (!isLoading && isAuthenticated && !selectedOrganization) {
      router.push('/onboarding/organization')
    }
  }, [isAuthenticated, selectedOrganization, isLoading, router])

  const selectedTemplateData = PROJECT_TEMPLATES.find(t => t.id === selectedTemplate)

  const handleCreateProject = async () => {
    if (!projectName.trim()) {
      setError('Nome do projeto é obrigatório')
      return
    }

    if (!selectedOrganization) {
      setError('Organização não selecionada')
      return
    }

    setIsCreatingProject(true)
    setError('')

    try {
      // Determinar template_id para marketplace templates
      const templateId = useMarketplaceTemplate ? selectedTemplate : undefined

      // Chamar Control API para criar projeto real
      const { project } = await controlApiProjects.create(selectedOrganization.id, {
        name: projectName.trim(),
        description: `Projeto criado com template: ${selectedTemplateData?.name || 'Personalizado'}`,
        environment: 'development',
        template_id: templateId
      })

      toast.success('Projeto criado com sucesso!')
      
      // Redirecionar para o projeto criado
      router.push('/projects')
    } catch (error: any) {
      console.error('Error creating project:', error)
      const errorMessage = error.message || 'Erro ao criar projeto. Tente novamente.'
      setError(errorMessage)
      toast.error(errorMessage)
    } finally {
      setIsCreatingProject(false)
    }
  }

  const handleNext = () => {
    if (currentStep === 1) {
      setCurrentStep(2)
    } else if (currentStep === 2) {
      handleCreateProject()
    }
  }

  const handleBack = () => {
    if (currentStep === 2) {
      setCurrentStep(1)
    } else {
      router.push('/onboarding/organization')
    }
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="flex items-center space-x-2">
          <Loader2 className="h-5 w-5 animate-spin" />
          <span className="text-foreground-light">Carregando...</span>
        </div>
      </div>
    )
  }

  return (
    <>
      <Head>
        <title>Criar primeiro projeto | Supabase</title>
        <meta name="description" content="Crie seu primeiro projeto Supabase" />
      </Head>

      <div className="min-h-screen bg-background py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          {/* Header */}
          <div className="text-center mb-12">
            <img
              src="/supabase-logo.svg"
              alt="Supabase"
              className="mx-auto h-12 w-auto mb-6"
            />
            <h1 className="text-3xl font-bold text-foreground mb-2">
              Crie seu primeiro projeto
            </h1>
            <p className="text-lg text-foreground-light">
              Escolha um template para começar rapidamente
            </p>
            
            {/* Organização selecionada */}
            {selectedOrganization && (
              <div className="mt-4 inline-flex items-center px-3 py-1 bg-surface-100 rounded-full">
                <span className="text-sm text-foreground-light mr-2">Organização:</span>
                <span className="text-sm font-medium text-foreground">{selectedOrganization.name}</span>
              </div>
            )}
          </div>

          {/* Progress indicator */}
          <div className="mb-8">
            <div className="flex items-center justify-center space-x-4">
              <div className={cn(
                "flex items-center justify-center w-8 h-8 rounded-full border-2",
                currentStep >= 1 ? "bg-brand border-brand text-white" : "border-border text-foreground-light"
              )}>
                {currentStep > 1 ? <Check className="h-4 w-4" /> : "1"}
              </div>
              <div className={cn(
                "h-0.5 w-12",
                currentStep >= 2 ? "bg-brand" : "bg-border"
              )} />
              <div className={cn(
                "flex items-center justify-center w-8 h-8 rounded-full border-2",
                currentStep >= 2 ? "bg-brand border-brand text-white" : "border-border text-foreground-light"
              )}>
                {currentStep > 2 ? <Check className="h-4 w-4" /> : "2"}
              </div>
            </div>
            <div className="flex justify-center mt-2 space-x-16">
              <span className={cn(
                "text-xs",
                currentStep >= 1 ? "text-foreground font-medium" : "text-foreground-light"
              )}>
                Escolher template
              </span>
              <span className={cn(
                "text-xs",
                currentStep >= 2 ? "text-foreground font-medium" : "text-foreground-light"
              )}>
                Configurar projeto
              </span>
            </div>
          </div>

          {/* Step 1: Template Selection */}
          {currentStep === 1 && (
            <div>
              <h2 className="text-xl font-semibold text-foreground mb-6 text-center">
                Escolha um template
              </h2>

              {/* Toggle entre templates básicos e marketplace */}
              <div className="flex justify-center mb-6">
                <div className="bg-surface-100 p-1 rounded-lg">
                  <Button
                    variant={!useMarketplaceTemplate ? "default" : "ghost"}
                    size="sm"
                    onClick={() => {
                      setUseMarketplaceTemplate(false)
                      setSelectedTemplate('web-app')
                    }}
                  >
                    Templates Básicos
                  </Button>
                  <Button
                    variant={useMarketplaceTemplate ? "default" : "ghost"}
                    size="sm"
                    onClick={() => {
                      setUseMarketplaceTemplate(true)
                      setSelectedTemplate(marketplaceTemplates[0]?.slug || '')
                    }}
                    disabled={loadingTemplates || marketplaceTemplates.length === 0}
                  >
                    Marketplace Templates
                  </Button>
                </div>
              </div>
              
              {/* Templates básicos */}
              {!useMarketplaceTemplate && (
                <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                  {PROJECT_TEMPLATES.map((template) => {
                    const Icon = template.icon
                    return (
                      <Card
                        key={template.id}
                        className={cn(
                          'p-6 cursor-pointer transition-all hover:border-brand',
                          selectedTemplate === template.id && !useMarketplaceTemplate && 'border-brand bg-surface-100',
                          template.recommended && 'ring-2 ring-brand/20'
                        )}
                        onClick={() => {
                          setSelectedTemplate(template.id)
                          setUseMarketplaceTemplate(false)
                        }}
                      >
                        <div className="relative">
                          {template.recommended && (
                            <Badge 
                              variant="default" 
                              className="absolute -top-2 -right-2 bg-brand text-white"
                            >
                              Recomendado
                            </Badge>
                          )}
                          
                          <div className="flex items-center mb-4">
                            <div className="p-2 bg-surface-200 rounded-lg mr-3">
                              <Icon className="h-5 w-5 text-foreground-light" />
                            </div>
                            <h3 className="font-medium text-foreground">{template.name}</h3>
                          </div>
                          
                          <p className="text-sm text-foreground-light mb-4">
                            {template.description}
                          </p>
                          
                          <div className="space-y-1">
                            {template.features.map((feature, index) => (
                              <div key={index} className="flex items-center text-xs text-foreground-light">
                                <Check className="h-3 w-3 mr-2 text-brand" />
                                {feature}
                              </div>
                            ))}
                          </div>
                        </div>
                      </Card>
                    )
                  })}
                </div>
              )}

              {/* Marketplace templates */}
              {useMarketplaceTemplate && (
                <div>
                  {loadingTemplates ? (
                    <div className="flex items-center justify-center py-12">
                      <Loader2 className="h-6 w-6 animate-spin mr-2" />
                      <span className="text-foreground-light">Carregando templates...</span>
                    </div>
                  ) : marketplaceTemplates.length === 0 ? (
                    <div className="text-center py-12">
                      <p className="text-foreground-light">Nenhum template encontrado no marketplace.</p>
                    </div>
                  ) : (
                    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                      {marketplaceTemplates.map((template) => (
                        <Card
                          key={template.slug}
                          className={cn(
                            'p-6 cursor-pointer transition-all hover:border-brand',
                            selectedTemplate === template.slug && useMarketplaceTemplate && 'border-brand bg-surface-100'
                          )}
                          onClick={() => {
                            setSelectedTemplate(template.slug)
                            setUseMarketplaceTemplate(true)
                          }}
                        >
                          <div className="relative">
                            <Badge 
                              variant="outline" 
                              className="absolute -top-2 -right-2 bg-green-100 text-green-800"
                            >
                              Marketplace
                            </Badge>
                            
                            <div className="flex items-center mb-4">
                              <div className="p-2 bg-surface-200 rounded-lg mr-3">
                                <Database className="h-5 w-5 text-foreground-light" />
                              </div>
                              <div>
                                <h3 className="font-medium text-foreground">{template.name}</h3>
                                <p className="text-xs text-foreground-light">por {template.author}</p>
                              </div>
                            </div>
                            
                            <p className="text-sm text-foreground-light mb-4">
                              {template.description}
                            </p>
                            
                            <div className="flex items-center justify-between">
                              <span className="text-xs text-foreground-light">
                                {template.downloads} downloads
                              </span>
                              <div className="flex items-center">
                                <span className="text-xs text-foreground-light mr-1">★</span>
                                <span className="text-xs text-foreground-light">{template.rating}</span>
                              </div>
                            </div>
                          </div>
                        </Card>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Step 2: Project Configuration */}
          {currentStep === 2 && (
            <div className="max-w-2xl mx-auto">
              <h2 className="text-xl font-semibold text-foreground mb-6 text-center">
                Configure seu projeto
              </h2>

              {/* Selected template summary */}
              {selectedTemplateData && (
                <Card className="p-6 mb-6 border-brand/50">
                  <div className="flex items-center mb-4">
                    <div className="p-2 bg-brand/10 rounded-lg mr-3">
                      <selectedTemplateData.icon className="h-5 w-5 text-brand" />
                    </div>
                    <div>
                      <h3 className="font-medium text-foreground">{selectedTemplateData.name}</h3>
                      <p className="text-sm text-foreground-light">{selectedTemplateData.description}</p>
                    </div>
                  </div>
                  
                  <div className="flex flex-wrap gap-2">
                    {selectedTemplateData.features.map((feature, index) => (
                      <Badge key={index} variant="outline" className="text-xs">
                        {feature}
                      </Badge>
                    ))}
                  </div>
                </Card>
              )}

              {/* Project name form */}
              <Card className="p-6">
                <div className="space-y-4">
                  <div>
                    <label htmlFor="projectName" className="block text-sm font-medium text-foreground mb-2">
                      Nome do projeto *
                    </label>
                    <Input
                      id="projectName"
                      type="text"
                      placeholder="Ex: Meu App Incrível"
                      value={projectName}
                      onChange={(e) => {
                        setProjectName(e.target.value)
                        setError('')
                      }}
                      disabled={isCreatingProject}
                      error={error}
                      className={cn(error && 'border-red-500')}
                    />
                    {error && (
                      <p className="mt-1 text-xs text-red-600">{error}</p>
                    )}
                    <p className="mt-1 text-xs text-foreground-light">
                      O nome pode ser alterado posteriormente nas configurações
                    </p>
                  </div>

                  {/* Project info */}
                  <div className="bg-surface-100 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-foreground mb-2">
                      Seu projeto incluirá:
                    </h4>
                    <ul className="space-y-1 text-sm text-foreground-light">
                      <li className="flex items-center">
                        <Check className="h-3 w-3 mr-2 text-brand" />
                        Base de dados PostgreSQL dedicada
                      </li>
                      <li className="flex items-center">
                        <Check className="h-3 w-3 mr-2 text-brand" />
                        APIs automáticas (REST & GraphQL)
                      </li>
                      <li className="flex items-center">
                        <Check className="h-3 w-3 mr-2 text-brand" />
                        Sistema de autenticação
                      </li>
                      <li className="flex items-center">
                        <Check className="h-3 w-3 mr-2 text-brand" />
                        Real-time subscriptions
                      </li>
                      <li className="flex items-center">
                        <Check className="h-3 w-3 mr-2 text-brand" />
                        Storage para arquivos
                      </li>
                    </ul>
                  </div>
                </div>
              </Card>
            </div>
          )}

          {/* Navigation buttons */}
          <div className="flex justify-between mt-8">
            <Button
              variant="outline"
              onClick={handleBack}
              disabled={isCreatingProject}
            >
              <ArrowLeft className="h-4 w-4 mr-2" />
              Voltar
            </Button>

            <Button
              onClick={handleNext}
              disabled={(!selectedTemplate && currentStep === 1) || (!projectName.trim() && currentStep === 2) || isCreatingProject}
            >
              {isCreatingProject ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Criando projeto...
                </>
              ) : currentStep === 1 ? (
                <>
                  Continuar
                  <ArrowRight className="h-4 w-4 ml-2" />
                </>
              ) : (
                'Criar projeto'
              )}
            </Button>
          </div>

          {/* Skip option for development */}
          {process.env.NODE_ENV === 'development' && (
            <div className="mt-8 text-center">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => router.push('/projects')}
              >
                Pular onboarding (dev)
              </Button>
            </div>
          )}
        </div>
      </div>
    </>
  )
}