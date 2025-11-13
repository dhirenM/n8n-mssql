# 🎯 n8n JWT Implementation Plan - Complete Architecture

## 📊 Your Complete System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     .NET Core API                           │
│              (JWT Token Generator)                          │
│   - Issues JWT tokens with HS256                            │
│   - Audience: AUDIENCE_ID                                   │
│   - Issuer: ISSUER                                          │
│   - Secret: AUDIENCE_SECRET / SYMMETRIC_KEY                 │
└───────────────────┬─────────────────────────────────────────┘
                    │ Generates JWT
                    ↓
        ┌───────────────────────┐
        │   JWT Token           │
        │   (Shared by all apps)│
        └───────┬───────────────┘
                │
    ┌───────────┴──────────────┐
    │                          │
    ↓                          ↓
┌─────────────┐          ┌─────────────┐
│  Flowise    │          │    n8n      │
│  (Working)  │          │   (New!)    │
└─────┬───────┘          └─────┬───────┘
      │                        │
      └────────┬───────────────┘
               │
               ↓
    ┌──────────────────────┐
    │  Elevate Database    │
    │  (Central DB)        │
    │                      │
    │  Tables:             │
    │  - company           │
    │    • subdomain       │
    │    • db_server       │
    │    • db_name         │
    │    • db_user         │
    │    • db_password     │
    └──────────┬───────────┘
               │
               ↓ (Query by subdomain)
               │
    ┌──────────┴──────────────────┐
    │  Voyager Database           │
    │  (Per-Company DB)           │
    │                             │
    │  Schemas:                   │
    │  ├── flowise.*             │
    │  │   └── (Flowise tables)  │
    │  │                          │
    │  └── n8n.*                  │
    │      └── (n8n tables)       │
    └─────────────────────────────┘
```

---

## 🎯 Requirements

### **What You Need:**

1. ✅ **Use existing .NET Core JWT tokens**
   - Same secret keys
   - Same audience/issuer
   - Same algorithm (HS256)

2. ✅ **Multi-tenant architecture** (like Flowise)
   - Subdomain → Elevate DB → Get Voyager DB credentials
   - Dynamic database connection per request
   - Use "n8n" schema in Voyager DB

3. ✅ **Share authentication** between Flowise and n8n
   - One JWT token works for both apps
   - User context shared
   - Permissions/features shared

---

## 🏗️ Implementation Strategy

### **Challenge: n8n's Single Database Architecture**

**Problem:**
- n8n initializes ONE DataSource at startup
- All code assumes `this.dataSource` or `Container.get(DataSource)`
- Can't easily switch databases per request

**Solution: Two Approaches**

---

## 🎨 **Approach 1: Minimal Changes (Recommended)**

### **Use Request Context + Schema Override**

Since you're already using the **same Voyager database**, just different schemas:
- Flowise uses: `flowise.*` schema
- n8n uses: `n8n.*` schema

**Key Insight:** ✅ **You don't need dynamic databases! Just dynamic schema!**

### **Implementation:**

#### **Step 1: Create Request Context Middleware**

```typescript
// packages/cli/src/middlewares/requestContext.ts

import { AsyncLocalStorage } from 'async_hooks';
import type { AuthenticatedRequest } from '@n8n/db';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

export const requestContextMiddleware = (req: any, res: any, next: any) => {
  const store = new Map();
  store.set('request', req);
  store.set('subdomain', req.subdomain);  // From subdomain validation
  store.set('schema', 'n8n');  // Always use n8n schema
  
  asyncLocalStorage.run(store, () => {
    next();
  });
};

export const getRequest = () => {
  return asyncLocalStorage.getStore()?.get('request') as AuthenticatedRequest;
};

export const getSubdomain = () => {
  return asyncLocalStorage.getStore()?.get('subdomain');
};

