# ============================================================================
# Start n8n in Development Mode with Vite Hot Reload
# ============================================================================
# This script starts BOTH backend and frontend in dev mode
# Run this in ONE PowerShell window
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting n8n Development Mode" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Kill old processes
Write-Host "Killing old processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Step 2: Set environment variables
Write-Host "`nSetting environment variables..." -ForegroundColor Yellow
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:VUE_APP_PUBLIC_PATH = "/n8nnet/"
$env:VUE_APP_URL_BASE_API = "/n8nnet/"
$env:NODE_ENV = "development"
$env:IS_VIRTUOSO_AI = "true"
$env:ELEVATE_MODE = "true"

Write-Host "  VITE_MULTI_TENANT_ENABLED = $env:VITE_MULTI_TENANT_ENABLED" -ForegroundColor Green
Write-Host "  VUE_APP_PUBLIC_PATH = $env:VUE_APP_PUBLIC_PATH" -ForegroundColor Green
Write-Host "  VUE_APP_URL_BASE_API = $env:VUE_APP_URL_BASE_API" -ForegroundColor Green
Write-Host "  NODE_ENV = $env:NODE_ENV" -ForegroundColor Green
Write-Host "  IS_VIRTUOSO_AI = $env:IS_VIRTUOSO_AI" -ForegroundColor Green
Write-Host "  ELEVATE_MODE = $env:ELEVATE_MODE" -ForegroundColor Green

# Step 3: Clear vite cache
Write-Host "`nClearing Vite cache..." -ForegroundColor Yellow
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\node_modules\.vite" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "✅ Cache cleared`n" -ForegroundColor Green

# Step 4: Reload nginx
Write-Host "Reloading nginx..." -ForegroundColor Yellow
cd C:\nginx-1.27.4
.\nginx.exe -s reload 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Nginx reloaded`n" -ForegroundColor Green
} else {
    Write-Host "⚠️ Nginx reload failed - starting fresh..." -ForegroundColor Yellow
    Start-Process .\nginx.exe -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

# Step 5: Start backend in background
Write-Host "Starting n8n backend..." -ForegroundColor Yellow
cd C:\Git\n8n-mssql
Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\START_N8N_MSSQL.ps1" -WindowStyle Normal
Write-Host "✅ Backend starting in separate window..." -ForegroundColor Green
Write-Host "   Wait for: 'n8n ready on http://localhost:5678'`n" -ForegroundColor White

# Wait for backend to start
Write-Host "Waiting 10 seconds for backend to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 6: Start Vite dev server
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting Vite Dev Server (Hot Reload)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

cd C:\Git\n8n-mssql\packages\frontend\editor-ui

Write-Host "Frontend will run on: http://localhost:8080" -ForegroundColor Green
Write-Host "Access via nginx: http://cmqacore.elevatelocal.com:5000/n8nnet/`n" -ForegroundColor Green

# Start vite (this will keep running in this window)
pnpm dev

