# ============================================================================
# FINAL REBUILD - Run This Once
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "FINAL CLEAN REBUILD" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Kill everything
Write-Host "1. Killing all processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "   ✅ Done`n" -ForegroundColor Green

# 2. Clear ALL caches
Write-Host "2. Clearing caches..." -ForegroundColor Yellow
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\node_modules\.vite" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\.vite" -Recurse -Force -ErrorAction SilentlyContinue  
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\dist" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "   ✅ Done`n" -ForegroundColor Green

# 3. Set environment variables
Write-Host "3. Setting environment variables..." -ForegroundColor Yellow
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:VUE_APP_PUBLIC_PATH = "/n8nnet/"
$env:VUE_APP_URL_BASE_API = "/n8nnet/"
Write-Host "   VITE_MULTI_TENANT_ENABLED = $env:VITE_MULTI_TENANT_ENABLED" -ForegroundColor White
Write-Host "   VUE_APP_URL_BASE_API = $env:VUE_APP_URL_BASE_API" -ForegroundColor White
Write-Host "   ✅ Done`n" -ForegroundColor Green

# 4. Rebuild frontend
Write-Host "4. Building frontend (this takes ~4 minutes)..." -ForegroundColor Yellow
cd C:\Git\n8n-mssql\packages\frontend\editor-ui
pnpm build

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n   ✅ Build successful!`n" -ForegroundColor Green
} else {
    Write-Host "`n   ❌ Build failed!`n" -ForegroundColor Red
    exit 1
}

# 5. Reload nginx
# Write-Host "5. Reloading nginx..." -ForegroundColor Yellow
# cd C:\nginx-1.27.4
# .\nginx.exe -s reload
# Write-Host "   ✅ Done`n" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ REBUILD COMPLETE!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Start n8n: cd C:\Git\n8n-mssql; .\START_N8N_MSSQL.ps1" -ForegroundColor White
Write-Host "2. Clear browser cache (Ctrl+Shift+Delete)" -ForegroundColor White
Write-Host "3. Access: http://cmqacore.elevatelocal.com:5000/n8nnet/" -ForegroundColor White
Write-Host ""