export const getSchema = () => {
  return asyncLocalStorage.getStore()?.get('schema');
};
```

#### **Step 2: Add .NET JWT Validation Middleware**

```typescript
// packages/cli/src/middlewares/dotnetJwtAuth.ts

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Container } from '@n8n/di';
import { UserRepository } from '@n8n/db';

// .NET Core JWT Configuration (from your .env)
const AUDIENCE_ID = process.env.DOTNET_AUDIENCE_ID;
const AUDIENCE_SECRET = process.env.DOTNET_AUDIENCE_SECRET;  // Base64
const ISSUER = process.env.DOTNET_ISSUER;
const SYMMETRIC_KEY = process.env.DOTNET_SYMMETRIC_KEY;  // Base64

export const dotnetJwtAuthMiddleware = async (
  req: Request, 
  res: Response, 
  next: NextFunction
) => {
  try {
    // 1. Extract token (Cookie or Bearer header)
    let token = req.cookies['n8n-auth'];  // Try n8n cookie first
    if (!token) {
      token = req.cookies['token'];  // Try Flowise cookie
    }
    if (!token) {
      const authHeader = req.headers['authorization'];
      if (authHeader?.startsWith('Bearer ')) {
        token = authHeader.split(' ')[1];
      }
    }

    if (!token) {
      return res.status(401).json({ message: 'Unauthorized: No token provided' });
    }

    // 2. Determine which secret to use (match Flowise logic)
    const isVirtuosoAI = process.env.IS_VIRTUOSO_AI === 'true';
    const secret = isVirtuosoAI 
      ? AUDIENCE_SECRET 
      : Buffer.from(AUDIENCE_SECRET, 'base64');

    const requestHost = req.hostname;
    const issuer = isVirtuosoAI 
      ? (ISSUER ?? requestHost) 
      : requestHost;
    
    // Encode subdomain as audience (like Flowise)
    const subdomain = req.subdomain || extractSubdomain(requestHost);
    const audience = isVirtuosoAI 
      ? (AUDIENCE_ID ?? requestHost) 
      : Buffer.from(subdomain).toString('base64');

    // 3. Verify JWT (same as .NET Core)
    const decodedToken = jwt.verify(token, secret, {
      algorithms: ['HS256'],
      issuer: issuer,
      audience: audience
    });

    // 4. Extract user info from token
    const payload = decodedToken as any;
    
    // 5. Find or create n8n user
    const userRepo = Container.get(UserRepository);
    let user = await userRepo.findOne({
      where: { email: payload.email || payload.sub },
      relations: ['role']
    });

    if (!user) {
      // Auto-create user from JWT if not exists
      user = await createUserFromJWT(payload);
    }

    // 6. Attach to request
    req.user = user;
    req.subdomain = subdomain;
    
    next();
    
  } catch (error: any) {
    console.error('JWT validation error:', error.message);
    return res.status(403).json({ message: `Forbidden: ${error.message}` });
  }
};

function extractSubdomain(host: string): string {
  const parts = host.split('.');
  return parts[0];
}

async function createUserFromJWT(payload: any) {
  // TODO: Implement auto-user creation from JWT
  // This should match your .NET Core user structure
  const userRepo = Container.get(UserRepository);
  
  // Create user with data from JWT
  const newUser = userRepo.create({
    email: payload.email || payload.sub,
    firstName: payload.given_name || payload.name || 'User',
    lastName: payload.family_name || '',
    // Don't set password - they authenticate via JWT only
    // Assign default role
  });
  
  return await userRepo.save(newUser);
}
```

#### **Step 3: Keep n8n in Same Voyager DB, Different Schema**

**You already did this!** ✅

Your configuration:
```powershell
# START_N8N_MSSQL.ps1
$env:DB_MSSQLDB_SCHEMA = "n8n"  # ✅ Correct!
```

**Result:**
```
Voyager Database:
  ├── flowise.workflow       ← Flowise data
  ├── flowise.chatflow       ← Flowise data
  │
  ├── n8n.workflow_entity    ← n8n data  
  ├── n8n.user               ← n8n data
  └── n8n.credentials_entity ← n8n data
