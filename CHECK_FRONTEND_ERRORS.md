# Check Frontend Initialization Errors

## Step 1: Open Browser Console

Press **F12** → **Console** tab

Look for JavaScript errors (red text). Common errors:

### Error 1: Settings API Failed
```
Error: Failed to fetch settings
Error initializing n8n
```

**Cause:** `/rest/settings` endpoint failing  
**Fix:** Check if settings endpoint returns data

### Error 2: Auth Store Failed
```
Cannot read property 'user' of undefined
Pinia store error
```

**Cause:** Authentication not properly initialized  
**Fix:** JWT may not be passing correctly

### Error 3: API Base URL Wrong
```
404 Not Found for /rest/...
Failed to load resource: /rest/settings
```

**Cause:** Frontend using wrong base path  
**Fix:** Check VUE_APP_URL_BASE_API is set correctly

---

## Step 2: Check Network Tab

Press **F12** → **Network** tab → **Clear** → **Refresh page**

### Look for These Requests (in order):

1. **`GET /n8nnet/rest/settings`** 
   - Status: Should be **200 OK**
   - Response: Should have settings object
   - ❌ If 500/403: Settings endpoint broken
   
2. **`GET /n8nnet/rest/login`** (might be called)
   - Status: 200 or 401
   - ❌ If error: Auth issue

3. **`WS /n8nnet/rest/push`** 
   - Should appear as WebSocket (WS) type
   - Status: 101 Switching Protocols
   - ❌ If missing: Push not being initiated

---

## Step 3: Test Settings Endpoint Manually

```powershell
# Test if settings endpoint works
$headers = @{
    "Cookie" = "n8n-auth=your-jwt-token-from-browser"
}

Invoke-WebRequest -Uri "http://localhost:5678/n8nnet/rest/settings" -Headers $headers
```

**Expected:** Returns settings JSON  
**If fails:** Settings endpoint is broken

---

## Step 4: Check for Specific Errors

### Check 1: Does Frontend Code Have Push Logic?

In browser console, type:
```javascript
// Check if push store exists
window.$pinia?.state?.value?.push

// Check settings
window.$pinia?.state?.value?.settings?.settings

// Check root store
window.$pinia?.state?.value?.root?.restUrl
```

Should show objects, not undefined.

### Check 2: What's the REST URL?

In browser console:
```javascript
console.log(window.$pinia?.state?.value?.root?.restUrl)
```

**Expected:** `/n8nnet/rest`  
**If wrong:** Frontend not configured with correct base path

---

## Common Causes & Fixes

### Cause 1: Frontend Build Issue

**Symptom:** Frontend not loading at all, or using wrong paths

**Solution:**
```powershell
# Rebuild frontend
cd C:\Git\n8n-mssql\packages\frontend\editor-ui
$env:VUE_APP_URL_BASE_API = "/n8nnet/"
pnpm build

# Restart n8n
cd C:\Git\n8n-mssql
.\START_N8N_MSSQL.ps1
```

### Cause 2: Settings Endpoint Returns Error

**Symptom:** Settings API fails, frontend can't initialize

**Solution:** Check backend logs for settings endpoint error

### Cause 3: JWT Not Sent with Requests

**Symptom:** All API requests return 401

**Solution:** Check if JWT is in cookies:
```javascript
// In browser console
document.cookie
// Should include: n8n-auth=...
```

---

## Quick Diagnostic Commands

### Browser Console Commands:

```javascript
// 1. Check if frontend initialized
console.log('Settings:', window.$pinia?.state?.value?.settings);

// 2. Check REST URL
console.log('REST URL:', window.$pinia?.state?.value?.root?.restUrl);

// 3. Check if push store exists
console.log('Push store:', window.$pinia?.state?.value?.push);

// 4. Manually test push connection
const restUrl = '/n8nnet/rest';
const pushUrl = `${restUrl}/push?pushRef=test`;
console.log('Push URL would be:', window.location.origin + pushUrl);
```

---

## Most Likely Issue

Based on the screenshot showing "Error connecting to n8n" but no WebSocket request:

**The frontend initialization is failing BEFORE it tries to connect to push.**

This is usually because:
1. ❌ Settings endpoint failed (returns error)
2. ❌ JavaScript error during init
3. ❌ Pinia store initialization failed

---

## 🚀 **Quick Fix to Try:**

```powershell
# 1. Hard refresh browser (clears ALL cache)
# Press Ctrl + Shift + Delete
# Select "Cached images and files"
# Clear

# 2. Or open in Incognito/Private window
# Ctrl + Shift + N (Chrome)
# Ctrl + Shift + P (Firefox)

# 3. Access: http://cmqacore.elevatelocal.com:5000/n8nnet/

# 4. Open Console (F12) immediately
# Look for the FIRST error that appears
```

---

## 📊 **What to Share:**

If still not working, share:
1. **Browser console errors** (first error that appears)
2. **Network tab** - status codes for `/rest/settings`, `/rest/login`
3. **n8n backend logs** - any errors when accessing the page

This will tell us exactly where the initialization is failing!

