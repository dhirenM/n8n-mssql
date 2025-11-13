# Debug Multitenant Database Routing

## Current Issue

**Error:** `Could not find any entity of type "Project" matching: { "where": { "id": "5d0e4203-1cce-496f-83f0-b77b1bee06af" }}`

**URL:** `http://cmqacore.elevatelocal.com:5000/n8nnet/rest/projects/5d0e4203-1cce-496f-83f0-b77b1bee06af`

This means the application is querying a database but not finding the project.

## Debugging Steps

### Step 1: Check Server Logs

After restarting the server, access the URL again and look for these log messages:

```
[SubdomainValidation] 🔍 Validating host: cmqacore.elevatelocal.com (forwarded: ..., path: /n8nnet/rest/projects/...)
[SubdomainValidation] 🎯 Extracted subdomain: "cmqacore" from host: "cmqacore.elevatelocal.com"
[SubdomainValidation] ✅ DataSource ready - subdomain: "cmqacore", database: "ACTUAL_DB_NAME"
[BaseRepository] ✅ Using tenant DB: ACTUAL_DB_NAME (subdomain: cmqacore)
[ProjectRepository] getPersonalProjectForUser - Context: {...}
```

### Step 2: Identify the Issue

#### Issue A: Wrong Subdomain Extracted

If you see:
```
[SubdomainValidation] 🎯 Extracted subdomain: "n8nnet" from host: ...
```

**Problem:** The subdomain extraction is getting "n8nnet" instead of "cmqacore"

**Cause:** The URL path `/n8nnet/` is being confused with the subdomain

**Solution:** The subdomain should come from the hostname, not the path. Check your DNS/proxy configuration.

**Expected:**
- Hostname: `cmqacore.elevatelocal.com` → subdomain = "cmqacore" ✅
- Path: `/n8nnet/rest/...` → ignored for subdomain ✅

#### Issue B: Using Default Database

If you see:
```
[BaseRepository] ⚠️ No dataSource in request, using default DB
```

**Problem:** The subdomain validation middleware is not setting `req.dataSource`

**Check:**
1. Is `ENABLE_MULTI_TENANT=true` in your .env?
2. Is the middleware order correct in server.ts?
3. Are you accessing a route that skips the middleware?

#### Issue C: Project Doesn't Exist in Tenant Database

If you see:
```
[BaseRepository] ✅ Using tenant DB: cmqa6 (subdomain: cmqacore)
```
And still get "Could not find any entity"

**Problem:** The project ID `5d0e4203-1cce-496f-83f0-b77b1bee06af` doesn't exist in the `cmqa6` database

**Solution:** Query the database to check:

```sql
-- Check which database has this project
SELECT 'dmnen_test' as db, * FROM dmnen_test.dbo.project WHERE id = '5d0e4203-1cce-496f-83f0-b77b1bee06af'
UNION ALL
SELECT 'cmqa6' as db, * FROM cmqa6.dbo.project WHERE id = '5d0e4203-1cce-496f-83f0-b77b1bee06af';

-- List all projects in cmqa6 database
SELECT id, name, type FROM cmqa6.dbo.project;
```

### Step 3: Common Solutions

#### Solution 1: Project is in Wrong Database

If the project exists in `dmnen_test` but not in `cmqa6`:

**Option A:** Copy the project to the tenant database
```sql
-- Copy project from dmnen_test to cmqa6
INSERT INTO cmqa6.dbo.project
SELECT * FROM dmnen_test.dbo.project 
WHERE id = '5d0e4203-1cce-496f-83f0-b77b1bee06af';

-- Also copy related records (project_relation, shared_workflow, etc.)
```

**Option B:** Create a new project in the frontend for the cmqacore tenant

#### Solution 2: Wrong Subdomain Mapping

Check the Elevate database to see which Voyager database `cmqacore` maps to:

```sql
-- Query Elevate DB
SELECT domain, database_server, database_name 
FROM elevate.dbo.company 
WHERE domain = 'cmqacore';
```

Expected result:
```
domain      database_server     database_name
cmqacore    voyager-sql-srv     cmqa6
```

If the mapping is wrong, update it:
```sql
UPDATE elevate.dbo.company 
SET database_name = 'cmqa6' 
WHERE domain = 'cmqacore';
```

#### Solution 3: Middleware Not Running

Check middleware registration in `server.ts`:

```typescript
if (process.env.ENABLE_MULTI_TENANT === 'true') {
  this.app.use(requestContextMiddleware);          // Must be first
  this.app.use(subdomainValidationMiddleware);     // Must be second
  this.app.use(dotnetJwtAuthMiddleware);
}
```

### Step 4: Verify Fix

After making changes:

1. **Restart the server**
2. **Clear browser cache** (or use Incognito/Private mode)
3. **Access the URL again**: `http://cmqacore.elevatelocal.com:5000/n8nnet/workflow/new`
4. **Check logs** for the ✅ messages

Expected successful logs:
```
[SubdomainValidation] ✅ DataSource ready - subdomain: "cmqacore", database: "cmqa6"
[BaseRepository] ✅ Using tenant DB: cmqa6 (subdomain: cmqacore)
[ProjectRepository] getPersonalProjectForUser - Context: {
  subdomain: 'cmqacore',
  isInTenantContext: true,
  hasRequestContext: true,
  defaultDatabase: 'dmnen_test',
  entityName: 'Project'
}
```

## Quick Diagnostic Commands

### Check if project exists in databases:

```sql
-- Search for project in all databases
EXEC sp_MSforeachdb 'USE [?]; IF DB_NAME() IN (''dmnen_test'', ''cmqa6'', ''pmgroup'') 
SELECT DB_NAME() as database_name, * FROM dbo.project WHERE id = ''5d0e4203-1cce-496f-83f0-b77b1bee06af'''
```

### Check subdomain mapping:

```sql
-- Check company configuration
SELECT 
    domain,
    database_server,
    database_name,
    is_active,
    created_at
FROM elevate.dbo.company 
WHERE domain IN ('cmqacore', 'pmgroup');
```

### Check user and project relations:

```sql
-- Check which users have access to projects in cmqa6
USE cmqa6;
SELECT 
    u.id as user_id,
    u.email,
    p.id as project_id,
    p.name as project_name,
    p.type as project_type,
    pr.role_id
FROM dbo.project p
LEFT JOIN dbo.project_relation pr ON p.id = pr.project_id
LEFT JOIN dbo.[user] u ON pr.user_id = u.id;
```

## Testing the Fix

### Test 1: Direct API Call

```bash
curl -H "Host: cmqacore.elevatelocal.com" \
     -H "Cookie: n8n-auth=YOUR_JWT_TOKEN" \
     http://localhost:5000/n8nnet/rest/projects/personal
```

Expected: Returns project data (not 404 or 500)

### Test 2: Browser Access

1. Open: `http://cmqacore.elevatelocal.com:5000/n8nnet/`
2. Login with JWT-authenticated user
3. Check browser console for errors
4. Check server logs for database routing

### Test 3: Verify Tenant Isolation

```bash
# Request to tenant 1
curl -H "Host: cmqacore.elevatelocal.com" \
     http://localhost:5000/n8nnet/rest/projects/personal

# Request to tenant 2  
curl -H "Host: pmgroup.elevatelocal.com" \
     http://localhost:5000/n8nnet/rest/projects/personal
```

Each should return different projects from their respective databases.

## Log Output Reference

### ✅ Success Pattern
```
[SubdomainValidation] 🔍 Validating host: cmqacore.elevatelocal.com
[SubdomainValidation] 🎯 Extracted subdomain: "cmqacore"
[SubdomainValidation] ✅ DataSource ready - subdomain: "cmqacore", database: "cmqa6"
[BaseRepository] ✅ Using tenant DB: cmqa6 (subdomain: cmqacore)
```

### ⚠️ Warning Patterns
```
[BaseRepository] ⚠️ No requestContext found, using default DB
  → AsyncLocalStorage not initialized

[BaseRepository] ⚠️ No store found (not in request context), using default DB
  → Not in HTTP request context (CLI/background job)

[BaseRepository] ⚠️ No dataSource in request, using default DB
  → Subdomain validation middleware didn't run or failed

[BaseRepository] ⚠️ DataSource for subdomain "cmqacore" is not initialized
  → DataSource connection failed
```

### ❌ Error Patterns
```
[SubdomainValidation] Failed to get Voyager DataSource for subdomain: cmqacore
  → Subdomain not found in Elevate DB or database connection failed

[BaseRepository] ❌ Error getting context manager, falling back to default
  → Unexpected error in context retrieval
```

## Environment Variables Check

Verify these are set in your `.env`:

```bash
# Multitenant Mode
ENABLE_MULTI_TENANT=true

# Default subdomain for localhost
DEFAULT_SUBDOMAIN=pmgroup

# .NET JWT Configuration (if using JWT auth)
USE_DOTNET_JWT=true
DOTNET_AUDIENCE_ID=...
DOTNET_AUDIENCE_SECRET=...
```

## Next Steps

1. Restart server and check logs with the new debug output
2. Identify which pattern matches your logs
3. Apply the corresponding solution
4. Test with the verification commands
5. Remove debug logging once issue is resolved (optional)

---

**Remember:** The logging will show you exactly which database is being queried. If it shows the correct database but the project isn't found, the issue is data-related, not routing-related.