```

**Perfect separation!** ✅

---

## 📋 Complete Implementation Checklist

### **Phase 1: JWT Validation (Core)**

- [ ] **1.1. Add Environment Variables**
  ```powershell
  # Add to START_N8N_MSSQL.ps1
  $env:DOTNET_AUDIENCE_ID = "<your-audience-id>"
  $env:DOTNET_AUDIENCE_SECRET = "<base64-secret>"
  $env:DOTNET_ISSUER = "<your-issuer>"
  $env:DOTNET_SYMMETRIC_KEY = "<base64-key>"
  ```

- [ ] **1.2. Create .NET JWT Middleware**
  - File: `packages/cli/src/middlewares/dotnetJwtAuth.ts`
  - Validate .NET Core JWT tokens
  - Extract user from token
  - Auto-create n8n user if doesn't exist

- [ ] **1.3. Modify n8n Startup**
  - Add middleware to Express app
  - Register before n8n's auth middleware
  - Handle token from cookie OR Bearer header

### **Phase 2: Request Context (Nice to Have)**

- [ ] **2.1. Create Request Context Middleware**
  - File: `packages/cli/src/middlewares/requestContext.ts`
  - Use AsyncLocalStorage
  - Store subdomain, user, request

- [ ] **2.2. Add to Express App**
  - Register early in middleware chain
  - Available throughout request lifecycle

### **Phase 3: Multi-DB Support (Optional)**

- [ ] **3.1. Subdomain Validation Middleware** (Copy from Flowise)
  - Extract subdomain from hostname
  - Query Elevate DB for company
  - Get Voyager DB credentials
  - Store in request context

- [ ] **3.2. Dynamic DataSource** (Complex!)
  - Create DataSource factory
  - Get credentials from Elevate DB
  - Create/cache DataSource per subdomain
  - Use in request context

**Note:** Since n8n and Flowise use the **SAME Voyager database**, you might not need this!

---

## 🔧 Detailed Implementation

### **Step 1: Environment Variables**

**Add to START_N8N_MSSQL.ps1:**

```powershell
# .NET Core JWT Settings (match your .NET Core API)
$env:DOTNET_AUDIENCE_ID = "YourAudienceId"
$env:DOTNET_AUDIENCE_SECRET = "Base64EncodedSecretFromDotNet"
$env:DOTNET_ISSUER = "https://your-api.com"
$env:DOTNET_SYMMETRIC_KEY = "Base64EncodedSymmetricKey"

# Optional: Enable .NET JWT validation
$env:USE_DOTNET_JWT = "true"

# Multi-tenant settings (from Flowise)
$env:IS_VIRTUOSO_AI = "false"  # or "true" depending on your setup
$env:USEAUTH = "true"

# Voyager Database (already configured!)
$env:DB_MSSQLDB_DATABASE = "dmnen_test"  # Voyager DB name
$env:DB_MSSQLDB_SCHEMA = "n8n"           # n8n schema ✅
```

---

### **Step 2: Create .NET JWT Middleware**

**File:** `packages/cli/src/middlewares/dotnet-jwt-auth.middleware.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Container } from '@n8n/di';
import { UserRepository } from '@n8n/db';
import { Logger } from '@n8n/backend-common';
import type { User } from '@n8n/db';

// .NET Core JWT Configuration
const AUDIENCE_ID = process.env.DOTNET_AUDIENCE_ID;
const AUDIENCE_SECRET_BASE64 = process.env.DOTNET_AUDIENCE_SECRET;
const ISSUER = process.env.DOTNET_ISSUER;
const SYMMETRIC_KEY_BASE64 = process.env.DOTNET_SYMMETRIC_KEY;

