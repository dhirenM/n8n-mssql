# ============================================================================
# Start Vite Dev Server for n8n Frontend
# ============================================================================
# Run this in a separate PowerShell window
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting n8n Frontend Dev Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Navigate to editor-ui
cd C:\Git\n8n-mssql\packages\frontend\editor-ui

# Set environment variables  
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:VUE_APP_PUBLIC_PATH = "/n8nnet/"
$env:VUE_APP_URL_BASE_API = "/n8nnet/"  # API requests need /n8nnet/ prefix
$env:NODE_ENV = "development"  # Important for vite base path logic
$env:IS_VIRTUOSO_AI = "true"
$env:ELEVATE_MODE = "true"

Write-Host "Environment Variables:" -ForegroundColor Green
Write-Host "  VITE_MULTI_TENANT_ENABLED = $env:VITE_MULTI_TENANT_ENABLED" -ForegroundColor White
Write-Host "  VUE_APP_PUBLIC_PATH = $env:VUE_APP_PUBLIC_PATH" -ForegroundColor White
Write-Host "  VUE_APP_URL_BASE_API = $env:VUE_APP_URL_BASE_API" -ForegroundColor White
Write-Host "  NODE_ENV = $env:NODE_ENV" -ForegroundColor White
Write-Host "  IS_VIRTUOSO_AI = $env:IS_VIRTUOSO_AI" -ForegroundColor White
Write-Host "  ELEVATE_MODE = $env:ELEVATE_MODE" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Vite Dev Server Configuration:" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Host: 0.0.0.0" -ForegroundColor White
Write-Host "  Port: 8080" -ForegroundColor White
Write-Host "  Allowed Hosts: cmqacore.elevatelocal.com" -ForegroundColor White
Write-Host "  API Proxy: /n8nnet/rest/* → localhost:5678" -ForegroundColor White
Write-Host "  Hot Reload: Enabled ✅" -ForegroundColor Green
Write-Host "`n========================================`n" -ForegroundColor Yellow

Write-Host "Starting Vite Dev Server..." -ForegroundColor Cyan
Write-Host "Access via: http://cmqacore.elevatelocal.com:5000/n8nnet/`n" -ForegroundColor Green

# Start vite dev server
pnpm dev

