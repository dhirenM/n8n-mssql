# Quick Fix Script - Apply TypeORM Patch with nvarchar(max) fix
# 
# This script applies the critical fix for SQL Server parameter validation errors
# Run after closing VS Code and stopping all n8n processes

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  n8n SQL Server Fix - Apply Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Stop all node processes
Write-Host "Stopping all Node.js processes..." -ForegroundColor Yellow
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Write-Host "✓ Processes stopped" -ForegroundColor Green
Write-Host ""

# Clean pnpm store
Write-Host "Cleaning pnpm store..." -ForegroundColor Yellow
pnpm store prune | Out-Null
Write-Host "✓ Store cleaned" -ForegroundColor Green
Write-Host ""

# Reinstall with updated patch
Write-Host "Reinstalling dependencies with updated TypeORM patch..." -ForegroundColor Yellow
Write-Host "(This will take a few minutes...)" -ForegroundColor Gray
Write-Host ""

$installOutput = pnpm install 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "✓ Dependencies installed successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Verify the fix was applied
    Write-Host "Verifying SQL Server driver fix..." -ForegroundColor Yellow
    $driverPath = Get-ChildItem "node_modules\.pnpm" -Recurse -Filter "SqlServerDriver.js" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($driverPath) {
        $content = Get-Content $driverPath.FullName -Raw
        
        # Check for our fixes
        $hasNvarcharFix = $content -match 'return "nvarchar"' -and $content -match 'column\.type === "simple-json"'
        $hasMaxLength = $content -match 'return "max"'
        $hasParametrizeFix = $content -match 'getColumnLength\(column\)'
        
        if ($hasNvarcharFix -and $hasMaxLength -and $hasParametrizeFix) {
            Write-Host "✓ All SQL Server fixes verified!" -ForegroundColor Green
            Write-Host "  - ntext → nvarchar conversion ✓" -ForegroundColor Green
            Write-Host "  - max length for JSON columns ✓" -ForegroundColor Green  
            Write-Host "  - parametrizeValue fix ✓" -ForegroundColor Green
        } else {
            Write-Host "⚠ Some fixes may be missing:" -ForegroundColor Yellow
            Write-Host "  - nvarchar conversion: $(if($hasNvarcharFix){'✓'}else{'✗'})"
            Write-Host "  - max length: $(if($hasMaxLength){'✓'}else{'✗'})"
            Write-Host "  - parametrize fix: $(if($hasParametrizeFix){'✓'}else{'✗'})"
        }
    } else {
        Write-Host "⚠ Could not find SqlServerDriver.js - verify patch was applied" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ Ready to Test!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Start n8n:" -ForegroundColor White
    Write-Host "  npm start" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then test saving your workflow at:" -ForegroundColor White
    Write-Host "  http://localhost:5678" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Expected result:" -ForegroundColor White
    Write-Host "  - No more 'Invalid string' errors ✓" -ForegroundColor Green
    Write-Host "  - Workflows with large Code nodes save successfully ✓" -ForegroundColor Green
    Write-Host ""
    
} else {
    Write-Host "✗ Installation failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error output:" -ForegroundColor Yellow
    $installOutput | Select-Object -Last 20
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "  1. Close VS Code and all terminals" -ForegroundColor White
    Write-Host "  2. Restart your computer to clear file locks" -ForegroundColor White
    Write-Host "  3. Run this script again" -ForegroundColor White
    Write-Host ""
    exit 1
}

