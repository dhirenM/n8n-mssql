# ==================================================
# Start n8n with MSSQL - GUARANTEED TO WORK
# ==================================================
# This script explicitly sets environment variables
# Run this script to start n8n with MSSQL every time
# ==================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "n8n with MSSQL Startup Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Set all MSSQL environment variables explicitly
$env:DB_TYPE = "mssqldb"
$env:DB_MSSQLDB_HOST = "10.242.218.73"
$env:DB_MSSQLDB_PORT = "1433"
$env:DB_MSSQLDB_DATABASE = "dmnen_test"
$env:DB_MSSQLDB_USER = "qa"
$env:DB_MSSQLDB_PASSWORD = "bestqateam"
$env:DB_MSSQLDB_SCHEMA = "dbo"
$env:DB_MSSQLDB_POOL_SIZE = "10"
$env:DB_MSSQLDB_CONNECTION_TIMEOUT = "20000"
$env:DB_MSSQLDB_ENCRYPT = "false"
$env:DB_MSSQLDB_TRUST_SERVER_CERTIFICATE = "true"

# Additional n8n settings to suppress warnings
$env:N8N_RUNNERS_ENABLED = "false"
$env:N8N_BLOCK_ENV_ACCESS_IN_NODE = "false"
$env:N8N_GIT_NODE_DISABLE_BARE_REPOS = "true"

# Skip migrations since schema is already created manually in SQL Server
$env:N8N_SKIP_MIGRATIONS = "true"

# Disable enterprise features that use LIMIT queries (temporary workaround)
$env:N8N_LICENSE_AUTO_RENEW_ENABLED = "false"
$env:N8N_LICENSE_AUTO_RENEW_OFFSET = "0"

Write-Host "Environment Variables Set:" -ForegroundColor Green
Write-Host "  DB_TYPE = $env:DB_TYPE" -ForegroundColor White
Write-Host "  DB_MSSQLDB_HOST = $env:DB_MSSQLDB_HOST" -ForegroundColor White  
Write-Host "  DB_MSSQLDB_DATABASE = $env:DB_MSSQLDB_DATABASE" -ForegroundColor White
Write-Host "  DB_MSSQLDB_USER = $env:DB_MSSQLDB_USER" -ForegroundColor White
Write-Host "  DB_MSSQLDB_PASSWORD = ********" -ForegroundColor White
Write-Host ""

Write-Host "  N8N_SKIP_MIGRATIONS = $env:N8N_SKIP_MIGRATIONS (schema already created)" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting n8n..." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Watch for these messages in the output:" -ForegroundColor Yellow
Write-Host "  ✅ 'Database type: mssqldb' (not sqlite!)" -ForegroundColor Green
Write-Host "  ✅ 'n8n ready on http://localhost:5678'" -ForegroundColor Green
Write-Host "  ✅ 'Skipping migrations' (migrations disabled)" -ForegroundColor Green
Write-Host "  ❌ NO SQLite warnings" -ForegroundColor Red
Write-Host "  ❌ NO 'json data type' errors" -ForegroundColor Red
Write-Host ""
Write-Host "All output will scroll below..." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Navigate to CLI directory and start
cd C:\Git\n8n\packages\cli
pnpm dev