// Decode secrets (same as Flowise)
const base64url = require('base64url');
const AUDIENCE_SECRET = AUDIENCE_SECRET_BASE64 
  ? Buffer.from(base64url.toBuffer(AUDIENCE_SECRET_BASE64), 'base64')
  : null;
const SYMMETRIC_KEY = SYMMETRIC_KEY_BASE64
  ? Buffer.from(base64url.toBuffer(SYMMETRIC_KEY_BASE64), 'base64')
  : null;

export const dotnetJwtAuthMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const logger = Container.get(Logger);
  
  try {
    // Skip if .NET JWT is disabled
    if (process.env.USE_DOTNET_JWT !== 'true') {
      return next();
    }

    // 1. Extract token from Cookie OR Authorization header
    let token: string | undefined;
    
    // Priority 1: n8n cookie
    token = req.cookies['n8n-auth'];
    
    // Priority 2: Flowise cookie (for shared sessions)
    if (!token) {
      token = req.cookies['token'];
    }
    
    // Priority 3: Authorization header
    if (!token) {
      const authHeader = req.headers['authorization'];
      if (authHeader?.startsWith('Bearer ')) {
        token = authHeader.split(' ')[1];
      }
    }

    // If no token, skip (let n8n's default auth handle it)
    if (!token) {
      logger.debug('.NET JWT: No token found, skipping');
      return next();
    }

    // 2. Determine secret and validation params (match .NET Core)
    const isVirtuosoAI = process.env.IS_VIRTUOSO_AI === 'true';
    const secret = isVirtuosoAI ? AUDIENCE_SECRET : AUDIENCE_SECRET;
    
    const requestHost = req.hostname;
    const issuer = isVirtuosoAI ? (ISSUER ?? requestHost) : requestHost;
    
    // Get subdomain for audience validation
    const subdomain = extractSubdomain(requestHost);
    const audience = isVirtuosoAI 
      ? (AUDIENCE_ID ?? requestHost)
      : Buffer.from(subdomain).toString('base64');

    // 3. Verify JWT (same as .NET Core validation)
    const decodedToken = jwt.verify(token, secret, {
      algorithms: ['HS256'],
      issuer: issuer,
      audience: audience,
      complete: true
    }) as any;

    const payload = decodedToken.payload;
    
    logger.debug('.NET JWT verified successfully', { 
      userId: payload.sub || payload.id,
      subdomain 
    });

    // 4. Find or create n8n user from JWT
    const userRepo = Container.get(UserRepository);
    const userEmail = payload.email || payload.sub;
    
    let user = await userRepo.findOne({
      where: { email: userEmail },
      relations: ['role']
    });

    // Auto-create user if doesn't exist
    if (!user) {
      logger.info('.NET JWT: Creating new n8n user from JWT', { email: userEmail });
      user = await createN8nUserFromDotNetJWT(payload);
    }

    // 5. Attach user to request
    req.user = user;
    
    // Store .NET JWT info for later use
    req.dotnetJwtPayload = payload;
    req.subdomain = subdomain;
    
    logger.debug('.NET JWT: User authenticated', { 
      userId: user.id, 
      email: user.email,
      subdomain 
    });
    
    next();
    
  } catch (error: any) {
    // JWT validation failed
    logger.warn('.NET JWT validation failed', { 
      error: error.message,
      token: token?.substring(0, 20) + '...'
    });
    
    // Don't block - let n8n's default auth try
    // This allows fallback to n8n's own JWT or API keys
    next();
  }
};

function extractSubdomain(host: string): string {
  // Handle localhost
  if (host.includes('localhost') || host.includes('127.0.0.1')) {
    return 'default';
  }
  
  // Extract subdomain
  const parts = host.split('.');
  return parts[0];
}

