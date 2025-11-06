# Start n8n with MSSQL - Debug Script
# This script explicitly sets environment variables and shows connection details

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting n8n with MSSQL Support" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Load from .env file
if (Test-Path .env) {
    Write-Host "✅ Loading configuration from .env file..." -ForegroundColor Green
    Get-Content .env | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$key" -Value $value
            if ($key -notmatch "PASSWORD") {
                Write-Host "   $key = $value" -ForegroundColor Gray
            } else {
                Write-Host "   $key = ********" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
} else {
    Write-Host "❌ .env file not found! Creating it..." -ForegroundColor Red
    exit 1
}

# Verify MSSQL package
Write-Host "Checking mssql package..." -ForegroundColor Yellow
node -e "try { require('mssql'); console.log('✅ mssql package found'); } catch(e) { console.log('❌ mssql package NOT found'); process.exit(1); }"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Installing mssql package..." -ForegroundColor Red
    pnpm add mssql
}
Write-Host ""

# Show configuration
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Database Configuration:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Type:     $env:DB_TYPE" -ForegroundColor White
Write-Host "Host:     $env:DB_MSSQLDB_HOST" -ForegroundColor White
Write-Host "Port:     $env:DB_MSSQLDB_PORT" -ForegroundColor White
Write-Host "Database: $env:DB_MSSQLDB_DATABASE" -ForegroundColor White
Write-Host "User:     $env:DB_MSSQLDB_USER" -ForegroundColor White
Write-Host "Schema:   $env:DB_MSSQLDB_SCHEMA" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "🚀 Starting n8n...`n" -ForegroundColor Green
Write-Host "Watch for these messages:" -ForegroundColor Yellow
Write-Host "  - 'Database type: mssqldb' ← Should say mssqldb" -ForegroundColor Yellow
Write-Host "  - 'Database connected successfully'" -ForegroundColor Yellow
Write-Host "  - 'n8n ready on http://localhost:5678'`n" -ForegroundColor Yellow

# Start n8n
pnpm dev

