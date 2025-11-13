# Debug: No /rest/login Request in Network Tab

## The Issue

If you don't see `/rest/login` in the Network tab, the frontend initialization isn't running at all.

## Quick Diagnostic Steps

### Step 1: Check Browser Console for Errors

**F12** → **Console** tab

Look for **red errors**, especially:
- JavaScript syntax errors
- Failed to load script errors
- Uncaught exceptions
- Module loading errors

**Common errors to look for:**
```
Failed to fetch
Uncaught SyntaxError
Cannot read property of undefined
CORS error
```

### Step 2: Check What Requests ARE Being Made

**F12** → **Network** tab → Refresh page

What requests DO you see? Look for:
- `/` or `/index.html` - Main page load
- `/assets/` - JavaScript bundles
- `/rest/settings` - Settings endpoint
- Any other `/rest/` endpoints

**Share what you see!**

### Step 3: Check If Page is Loading

1. Does the n8n UI appear at all?
2. Do you see the n8n logo?
3. Is it stuck on a loading screen?
4. Is the page completely blank?

### Step 4: Check Settings Store

The user store only initializes **after** the settings store. Run this in console:

```javascript
// Check if settings are loaded
console.log('Settings Store:', window.$stores?.settingsStore);
console.log('Settings:', window.$stores?.settingsStore?.settings);
```

If settings aren't loaded, the user store won't initialize.

### Step 5: Check if Stores Exist at All

```javascript
// Check if Pinia stores are available
console.log('All Stores:', window.$stores);
console.log('Has usersStore:', !!window.$stores?.usersStore);
console.log('Has projectsStore:', !!window.$stores?.projectsStore);
```

## Common Causes & Fixes

### Cause 1: Settings Endpoint Failed

**Symptom:** No `/rest/settings` request or it fails

**Check:** Look for GET `/rest/settings` in Network tab

**Fix:** Settings endpoint might be blocked. Check if subdomain middleware is interfering.

**Temporary workaround:** Add `/rest/settings` to the skip list in subdomain middleware.

### Cause 2: JavaScript Bundle Failed to Load

**Symptom:** Console shows "Failed to load script" or similar

**Check:** Network tab shows 404 for `/assets/*.js` files

**Fix:** 
- Clear browser cache
- Check n8n is built correctly
- Run `pnpm build` if in development

### Cause 3: Route Middleware Blocking

**Symptom:** Page loads but initialization doesn't run

**Check:** Console for navigation errors

**Fix:** Check router middleware (more details below)

### Cause 4: TypeScript/Build Errors

**Symptom:** Old JavaScript still running

**Check:** Network tab → Click on a `.js` file → Check "Last-Modified" date

**Fix:**
```powershell
cd C:\Git\n8n-mssql
pnpm build
```

Then restart n8n.

## Deep Dive: Where Login is Called

The login flow starts in `init.ts`:

```typescript
// packages/frontend/editor-ui/src/init.ts

export async function initializeCore() {
    // ...
    
    // 1. Settings store initializes first
    await settingsStore.initialize();
    
    // 2. THEN users store initializes
    if (settingsStore.isUserManagementEnabled) {
        await usersStore.initialize({
            quota: settingsStore.userManagement.quota,
        });
    }
}

// In usersStore.initialize():
async function initialize() {
    await loginWithCookie();  // <-- This calls /rest/login
}
```

**If `/rest/login` isn't called, one of these failed:**
1. Settings store didn't initialize
2. User management is disabled in settings
3. An error occurred before `usersStore.initialize()`

## Debugging Script

Run this in browser console to see where it's failing:

```javascript
// Check initialization state
const checks = {
    'Stores exist': !!window.$stores,
    'Settings store exists': !!window.$stores?.settingsStore,
    'Users store exists': !!window.$stores?.usersStore,
    'Projects store exists': !!window.$stores?.projectsStore,
    'Settings initialized': !!window.$stores?.settingsStore?.settings,
    'User management enabled': window.$stores?.settingsStore?.isUserManagementEnabled,
    'Users store initialized': window.$stores?.usersStore?.initialized,
    'Current user': window.$stores?.usersStore?.currentUser,
};

console.table(checks);

// Also check settings
console.log('Full Settings:', window.$stores?.settingsStore?.settings);
```

## What to Share

Please share:

1. **Browser console output** (any red errors)
2. **Network tab requests** (what requests ARE being made?)
3. **Output from the debugging script above**
4. **What you see on screen** (blank page? loading? error message?)

This will help me pinpoint exactly where the initialization is failing.

## Possible Quick Fixes to Try

### Fix 1: Ensure /rest/settings is Not Blocked

The settings endpoint must work for anything to initialize. Let me check your middleware...

