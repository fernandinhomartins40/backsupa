/**
 * Página de criação/seleção de organização
 * Usa o design system existente do Supabase
 */

import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import Head from 'next/head'
import { Building, Plus, ArrowRight, Loader2 } from 'lucide-react'
import { Button, Input, Card, Badge, cn } from 'ui'
import { useMultiTenantProject } from 'components/layouts/ProjectLayout/MultiTenantProjectContext'
import { controlApiOrganizations } from 'lib/api/controlApi'
import { toast } from 'sonner'

export default function OrganizationPage() {
  const router = useRouter()
  const { 
    organizations, 
    selectedOrganization, 
    selectOrganization,
    isLoading,
    isAuthenticated 
  } = useMultiTenantProject()

  const [showCreateForm, setShowCreateForm] = useState(false)
  const [isCreatingOrg, setIsCreatingOrg] = useState(false)
  const [orgName, setOrgName] = useState('')
  const [error, setError] = useState('')

  // Verificar autenticação
  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/onboarding/login')
    }
  }, [isAuthenticated, isLoading, router])

  // Se já tem organizações, mostrar seleção
  const hasOrganizations = organizations.length > 0

  const handleSelectOrganization = (org: any) => {
    selectOrganization(org)
    router.push('/onboarding/first-project')
  }

  const handleCreateOrganization = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!orgName.trim()) {
      setError('Nome da organização é obrigatório')
      return
    }

    setIsCreatingOrg(true)
    setError('')

    try {
      // Criar slug a partir do nome
      const slug = orgName.toLowerCase()
        .replace(/[^a-z0-9]/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '')

      // Chamar Control API para criar organização real
      const { organization } = await controlApiOrganizations.create({
        name: orgName.trim(),
        slug: slug,
        description: `Organização ${orgName.trim()}`
      })

      toast.success('Organização criada com sucesso!')
      
      // Selecionar a organização criada
      selectOrganization(organization)
      
      // Redirecionar para criação do primeiro projeto
      router.push('/onboarding/first-project')
    } catch (error: any) {
      console.error('Error creating organization:', error)
      const errorMessage = error.message || 'Erro ao criar organização. Tente novamente.'
      setError(errorMessage)
      toast.error(errorMessage)
    } finally {
      setIsCreatingOrg(false)
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
        <title>Organização | Supabase</title>
        <meta name="description" content="Selecione ou crie uma organização" />
      </Head>

      <div className="min-h-screen bg-background py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto">
          {/* Header */}
          <div className="text-center mb-12">
            <img
              src="/supabase-logo.svg"
              alt="Supabase"
              className="mx-auto h-12 w-auto mb-6"
            />
            <h1 className="text-3xl font-bold text-foreground mb-2">
              {hasOrganizations ? 'Selecione uma organização' : 'Crie sua organização'}
            </h1>
            <p className="text-lg text-foreground-light">
              {hasOrganizations 
                ? 'Escolha uma organização para continuar ou crie uma nova'
                : 'Uma organização agrupa seus projetos e equipe'
              }
            </p>
          </div>

          {/* Organizations list */}
          {hasOrganizations && (
            <div className="mb-8">
              <h2 className="text-lg font-medium text-foreground mb-4">
                Suas organizações
              </h2>
              <div className="grid gap-4 md:grid-cols-2">
                {organizations.map((org) => (
                  <Card
                    key={org.id}
                    className={cn(
                      'p-6 cursor-pointer transition-all hover:border-brand',
                      selectedOrganization?.id === org.id && 'border-brand bg-surface-100'
                    )}
                    onClick={() => handleSelectOrganization(org)}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <div className="p-2 bg-surface-200 rounded-lg">
                          <Building className="h-5 w-5 text-foreground-light" />
                        </div>
                        <div>
                          <h3 className="font-medium text-foreground">{org.name}</h3>
                          <p className="text-sm text-foreground-light">
                            {org.project_count} projeto{org.project_count !== 1 ? 's' : ''}
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center space-x-2">
                        <Badge variant="outline">
                          {org.role}
                        </Badge>
                        <ArrowRight className="h-4 w-4 text-foreground-light" />
                      </div>
                    </div>
                  </Card>
                ))}
              </div>

              {/* Divider */}
              <div className="my-8 relative">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-border" />
                </div>
                <div className="relative flex justify-center text-sm">
                  <span className="px-4 bg-background text-foreground-light">ou</span>
                </div>
              </div>
            </div>
          )}

          {/* Create organization section */}
          <div>
            {!showCreateForm ? (
              <Card className="p-6 border-2 border-dashed border-border hover:border-brand transition-colors">
                <div className="text-center">
                  <div className="p-3 bg-surface-100 rounded-full w-fit mx-auto mb-4">
                    <Plus className="h-6 w-6 text-foreground-light" />
                  </div>
                  <h3 className="text-lg font-medium text-foreground mb-2">
                    Criar nova organização
                  </h3>
                  <p className="text-foreground-light mb-6">
                    Crie uma organização para gerenciar seus projetos e equipe
                  </p>
                  <Button onClick={() => setShowCreateForm(true)}>
                    <Plus className="h-4 w-4 mr-2" />
                    Nova organização
                  </Button>
                </div>
              </Card>
            ) : (
              <Card className="p-6">
                <h3 className="text-lg font-medium text-foreground mb-4">
                  Criar organização
                </h3>
                
                <form onSubmit={handleCreateOrganization} className="space-y-4">
                  <div>
                    <label htmlFor="orgName" className="block text-sm font-medium text-foreground mb-2">
                      Nome da organização *
                    </label>
                    <Input
                      id="orgName"
                      type="text"
                      placeholder="Ex: Minha Empresa"
                      value={orgName}
                      onChange={(e) => {
                        setOrgName(e.target.value)
                        setError('')
                      }}
                      disabled={isCreatingOrg}
                      error={error}
                      className={cn(error && 'border-red-500')}
                    />
                    {error && (
                      <p className="mt-1 text-xs text-red-600">{error}</p>
                    )}
                  </div>

                  <div className="flex space-x-3">
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => {
                        setShowCreateForm(false)
                        setOrgName('')
                        setError('')
                      }}
                      disabled={isCreatingOrg}
                    >
                      Cancelar
                    </Button>
                    <Button
                      type="submit"
                      disabled={!orgName.trim() || isCreatingOrg}
                    >
                      {isCreatingOrg ? (
                        <>
                          <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                          Criando...
                        </>
                      ) : (
                        'Criar organização'
                      )}
                    </Button>
                  </div>
                </form>
              </Card>
            )}
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