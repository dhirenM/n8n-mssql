# Restart and Test Guide

## 🔧 Changes Made (Latest)

### 1. BaseRepository - Override TypeORM Methods ✅
Added override methods so `findOneOrFail()`, `find()`, `count()`, etc. automatically use tenant database.

### 2. Push Endpoint - Path Normalization & Logging ✅
- Normalized path to remove double slashes
- Added comprehensive logging to both handler and WebSocket upgrade

### 3. Subdomain Validation - Skip Logging ✅
Added logging to show when push endpoint is being skipped

---

## 📋 Restart Steps

### Step 1: Stop Current Server
```powershell
# In the terminal running n8n, press:
Ctrl+C
```

### Step 2: Rebuild
```powershell
cd C:\Git\n8n-mssql
npm run build
```

**Wait for:** "Build completed successfully"

### Step 3: Start Server
```powershell
npm run start
```

### Step 4: Watch for Startup Logs

**Look for these EXACT log messages:**

```
✅ GOOD SIGNS:
┌─────────────────────────────────────────────────────────────┐
│ [Push] Registering push handler at: "/n8nnet/rest/push"     │
│ [Push] Registering WebSocket upgrade handler at:            │
│        "/n8nnet/rest/push"                                   │
│ ✅ Multi-tenant middleware registered                        │
└─────────────────────────────────────────────────────────────┘

⚠️ WATCH FOR PROBLEMS:
┌─────────────────────────────────────────────────────────────┐
│ [Push] Registering push handler at: "/rest/push"            │
│   → ❌ Missing base path!                                   │
│                                                              │
│ [Push] Registering push handler at: "//n8nnet/rest/push"   │
│   → ❌ Double slashes!                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing Checklist

### Test 1: Push Endpoint (Fix for 404 error)

**Access in browser:**
```
http://cmqacore.elevatelocal.com:5000/n8nnet/workflow/new
```

**Check browser console:**
- ❌ Before: `GET .../rest/push 404 (Not Found)`
- ✅ After: Push connection establishes successfully

**Check server logs for:**
```
[SubdomainValidation] Skipping validation for: /n8nnet/rest/push (method: GET, upgrade: undefined)
[Push] Incoming request to: /n8nnet/rest/push?pushRef=...
```

---

### Test 2: Project API (Fix for 500 error)

**The browser will call:**
```
GET /n8nnet/rest/projects/5d0e4203-1cce-496f-83f0-b77b1bee06af
```

**Check server logs for:**
```
[SubdomainValidation] 🔍 Validating host: cmqacore.elevatelocal.com
[SubdomainValidation] 🎯 Extracted subdomain: "cmqacore"
[SubdomainValidation] ✅ DataSource ready - subdomain: "cmqacore", database: "cmqa6"
[BaseRepository] ✅ Using tenant DB: cmqa6 (subdomain: cmqacore)
[ProjectRepository] getPersonalProjectForUser - Context: {
  subdomain: 'cmqacore',
  isInTenantContext: true,
  ...
}
```

**Possible outcomes:**

#### Outcome A: Success! ✅
```
Project found and returned
```
**Meaning:** Everything works! The project exists in cmqa6 database.

#### Outcome B: Still 500 Error - "Project not found"
```
[BaseRepository] ✅ Using tenant DB: cmqa6 (subdomain: cmqacore)
But still: Could not find any entity of type "Project"
```
**Meaning:** Routing is working, but project doesn't exist in cmqa6 database.

**Solution:** Check which database has the project:
```sql
-- Find the project
EXEC sp_MSforeachdb 'USE [?]; 
IF DB_NAME() IN (''dmnen_test'', ''cmqa6'', ''pmgroup'') 
SELECT DB_NAME() as database_name, id, name, type 
FROM dbo.project 
WHERE id = ''5d0e4203-1cce-496f-83f0-b77b1bee06af'''

-- If not found, list all projects in cmqa6
SELECT id, name, type FROM cmqa6.dbo.project;
```

#### Outcome C: Still 500 Error - Using default DB
```
[BaseRepository] ⚠️ No dataSource in request, using default DB
```
**Meaning:** Subdomain validation didn't run or failed.

**Check:** Is `ENABLE_MULTI_TENANT=true` in your .env?

---

### Test 3: Verify Tenant Isolation

Once working, test that tenants are isolated:

**Step 1: Create workflow in cmqacore tenant**
```
1. Access: http://cmqacore.elevatelocal.com:5000/n8nnet/
2. Create a new workflow
3. Save it
```

**Step 2: Check it's in correct database**
```sql
-- Should find it in cmqa6
SELECT id, name FROM cmqa6.dbo.workflow_entity ORDER BY createdAt DESC;
```

**Step 3: Verify isolation**
```
1. Access different tenant: http://pmgroup.elevatelocal.com:5000/n8nnet/
2. The workflow from step 1 should NOT appear here
```

---

## 🎯 Success Criteria

After restart, you should see **ALL** of these:

### Server Startup ✅
```
[Push] Registering push handler at: "/n8nnet/rest/push"
[Push] Registering WebSocket upgrade handler at: "/n8nnet/rest/push"
✅ Multi-tenant middleware registered
n8n ready on 0.0.0.0, port 5000
```

### Browser Access ✅
```
✓ No push 404 error in console
✓ No project 500 error
✓ Workflow editor loads
✓ "Connection lost" message disappears
```

### Server Logs ✅
```
[SubdomainValidation] Skipping validation for: /n8nnet/rest/push
[SubdomainValidation] 🎯 Extracted subdomain: "cmqacore"
[SubdomainValidation] ✅ DataSource ready - subdomain: "cmqacore", database: "cmqa6"
[BaseRepository] ✅ Using tenant DB: cmqa6 (subdomain: cmqacore)
```

---

## 🐛 Troubleshooting

### Issue: Push still 404

**Check startup logs for:**
```
[Push] Registering push handler at: "???"
```

**If it shows:**
- `/rest/push` → Missing base path, check N8N_PATH env var
- `//n8nnet/rest/push` → Double slash issue, check globalConfig.path
- `/n8nnet/rest/push` → Correct! Issue is elsewhere

**Then check runtime logs:**
```
[SubdomainValidation] Skipping validation for: /n8nnet/rest/push
```

**If NOT showing** → Subdomain middleware is blocking it

### Issue: Project still 500

**Check logs for:**
```
[BaseRepository] ✅ Using tenant DB: cmqa6
```

**If shows "using default DB"** → Routing not working
**If shows "Using tenant DB"** → Project doesn't exist, run SQL queries above

---

## 📝 Environment Variables to Check

Make sure these are set in your `.env` or environment:

```bash
# Required for multitenant mode
ENABLE_MULTI_TENANT=true

# Base path (already set if you see /n8nnet in URLs)
N8N_PATH=/n8nnet

# Default subdomain for localhost
DEFAULT_SUBDOMAIN=pmgroup

# .NET JWT (if using)
USE_DOTNET_JWT=true
```

---

## 🎯 Quick Diagnostic Commands

### Check Server Startup Logs
```powershell
# In PowerShell, restart with verbose logging
$env:N8N_LOG_LEVEL="debug"
npm run start
```

### Check Express Routes Registered
Add this temporarily in Server.ts after all routes are registered:

```typescript
// Debug: List all registered routes
this.logger.info('Registered routes:');
this.app._router.stack
  .filter((r: any) => r.route || r.name === 'router')
  .forEach((r: any) => {
    if (r.route) {
      this.logger.info(`  ${Object.keys(r.route.methods)} ${r.route.path}`);
    }
  });
```

---

## 📞 What to Share If Still Broken

If issues persist after restart, share:

1. **Startup logs** (first 50 lines after "npm run start")
2. **The exact log lines** containing:
   - `[Push] Registering push handler at: "..."`
   - `[SubdomainValidation] Skipping validation for: ...`
3. **Your .env file** (N8N_PATH value)
4. **Browser console errors** (screenshot or copy/paste)

With these logs, I can pinpoint the exact issue! 🎯

---

**Now restart your server and share the logs!** 🚀

