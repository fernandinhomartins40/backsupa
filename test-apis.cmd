@echo off
echo ==========================================
echo    TESTE DAS APIs BaaS Supabase Clone
echo ==========================================
echo.

echo [INFO] Testando APIs...
echo.

echo [1] Testando Billing API...
curl -s http://localhost:3002/health
if errorlevel 1 (
    echo [ERROR] Billing API nao esta respondendo
) else (
    echo [OK] Billing API funcionando
)
echo.

echo [2] Testando Marketplace API...
curl -s http://localhost:3003/health  
if errorlevel 1 (
    echo [ERROR] Marketplace API nao esta respondendo
) else (
    echo [OK] Marketplace API funcionando
)
echo.

echo [3] Testando Control API...
curl -s http://localhost:3001/health
if errorlevel 1 (
    echo [ERROR] Control API nao esta respondendo
) else (
    echo [OK] Control API funcionando
)
echo.

echo ==========================================
echo           ENDPOINTS DISPONIVEIS
echo ==========================================
echo.
echo BILLING API (porta 3002):
echo   GET /health              - Health check
echo   GET /api/plans           - Listar planos
echo   GET /api/subscription    - Subscription atual
echo   GET /api/usage           - Estatisticas de uso
echo   POST /api/checkout       - Criar checkout Stripe
echo.
echo MARKETPLACE API (porta 3003):
echo   GET /health              - Health check
echo   GET /api/categories      - Listar categorias
echo   GET /api/templates       - Listar templates
echo   GET /api/templates/:slug - Detalhes do template
echo   POST /api/templates/:slug/download - Download template
echo.
echo CONTROL API (porta 3001):
echo   GET /health              - Health check
echo   GET /api/projects        - Listar projetos
echo   POST /api/projects       - Criar projeto
echo   GET /api/system/status   - Status do sistema
echo.
pause