async function createN8nUserFromDotNetJWT(payload: any): Promise<User> {
  const userRepo = Container.get(UserRepository);
  const logger = Container.get(Logger);
  
  // Create user from JWT claims
  const newUser = userRepo.create({
    email: payload.email || payload.sub,
    firstName: payload.given_name || payload.name || 'User',
    lastName: payload.family_name || '',
    // No password - they authenticate via .NET JWT only
    password: null,
    // Assign default role (or get from JWT claims)
    // role: await getDefaultRole()
  });
  
  const savedUser = await userRepo.save(newUser);
  logger.info('Created new n8n user from .NET JWT', { 
    userId: savedUser.id,
    email: savedUser.email 
  });
  
  return savedUser;
}

// Extend Express Request type
declare global {
  namespace Express {
    interface Request {
      dotnetJwtPayload?: any;
      subdomain?: string;
    }
  }
}
```

#### **Step 3: Integrate into n8n Server**

**File:** `packages/cli/src/Server.ts` (or main server file)

Find where n8n sets up Express middleware and add:

```typescript
import { dotnetJwtAuthMiddleware } from './middlewares/dotnet-jwt-auth.middleware';
import { requestContextMiddleware } from './middlewares/requestContext';

// In server setup:
app.use(cookieParser());  // ← Should already exist
app.use(requestContextMiddleware);  // ← ADD THIS
app.use(dotnetJwtAuthMiddleware);   // ← ADD THIS (before n8n's auth)

// Then n8n's existing middleware continues...
```

**Order matters!**
1. Cookie parser (to read cookies)
2. Request context (to store per-request data)
3. .NET JWT auth (to validate .NET tokens first)
4. n8n's existing auth (as fallback)

---

## 🔄 **Approach 2: Full Multi-DB Like Flowise (Complex)**

### **If You Need Separate Voyager Databases per Subdomain**

This is needed only if different companies have completely separate Voyager databases.

**Implementation:**

#### **Step 1: Copy Flowise's Subdomain Validation**

```typescript
// packages/cli/src/middlewares/subdomain-validation.middleware.ts

import { Request, Response, NextFunction } from 'express';
import { DataSource } from 'typeorm';

// Elevate DB connection (singleton)
let elevateDataSource: DataSource;

export const subdomainValidationMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    // Extract subdomain
    const host = req.hostname;
    const subdomain = extractSubdomain(host);
    
    // Query Elevate DB for company
    const company = await elevateDataSource.query(
      `SELECT * FROM company WHERE domain = @0`,
      [subdomain]
    );
    
    if (!company || company.length === 0) {
      return res.status(403).json({ 
        error: 'Invalid subdomain' 
      });
    }
    
    // Check if company is active
    if (company[0].inactive) {
      return res.status(403).json({ 
        error: 'Company inactive' 
      });
    }
    
    // Get Voyager DB credentials from company record
    const voyagerDataSource = await getVoyagerDataSource(company[0]);
    
    // Store in request context
    req.company = company[0];
    req.dataSource = voyagerDataSource;
    req.subdomain = subdomain;
    
    next();
    
  } catch (error) {
    console.error('Subdomain validation error:', error);
    return res.status(500).json({ error: 'Internal error' });
  }
};

async function getVoyagerDataSource(company: any): Promise<DataSource> {
  // Create or get cached DataSource for this company's Voyager DB
  // Use company.db_server, company.db_name, etc.
  
  const dataSource = new DataSource({
    type: 'mssql',
    host: company.db_server,
    port: 1433,
    database: company.db_name,
    username: company.db_user,
    password: company.db_password,
    schema: 'n8n',  // Use n8n schema
    // ... other options
  });
  
  if (!dataSource.isInitialized) {
    await dataSource.initialize();
  }
  
  return dataSource;
}
```

⚠️ **Warning:** This requires refactoring ALL database access in n8n to use `req.dataSource` instead of the singleton `DataSource`!

---

## 🎯 Recommended Approach

### **Use Approach 1** (Minimal Changes)

**Why:**
1. ✅ You're already using the **SAME Voyager database** for Flowise and n8n
2. ✅ Different schemas (`flowise.*` vs `n8n.*`) provide isolation
3. ✅ No need for dynamic database connections
4. ✅ Much simpler implementation
5. ✅ Less code to maintain

**What you get:**
- ✅ .NET JWT tokens work in n8n
- ✅ Shared authentication (one login for Flowise + n8n)
- ✅ Same user can access both systems
- ✅ Data isolation via schemas
- ✅ Minimal code changes

---

## 📝 Implementation Steps (Approach 1)

### **Step 1: Prepare Environment**

```powershell
# Copy .NET JWT settings from Flowise .env
# Add to n8n START_N8N_MSSQL.ps1

