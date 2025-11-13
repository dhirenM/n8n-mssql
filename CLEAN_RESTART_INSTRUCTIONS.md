# Clean Restart Instructions

## 🔄 Steps to Apply All Fixes

### 1. Stop All Node Processes

**In PowerShell where n8n is running:**
```powershell
# Stop with Ctrl + C
# Then verify all stopped:
Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Stop-Process -Force
```

### 2. Clean Build

```powershell
cd C:\Git\n8n-mssql\packages\cli
pnpm build
```

### 3. Restart n8n

```powershell
cd C:\Git\n8n-mssql
.\START_N8N_MSSQL.ps1
```

### 4. Wait for Ready

Look for:
```
Registering settings route at: /n8nnet/rest/settings
n8n ready on http://localhost:5678
```

### 5. Test Settings

```javascript
fetch('/n8nnet/rest/settings')
  .then(r => r.json())
  .then(json => console.log('Unwrapped?:', !('data' in json), 'Has sso?:', !!json.sso));
```

### 6. Hard Refresh Browser

```
Ctrl + Shift + F5
```

---

## ✅ If Settings Return 404 Again

The controller.registry.ts changes might not be applying. Try this alternative approach:

Check backend console logs - do you see:
```
Registering settings route at: /n8nnet/rest/settings
```

If NOT, the basePath variable isn't being set correctly.

