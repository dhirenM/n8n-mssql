# ============================================================================
# Restore TypeORM MSSQL Fixes
# ============================================================================
# This script restores MSSQL fixes to TypeORM query builders
# Run this AFTER `pnpm install` to reapply your MSSQL fixes
# ============================================================================

$backupDir = "C:\n8n-typeorm-mssql-fixes-backup"

# Find the TypeORM path (it might change with version updates)
$typeormPath = Get-ChildItem -Path "C:\Git\n8n-mssql\node_modules\.pnpm" -Filter "@n8n+typeorm*" -Directory | Select-Object -First 1

if (-not $typeormPath) {
    Write-Host "❌ ERROR: Could not find @n8n/typeorm in node_modules" -ForegroundColor Red
    Write-Host "Run 'pnpm install' first" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $backupDir)) {
    Write-Host "❌ ERROR: Backup directory not found: $backupDir" -ForegroundColor Red
    Write-Host "Run '.\BACKUP_TYPEORM_FIXES.ps1' first to create backups" -ForegroundColor Yellow
    exit 1
}

$queryBuilderPath = Join-Path $typeormPath.FullName "node_modules\@n8n\typeorm\query-builder"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Restore TypeORM MSSQL Fixes" -ForegroundColor Cyan  
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $backupDir" -ForegroundColor Gray
Write-Host "Target: $queryBuilderPath" -ForegroundColor Gray
Write-Host ""

# List of files to restore
$filesToRestore = @(
    "SelectQueryBuilder.js",
    "QueryBuilder.js",
    "UpdateQueryBuilder.js",
    "InsertQueryBuilder.js",
    "DeleteQueryBuilder.js"
)

$restored = 0

foreach ($file in $filesToRestore) {
    $sourcePath = Join-Path $backupDir $file
    $destPath = Join-Path $queryBuilderPath $file
    
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $destPath -Force
        
        $fileSize = (Get-Item $destPath).Length
        Write-Host "  ✅ Restored: $file ($fileSize bytes)" -ForegroundColor Green
        $restored++
    } else {
        Write-Host "  ⚠️  Backup not found: $file" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✅ Restore Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files restored: $restored/$($filesToRestore.Count)" -ForegroundColor White
Write-Host ""

# Show metadata if available
$metadataPath = Join-Path $backupDir "backup-metadata.json"
if (Test-Path $metadataPath) {
    Write-Host "Backup Information:" -ForegroundColor Yellow
    Get-Content $metadataPath | ConvertFrom-Json | Format-List
}

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Start n8n: .\START_N8N_MSSQL.ps1" -ForegroundColor White
Write-Host "  2. Test MSSQL functionality" -ForegroundColor White
Write-Host ""

