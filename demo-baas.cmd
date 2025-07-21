@echo off
echo ==========================================
echo    BaaS Supabase Clone - DEMONSTRACAO
echo ==========================================
echo.

echo [INFO] Verificando Node.js...
node --version
if errorlevel 1 (
    echo [ERROR] Node.js nao encontrado!
    pause
    exit /b 1
)

echo.
echo [INFO] Iniciando APIs do BaaS...
echo.

echo [1/3] Iniciando Billing API (porta 3002)...
cd /d "%~dp0docker\billing-system\billing-api"
start "Billing API" cmd /k "npm start"

timeout /t 3 /nobreak >nul

echo [2/3] Iniciando Marketplace API (porta 3003)...
cd /d "%~dp0docker\billing-system\marketplace"
start "Marketplace API" cmd /k "npm start"

timeout /t 3 /nobreak >nul

echo [3/3] Iniciando Control API (porta 3001)...
cd /d "%~dp0docker\control-api"
start "Control API" cmd /k "npm start"

timeout /t 5 /nobreak >nul

echo.
echo ==========================================
echo           SISTEMA INICIADO!
echo ==========================================
echo.
echo URLs de acesso:
echo   Billing API:     http://localhost:3002/health
echo   Marketplace API: http://localhost:3003/health  
echo   Control API:     http://localhost:3001/health
echo.
echo Endpoints uteis:
echo   Planos:          http://localhost:3002/api/plans
echo   Templates:       http://localhost:3003/api/templates
echo   Categorias:      http://localhost:3003/api/categories
echo.
echo [INFO] As APIs estao rodando em janelas separadas
echo [INFO] Feche as janelas para parar os servicos
echo.
pause