# ============================================================================
# ONE COMMAND TO REBUILD EVERYTHING AND APPLY CHANGES
# ============================================================================
# Run this EVERY TIME you make frontend changes
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "KILLING ALL PROCESSES" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Red

# Kill all node processes
Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "CLEARING CACHES" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Yellow

# Clear vite cache
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\node_modules\.vite" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\.vite" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "✅ Vite cache cleared`n"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SETTING ENVIRONMENT VARIABLES" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:VUE_APP_PUBLIC_PATH = "/n8nnet/"
$env:VUE_APP_URL_BASE_API = "/n8nnet/"
$env:IS_VIRTUOSO_AI = "true"
$env:ELEVATE_MODE = "true"

Write-Host "  VITE_MULTI_TENANT_ENABLED = $env:VITE_MULTI_TENANT_ENABLED" -ForegroundColor White
Write-Host "  VUE_APP_PUBLIC_PATH = $env:VUE_APP_PUBLIC_PATH" -ForegroundColor White
Write-Host "  VUE_APP_URL_BASE_API = $env:VUE_APP_URL_BASE_API" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "BUILDING FRONTEND" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

cd C:\Git\n8n-mssql\packages\frontend\editor-ui
pnpm build

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ BUILD FAILED!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ BUILD COMPLETE!" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RELOADING NGINX" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

cd C:\nginx-1.27.4
.\nginx.exe -s reload
Write-Host "✅ Nginx reloaded`n" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ ALL DONE!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart n8n backend: .\START_N8N_MSSQL.ps1" -ForegroundColor White
Write-Host "2. Clear browser cache (Ctrl+Shift+Delete)" -ForegroundColor White
Write-Host "3. Refresh: http://cmqacore.elevatelocal.com:5000/n8nnet/" -ForegroundColor White
Write-Host ""

