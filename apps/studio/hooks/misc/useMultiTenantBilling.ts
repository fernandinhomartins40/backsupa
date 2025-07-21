import { useCallback } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

import { controlApiBilling, type Usage } from 'lib/api/controlApi'
import { useMultiTenantOrgSubscriptionQuery } from 'data/subscriptions/org-subscription-multitenant-query'
import { subscriptionKeys } from 'data/subscriptions/keys'
import { useQuery } from '@tanstack/react-query'

export interface UseMultiTenantBillingProps {
  orgId?: number
}

export const useMultiTenantBilling = ({ orgId }: UseMultiTenantBillingProps = {}) => {
  const queryClient = useQueryClient()

  // Query para subscription
  const {
    data: subscription,
    isLoading: isLoadingSubscription,
    error: subscriptionError,
    refetch: refetchSubscription,
  } = useMultiTenantOrgSubscriptionQuery({ orgId }, {
    enabled: !!orgId,
  })

  // Query para usage
  const {
    data: usage,
    isLoading: isLoadingUsage,
    error: usageError,
    refetch: refetchUsage,
  } = useQuery({
    queryKey: ['multi-tenant-billing', 'usage', orgId],
    queryFn: () => controlApiBilling.getUsage(orgId!),
    enabled: !!orgId,
    staleTime: 5 * 60 * 1000, // 5 minutos
  })

  // Query para invoices
  const {
    data: invoices,
    isLoading: isLoadingInvoices,
    error: invoicesError,
  } = useQuery({
    queryKey: ['multi-tenant-billing', 'invoices', orgId],
    queryFn: () => controlApiBilling.getInvoices(orgId!),
    enabled: !!orgId,
    staleTime: 10 * 60 * 1000, // 10 minutos
  })

  // Mutation para atualizar plano
  const updatePlanMutation = useMutation({
    mutationFn: ({ planId }: { planId: string }) => 
      controlApiBilling.updatePlan(orgId!, planId),
    onSuccess: () => {
      toast.success('Plano atualizado com sucesso')
      
      // Invalidar queries relacionadas
      queryClient.invalidateQueries({
        queryKey: subscriptionKeys.multiTenantOrgSubscription(orgId)
      })
      queryClient.invalidateQueries({
        queryKey: ['multi-tenant-billing', 'usage', orgId]
      })
    },
    onError: (error: any) => {
      toast.error(`Erro ao atualizar plano: ${error.message}`)
    },
  })

  // Mutation para criar checkout session
  const createCheckoutMutation = useMutation({
    mutationFn: ({ planId }: { planId: string }) =>
      controlApiBilling.createCheckoutSession(orgId!, planId),
    onSuccess: (data) => {
      // Redirecionar para checkout do Stripe
      window.location.href = data.checkout_url
    },
    onError: (error: any) => {
      toast.error(`Erro ao criar checkout: ${error.message}`)
    },
  })

  // Função para atualizar plano
  const updatePlan = useCallback((planId: string) => {
    if (!orgId) {
      toast.error('ID da organização não fornecido')
      return
    }
    updatePlanMutation.mutate({ planId })
  }, [orgId, updatePlanMutation])

  // Função para iniciar checkout
  const startCheckout = useCallback((planId: string) => {
    if (!orgId) {
      toast.error('ID da organização não fornecido')
      return
    }
    createCheckoutMutation.mutate({ planId })
  }, [orgId, createCheckoutMutation])

  // Função para refresh de dados
  const refresh = useCallback(() => {
    refetchSubscription()
    refetchUsage()
  }, [refetchSubscription, refetchUsage])

  // Calcular porcentagens de uso
  const usagePercentages = subscription && usage ? {
    apiRequests: subscription.limits.api_requests > 0 
      ? Math.round((usage.api_requests / subscription.limits.api_requests) * 100)
      : 0,
    storage: subscription.limits.storage_gb > 0
      ? Math.round((usage.storage_gb / subscription.limits.storage_gb) * 100)
      : 0,
    bandwidth: subscription.limits.bandwidth_gb > 0
      ? Math.round((usage.bandwidth_gb / subscription.limits.bandwidth_gb) * 100)
      : 0,
  } : null

  // Status geral
  const isLoading = isLoadingSubscription || isLoadingUsage || isLoadingInvoices
  const hasError = subscriptionError || usageError || invoicesError
  const isUpdatingPlan = updatePlanMutation.isPending
  const isCreatingCheckout = createCheckoutMutation.isPending

  return {
    // Data
    subscription,
    usage,
    invoices: invoices?.invoices,
    usagePercentages,
    
    // Loading states
    isLoading,
    isLoadingSubscription,
    isLoadingUsage,
    isLoadingInvoices,
    isUpdatingPlan,
    isCreatingCheckout,
    
    // Error states
    hasError,
    subscriptionError,
    usageError,
    invoicesError,
    
    // Actions
    updatePlan,
    startCheckout,
    refresh,
    
    // Computed states
    isOverUsage: usagePercentages ? Object.values(usagePercentages).some(p => p > 100) : false,
    isNearLimit: usagePercentages ? Object.values(usagePercentages).some(p => p > 80) : false,
  }
}

export default useMultiTenantBilling