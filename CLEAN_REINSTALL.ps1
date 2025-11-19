# Clean Reinstall Script for n8n with TypeORM MSSQL Patch
# Run this script to properly reinstall dependencies with the updated TypeORM patch

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "n8n Clean Reinstall Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Stop all node processes
Write-Host "Step 1: Stopping all Node.js processes..." -ForegroundColor Yellow
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Write-Host "✓ Node processes stopped" -ForegroundColor Green
Write-Host ""

# Remove node_modules
Write-Host "Step 2: Removing node_modules directory..." -ForegroundColor Yellow
try {
    Remove-Item -Path "node_modules" -Recurse -Force -ErrorAction Stop
    Write-Host "✓ node_modules removed" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not remove node_modules: $_" -ForegroundColor Red
    Write-Host "Please close all applications and try again, or restart your computer" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Clean pnpm store
Write-Host "Step 3: Cleaning pnpm store..." -ForegroundColor Yellow
pnpm store prune
Write-Host "✓ pnpm store cleaned" -ForegroundColor Green
Write-Host ""

# Install dependencies
Write-Host "Step 4: Installing dependencies with TypeORM patch..." -ForegroundColor Yellow
pnpm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Dependencies installed successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Installation failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Verify TypeORM patch was applied
Write-Host "Step 5: Verifying TypeORM MSSQL driver is installed..." -ForegroundColor Yellow
$sqlServerDriver = Get-ChildItem "node_modules\.pnpm" -Recurse -Filter "SqlServerDriver.js" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sqlServerDriver) {
    Write-Host "✓ SQL Server driver found: $($sqlServerDriver.FullName)" -ForegroundColor Green
    
    # Check if it has our fix
    $content = Get-Content $sqlServerDriver.FullName -Raw
    if ($content -match 'return "nvarchar"' -and $content -match 'return "max"') {
        Write-Host "✓ TypeORM patch applied correctly (ntext → nvarchar(max))" -ForegroundColor Green
    } else {
        Write-Host "⚠ SQL Server driver found but patch may not be applied correctly" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ SQL Server driver NOT found - patch was not applied!" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Clean Reinstall Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now start n8n:" -ForegroundColor White
Write-Host "  npm start" -ForegroundColor Cyan
Write-Host ""
Write-Host "Or test workflow save at:" -ForegroundColor White
Write-Host "  http://localhost:5678" -ForegroundColor Cyan
Write-Host ""

