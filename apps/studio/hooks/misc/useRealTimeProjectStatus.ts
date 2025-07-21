import { useEffect, useState, useRef } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'

import { controlApiSystem } from 'lib/api/controlApi'

export interface ProjectHealthStatus {
  overall_health: 'healthy' | 'degraded' | 'unhealthy'
  services: {
    database: 'healthy' | 'degraded' | 'unhealthy'
    api: 'healthy' | 'degraded' | 'unhealthy'
    storage: 'healthy' | 'degraded' | 'unhealthy'
    realtime: 'healthy' | 'degraded' | 'unhealthy'
  }
  last_updated: string
}

export interface UseRealTimeProjectStatusProps {
  orgId: number
  projectId: number
  enabled?: boolean
  pollingInterval?: number // em ms, default: 30s
}

export const useRealTimeProjectStatus = ({ 
  orgId, 
  projectId, 
  enabled = true,
  pollingInterval = 30000 
}: UseRealTimeProjectStatusProps) => {
  const queryClient = useQueryClient()
  const intervalRef = useRef<NodeJS.Timeout>()
  const [isConnected, setIsConnected] = useState(true)
  const [lastUpdate, setLastUpdate] = useState<Date>()

  // Query base para health status
  const {
    data: healthStatus,
    isLoading,
    error,
    refetch: refetchHealth,
  } = useQuery({
    queryKey: ['project-health', orgId, projectId],
    queryFn: () => controlApiSystem.getProjectHealth(orgId, projectId),
    enabled: enabled && !!orgId && !!projectId,
    staleTime: pollingInterval - 1000, // Sempre considerado stale pouco antes do próximo poll
    retry: 3,
    retryDelay: 5000,
  })

  // Função para atualizar dados
  const updateStatus = async () => {
    if (!enabled || !orgId || !projectId) return

    try {
      await refetchHealth()
      setIsConnected(true)
      setLastUpdate(new Date())
    } catch (error) {
      console.warn('Failed to update project status:', error)
      setIsConnected(false)
    }
  }

  // Setup polling
  useEffect(() => {
    if (!enabled || !orgId || !projectId) {
      return
    }

    // Limpar interval existente
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
    }

    // Setup novo polling
    intervalRef.current = setInterval(updateStatus, pollingInterval)

    // Cleanup
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
      }
    }
  }, [enabled, orgId, projectId, pollingInterval])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
      }
    }
  }, [])

  // Função para forçar refresh imediato
  const forceRefresh = async () => {
    await updateStatus()
  }

  // Função para parar polling
  const stopPolling = () => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
      intervalRef.current = undefined
    }
  }

  // Função para reiniciar polling
  const startPolling = () => {
    if (!intervalRef.current && enabled) {
      intervalRef.current = setInterval(updateStatus, pollingInterval)
    }
  }

  // Status helpers
  const isHealthy = healthStatus?.overall_health === 'healthy'
  const isDegraded = healthStatus?.overall_health === 'degraded'
  const isUnhealthy = healthStatus?.overall_health === 'unhealthy'

  // Services status breakdown
  const servicesStatus = healthStatus?.services || {}
  const healthyServices = Object.values(servicesStatus).filter(s => s === 'healthy').length
  const totalServices = Object.keys(servicesStatus).length
  const healthPercentage = totalServices > 0 ? Math.round((healthyServices / totalServices) * 100) : 0

  // Determine status color
  const getStatusColor = () => {
    if (isHealthy) return 'green'
    if (isDegraded) return 'yellow'
    if (isUnhealthy) return 'red'
    return 'gray'
  }

  // Get status icon
  const getStatusIcon = () => {
    if (isHealthy) return '✅'
    if (isDegraded) return '⚠️'
    if (isUnhealthy) return '❌'
    return '❓'
  }

  // Get status text
  const getStatusText = () => {
    if (isHealthy) return 'Saudável'
    if (isDegraded) return 'Degradado'
    if (isUnhealthy) return 'Não Saudável'
    return 'Desconhecido'
  }

  return {
    // Core data
    healthStatus,
    
    // Loading states
    isLoading,
    isPolling: !!intervalRef.current,
    isConnected,
    lastUpdate,
    
    // Error state
    error,
    
    // Actions
    forceRefresh,
    stopPolling,
    startPolling,
    
    // Status helpers
    isHealthy,
    isDegraded,
    isUnhealthy,
    healthPercentage,
    servicesStatus,
    
    // UI helpers
    statusColor: getStatusColor(),
    statusIcon: getStatusIcon(),
    statusText: getStatusText(),
    
    // Computed
    hasIssues: isDegraded || isUnhealthy,
    criticalIssues: isUnhealthy,
  }
}

export default useRealTimeProjectStatus