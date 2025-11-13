# Simple Startup Guide - Production Ready

## 🎯 Simple Architecture

```
Browser (cmqacore.elevatelocal.com:5000)
  ↓
Nginx (port 5000)
  └─ /n8nnet/* → n8n Backend (port 5678)
      ├─ Serves built frontend files
      └─ Handles all API requests
```

---

## 🚀 Startup Steps

### 1. Build Frontend (One Time)

```powershell
cd C:\Git\n8n-mssql\packages\frontend\editor-ui
$env:VITE_MULTI_TENANT_ENABLED = "true"
pnpm build
```

Wait for: `✓ built in Xm XXs`

### 2. Start n8n Backend

```powershell
cd C:\Git\n8n-mssql
.\START_N8N_MSSQL.ps1
```

Wait for: `n8n ready on http://localhost:5678`

### 3. Start/Reload Nginx

```powershell
cd C:\nginx-1.27.4
.\nginx.exe -s reload
# OR if not running:
.\nginx.exe
```

### 4. Access

```
http://cmqacore.elevatelocal.com:5000/n8nnet/
```

---

## ✅ Expected Result

**Console:**
```
🔒 Multi-tenant mode enabled - using custom JWT authentication
[Axios Interceptor] Custom auth headers: {
  Authorization: '***',
  Role: 'Virtuoso Central',
  Database: 'CMQA6'
}
```

**Behavior:**
- All requests go to `http://localhost:5678/n8nnet/*`
- Headers included in every request
- No caching issues

---

## 🔄 When You Make Code Changes

**Frontend changes:**
```powershell
cd C:\Git\n8n-mssql\packages\frontend\editor-ui
$env:VITE_MULTI_TENANT_ENABLED = "true"
pnpm build  # Rebuild

# n8n auto-reloads and serves new files
```

**Backend changes:**
```
# Just save - pnpm dev auto-reloads!
```

---

Simple and works! ✅

