# ==================================================
# n8n Settings Configuration for Custom JWT Authentication
# ==================================================
# This file contains all environment variable settings
# for n8n with JWT authentication and multi-tenant support
# ==================================================
# Import this file in your startup script with:
# . .\N8N_SETTINGS_FOR_JWT_AUTH.ps1
# ==================================================

Write-Host "`n[Settings] Loading JWT Auth configuration..." -ForegroundColor Cyan

# ============================================================
# Elevate Database (Multi-Tenant Central DB)
# ============================================================
$env:ELEVATE_DB_HOST = "10.242.1.65\SQL2K19"
$env:ELEVATE_DB_PORT = "1433"
$env:ELEVATE_DB_NAME = "elevate_multitenant_mssql_dev"
$env:ELEVATE_DB_USER = "elevate_multitenant_mssql_dev"
$env:ELEVATE_DB_PASSWORD = "q9Q68cKQdBFIzC"
$env:ELEVATE_DB_ENCRYPT = "false"
$env:ELEVATE_DB_TRUST_CERT = "true"
$env:ELEVATE_DB_POOL_SIZE = "5"
$env:ELEVATE_DB_CONNECTION_TIMEOUT = "20000"

# ============================================================
# .NET Core JWT Authentication Settings
# ============================================================
$env:DOTNET_AUDIENCE_ID = "b7d348cb8f204f09b17b1b2d0c951afd"
$env:DOTNET_AUDIENCE_SECRET = "fdbc6c9efcc14b2f-7299dae388174d8fb9c6ef8844"
$env:DOTNET_ISSUER = "qMCdFDQuF23RV1Y-1Gq9L3cF3VmuFwVbam4fMTdAfpo"
$env:DOTNET_SYMMETRIC_KEY = "414e1927a3884f68abc79f7283837fd1"
$env:USE_DOTNET_JWT = "true"

# JWT User Default Roles (FULL ACCESS for Elevate mode)
# NOTE: Using admin roles gives JWT users full access to everything
#       .NET API handles authorization, so n8n just needs to work
# TODO: Change to 'global:member' and 'project:editor' later to restrict access
$env:JWT_USER_DEFAULT_ROLE = "global:admin"      # Global role (full system access)
$env:JWT_USER_PROJECT_ROLE = "project:admin"     # Project role (full project access)

# ============================================================
# Multi-Tenant Settings
# ============================================================
$env:ENABLE_MULTI_TENANT = "true"
$env:DEFAULT_SUBDOMAIN = "pmgroup"
$env:ELEVATE_PASSPHRASE = '22582f1f1$66jjddlasmq1'  # Use single quotes to preserve $ character

# ============================================================
# Voyager Database Configuration (Fallback/CLI)
# ============================================================
# In multi-tenant mode, these are NOT used for HTTP requests
# They come from Elevate DB per subdomain dynamically
# These settings are only for CLI commands or configuration templates
$env:DB_TYPE = "mssqldb"
$env:DB_MSSQLDB_HOST = "10.242.218.73"
$env:DB_MSSQLDB_PORT = "1433"
$env:DB_MSSQLDB_DATABASE = "dmnen_test"
$env:DB_MSSQLDB_USER = "qa"
$env:DB_MSSQLDB_PASSWORD = "bestqateam"
$env:DB_MSSQLDB_SCHEMA = "n8n"
$env:DB_MSSQLDB_POOL_SIZE = "10"
$env:DB_MSSQLDB_CONNECTION_TIMEOUT = "20000"
$env:DB_MSSQLDB_ENCRYPT = "false"
$env:DB_MSSQLDB_TRUST_SERVER_CERTIFICATE = "true"

# ============================================================
# n8n Base URL Configuration
# ============================================================
$env:N8N_PATH = "/n8nnet/"                   # Base path for UI and API (trailing slash required!)
$env:N8N_EDITOR_BASE_URL = "http://localhost:5678/n8nnet"
$env:WEBHOOK_URL = "http://localhost:5678"   # Webhooks remain at root

# ============================================================
# Security Settings (Development)
# ============================================================
# Disable secure cookies (we're using HTTP not HTTPS)
# IMPORTANT: In production with HTTPS, set this to "true"
$env:N8N_SECURE_COOKIE = "false"

# Verify the setting
Write-Host "[Settings] N8N_SECURE_COOKIE = $env:N8N_SECURE_COOKIE" -ForegroundColor $(if ($env:N8N_SECURE_COOKIE -eq "false") { "Green" } else { "Red" })

# ============================================================
# Additional n8n Settings
# ============================================================
$env:N8N_RUNNERS_ENABLED = "false"
$env:N8N_BLOCK_ENV_ACCESS_IN_NODE = "false"
$env:N8N_GIT_NODE_DISABLE_BARE_REPOS = "true"

# Push connection settings (for real-time updates)
# TEMPORARY: Use SSE instead of WebSocket to bypass frontend initialization bug
$env:N8N_PUSH_BACKEND = "sse"  # Use SSE (works around frontend bug)
# TODO: Change back to "websocket" after frontend is rebuilt properly

# Skip migrations since schema is already created manually in SQL Server
$env:N8N_SKIP_MIGRATIONS = "true"

# Disable enterprise features that use LIMIT queries (temporary workaround)
$env:N8N_LICENSE_AUTO_RENEW_ENABLED = "false"
$env:N8N_LICENSE_AUTO_RENEW_OFFSET = "0"

# ============================================================
# Frontend Environment Variables
# ============================================================
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:IS_VIRTUOSO_AI = "false"
$env:ELEVATE_MODE = "true"

# ============================================================
# Logging Configuration (for debugging JWT and SQL issues)
# ============================================================
$env:N8N_LOG_LEVEL = "debug"  # Options: error, warn, info, debug
$env:N8N_LOG_OUTPUT = "console"  # Options: console, file

# ============================================================
# Disable Non-Essential Features (Reduces Errors)
# ============================================================
# Disable PostHog analytics (causes 500 errors, not needed for Elevate mode)
$env:N8N_DIAGNOSTICS_ENABLED = "false"

# Disable telemetry (usage tracking to n8n servers, not needed)
$env:N8N_TELEMETRY_ENABLED = "false"

# Disable personalization surveys (not relevant for Elevate mode)
$env:N8N_PERSONALIZATION_ENABLED = "false"

# Disable version notifications (optional - checks for n8n updates)
$env:N8N_VERSION_NOTIFICATIONS_ENABLED = "false"

# Disable data tables module (optional feature, causes 403 without proper scopes)
# Data tables are a newer feature not essential for workflow automation
$env:N8N_ACTIVE_MODULES = ""  # Empty = disable optional modules

# Enable TypeORM SQL query logging (helps debug MSSQL syntax errors)
$env:TYPEORM_LOGGING = "true"  # Shows all SQL queries
$env:DB_LOGGING_ENABLED = "true"  # Alternative logging flag

# Optional: Skip JWT issuer/audience validation for debugging
# $env:SKIP_JWT_ISSUER_AUDIENCE_CHECK = "true"

# ============================================================
# Optional Settings (Uncomment if needed)
# ============================================================
# Disable MFA if it interferes with JWT authentication
# $env:N8N_MFA_ENABLED = "false"

Write-Host "[Settings] ✓ JWT Auth configuration loaded" -ForegroundColor Green
Write-Host "[Settings] ✓ Multi-tenant mode enabled" -ForegroundColor Green
Write-Host "[Settings] ✓ Secure cookies disabled (HTTP mode)" -ForegroundColor Green
Write-Host "[Settings] ✓ Push backend set to SSE`n" -ForegroundColor Green

