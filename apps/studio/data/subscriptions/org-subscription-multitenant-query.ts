import { PermissionAction } from '@supabase/shared-types/out/constants'
import { useQuery, UseQueryOptions } from '@tanstack/react-query'

import { controlApiBilling, type MultiTenantSubscription } from 'lib/api/controlApi'
import { useCheckPermissions } from 'hooks/misc/useCheckPermissions'
import type { ResponseError } from 'types'
import { subscriptionKeys } from './keys'

export type MultiTenantOrgSubscriptionVariables = {
  orgId?: number
}

export async function getMultiTenantOrgSubscription(
  { orgId }: MultiTenantOrgSubscriptionVariables,
  signal?: AbortSignal
): Promise<MultiTenantSubscription> {
  if (!orgId) throw new Error('orgId is required')

  // Usar Control API em vez da Platform API
  const subscription = await controlApiBilling.getSubscription(orgId)
  return subscription
}

export type MultiTenantOrgSubscriptionData = Awaited<ReturnType<typeof getMultiTenantOrgSubscription>>
export type MultiTenantOrgSubscriptionError = ResponseError

export const useMultiTenantOrgSubscriptionQuery = <TData = MultiTenantOrgSubscriptionData>(
  { orgId }: MultiTenantOrgSubscriptionVariables,
  {
    enabled = true,
    ...options
  }: UseQueryOptions<MultiTenantOrgSubscriptionData, MultiTenantOrgSubscriptionError, TData> = {}
) => {
  const canReadSubscriptions = useCheckPermissions(
    PermissionAction.BILLING_READ,
    'stripe.subscriptions'
  )

  return useQuery<MultiTenantOrgSubscriptionData, MultiTenantOrgSubscriptionError, TData>(
    subscriptionKeys.multiTenantOrgSubscription(orgId),
    ({ signal }) => getMultiTenantOrgSubscription({ orgId }, signal),
    {
      enabled: enabled && canReadSubscriptions && typeof orgId !== 'undefined',
      staleTime: 5 * 60 * 1000, // 5 minutos
      ...options,
    }
  )
}