$env:USE_DOTNET_JWT = "true"
$env:DOTNET_AUDIENCE_ID = "YourAudienceId"
$env:DOTNET_AUDIENCE_SECRET = "Base64Secret"
$env:DOTNET_ISSUER = "https://your-api.com"
$env:IS_VIRTUOSO_AI = "false"  # or "true"
```

### **Step 2: Create Middleware Files**

```
packages/cli/src/middlewares/
├── requestContext.ts          # NEW - Request context
├── dotnet-jwt-auth.ts         # NEW - .NET JWT validation
└── index.ts                   # MODIFY - Export new middlewares
```

### **Step 3: Integrate Middleware**

**Find:** `packages/cli/src/Server.ts` or wherever Express app is configured

**Add:**
```typescript
import { dotnetJwtAuthMiddleware } from '@/middlewares/dotnet-jwt-auth';
import { requestContextMiddleware } from '@/middlewares/requestContext';

// Add early in middleware chain:
app.use(cookieParser());
app.use(requestContextMiddleware);
app.use(dotnetJwtAuthMiddleware);
```

### **Step 4: Test**

```powershell
# 1. Start n8n
.\START_N8N_MSSQL.ps1

# 2. Get JWT token from your .NET API
# 3. Access n8n with token:
#    - Cookie: token=<jwt-token>
#    - OR Header: Authorization: Bearer <jwt-token>

# 4. Verify user is authenticated
# 5. Check n8n.user table for auto-created user
```

---

## 🔐 JWT Token Structure (From .NET Core)

**What your .NET Core API generates:**

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "user-id" or "email",
    "email": "user@example.com",
    "name": "User Name",
    "given_name": "First",
    "family_name": "Last",
    "aud": "<audience-id>",
    "iss": "<issuer>",
    "exp": 1234567890,
    "iat": 1234567890,
    // ... other claims from .NET Core
  }
}
```

**Make sure your middleware extracts:**
- Email (for finding/creating n8n user)
- Name (for user profile)
- Any workspace/organization IDs (if in token)

---

## 🎨 Architecture Diagram

```
User Login
    ↓
.NET Core API
    ↓
Generate JWT Token
    │
    ├→ Set Cookie: token=<jwt>
    └→ Return: { token, user }
    
User Access Flowise
    ↓
Flowise reads cookie: token
    ↓
Validates with .NET JWT settings
    ↓
Query: flowise.* schema
    ↓
✅ Works!

User Access n8n (SAME TOKEN!)
    ↓
n8n reads cookie: token
    ↓
dotnetJwtAuthMiddleware validates
    ↓
Auto-create n8n user if needed
    ↓
Query: n8n.* schema  
    ↓
✅ Works!
```

**One token, two apps, same database, different schemas!** 🎉

---

## ⚠️ Important Considerations

### **1. User Synchronization**

**Question:** When a user logs in via .NET API and accesses n8n, should we:

**Option A:** Auto-create n8n user from JWT
```typescript
if (!user) {
  user = await createUserFromJWT(payload);
}
```

**Option B:** Require pre-registration in n8n
```typescript
if (!user) {
  return res.status(401).json({ 
    message: 'User not registered in n8n' 
  });
}
```

