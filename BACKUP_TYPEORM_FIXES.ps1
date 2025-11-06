# ============================================================================
# Backup TypeORM MSSQL Fixes
# ============================================================================
# This script backs up all modified TypeORM query builder files
# Run this BEFORE running `pnpm install` to preserve your MSSQL fixes
# ============================================================================

$backupDir = "C:\n8n-typeorm-mssql-fixes-backup"
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$versionedBackup = "$backupDir-$timestamp"

# Find the TypeORM path (it might change with version updates)
$typeormPath = Get-ChildItem -Path "C:\Git\n8n\node_modules\.pnpm" -Filter "@n8n+typeorm*" -Directory | Select-Object -First 1

if (-not $typeormPath) {
    Write-Host "❌ ERROR: Could not find @n8n/typeorm in node_modules" -ForegroundColor Red
    Write-Host "Make sure pnpm install has been run" -ForegroundColor Yellow
    exit 1
}

$queryBuilderPath = Join-Path $typeormPath.FullName "node_modules\@n8n\typeorm\query-builder"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Backup TypeORM MSSQL Fixes" -ForegroundColor Cyan  
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $queryBuilderPath" -ForegroundColor Gray
Write-Host "Backup: $backupDir" -ForegroundColor Gray
Write-Host ""

# Create backup directories
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
New-Item -ItemType Directory -Force -Path $versionedBackup | Out-Null

# List of files with MSSQL fixes
$filesToBackup = @(
    "SelectQueryBuilder.js",
    "QueryBuilder.js",
    "UpdateQueryBuilder.js",
    "InsertQueryBuilder.js",
    "DeleteQueryBuilder.js"
)

$backedUp = 0

foreach ($file in $filesToBackup) {
    $sourcePath = Join-Path $queryBuilderPath $file
    $destPath = Join-Path $backupDir $file
    $versionedPath = Join-Path $versionedBackup $file
    
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $destPath -Force
        Copy-Item $sourcePath $versionedPath -Force
        
        $fileSize = (Get-Item $sourcePath).Length
        Write-Host "  ✅ Backed up: $file ($fileSize bytes)" -ForegroundColor Green
        $backedUp++
    } else {
        Write-Host "  ⚠️  Not found: $file" -ForegroundColor Yellow
    }
}

# Create metadata file
$metadata = @{
    BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    n8nVersion = "1.119.0"
    TypeORMPath = $typeormPath.Name
    FilesBackedUp = $backedUp
} | ConvertTo-Json

$metadata | Out-File -FilePath (Join-Path $backupDir "backup-metadata.json")
$metadata | Out-File -FilePath (Join-Path $versionedBackup "backup-metadata.json")

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✅ Backup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files backed up: $backedUp/$($filesToBackup.Count)" -ForegroundColor White
Write-Host ""
Write-Host "Backup locations:" -ForegroundColor Yellow
Write-Host "  Latest: $backupDir" -ForegroundColor White
Write-Host "  Versioned: $versionedBackup" -ForegroundColor White
Write-Host ""
Write-Host "To restore: .\RESTORE_TYPEORM_FIXES.ps1" -ForegroundColor Cyan
Write-Host ""

