# Testing the "Create Workflow" Button Fix

## What Was Fixed

Modified `packages\cli\src\middlewares\subdomain-validation.middleware.ts`:
- **Before:** Skipped ALL `/rest/login` requests (including GET)
- **After:** Only skips POST `/rest/login` (username/password login)
- **Result:** GET `/rest/login` now goes through JWT auth properly

## Test Steps

### 1. Restart n8n

Stop your current n8n instance and start it again:

```powershell
# If running via PowerShell script:
.\START_N8N_MSSQL.ps1

# Or if running manually:
pnpm start
```

### 2. Clear Browser Cache & Cookies

**Important:** You MUST clear browser data for the n8n domain:

1. Open n8n in browser
2. Press **F12** → **Application** tab
3. Click **Clear storage** → Check all boxes → **Clear site data**
4. OR just use Incognito/Private mode

### 3. Navigate to n8n

Go to your n8n URL (e.g., `http://cmqacore.elevatelocal.com:5000/n8nnet/home/workflows`)

### 4. Check Browser Console

Open Developer Tools (**F12**) → **Console** tab

You should see n8n loading. Look for any errors.

### 5. Check if User is Logged In

Run this in the browser console:

```javascript
// Check if stores are populated
console.log('Current User:', window.$stores?.usersStore?.currentUser);
console.log('Current Project:', window.$stores?.projectsStore?.currentProject);
console.log('Project Scopes:', window.$stores?.projectsStore?.currentProject?.scopes);
```

**Expected Output:**
```javascript
Current User: {
  id: "53B25A07-947C-4DC0-8AC2-C71B741F86E7",
  email: "amol.changle@local.com",
  role: "global:admin",
  ...
}

Current Project: {
  id: "7DC1417B-F75C-405E-A2AB-D843C0162EAA",
  name: "n8nnet",
  type: "team",
  scopes: ["workflow:create", "workflow:read", "workflow:update", ...]
}
```

### 6. Check the Button

Look at the "Create workflow" button in the top-right corner.

- ✅ **Success:** Button is enabled (clickable)
- ❌ **Still disabled:** See troubleshooting below

### 7. Check Network Tab

**F12** → **Network** tab → Refresh page

Look for these requests:
1. **GET `/rest/login`** → Should return status **200** with user data
2. **GET `/rest/projects/my-projects`** → Should return your projects
3. **GET `/rest/projects/personal`** → Should return personal project

## Troubleshooting

### If Button is Still Disabled

#### A. Check Backend Logs

Look for JWT middleware logs when you load the page:

**Expected logs:**
```
.NET JWT: Token contents (unverified): { ... }
.NET JWT: ✅ Successfully verified with secret format: ...
.NET JWT verified successfully
.NET JWT: User authenticated
```

**If you see:**
```
.NET JWT: No dataSource in request
```
→ The subdomain middleware still isn't working. Check if you saved the file correctly.

**If you see:**
```
.NET JWT validation disabled
```
→ Make sure `USE_DOTNET_JWT=true` in your environment variables

#### B. Check Network Response

In Network tab, click on the **GET `/rest/login`** request:

**Response should be:**
```json
{
  "id": "53B25A07-947C-4DC0-8AC2-C71B741F86E7",
  "email": "amol.changle@local.com",
  "firstName": "Amol",
  "lastName": "Changle",
  "role": "global:admin",
  ...
}
```

**If response is empty or 401:**
- JWT validation failed
- Check `DOTNET_AUDIENCE_SECRET` environment variable
- Check JWT token in cookies (Developer Tools → Application → Cookies)

#### C. Check JWT Cookie

**F12** → **Application** → **Cookies** → Your domain

Look for:
- `n8n-auth` cookie with a long token value
- OR `token` cookie with a long token value

**If no JWT cookie:**
- You need to log in via your .NET API first
- The .NET API should set the cookie when you authenticate
- Cookie domain must match n8n domain

### If You Get TypeScript Errors

Run:
```powershell
cd C:\Git\n8n-mssql
pnpm build
```

Then restart n8n.

## Verification Checklist

- [ ] n8n restarted successfully
- [ ] Browser cache cleared
- [ ] No errors in browser console
- [ ] GET `/rest/login` returns 200 with user data
- [ ] `window.$stores.usersStore.currentUser` is populated
- [ ] `window.$stores.projectsStore.currentProject` is populated
- [ ] `currentProject.scopes` includes `"workflow:create"`
- [ ] "Create workflow" button is enabled and clickable

## If Everything Works

Congratulations! 🎉 

You can now:
- Click "Create workflow" button
- Create workflows
- Edit workflows
- All with proper JWT authentication from your .NET API

## If Still Not Working

Share these details:
1. Output from browser console (the `console.log` commands above)
2. Screenshot of Network tab showing `/rest/login` request/response
3. Backend logs around the time of page load
4. Any error messages in browser console or backend logs

## Additional Notes

### Why This Works

```
Browser → GET /rest/login with JWT cookie
    ↓
Subdomain Middleware (now processes GET /login!)
    → Attaches dataSource to request
    ↓
JWT Middleware
    → Sees dataSource ✓
    → Validates JWT token ✓
    → Attaches user to request ✓
    ↓
Auth Controller
    → Returns user from request ✓
    ↓
Frontend
    → Receives user data ✓
    → Populates stores ✓
    → Enables "Create workflow" button ✓
```

### What Changed

**ONE LINE** in `subdomain-validation.middleware.ts` (line 38):

```typescript
// Before:
req.url.includes('/rest/login') ||        // Login endpoint

// After:
(req.url.includes('/rest/login') && req.method === 'POST') || // Username/password login (POST only)
```

That's it! One line changed the entire authentication flow.