**Recommendation:** ✅ **Option A** (matches Flowise behavior)

---

### **2. Role Mapping**

**Question:** How to map .NET roles to n8n roles?

**Options:**

**A. Default Role:**
```typescript
// All .NET users get 'member' role in n8n
user.role = await getRoleByName('global:member');
```

**B. JWT Claim Mapping:**
```typescript
// .NET JWT includes role claim
if (payload.role === 'admin') {
  user.role = await getRoleByName('global:owner');
} else {
  user.role = await getRoleByName('global:member');
}
```

**C. Organization-Based:**
```typescript
// Check organization in Flowise, map to n8n role
if (payload.organizationId) {
  // Query organization from Voyager DB
  // Determine appropriate n8n role
}
```

**Recommendation:** Start with **Option A** (simple), enhance later

---

### **3. Schema Isolation**

**Current Setup:** ✅ **Perfect!**

```
Voyager Database (dmnen_test):
  ├── flowise.workflow         ← Flowise data
  ├── flowise.chatflow         ← Flowise data
  │
  └── n8n.workflow_entity      ← n8n data
      n8n.user                 ← n8n data
      n8n.credentials_entity   ← n8n data
```

**No changes needed!** Your schema configuration is correct.

---

## 📦 Dependencies to Add

```json
{
  "dependencies": {
    "base64url": "^3.0.1",  // For base64 URL encoding (like .NET)
    "cookie-parser": "^1.4.6"  // Probably already in n8n
  }
}
```

---

## 🧪 Testing Plan

### **Test 1: JWT Validation**

```powershell
# Get JWT from .NET API
$token = "<jwt-token-from-dotnet>"

# Test with curl
curl http://localhost:5678/rest/workflows `
  -H "Authorization: Bearer $token"

# Should return workflows (if user authenticated)
```

### **Test 2: Cookie Authentication**

```powershell
# Set cookie in browser
document.cookie = "token=<jwt-token-from-dotnet>"

# Navigate to n8n UI
# Should be authenticated
```

### **Test 3: User Auto-Creation**

```sql
-- Check n8n users table
SELECT * FROM n8n.[user];

-- Should see user auto-created from JWT
```

### **Test 4: Schema Isolation**

```sql
-- Verify Flowise and n8n don't see each other's data
SELECT * FROM flowise.workflow;  -- Flowise workflows
SELECT * FROM n8n.workflow_entity;  -- n8n workflows

-- Should be separate!
```

---

## 🎯 Summary

### **Your Situation:**

1. ✅ .NET Core API generates JWT tokens
2. ✅ Flowise validates these tokens (working)
3. ✅ Same Voyager database for Flowise + n8n
4. ✅ Different schemas (flowise.* vs n8n.*)
5. ❓ Need n8n to accept same .NET JWT tokens

### **Solution:**

✅ **Add .NET JWT validation middleware to n8n**
- Validate tokens with same secret/config as .NET
- Auto-create users from JWT
- Use existing n8n schema in Voyager DB
- Minimal code changes

**Complexity:** 🟢 **LOW-MEDIUM**

**Time:** ~1-2 days

---

## 🚀 Ready to Implement?

**I can help you:**

1. ✅ Create the .NET JWT middleware
2. ✅ Create request context middleware
3. ✅ Integrate into n8n's server
4. ✅ Add environment variables
5. ✅ Test the implementation
6. ✅ Handle user auto-creation
7. ✅ Map roles from .NET to n8n

**What information do I need from you:**

1. **JWT Token Sample** (or payload structure from .NET API)
2. **Environment Variable Values** (AUDIENCE_ID, etc.)
3. **.NET Core JWT Configuration** (algorithm, claims, etc.)
4. **How should roles map?** (.NET roles → n8n roles)
5. **Should users auto-create?** (or pre-register required)

**Ready to start implementing?** 🚀

