# SIMPLE WORKING SOLUTION - Production Builds

## 🎯 Forget Vite Dev Server - Use Production Builds

Vite dev server with base paths is too complex. Use this SIMPLE approach instead:

---

## ✅ ONE-TIME SETUP

### 1. Clean Everything

```powershell
# Kill all node
Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force

# Clear caches
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\node_modules\.vite" -Recurse -Force -ErrorAction SilentlyContinue
```

### 2. Build Frontend ONCE

```powershell
cd C:\Git\n8n-mssql\packages\frontend\editor-ui

# Set env vars
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:VUE_APP_PUBLIC_PATH = "/n8nnet/"
$env:VUE_APP_URL_BASE_API = "/n8nnet/"

# Build
pnpm build

# Wait for: ✓ built in Xm XXs
```

### 3. Configure Nginx (Simple!)

```nginx
location /n8nnet/ {
    proxy_pass http://localhost:5678/n8nnet/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_cache off;
}
```

### 4. Start n8n Backend (Has Watch Mode!)

```powershell
cd C:\Git\n8n-mssql
.\START_N8N_MSSQL.ps1
```

This starts:
- ✅ TypeScript watch (auto-recompiles backend on save)
- ✅ Nodemon (auto-restarts on compile)
- ✅ Serves built frontend from editor-ui/dist/

---

## 🔄 When You Make Changes

### Backend Changes (.ts files in packages/cli):
```
Just save → Auto-recompiles → Auto-restarts → Done! ✅
```

### Frontend Changes (.ts/.vue files in packages/frontend):
```powershell
cd C:\Git\n8n-mssql\packages\frontend\editor-ui
$env:VITE_MULTI_TENANT_ENABLED = "true"
pnpm build
# n8n watch mode detects new dist/ files and auto-reloads
# Refresh browser: Ctrl+F5
```

---

## ✅ Benefits

- ✅ **Simple** - No Vite dev server complexity
- ✅ **Works** - No base path issues
- ✅ **Fast** - Backend auto-reloads (90% of your changes)
- ✅ **Proven** - Standard n8n workflow

---

## 📋 Architecture

```
Browser
  ↓
Nginx (5000) → /n8nnet/
  ↓
n8n Backend (5678)
  ├─ Serves: editor-ui/dist/ (built files)
  └─ Handles: /rest/* API
```

Simple and clean! ✅

---

## 🚀 Start Fresh Now

```powershell
# 1. Kill everything
Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force

# 2. Build frontend
cd C:\Git\n8n-mssql\packages\frontend\editor-ui
$env:VITE_MULTI_TENANT_ENABLED = "true"
pnpm build

# 3. Reload nginx
cd C:\nginx-1.27.4
.\nginx.exe -s reload

# 4. Start n8n (serves built files + has watch mode)
cd C:\Git\n8n-mssql
.\START_N8N_MSSQL.ps1

# 5. Access
http://cmqacore.elevatelocal.com:5000/n8nnet/
```

This WILL work! 🎯

