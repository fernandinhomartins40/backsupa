/**
 * Configurações de billing integradas com sistema multi-tenant
 * Combina billing original do Supabase com billing multi-tenant
 */

import { useEffect, useState } from 'react'
import { useParams } from 'common'
import { Loader } from 'components/ui/Loading'
import { useMultiTenantBilling } from 'hooks/misc/useMultiTenantBilling'
import { useSelectedOrganization } from 'hooks/misc/useSelectedOrganization'

// Componentes de billing existentes
import { BillingSettingsProvider } from './BillingSettings.utils'
import Subscription from './Subscription/Subscription'
import PaymentMethods from './PaymentMethods/PaymentMethods'
import BillingBreakdown from './BillingBreakdown/BillingBreakdown'

import { Alert, AlertDescription } from 'ui'
import { ExternalLink, AlertTriangle, CreditCard, BarChart3 } from 'lucide-react'

const BillingSettings = () => {
  const { panel } = useParams()
  const selectedOrganization = useSelectedOrganization()
  const [activePanel, setActivePanel] = useState('subscriptionPlan')

  // Multi-tenant billing hook
  const {
    subscription: mtSubscription,
    usage: mtUsage,
    usagePercentages,
    isLoading: isMtLoading,
    hasError: hasMtError,
    isOverUsage,
    isNearLimit,
    refresh: refreshMtBilling
  } = useMultiTenantBilling({ 
    orgId: selectedOrganization?.id 
  })

  // Sincronizar panel ativo
  useEffect(() => {
    if (panel && typeof panel === 'string') {
      setActivePanel(panel)
    }
  }, [panel])

  if (!selectedOrganization) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader />
      </div>
    )
  }

  if (isMtLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="text-center">
          <Loader />
          <p className="text-sm text-foreground-light mt-2">
            Carregando configurações de billing...
          </p>
        </div>
      </div>
    )
  }

  return (
    <BillingSettingsProvider>
      <div className="space-y-6">
        {/* Multi-tenant billing alerts */}
        {hasMtError && (
          <Alert variant="destructive">
            <AlertTriangle className="h-4 w-4" />
            <AlertDescription>
              Erro ao carregar informações de billing multi-tenant. 
              Algumas funcionalidades podem estar limitadas.
            </AlertDescription>
          </Alert>
        )}

        {isOverUsage && (
          <Alert variant="destructive">
            <AlertTriangle className="h-4 w-4" />
            <AlertDescription>
              Você ultrapassou os limites do seu plano atual. 
              Considere fazer upgrade para evitar interrupções no serviço.
            </AlertDescription>
          </Alert>
        )}

        {isNearLimit && !isOverUsage && (
          <Alert>
            <BarChart3 className="h-4 w-4" />
            <AlertDescription>
              Você está próximo dos limites do seu plano. 
              Monitore seu uso ou considere fazer upgrade.
            </AlertDescription>
          </Alert>
        )}

        {/* Multi-tenant subscription info */}
        {mtSubscription && (
          <div className="bg-surface-100 border rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center space-x-2">
                <CreditCard className="h-5 w-5 text-foreground-light" />
                <h3 className="text-lg font-medium text-foreground">
                  Plano Multi-Tenant
                </h3>
              </div>
              <div className="flex items-center space-x-2">
                <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                  mtSubscription.status === 'active' 
                    ? 'bg-green-100 text-green-800' 
                    : 'bg-red-100 text-red-800'
                }`}>
                  {mtSubscription.status === 'active' ? 'Ativo' : 'Inativo'}
                </div>
                <button 
                  onClick={refreshMtBilling}
                  className="text-xs text-foreground-light hover:text-foreground"
                >
                  Atualizar
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <p className="text-sm font-medium text-foreground mb-1">Plano Atual</p>
                <p className="text-lg font-bold text-brand">{mtSubscription.plan_name}</p>
              </div>
              <div>
                <p className="text-sm font-medium text-foreground mb-1">Período</p>
                <p className="text-sm text-foreground-light">
                  {new Date(mtSubscription.current_period_start).toLocaleDateString()} - {' '}
                  {new Date(mtSubscription.current_period_end).toLocaleDateString()}
                </p>
              </div>
              <div>
                <p className="text-sm font-medium text-foreground mb-1">Email de Cobrança</p>
                <p className="text-sm text-foreground-light">{mtSubscription.billing_email}</p>
              </div>
            </div>

            {/* Usage breakdown */}
            {mtUsage && usagePercentages && (
              <div className="mt-6 pt-6 border-t">
                <h4 className="text-sm font-medium text-foreground mb-4">Uso Atual</h4>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-foreground-light">Requisições API</span>
                      <span className="text-foreground">{usagePercentages.apiRequests}%</span>
                    </div>
                    <div className="w-full bg-surface-200 rounded-full h-2">
                      <div 
                        className={`h-2 rounded-full ${
                          usagePercentages.apiRequests > 90 ? 'bg-red-500' :
                          usagePercentages.apiRequests > 70 ? 'bg-yellow-500' : 'bg-green-500'
                        }`}
                        style={{ width: `${Math.min(usagePercentages.apiRequests, 100)}%` }}
                      />
                    </div>
                    <p className="text-xs text-foreground-light">
                      {mtUsage.api_requests.toLocaleString()} / {mtSubscription.limits.api_requests.toLocaleString()}
                    </p>
                  </div>

                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-foreground-light">Storage</span>
                      <span className="text-foreground">{usagePercentages.storage}%</span>
                    </div>
                    <div className="w-full bg-surface-200 rounded-full h-2">
                      <div 
                        className={`h-2 rounded-full ${
                          usagePercentages.storage > 90 ? 'bg-red-500' :
                          usagePercentages.storage > 70 ? 'bg-yellow-500' : 'bg-green-500'
                        }`}
                        style={{ width: `${Math.min(usagePercentages.storage, 100)}%` }}
                      />
                    </div>
                    <p className="text-xs text-foreground-light">
                      {mtUsage.storage_gb.toFixed(1)} GB / {mtSubscription.limits.storage_gb} GB
                    </p>
                  </div>

                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-foreground-light">Bandwidth</span>
                      <span className="text-foreground">{usagePercentages.bandwidth}%</span>
                    </div>
                    <div className="w-full bg-surface-200 rounded-full h-2">
                      <div 
                        className={`h-2 rounded-full ${
                          usagePercentages.bandwidth > 90 ? 'bg-red-500' :
                          usagePercentages.bandwidth > 70 ? 'bg-yellow-500' : 'bg-green-500'
                        }`}
                        style={{ width: `${Math.min(usagePercentages.bandwidth, 100)}%` }}
                      />
                    </div>
                    <p className="text-xs text-foreground-light">
                      {mtUsage.bandwidth_gb.toFixed(1)} GB / {mtSubscription.limits.bandwidth_gb} GB
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Navigation tabs */}
        <div className="border-b">
          <nav className="flex space-x-8">
            <button
              onClick={() => setActivePanel('subscriptionPlan')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activePanel === 'subscriptionPlan'
                  ? 'border-brand text-brand'
                  : 'border-transparent text-foreground-light hover:text-foreground hover:border-gray-300'
              }`}
            >
              Planos & Assinatura
            </button>
            <button
              onClick={() => setActivePanel('paymentMethods')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activePanel === 'paymentMethods'
                  ? 'border-brand text-brand'
                  : 'border-transparent text-foreground-light hover:text-foreground hover:border-gray-300'
              }`}
            >
              Métodos de Pagamento
            </button>
            <button
              onClick={() => setActivePanel('costControl')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activePanel === 'costControl'
                  ? 'border-brand text-brand'
                  : 'border-transparent text-foreground-light hover:text-foreground hover:border-gray-300'
              }`}
            >
              Controle de Custos
            </button>
          </nav>
        </div>

        {/* Panel content */}
        <div id="billing-page-top">
          {activePanel === 'subscriptionPlan' && (
            <Subscription 
              mtSubscription={mtSubscription}
              mtUsage={mtUsage}
              refreshMtBilling={refreshMtBilling}
            />
          )}
          {activePanel === 'paymentMethods' && <PaymentMethods />}
          {activePanel === 'costControl' && (
            <BillingBreakdown 
              mtUsage={mtUsage}
              mtSubscription={mtSubscription}
            />
          )}
        </div>

        {/* Footer com link para gerenciamento avançado */}
        <div className="bg-surface-100 border rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-foreground">
                Gerenciamento Avançado de Billing
              </p>
              <p className="text-xs text-foreground-light">
                Acesse o portal de billing para funcionalidades avançadas
              </p>
            </div>
            <a
              href={`${process.env.NEXT_PUBLIC_CONTROL_API_URL}/organizations/${selectedOrganization.id}/billing/portal`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-brand bg-brand/10 hover:bg-brand/20 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-brand"
            >
              Abrir Portal
              <ExternalLink className="ml-2 h-3 w-3" />
            </a>
          </div>
        </div>
      </div>
    </BillingSettingsProvider>
  )
}

export default BillingSettings