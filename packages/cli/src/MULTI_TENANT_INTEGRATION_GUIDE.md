# 🔧 Multi-Tenant Integration Guide for n8n

## Files Created

✅ All core multi-tenant files have been created:

```
packages/cli/src/
├── databases/
│   ├── elevate.datasource.ts           # ✅ Elevate DB (singleton)
│   ├── voyager.datasource.factory.ts   # ✅ Voyager DBs (dynamic)
│   └── datasource.proxy.ts             # ✅ Container proxy
│
└── middlewares/
    ├── requestContext.ts                # ✅ AsyncLocalStorage
    ├── subdomain-validation.middleware.ts  # ✅ Subdomain → DB mapping
    └── dotnet-jwt-auth.middleware.ts    # ✅ .NET JWT validation
```

---

## 🔌 Integration Steps

### **Step 1: Find n8n's Server Initialization**

Look for the main server file. It's likely one of these:

```
packages/cli/src/Server.ts
packages/cli/src/index.ts  
packages/cli/bin/n8n
```

Find where n8n:
- Creates the Express app
- Initializes the database
- Registers middleware

---

### **Step 2: Initialize Elevate DataSource**

**Add to server initialization** (BEFORE initializing n8n's main DataSource):

```typescript
import { initializeElevateDataSource } from '@/databases/elevate.datasource';

// In server init function:
async function init() {
  // ... existing code
  
  // Initialize Elevate DB (multi-tenant central database)
  await initializeElevateDataSource();
  
  // ... continue with n8n's DataSource initialization
}
```

---

### **Step 3: Install DataSource Proxy**

**Add AFTER n8n's DataSource is initialized:**

```typescript
import { installDataSourceProxy } from '@/databases/datasource.proxy';

// After n8n DataSource initialization:
async function init() {
  // ... Elevate DB initialization
  
  // Initialize n8n's main DataSource
  await initializeDataSource();
  
  // Install multi-tenant proxy
  if (process.env.ENABLE_MULTI_TENANT === 'true') {
    installDataSourceProxy();
  }
  
  // ... continue
}
```

---

### **Step 4: Register Middleware**

**Add to Express app setup** (in order!):

```typescript
import cookieParser from 'cookie-parser';
import { requestContextMiddleware } from '@/middlewares/requestContext';
import { subdomainValidationMiddleware } from '@/middlewares/subdomain-validation.middleware';
import { dotnetJwtAuthMiddleware } from '@/middlewares/dotnet-jwt-auth.middleware';

// Setup Express middleware (ORDER IS CRITICAL):
app.use(cookieParser());                        // 1. Parse cookies
app.use(requestContextMiddleware);              // 2. Setup request context
app.use(subdomainValidationMiddleware);         // 3. Validate subdomain → get Voyager DB
app.use(dotnetJwtAuthMiddleware);               // 4. Validate .NET JWT → load user

// ... n8n's existing middleware continues
```

---

### **Step 5: Add base64url Dependency**

```bash
cd packages/cli
pnpm add base64url
```

---

## 📝 Example Integration (Pseudocode)

```typescript
// packages/cli/src/Server.ts (or similar)

import express from 'express';
import cookieParser from 'cookie-parser';
import { initializeElevateDataSource } from '@/databases/elevate.datasource';
import { installDataSourceProxy } from '@/databases/datasource.proxy';
import { requestContextMiddleware } from '@/middlewares/requestContext';
import { subdomainValidationMiddleware } from '@/middlewares/subdomain-validation.middleware';
import { dotnetJwtAuthMiddleware } from '@/middlewares/dotnet-jwt-auth.middleware';

export class Server {
  async init() {
    // 1. Initialize Elevate DB (singleton)
    await initializeElevateDataSource();
    
    // 2. Initialize n8n's main DataSource (existing code)
    await this.initializeDataSource();
    
    // 3. Install multi-tenant proxy
    if (process.env.ENABLE_MULTI_TENANT === 'true') {
      installDataSourceProxy();
    }
    
    // 4. Setup Express app
    this.setupExpressApp();
  }
  
  setupExpressApp() {
    const app = express();
    
    // Essential middleware (in order!)
    app.use(cookieParser());
    app.use(requestContextMiddleware);
    app.use(subdomainValidationMiddleware);
    app.use(dotnetJwtAuthMiddleware);
    
    // ... n8n's existing middleware
    // ... routes
    
    return app;
  }
}
```

---

## 🧪 Testing

### **Test 1: Check Elevate DB Connection**

```powershell
# Start n8n
.\START_N8N_MSSQL.ps1

# Check logs for:
# ✅ Elevate DataSource initialized successfully
#    Server: 10.242.1.65\SQL2K19
#    Database: elevate_multitenant_mssql_dev
```

### **Test 2: Test Subdomain Validation**

```powershell
# Access with subdomain
curl http://client1.yourdomain.com:5678/rest/workflows

# Check logs for:
# Subdomain validation for host: client1.yourdomain.com
# Extracted subdomain: client1
# Querying Elevate DB for subdomain: client1
# Creating Voyager DataSource for subdomain: client1
# ✅ Voyager DataSource initialized for: client1 → client1_voyager
```

### **Test 3: Test JWT Authentication**

```powershell
# Get JWT from .NET API
$token = "<jwt-from-dotnet-api>"

# Test with curl
curl http://client1.yourdomain.com:5678/rest/workflows `
  -H "Authorization: Bearer $token"

# Check logs for:
# .NET JWT verified successfully
# userId: <user-id>
# email: <email>
# subdomain: client1
```

### **Test 4: Verify Multi-Tenant Isolation**

```sql
-- Connect to client1_voyager
USE client1_voyager;
SELECT * FROM n8n.[user];
-- Should show users for client1 only

-- Connect to client2_voyager  
USE client2_voyager;
SELECT * FROM n8n.[user];
-- Should show users for client2 only (separate!)
```

---

## ⚠️ Important Notes

### **1. Dependencies**

Make sure these are installed:

```bash
cd packages/cli
pnpm add base64url
```

### **2. TypeScript Compilation**

After creating the files, rebuild:

```bash
cd packages/cli
pnpm build
```

### **3. Migration Handling**

**Important:** Migrations should run ONCE per Voyager database, not per request!

You may need to disable auto-migrations:

```powershell
$env:N8N_SKIP_MIGRATIONS = "true"
```

And run migrations manually for each Voyager DB.

---

## 🐛 Troubleshooting

### **Issue: "Elevate DataSource not initialized"**

**Solution:** Make sure `initializeElevateDataSource()` is called before any middleware tries to use it.

### **Issue: "No DataSource in request context"**

**Solution:** Check middleware order. `subdomainValidationMiddleware` must run before routes.

### **Issue: "Company not found for subdomain"**

**Solution:** 
1. Check subdomain extraction logic
2. Verify company exists in Elevate DB
3. Check company.domain column matches subdomain

### **Issue: "Failed to connect to Voyager database"**

**Solution:**
1. Verify credentials in Elevate DB company table
2. Check network connectivity to Voyager DB server
3. Verify n8n schema exists in Voyager DB

---

## 📊 System Check Endpoint

**Add this endpoint for debugging:**

```typescript
app.get('/rest/multi-tenant/status', async (req, res) => {
  const { VoyagerDataSourceFactory } = await import('@/databases/voyager.datasource.factory');
  const { getElevateDataSource } = await import('@/databases/elevate.datasource');
  const { isProxyInstalled } = await import('@/databases/datasource.proxy');
  
  res.json({
    multiTenantEnabled: process.env.ENABLE_MULTI_TENANT === 'true',
    elevateDb: {
      initialized: getElevateDataSource()?.isInitialized || false,
      database: process.env.ELEVATE_DB_NAME
    },
    voyagerCache: VoyagerDataSourceFactory.getCacheStats(),
    proxyInstalled: isProxyInstalled(),
    currentSubdomain: (req as any).subdomain
  });
});
```

Access: `http://localhost:5678/rest/multi-tenant/status`

---

## ✅ Verification Checklist

After integration:

- [ ] n8n starts without errors
- [ ] Elevate DB connects successfully
- [ ] Accessing with subdomain creates Voyager DataSource
- [ ] .NET JWT tokens are validated
- [ ] Users are auto-created from JWT
- [ ] Different subdomains access different Voyager DBs
- [ ] Data is isolated per client
- [ ] Existing n8n functionality still works

---

## 🎯 Next Steps

1. **Find n8n's server initialization file**
2. **Add the integration code**
3. **Install base64url dependency**
4. **Build TypeScript**
5. **Start n8n and test**

**Need help finding the right files to modify?** Let me know! 🚀

