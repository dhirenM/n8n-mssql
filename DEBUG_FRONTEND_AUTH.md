# Frontend Authentication Debug Guide

## The Problem

Your database is configured correctly, but the frontend shows:
```javascript
Current Project: undefined
Current User: undefined
```

This means the frontend isn't getting the user/project data from the backend.

## How n8n Frontend Authentication Works

1. **Browser loads the page** with JWT token in cookie (`n8n-auth` or `token`)
2. **Frontend calls** `usersStore.initialize()` in `init.ts`
3. **This calls** `loginWithCookie()` → `usersApi.loginCurrentUser()` 
4. **Backend endpoint** `/rest/login` (or `/login`) should:
   - Read the JWT token from cookie
   - Validate it via your `.dotnetJwtAuthMiddleware`
   - Return user data with projects
5. **Frontend stores** user and project data in Pinia stores

## Diagnosis Steps

### Step 1: Check Browser Network Tab

1. Open n8n in browser
2. Press **F12** → **Network** tab
3. Refresh the page
4. Look for requests to `/rest/login` or similar
5. Check the response:
   - **Status 200**: Good, but check response body
   - **Status 401/403**: JWT validation failed
   - **Status 500**: Server error
   - **No request**: Frontend isn't trying to log in

### Step 2: Check Browser Console

Look for errors related to:
- API calls failing
- CORS errors
- Authentication errors
- Store initialization errors

### Step 3: Check n8n Server Logs

Your JWT middleware logs a lot of debug info. Check for:
```
.NET JWT: Token contents (unverified)
.NET JWT verified successfully
.NET JWT: User authenticated
```

If you don't see these, the middleware isn't running or the token isn't being sent.

### Step 4: Check the JWT Cookie

In browser console, run:
```javascript
// Check if JWT cookie exists
document.cookie.split(';').forEach(c => console.log(c.trim()));
```

You should see either:
- `n8n-auth=<long-token-string>`
- `token=<long-token-string>`

If no JWT cookie exists, you need to get one from your .NET API first.

## Common Issues & Fixes

### Issue 1: JWT Cookie Not Present
**Symptom:** No `n8n-auth` or `token` cookie in browser
**Fix:** Make sure your .NET API sets the cookie when users log in

### Issue 2: JWT Cookie Domain Mismatch
**Symptom:** Cookie exists but isn't sent to n8n
**Fix:** Cookie domain must match n8n domain (e.g., `.yourdomain.com`)

### Issue 3: JWT Middleware Not Running
**Symptom:** No JWT logs in n8n console
**Fix:** Check that `USE_DOTNET_JWT=true` in your environment variables

### Issue 4: JWT Validation Fails
**Symptom:** Logs show "JWT verification failed"
**Fix:** Check `DOTNET_AUDIENCE_SECRET` matches your .NET API configuration

### Issue 5: User Created But Not Returned
**Symptom:** JWT validates but API returns 401/empty
**Fix:** The `/rest/login` endpoint might not be using JWT auth

## Quick Test

Run this in n8n backend (create a test endpoint or modify Server.ts):

```typescript
// Test endpoint to check if JWT auth is working
app.get('/test-jwt', async (req, res) => {
  console.log('Headers:', req.headers);
  console.log('Cookies:', req.cookies);
  console.log('User from middleware:', (req as any).user);
  
  res.json({
    hasUser: !!(req as any).user,
    userEmail: (req as any).user?.email,
    cookies: Object.keys(req.cookies || {}),
  });
});
```

Then visit: `http://your-n8n-url/test-jwt`

## Next Steps Based on Network Tab

### If `/rest/login` returns 401:
The JWT isn't being validated. Check:
1. JWT cookie is being sent with request
2. `USE_DOTNET_JWT=true` is set
3. JWT middleware is registered before the login route

### If `/rest/login` returns user but stores are still undefined:
Frontend issue. Check:
1. Browser console for JavaScript errors
2. Response structure matches what frontend expects
3. Pinia stores are initializing

### If no `/rest/login` request is made:
Frontend isn't trying to log in. Check:
1. Is the page loading at all?
2. Check browser console for errors during initialization
3. Settings store might not be initialized

## The Most Likely Fix

Based on your setup, the issue is probably that **n8n's `/rest/login` endpoint doesn't use your JWT middleware**. 

n8n has its own authentication system, and your JWT middleware might only be running on certain routes. You need to ensure the login endpoint also accepts JWT tokens.

### Check This File

Look at: `packages/cli/src/controllers/auth.controller.ts`

The login endpoints might have their own authentication that doesn't use your middleware.

### Solution

You might need to:
1. Create a custom route that handles JWT login
2. Or modify the existing login endpoint to check for JWT tokens
3. Or bypass the login endpoint entirely and use a different initialization method

Let me check your Server.ts to see how routes are set up...

