/**
 * Wrapper para NavigationBar que adiciona o ProjectSelector
 * Mantém a NavigationBar original intacta
 */

import NavigationBar from './NavigationBar/NavigationBar'
import { ProjectSelector } from './ProjectSelector'
import { useMultiTenantProject } from './MultiTenantProjectContext'

export default function NavigationBarWithProjectSelector() {
  const { isAuthenticated } = useMultiTenantProject()

  return (
    <div className="flex flex-col h-full">
      {/* ProjectSelector no topo se autenticado na Control API */}
      {isAuthenticated && <ProjectSelector />}
      
      {/* NavigationBar original */}
      <div className="flex-1">
        <NavigationBar />
      </div>
    </div>
  )
}