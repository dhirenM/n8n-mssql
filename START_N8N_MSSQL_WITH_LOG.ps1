# ==================================================
# Start n8n with MSSQL - WITH FULL LOGGING
# ==================================================
# This script logs all output to a file so you can review it
# ==================================================

$logFile = "C:\Git\n8n\n8n-mssql-startup.log"

# Function to log to both console and file
function Write-Log {
    param($Message, $Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $Message | Out-File -FilePath $logFile -Append
}

# Start logging
"========================================" | Out-File -FilePath $logFile
"n8n MSSQL Startup Log - $(Get-Date)" | Out-File -FilePath $logFile  
"========================================" | Out-File -FilePath $logFile

Write-Log "`n========================================" "Cyan"
Write-Log "n8n with MSSQL Startup Script" "Cyan"
Write-Log "========================================`n" "Cyan"
Write-Log "Log file: $logFile" "Gray"
Write-Log ""

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

# Enable SQL query logging to debug errors
$env:DB_LOGGING_ENABLED = "true"
$env:DB_LOGGING_OPTIONS = "all"
$env:DB_LOGGING_MAX_EXECUTION_TIME = "0"

# Disable enterprise features that use LIMIT queries (temporary workaround)
$env:N8N_LICENSE_AUTO_RENEW_ENABLED = "false"
$env:N8N_LICENSE_AUTO_RENEW_OFFSET = "0"

Write-Log "Environment Variables Set:" "Green"
Write-Log "  DB_TYPE = $env:DB_TYPE" "White"
Write-Log "  DB_MSSQLDB_HOST = $env:DB_MSSQLDB_HOST" "White"
Write-Log "  DB_MSSQLDB_DATABASE = $env:DB_MSSQLDB_DATABASE" "White"
Write-Log "  DB_MSSQLDB_USER = $env:DB_MSSQLDB_USER" "White"
Write-Log "  DB_MSSQLDB_PASSWORD = ********" "White"
Write-Log ""

Write-Log "========================================" "Cyan"
Write-Log "Starting n8n..." "Cyan"
Write-Log "========================================" "Cyan"
Write-Log ""

Write-Log "Watch for:" "Yellow"
Write-Log "  ✅ 'Database type: mssqldb'" "Gray"
Write-Log "  ✅ 'n8n ready on http://localhost:5678'" "Gray"  
Write-Log "  ❌ NO 'DB_SQLITE_POOL_SIZE' warnings" "Gray"
Write-Log "  ❌ NO 'json data type not supported' errors" "Gray"
Write-Log ""

Write-Log "Output is being logged to: $logFile" "Cyan"
Write-Log "You can review it anytime with: Get-Content $logFile`n" "Cyan"

# Navigate to CLI directory and start
cd C:\Git\n8n\packages\cli

# Start n8n and capture output to both console and log file
pnpm dev 2>&1 | Tee-Object -FilePath $logFile -Append

