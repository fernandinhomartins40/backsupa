#!/usr/bin/env python3
"""
Supabase Custom Exporter
Exporta métricas customizadas das instâncias Supabase para Prometheus
"""

import os
import time
import logging
import threading
from datetime import datetime
from typing import Dict, List, Optional

import docker
import psycopg2
import requests
from flask import Flask, Response
from prometheus_client import Counter, Gauge, Histogram, Info, generate_latest, CONTENT_TYPE_LATEST

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configurações
MASTER_DB_URL = os.getenv('MASTER_DB_URL', 'postgresql://postgres:postgres@host.docker.internal:5432/supabase_master')
DOCKER_HOST = os.getenv('DOCKER_HOST', 'unix:///var/run/docker.sock')
METRICS_PORT = int(os.getenv('METRICS_PORT', '9200'))
SCRAPE_INTERVAL = int(os.getenv('SCRAPE_INTERVAL', '30'))

# Métricas Prometheus
supabase_instances_total = Gauge('supabase_instances_total', 'Total number of Supabase instances')
supabase_instances_running = Gauge('supabase_instances_running', 'Number of running Supabase instances')
supabase_instances_by_org = Gauge('supabase_instances_by_org', 'Instances by organization', ['org_id', 'org_name'])
supabase_instance_uptime = Gauge('supabase_instance_uptime_seconds', 'Instance uptime in seconds', ['instance_id', 'project_name'])
supabase_instance_status = Gauge('supabase_instance_status', 'Instance status (1=running, 0=stopped)', ['instance_id', 'project_name', 'org_id'])

# Métricas de Docker
docker_containers_total = Gauge('supabase_docker_containers_total', 'Total Docker containers for Supabase')
docker_container_status = Gauge('supabase_docker_container_status', 'Container status', ['container_name', 'instance_id', 'service'])
docker_container_restart_count = Counter('supabase_docker_container_restarts_total', 'Container restart count', ['container_name', 'instance_id'])

# Métricas de recursos
instance_cpu_usage = Gauge('supabase_instance_cpu_usage_percent', 'CPU usage per instance', ['instance_id', 'project_name'])
instance_memory_usage = Gauge('supabase_instance_memory_usage_bytes', 'Memory usage per instance', ['instance_id', 'project_name'])
instance_disk_usage = Gauge('supabase_instance_disk_usage_bytes', 'Disk usage per instance', ['instance_id', 'project_name'])

# Métricas de banco de dados
database_connections = Gauge('supabase_database_connections', 'Active database connections', ['instance_id', 'project_name'])
database_size = Gauge('supabase_database_size_bytes', 'Database size in bytes', ['instance_id', 'project_name'])

# Métricas de API
api_requests_total = Counter('supabase_api_requests_total', 'Total API requests', ['instance_id', 'method', 'status'])
api_response_time = Histogram('supabase_api_response_time_seconds', 'API response time', ['instance_id'])

# Informações do sistema
system_info = Info('supabase_exporter_info', 'Information about the Supabase exporter')

