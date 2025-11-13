# Elevate Mode: Bypass n8n Authentication Strategy

## 🎯 Goal

When `VITE_MULTI_TENANT_ENABLED=true`:
- ✅ **Ignore n8n's built-in authentication** (cookies, sessions, JWT)
- ✅ **Use .NET JWT token** from Elevate/Virtuoso.ai
- ✅ **Pass JWT + Role + Database** in every request header
- ✅ **Backend validates JWT** using dotnet-jwt-auth.middleware
- ✅ **Continue execution** regardless of n8n auth state

## 🔧 Current Implementation

### Frontend (Already Implemented)

**File:** `packages/frontend/editor-ui/src/plugins/axios-interceptor.ts`

```typescript
// ALWAYS adds these headers in multi-tenant mode:
Authorization: Bearer <JWT_TOKEN>
Role: <USER_ROLE>
Database: <DATABASE_NAME>
```

**Initialized in:** `packages/frontend/editor-ui/src/main.ts`

```typescript
import { setupAxiosInterceptor, initializeAuthSync } from '@/plugins/axios-interceptor';

initializeAuthSync();
setupAxiosInterceptor();
```

### Backend (Partially Implemented)

**File:** `packages/cli/src/middlewares/dotnet-jwt-auth.middleware.ts`

- Validates .NET JWT tokens
- Extracts user information
- Should bypass n8n's auth middleware

## ❌ Current Problem

The issue is that **settings aren't loading** before the SSO store tries to initialize.

**Error Flow:**
```
1. init.ts calls: await settingsStore.initialize()
   ↓
2. This fails silently (error caught by try-catch)
   ↓
3. Code continues anyway
   ↓
4. Tries to access: settingsStore.settings.sso
   ↓
5. ERROR: settings is undefined
```

## ✅ Solution Strategy

### Option 1: Fix Settings Loading (Current Approach)

Make sure settings endpoint works and loads data into settingsStore properly.

**Already done:**
- ✅ Backend returns unwrapped data (`raw: true`)
- ✅ Settings endpoint accessible (`/n8nnet/rest/settings` returns 200)
- 🔄 Need to ensure settingsStore processes it correctly

### Option 2: Bypass Settings Requirement (Alternative)

If settings keep failing, we can provide default values:

```typescript
// In init.ts
try {
  await settingsStore.initialize();
} catch (error) {
  console.warn('Settings failed, using defaults for Elevate mode');
  // Set minimal settings manually
  settingsStore.settings = {
    sso: {
      ldap: { loginEnabled: false, loginLabel: '' },
      saml: { loginEnabled: false, loginLabel: '' },
      oidc: { loginEnabled: false, loginUrl: '', callbackUrl: '' },
    },
    enterprise: { ldap: false, saml: false, oidc: false },
    // ... other required properties
  };
}
```

## 🎯 What You Need

For Elevate mode to work, you need:

1. ✅ **Frontend sends headers** - Already implemented
2. ✅ **Backend receives headers** - Already implemented (voyager.datasource.factory)
3. ✅ **JWT validation** - Already implemented (dotnet-jwt-auth.middleware)
4. ❌ **Settings load properly** - Currently failing
5. ❌ **Bypass n8n auth checks** - Need to implement

## 🚀 Next Steps

### Immediate Fix Needed

Find out WHY `settingsStore.initialize()` is failing:

**Check browser console after next reload** - you should now see:
```
"Failed to initialize settings store: <error message>"
OR
"Settings not loaded properly - sso configuration missing"
```

This will tell us exactly what's failing!

### After Settings Work

Once settings load, you'll need to ensure:

1. **dotnet-jwt-auth.middleware** runs BEFORE n8n's auth middleware
2. If JWT is valid, set `req.user` to bypass n8n auth
3. Skip n8n's cookie/session checks entirely

## 📋 Current Status

✅ **Working:**
- Axios interceptor adds headers
- Backend receives headers
- Settings endpoint returns data (unwrapped)
- Voyager database routing works

❌ **Not Working:**
- Settings not loading into settingsStore
- SSO store crashes on undefined
- App not rendering

🔄 **In Progress:**
- Frontend rebuild with better error messages
- Will show exact error why settings fail

---

**Wait for frontend rebuild to complete, then restart n8n and check browser console for the new error messages!** 🔍

