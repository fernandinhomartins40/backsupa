export const subscriptionKeys = {
  orgSubscription: (orgSlug: string | undefined) =>
    ['organizations', orgSlug, 'subscription'] as const,
  multiTenantOrgSubscription: (orgId: number | undefined) =>
    ['organizations', orgId, 'multi-tenant-subscription'] as const,
  orgPlans: (orgSlug: string | undefined) => ['organizations', orgSlug, 'plans'] as const,

  addons: (projectRef: string | undefined) => ['projects', projectRef, 'addons'] as const,
}
