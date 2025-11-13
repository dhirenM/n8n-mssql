# ==================================================
# Start n8n with MSSQL - GUARANTEED TO WORK
# ==================================================
# This script loads configuration and starts n8n
# Run this script to start n8n with MSSQL every time
# ==================================================
# PREREQUISITE: Run ELEVATE_MODE_PREREQUISITES.sql
#               on each tenant database (Voyager) FIRST!
# ==================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "n8n with MSSQL Startup Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "⚠️  IMPORTANT: Before first run on a tenant database:" -ForegroundColor Yellow
Write-Host "   Run ELEVATE_MODE_PREREQUISITES.sql on the Voyager database" -ForegroundColor Yellow
Write-Host "   This creates the default 'n8nnet' project and required roles`n" -ForegroundColor Yellow

# ============================================================
# Load Configuration
# ============================================================
Write-Host "Loading configuration..." -ForegroundColor Yellow

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import all JWT auth and database settings
. "$scriptDir\N8N_SETTINGS_FOR_JWT_AUTH.ps1"

# ============================================================
# Display Configuration Summary
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Database:" -ForegroundColor Yellow
Write-Host "  DB_TYPE = $env:DB_TYPE" -ForegroundColor White
Write-Host "  DB_MSSQLDB_HOST = $env:DB_MSSQLDB_HOST" -ForegroundColor White  
Write-Host "  DB_MSSQLDB_DATABASE = $env:DB_MSSQLDB_DATABASE" -ForegroundColor White
Write-Host "  DB_MSSQLDB_USER = $env:DB_MSSQLDB_USER" -ForegroundColor White
Write-Host "  DB_MSSQLDB_PASSWORD = ********" -ForegroundColor White
Write-Host "  DB_MSSQLDB_SCHEMA = $env:DB_MSSQLDB_SCHEMA" -ForegroundColor White
Write-Host ""

Write-Host "Authentication:" -ForegroundColor Yellow
Write-Host "  USE_DOTNET_JWT = $env:USE_DOTNET_JWT" -ForegroundColor White
Write-Host "  JWT_USER_DEFAULT_ROLE = $env:JWT_USER_DEFAULT_ROLE" -ForegroundColor White
Write-Host "  JWT_USER_PROJECT_ROLE = $env:JWT_USER_PROJECT_ROLE" -ForegroundColor White
Write-Host ""

Write-Host "Multi-Tenant:" -ForegroundColor Yellow
Write-Host "  ENABLE_MULTI_TENANT = $env:ENABLE_MULTI_TENANT" -ForegroundColor White
Write-Host "  DEFAULT_SUBDOMAIN = $env:DEFAULT_SUBDOMAIN" -ForegroundColor White
Write-Host ""

Write-Host "Connection:" -ForegroundColor Yellow
Write-Host "  N8N_PUSH_BACKEND = $env:N8N_PUSH_BACKEND" -ForegroundColor White
Write-Host "  N8N_SECURE_COOKIE = $env:N8N_SECURE_COOKIE" -ForegroundColor White
Write-Host "  N8N_SKIP_MIGRATIONS = $env:N8N_SKIP_MIGRATIONS" -ForegroundColor White
Write-Host ""

# ============================================================
# Start n8n
# ============================================================
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
cd C:\Git\n8n-mssql\packages\cli
pnpm dev
