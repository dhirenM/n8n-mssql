# Debug Push Connection Issue

## Quick Diagnostics

### Step 1: Check Browser Console

Press **F12** in your browser and look at the **Console** tab for errors related to:
- WebSocket connection
- `/push` endpoint
- Connection refused
- 401/403/404 errors

**Look for messages like:**
```
WebSocket connection to 'ws://...' failed
Failed to construct 'WebSocket': ...
/rest/push returned 404
```

### Step 2: Check Network Tab

In browser F12 → **Network** tab:
1. Filter by "WS" (WebSocket)
2. Look for `/push` connection
3. Check the status code and response

**Expected:**
- Request URL: `ws://cmqacore.elevatelocal.com:5000/n8nnet/rest/push?pushRef=...`
- Status: 101 Switching Protocols (success)

**If you see:**
- 404 → Push endpoint not registered at correct path
- 401/403 → Authentication failing on push endpoint
- Failed → WebSocket not working through nginx

### Step 3: Check Backend Logs

In the terminal running n8n, look for:
```
[Node] Listening on /n8nnet/rest/push
[Node] WebSocket upgrade request for /n8nnet/rest/push
[Node] Push connection established
```

Or errors like:
```
[Node] Error: Cannot find module '/push'
[Node] 404 - /n8nnet/rest/push not found
```

---

## Common Issues & Solutions

### Issue 1: n8n Didn't Restart After server.ts Change

**Symptom:** Still seeing the error even after the fix

**Solution:**
```powershell
# Manually stop and restart
Ctrl+C

# Start again
.\START_N8N_MSSQL.ps1

# Wait for "n8n ready on http://localhost:5678"
```

### Issue 2: Nginx Not Forwarding WebSocket

**Symptom:** 502 Bad Gateway or connection refused

**Check nginx.conf:**
```nginx
location /n8nnet/ {
    proxy_pass http://localhost:5678/n8nnet/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;      # ← REQUIRED for WebSocket
    proxy_set_header Connection "upgrade";       # ← REQUIRED for WebSocket
    proxy_set_header Host $host;
}
```

**Fix:** Add the WebSocket headers to your nginx config and reload nginx.

### Issue 3: Authentication Failing on Push Endpoint

**Symptom:** Push endpoint returns 401/403

**The push endpoint requires authentication** (line 97 in push/index.ts):
```typescript
app.use(
    `/${restEndpoint}/push`,
    this.authService.createAuthMiddleware({ allowSkipMFA: false }),  // ← Auth required!
    ...
);
```

**Solution:** Make sure JWT middleware runs for `/push` endpoint.

### Issue 4: Push Backend Config Wrong

**Symptom:** Using SSE instead of WebSocket

**Check your environment:**
```powershell
$env:N8N_PUSH_BACKEND = "websocket"  # Add this if missing
```

---

## Quick Test Commands

### Test 1: Check if Push Endpoint Exists

```powershell
# Test from PowerShell
$headers = @{
    "Cookie" = "n8n-auth=your-jwt-token-here"
}

Invoke-WebRequest -Uri "http://localhost:5678/n8nnet/rest/push" -Headers $headers -Method GET
```

**Expected:** Should connect or return auth error  
**If 404:** Push endpoint not registered correctly

### Test 2: Check WebSocket from Browser Console

```javascript
// In browser console (F12)
const ws = new WebSocket('ws://cmqacore.elevatelocal.com:5000/n8nnet/rest/push?pushRef=test');
ws.onopen = () => console.log('✅ Connected');
ws.onerror = (err) => console.error('❌ Error:', err);
```

**Expected:** Should connect or show specific error  
**If fails:** WebSocket not working through nginx

---

## Systematic Debugging

Run these in order:

### 1. Verify n8n Restarted
```powershell
# Check n8n process
Get-Process | Where-Object {$_.ProcessName -like "*node*"}

# If old process still running, kill it:
Stop-Process -Name "node" -Force

# Start fresh
.\START_N8N_MSSQL.ps1
```

### 2. Check Push Endpoint Registration

Look in n8n startup logs for:
```
[Node] Push connection handler registered at: /n8nnet/rest/push
```

### 3. Enable Debug Logging

Already enabled in START_N8N_MSSQL.ps1:
```powershell
$env:N8N_LOG_LEVEL = "debug"
```

Look for push-related debug messages.

### 4. Test Direct Connection

Access directly (bypass nginx):
```
http://localhost:5678/n8nnet/
```

If this works but nginx doesn't, it's a nginx WebSocket config issue.

---

## Quick Fixes

### Fix 1: Ensure WebSocket Backend

Add to `START_N8N_MSSQL.ps1` before starting n8n:

```powershell
# Ensure WebSocket push backend
$env:N8N_PUSH_BACKEND = "websocket"
```

### Fix 2: Nginx WebSocket Support

Update your nginx config (`c:\nginx-1.27.4\conf\nginx.conf`):

```nginx
location /n8nnet/ {
    proxy_pass http://localhost:5678/n8nnet/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # WebSocket support (CRITICAL!)
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Timeouts
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
}
```

Then reload nginx:
```powershell
nginx -s reload
```

### Fix 3: Disable Push Temporarily (Workaround)

If you just want the app to work without real-time updates:

```powershell
# In START_N8N_MSSQL.ps1, add:
$env:N8N_PUSH_BACKEND = "sse"  # Use Server-Sent Events instead of WebSocket
```

---

## Expected Behavior After Fix

### In Browser Console:
```
WebSocket connection established to ws://cmqacore.elevatelocal.com:5000/n8nnet/rest/push
✅ Connected to n8n
```

### In Network Tab:
```
WS /n8nnet/rest/push
Status: 101 Switching Protocols
✅ Connection established
```

### In n8n Logs:
```
[Node] Push connection established for session: ...
[Node] WebSocket client connected
```

---

## Most Likely Cause

Based on your setup, I suspect **nginx is not configured for WebSocket**.

**Quick Test:**
```nginx
# Check your nginx config
cat c:\nginx-1.27.4\conf\nginx.conf | Select-String -Pattern "upgrade|websocket" -CaseInsensitive
```

If you see **no results**, that's the problem!

---

## TL;DR - Quick Fix

1. **Add to nginx.conf:**
   ```nginx
   proxy_http_version 1.1;
   proxy_set_header Upgrade $http_upgrade;
   proxy_set_header Connection "upgrade";
   ```

2. **Reload nginx:**
   ```powershell
   nginx -s reload
   ```

3. **Restart n8n:**
   ```powershell
   .\START_N8N_MSSQL.ps1
   ```

4. **Refresh browser:** Ctrl+F5

**This should fix it!** 🎯

