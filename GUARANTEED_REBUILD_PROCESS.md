# Guaranteed Rebuild Process - Follow These Steps EXACTLY

## 🎯 Problem

Changes to environment variables don't reflect in browser because:
1. Old vite dev server still running with old env vars
2. Browser caching compiled files
3. Environment variables not picked up by vite

---

## ✅ GUARANTEED PROCESS - Follow These Steps IN ORDER

### Step 1: KILL EVERYTHING

```powershell
# Kill all node processes
Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force

# Verify all killed
Get-Process | Where-Object {$_.ProcessName -eq "node"}
# Should show nothing
```

### Step 2: DELETE VITE CACHE

```powershell
# Delete vite cache and node_modules/.vite
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\node_modules\.vite" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Git\n8n-mssql\packages\frontend\editor-ui\.vite" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ Cache deleted"
```

### Step 3: SET ENVIRONMENT VARIABLE IN CURRENT SHELL

```powershell
# Set it in THIS PowerShell session
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:VUE_APP_URL_BASE_API = "/n8nnet/"

# VERIFY it's set
Write-Host "VITE_MULTI_TENANT_ENABLED = $env:VITE_MULTI_TENANT_ENABLED"
Write-Host "VUE_APP_URL_BASE_API = $env:VUE_APP_URL_BASE_API"
```

### Step 4: BUILD FRONTEND (NOT pnpm dev)

```powershell
cd C:\Git\n8n-mssql\packages\frontend\editor-ui

# Build with environment variable
pnpm build

# Wait for: ✓ built in Xm XXs
```

### Step 5: VERIFY BUILD OUTPUT

```powershell
# Check what's in the built index.html
Select-String -Path "dist\index.html" -Pattern "VUE_APP_URL_BASE_API"

# Should show the embedded value
```

### Step 6: START N8N BACKEND

```powershell
cd C:\Git\n8n-mssql
.\START_N8N_MSSQL.ps1

# Wait for: n8n ready on http://localhost:5678
```

### Step 7: RELOAD NGINX

```powershell
cd C:\nginx-1.27.4
.\nginx.exe -s reload
```

### Step 8: CLEAR BROWSER COMPLETELY

```
1. Close ALL browser tabs
2. Ctrl + Shift + Delete
3. Clear "Cached images and files"
4. Time range: "All time"
5. Clear data
6. Close browser
7. Wait 5 seconds
8. Reopen browser
```

### Step 9: ACCESS

```
http://cmqacore.elevatelocal.com:5000/n8nnet/
```

### Step 10: VERIFY IN CONSOLE

```javascript
// Check what was actually loaded
console.log('import.meta.env:', import.meta.env);
```

Should show:
```
VITE_MULTI_TENANT_ENABLED: "true"
VUE_APP_URL_BASE_API: "/n8nnet/"
```

---

## 🚫 COMMON MISTAKES TO AVOID

1. ❌ Running `pnpm dev` instead of `pnpm build`
   - `pnpm dev` starts dev server (doesn't update dist/)
   - `pnpm build` creates production files in dist/

2. ❌ Setting env var in script but not exporting
   - Scripts set vars for themselves, not parent shell
   - Must set in PowerShell session BEFORE running build

3. ❌ Not killing old node processes
   - Old vite dev servers keep running
   - They serve old files

4. ❌ Not clearing vite cache
   - `.vite` and `node_modules/.vite` cache old builds
   - Must delete before rebuild

5. ❌ Using vite dev server (port 8080)
   - Adds complexity
   - Use built files served by n8n (port 5678)

---

## 💡 RECOMMENDED WORKFLOW

**For Development:**

Use `pnpm dev` in CLI (backend) - it auto-reloads ✅

For frontend changes:
```powershell
# ONE TIME: Set env vars
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:VUE_APP_URL_BASE_API = "/n8nnet/"

# EVERY CHANGE: Rebuild
cd C:\Git\n8n-mssql\packages\frontend\editor-ui
pnpm build

# n8n backend (pnpm dev) auto-detects new dist/ files and reloads
```

---

## 📋 Quick Reference Card

```
WHEN CHANGING FRONTEND:
1. Set env vars
2. pnpm build
3. Wait for "✓ built"
4. n8n auto-reloads
5. Hard refresh browser

WHEN CHANGING BACKEND:
1. Just save file
2. tsc-watch auto-recompiles
3. nodemon auto-restarts
4. Done!
```

---

Follow the GUARANTEED PROCESS above right now!