class SupabaseExporter:
    def __init__(self):
        self.docker_client = None
        self.db_connection = None
        self.app = Flask(__name__)
        self.setup_routes()
        
        # Inicializar informações do sistema
        system_info.info({
            'version': '1.0.0',
            'python_version': os.sys.version,
            'start_time': datetime.now().isoformat()
        })
        
    def setup_routes(self):
        """Configurar rotas Flask"""
        @self.app.route('/metrics')
        def metrics():
            return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
            
        @self.app.route('/health')
        def health():
            return {'status': 'healthy', 'timestamp': datetime.now().isoformat()}
            
    def connect_docker(self):
        """Conectar ao Docker"""
        try:
            self.docker_client = docker.from_env()
            self.docker_client.ping()
            logger.info("Conectado ao Docker com sucesso")
            return True
        except Exception as e:
            logger.error(f"Erro ao conectar ao Docker: {e}")
            return False
            
    def connect_database(self):
        """Conectar ao banco master"""
        try:
            self.db_connection = psycopg2.connect(MASTER_DB_URL)
            logger.info("Conectado ao banco master com sucesso")
            return True
        except Exception as e:
            logger.error(f"Erro ao conectar ao banco master: {e}")
            return False
            
    def get_instances_from_db(self) -> List[Dict]:
        """Obter lista de instâncias do banco master"""
        if not self.db_connection:
            return []
            
        try:
            with self.db_connection.cursor() as cursor:
                cursor.execute("""
                    SELECT 
                        p.instance_id,
                        p.name as project_name,
                        p.organization_id,
                        o.name as org_name,
                        p.status,
                        p.subdomain,
                        p.port,
                        p.created_at
                    FROM projects p
                    LEFT JOIN organizations o ON p.organization_id = o.id
                    WHERE p.deleted_at IS NULL
                """)
                
                columns = [desc[0] for desc in cursor.description]
                return [dict(zip(columns, row)) for row in cursor.fetchall()]
                
        except Exception as e:
            logger.error(f"Erro ao consultar instâncias: {e}")
            return []
            
    def get_docker_containers(self) -> List[Dict]:
        """Obter containers Docker relacionados ao Supabase"""
        if not self.docker_client:
            return []
            
        containers = []
        try:
            for container in self.docker_client.containers.list(all=True):
                name = container.name
                
                # Filtrar apenas containers Supabase
                if any(service in name for service in ['_studio', '_kong', '_db', '_storage']):
                    # Extrair instance_id do nome do container
                    parts = name.split('_')
                    if len(parts) >= 3:
                        instance_id = '_'.join(parts[:-1])
                        service = parts[-1]
                        
                        containers.append({
                            'name': name,
                            'instance_id': instance_id,
                            'service': service,
                            'status': container.status,
                            'created': container.attrs['Created'],
                            'restart_count': container.attrs['RestartCount']
                        })
                        
        except Exception as e:
            logger.error(f"Erro ao listar containers: {e}")
            
        return containers
        
    def check_instance_health(self, subdomain: str, port: int) -> bool:
        """Verificar se uma instância está saudável"""
        try:
            url = f"http://localhost:{port}"
            response = requests.get(url, timeout=5)
            return response.status_code in [200, 302]
        except:
            return False
            
    def get_container_stats(self, container_name: str) -> Dict:
        """Obter estatísticas de um container"""
        if not self.docker_client:
            return {}
            
        try:
            container = self.docker_client.containers.get(container_name)
            if container.status != 'running':
                return {}
                
            stats = container.stats(stream=False)
            
            # Calcular uso de CPU
            cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                       stats['precpu_stats']['cpu_usage']['total_usage']
            system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                          stats['precpu_stats']['system_cpu_usage']
            cpu_percent = (cpu_delta / system_delta) * 100.0 if system_delta > 0 else 0
            
            # Uso de memória
            memory_usage = stats['memory_stats']['usage']
            memory_limit = stats['memory_stats']['limit']
            
            return {
                'cpu_percent': cpu_percent,
                'memory_usage': memory_usage,
                'memory_limit': memory_limit,
                'memory_percent': (memory_usage / memory_limit) * 100 if memory_limit > 0 else 0
            }
            
        except Exception as e:
            logger.error(f"Erro ao obter stats do container {container_name}: {e}")
            return {}
            
    def update_metrics(self):
        """Atualizar todas as métricas"""
        logger.info("Atualizando métricas...")
        
        # Obter dados
        instances = self.get_instances_from_db()
        containers = self.get_docker_containers()
        
        # Métricas básicas de instâncias
        supabase_instances_total.set(len(instances))
        
        running_count = sum(1 for inst in instances if inst['status'] == 'running')
        supabase_instances_running.set(running_count)
        
        # Métricas por organização
        org_counts = {}
        for instance in instances:
            org_id = str(instance['organization_id'])
            org_name = instance['org_name'] or f"org_{org_id}"
            org_counts[org_id] = org_counts.get(org_id, 0) + 1
            
        # Limpar métricas anteriores
        supabase_instances_by_org.clear()
        for org_id, count in org_counts.items():
            org_name = next((inst['org_name'] for inst in instances 
                           if str(inst['organization_id']) == org_id), f"org_{org_id}")
            supabase_instances_by_org.labels(org_id=org_id, org_name=org_name).set(count)
            
        # Métricas de status por instância
        supabase_instance_status.clear()
        for instance in instances:
            status_value = 1 if instance['status'] == 'running' else 0
            supabase_instance_status.labels(
                instance_id=instance['instance_id'],
                project_name=instance['project_name'],
                org_id=str(instance['organization_id'])
            ).set(status_value)
            
            # Verificar saúde da instância
            if instance['status'] == 'running' and instance['port']:
                is_healthy = self.check_instance_health(instance['subdomain'], instance['port'])
                if not is_healthy:
                    logger.warning(f"Instância {instance['instance_id']} não está respondendo")
                    
        # Métricas de containers
        docker_containers_total.set(len(containers))
        
        docker_container_status.clear()
        for container in containers:
            status_value = 1 if container['status'] == 'running' else 0
            docker_container_status.labels(
                container_name=container['name'],
                instance_id=container['instance_id'],
                service=container['service']
            ).set(status_value)
            
            # Estatísticas de recursos por container
            if container['status'] == 'running':
                stats = self.get_container_stats(container['name'])
                if stats:
                    # Associar com instância
                    instance_info = next((inst for inst in instances 
                                        if inst['instance_id'] == container['instance_id']), None)
                    if instance_info:
                        project_name = instance_info['project_name']
                        
                        if container['service'] in ['studio', 'kong']:  # Containers principais
                            instance_cpu_usage.labels(
                                instance_id=container['instance_id'],
                                project_name=project_name
                            ).set(stats['cpu_percent'])
                            
                            instance_memory_usage.labels(
                                instance_id=container['instance_id'],
                                project_name=project_name
                            ).set(stats['memory_usage'])
                            
        logger.info(f"Métricas atualizadas: {len(instances)} instâncias, {len(containers)} containers")
        
    def run_metrics_loop(self):
        """Loop principal de coleta de métricas"""
        while True:
            try:
                if not self.docker_client and not self.connect_docker():
                    logger.error("Não foi possível conectar ao Docker")
                    time.sleep(30)
                    continue
                    
                if not self.db_connection and not self.connect_database():
                    logger.warning("Não foi possível conectar ao banco master, continuando sem dados do DB")
                    
                self.update_metrics()
                time.sleep(SCRAPE_INTERVAL)
                
            except Exception as e:
                logger.error(f"Erro no loop de métricas: {e}")
                time.sleep(10)
                
    def run(self):
        """Executar o exporter"""
        logger.info(f"Iniciando Supabase Exporter na porta {METRICS_PORT}")
        
        # Iniciar thread de coleta de métricas
        metrics_thread = threading.Thread(target=self.run_metrics_loop, daemon=True)
        metrics_thread.start()
        
        # Iniciar servidor Flask
        self.app.run(host='0.0.0.0', port=METRICS_PORT, debug=False)

if __name__ == '__main__':
    exporter = SupabaseExporter()
    exporter.run()