# 📊 Flowise JWT Authentication - Complete Analysis

## Overview

Flowise implements a comprehensive **multi-tenant JWT authentication system** with:
- ✅ JWT tokens (access + refresh tokens)
- ✅ Cookie-based authentication
- ✅ Subdomain-based multi-tenancy
- ✅ Dynamic database connections per subdomain
- ✅ SSO integration
- ✅ Session persistence (Redis/Database/SQLite)
- ✅ Passport.js integration
- ✅ API Key fallback authentication

---

## 🏗️ Architecture Components

### 1. **Middleware Stack (Execution Order)**

```typescript
// From index.ts (lines 200-257)

1. Express body parser & CORS
2. Cookie parser
3. Request logger
4. queryParamsStore                    // Store query params
5. requestContextMiddleware            // AsyncLocalStorage for request context
6. Subdomain validation                // Multi-tenant database selection
7. initializeJwtCookieMiddleware       // Passport + JWT setup
8. Custom authentication logic         // Whitelist URLs + JWT/API Key validation
```

### 2. **JWT Authentication Components**

#### **A. authenticateJWT.ts** (Primary JWT Validation)

```typescript
// Key Features:
- Extracts token from: Authorization header OR cookie
- Validates token with jwt.verify()
- Supports multiple secret types (VirtuosoAI vs regular)
- Validates issuer and audience
- Falls back to API Key validation if JWT fails

// Configuration:
const AUDIENCE_ID = process.env.AUDIENCE_ID
const AUDIENCE_SECRET = process.env.AUDIENCE_SECRET
const SYMMETRIC_KEY = process.env.SYMMETRIC_KEY
const ISSUER = process.env.ISSUER

// Token Sources:
1. Authorization: Bearer <token>
2. Cookie: token=<token>

// Validation Flow:
jwt.verify(token, secret, {
    algorithms: ["HS256"],
    issuer: issuer,
    audience: audience
})
```

#### **B. Passport JWT Strategy** (AuthStrategy.ts)

```typescript
// Cookie-based JWT extraction
const _cookieExtractor = (req) => {
    return req.cookies['token']
}

// JWT Strategy Configuration:
- Extracts JWT from cookies
- Decrypts encrypted user metadata
- Validates user ID matches encrypted data
- Attaches user to req.user

// Security:
- User info encrypted in token payload
- Format: userId:workspaceId (encrypted)
```

#### **C. Passport Local Strategy** (Login)

```typescript
// Login Flow (index.ts lines 88-179):
1. Receive email + password
2. Call AccountService.login()
3. Fetch user workspace details
4. Load organization, role, permissions
5. Create LoggedInUser object with:
   - User info
   - Active workspace
   - Organization details
   - Permissions array
   - Features from subscription
6. Generate JWT tokens
7. Set cookies
```

### 3. **Token Management**

#### **Access Token (Short-lived)**

```typescript
// Default: 60 minutes
const JWT_TOKEN_EXPIRY_IN_MINUTES = process.env.JWT_TOKEN_EXPIRY_IN_MINUTES || 60

// Token Payload:
{
    id: userId,
    username: userName,
    meta: encrypted(userId:workspaceId),
    exp: timestamp,
    iat: timestamp,
    aud: audience,
    iss: issuer
}
```

#### **Refresh Token (Long-lived)**

```typescript
// Default: 90 days (129600 minutes)
const JWT_REFRESH_TOKEN_EXPIRY_IN_MINUTES = process.env.JWT_REFRESH_TOKEN_EXPIRY_IN_MINUTES || 129600

// Stored in httpOnly cookie
// Used to generate new access tokens without re-login
```

#### **Token Refresh Endpoint**

```typescript
// POST /api/v1/auth/refreshToken
- Reads refreshToken from cookies
- Verifies refresh token
- Generates new access token
- Updates cookies
- Supports SSO token refresh
```

### 4. **Session Persistence**

#### **Three Storage Options:**

**A. Redis (for Queue Mode)**
```typescript
// Uses: connect-redis
const redisStore = new RedisStore({ 
    client: redis 
})
```

**B. Database (PostgreSQL/MySQL)**
```typescript
// PostgreSQL: connect-pg-simple
// MySQL: express-mysql-session
// Table: login_sessions
```

**C. SQLite (Default)**
```typescript
// Uses: connect-sqlite3
// File: ~/.flowise/database.sqlite
// Table: login_sessions
```

### 5. **Multi-Tenant Architecture**

#### **Subdomain Validation** (SubdomainValidation.ts)

```typescript
// Flow:
1. Extract subdomain from host
   - Format: subdomain.domain.com
   
2. Query elevate database for company:
   - SELECT * FROM company WHERE domain = 'subdomain'
   
3. Check company status:
   - If inactive → 403 Forbidden
   - If not found → 403 Invalid subdomain
   
4. Get database connection for subdomain:
   - Each subdomain has its own database
   - DataSource stored in req.dataSource
   
5. Add to request:
   - req.subdomain
   - req.company
   - req.dataSource
```

#### **Request Context** (requestContext.ts)

```typescript
// Uses AsyncLocalStorage to store per-request data:
- DataSource (different DB per subdomain)
- Request object
- Any other context data

// Access anywhere:
const dataSource = getRequestDataSource()
```

### 6. **Authentication Flow**

#### **Login Flow**

```mermaid
POST /api/v1/auth/login
    ↓
Passport Local Strategy
    ↓
AccountService.login(email, password)
    ↓
Validate credentials
    ↓
Fetch user workspace, org, role, permissions
    ↓
Generate JWT Access Token + Refresh Token
    ↓
Set httpOnly cookies (token, refreshToken)
    ↓
Return LoggedInUser object
```

#### **Authenticated Request Flow**

```mermaid
Request → /api/v1/some-endpoint
    ↓
Check if whitelisted (public endpoint)
    ↓ (if not whitelisted)
Check for token:
  - Cookie: token
  - Header: Authorization: Bearer <token>
    ↓
authenticateJWT middleware
    ↓
jwt.verify(token, secret, options)
    ↓
If valid → req.user = decodedUser
    ↓
If invalid → Try API Key validation
    ↓
If both fail → 401 Unauthorized
    ↓
Continue to route handler
```

### 7. **API Key Fallback**

```typescript
// If JWT fails, try API Key:
const isKeyValidated = await validateAPIKey(req)

// API Key flow:
1. Extract API key from header/query
2. Find workspace by API key
3. Load organization, role, permissions
4. Set req.user with owner role permissions
5. Continue request
```

### 8. **LoggedInUser Object**

```typescript
interface LoggedInUser {
    id: string                                  // User ID
    email: string                               // User email
    name: string                                // User name
    roleId: string                              // Role ID
    activeOrganizationId: string                // Current org
    activeOrganizationSubscriptionId: string    // Subscription
    activeOrganizationCustomerId: string        // Customer ID
    activeOrganizationProductId: string         // Product ID
    isOrganizationAdmin: boolean                // Admin flag
    activeWorkspaceId: string                   // Current workspace
    activeWorkspace: string                     // Workspace name
    assignedWorkspaces: IAssignedWorkspace[]    // All workspaces
    isApiKeyValidated: boolean                  // Auth method
    permissions: string[]                       // Permission array
    features: Record<string, string>            // Feature flags
    ssoRefreshToken?: string                    // SSO tokens
    ssoToken?: string
    ssoProvider?: string
}
```

---

## 🔑 Key Features

### 1. **Dual Authentication**
- JWT Token (primary)
- API Key (fallback)

### 2. **Token Storage**
- httpOnly cookies (secure)
- Bearer token in header (for API calls)

### 3. **Token Encryption**
- User metadata encrypted in token payload
- Prevents token tampering

### 4. **Multi-Tenancy**
- Subdomain-based isolation
- Each subdomain → separate database
- Dynamic DataSource per request

### 5. **Whitelist System**
- Public endpoints bypass authentication
- Examples: /health, /public-chatflows, /api/v1/get-icons

### 6. **Session Management**
- express-session with Passport
- Persistent sessions (Redis/DB/SQLite)
- Session survives server restart

---

## 📝 Configuration (Environment Variables)

```bash
# JWT Settings
JWT_AUTH_TOKEN_SECRET=auth_token           # Access token secret
JWT_REFRESH_TOKEN_SECRET=refresh_token     # Refresh token secret
JWT_AUDIENCE=AUDIENCE                      # Token audience
JWT_ISSUER=ISSUER                          # Token issuer
JWT_TOKEN_EXPIRY_IN_MINUTES=60             # Access token expiry
JWT_REFRESH_TOKEN_EXPIRY_IN_MINUTES=129600 # Refresh token expiry (90 days)

# Custom Auth Settings (for VirtuosoAI)
USEAUTH=true                               # Enable authentication
SYMMETRIC_KEY=<base64-key>                 # Symmetric encryption key
ISSUER=<issuer-url>                        # Custom issuer
AUDIENCE_ID=<audience-id>                  # Custom audience
AUDIENCE_SECRET=<audience-secret>          # Custom secret

# Session Storage
EXPIRE_AUTH_TOKENS_ON_RESTART=false        # Persist sessions
MODE=queue                                 # Use Redis for sessions
REDIS_HOST=localhost
REDIS_PORT=6379

# App Settings
APP_URL=https://yourdomain.com             # For secure cookies
EXPRESS_SESSION_SECRET=flowise             # Session secret
```

---

## 🔐 Security Features

### 1. **Token Security**
- httpOnly cookies (prevent XSS)
- Secure flag for HTTPS
- sameSite: 'lax' (prevent CSRF)
- Short-lived access tokens (60 min)
- Encrypted user metadata in payload

### 2. **Session Security**
- Session store persistence
- Session hijacking prevention
- Automatic token refresh

### 3. **Multi-Layer Authentication**
1. JWT token validation
2. API Key validation
3. Subdomain validation
4. Company status check
5. License validation (Enterprise)

---

## 📦 Dependencies Used

```json
{
    "passport": "^0.x.x",              // Authentication framework
    "passport-jwt": "^4.x.x",          // JWT strategy
    "passport-local": "^1.x.x",        // Local (email/password) strategy
    "jsonwebtoken": "^9.x.x",          // JWT creation/validation
    "express-session": "^1.x.x",       // Session management
    "cookie-parser": "^1.x.x",         // Cookie parsing
    "connect-redis": "^7.x.x",         // Redis session store
    "connect-pg-simple": "^9.x.x",     // PostgreSQL session store
    "express-mysql-session": "^3.x.x", // MySQL session store
    "connect-sqlite3": "^0.x.x",       // SQLite session store
    "ioredis": "^5.x.x",               // Redis client
    "base64url": "^3.x.x"              // Base64 URL encoding
}
```

---

## 🎯 Comparison: Flowise vs n8n Authentication

| Feature | Flowise | n8n (Current) |
|---------|---------|---------------|
| **Auth Method** | JWT + Passport | JWT + Session cookies |
| **Token Storage** | httpOnly cookies | httpOnly cookies |
| **Refresh Tokens** | ✅ Yes (90 days) | ✅ Yes |
| **Multi-tenancy** | ✅ Subdomain-based | ❌ No |
| **Session Persistence** | Redis/DB/SQLite | Database only |
| **API Key Fallback** | ✅ Yes | ✅ Yes |
| **SSO** | ✅ Yes | ✅ Yes (SAML) |
| **Passport.js** | ✅ Yes | ✅ Yes |
| **Dynamic DB per request** | ✅ Yes (per subdomain) | ❌ Single DB |

---

## 🔄 How to Adapt to n8n

### **Challenge: n8n's Architecture is Different**

n8n already has:
- ✅ JWT authentication (packages/cli/src/auth)
- ✅ User management
- ✅ Session handling
- ✅ Cookie-based auth
- ✅ Passport.js integration
- ✅ API key authentication

**Key Differences:**
1. **n8n is single-tenant** (one database for all users)
2. **Flowise is multi-tenant** (one database per subdomain)
3. **n8n uses projects/credentials** (not workspaces)
4. **n8n has built-in auth** (Flowise added it custom)

---

## 💡 What Can Be Adapted from Flowise?

### **1. Subdomain-Based Multi-Tenancy** (Major Feature)

**Effort:** ⚠️ **HIGH** (requires significant n8n architecture changes)

**What it does:**
- Each subdomain (customer1.yourdomain.com) → separate database
- Dynamic database connection per request
- Complete data isolation

**Implementation in n8n:**
- ❌ **Complex** - n8n's DataSource is initialized once at startup
- Would need to refactor entire DB connection architecture
- AsyncLocalStorage for request-specific DataSource
- Dynamic schema/database switching

**Recommendation:** ⚠️ **Skip this** unless absolutely required

---

### **2. Request Context Middleware** (Useful!)

**Effort:** 🟢 **LOW**

**What it does:**
- Uses AsyncLocalStorage to store request-specific data
- Access request/user anywhere without passing it through function params

**Implementation in n8n:**
```typescript
// Add to packages/cli/src/middlewares/requestContext.ts
import { AsyncLocalStorage } from 'async_hooks';
import { Request } from 'express';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

export const requestContextMiddleware = (req, res, next) => {
  const store = new Map<string, any>();
  store.set('request', req);
  store.set('user', req.user);
  
  asyncLocalStorage.run(store, () => {
    next();
  });
};

export const getRequest = () => {
  return asyncLocalStorage.getStore()?.get('request');
};

export const getUser = () => {
  return asyncLocalStorage.getStore()?.get('user');
};
```

**Benefits:**
- Access user/request anywhere in the call stack
- No need to pass req through every function
- Cleaner code

**Recommendation:** ✅ **Useful addition**

---

### **3. Token Encryption in Payload** (Security Enhancement)

**Effort:** 🟡 **MEDIUM**

**What it does:**
- Encrypts sensitive user data in JWT payload
- Format: `meta: encrypted(userId:workspaceId)`
- Validates on each request

**Current Flowise Implementation:**
```typescript
// Generate token
const encryptedUserInfo = encryptToken(userId + ':' + workspaceId)
const token = sign(
    { id: userId, username: userName, meta: encryptedUserInfo },
    secret,
    options
)

// Validate token
const meta = decryptToken(payload.meta)
const ids = meta.split(':')
if (req.user.id !== ids[0]) {
    return done(null, false, 'Unauthorized')
}
```

**Implementation in n8n:**
- Add encryption/decryption utilities
- Modify JWT payload to include encrypted metadata
- Add validation in JWT strategy

**Recommendation:** 🟡 **Optional** - adds security but n8n's current JWT is secure

---

### **4. Dual Token Support (Cookie + Bearer)**

**Effort:** 🟢 **LOW**

**What it does:**
- Accept tokens from cookies OR Authorization header
- Useful for web UI (cookies) and API clients (Bearer tokens)

**Current Flowise:**
```typescript
let authHeader = req.headers['authorization'];

if (!authHeader || !authHeader.startsWith("Bearer ")) {
    authHeader = getCookie(req, 'token') ?? undefined;
}

const token = authHeader.startsWith("Bearer ") 
    ? authHeader.split(" ")[1] 
    : authHeader;
```

**n8n Status:** ✅ **Already has this!** (check packages/cli/src/auth)

**Recommendation:** ✅ **Verify n8n implementation, likely already exists**

---

### **5. API Key Fallback Authentication**

**Effort:** 🟢 **LOW**

**What it does:**
- If JWT validation fails, try API Key
- Useful for programmatic access

**Flowise Implementation:**
```typescript
try {
    jwt.verify(token, secret, options)
} catch (error) {
    // JWT failed, try API Key
    const isKeyValidated = await validateAPIKey(req)
    if (!isKeyValidated) {
        return res.status(403).json({ message: 'Forbidden' })
    }
}
```

**n8n Status:** ✅ **Already has API Key authentication**

**Recommendation:** ✅ **Verify n8n's fallback logic**

---

### **6. Extended LoggedInUser Object**

**Effort:** 🟡 **MEDIUM**

**What it adds:**
```typescript
interface LoggedInUser {
    // ... existing n8n user fields
    
    // Flowise additions:
    activeOrganizationId: string
    activeOrganizationSubscriptionId: string
    activeOrganizationCustomerId: string
    activeOrganizationProductId: string
    isOrganizationAdmin: boolean
    activeWorkspaceId: string
    activeWorkspace: string
    assignedWorkspaces: IAssignedWorkspace[]
    permissions: string[]          // Array of permission strings
    features: Record<string, string>  // Feature flags
}
```

**Implementation:**
- Extend n8n's User entity
- Add organization/subscription fields
- Add permissions array
- Add feature flags from license

**Recommendation:** 🟡 **Useful if you need organization/subscription tracking**

---

## 🚀 Recommended Adaptations for n8n

### **What to Implement:**

#### **1. Request Context Middleware** ✅ (Easy Win)

**Why:** Access user/request anywhere without parameter passing

**Steps:**
1. Create `packages/cli/src/middlewares/requestContext.ts`
2. Add middleware to Express app
3. Use throughout codebase

**Benefit:** Cleaner code, easier debugging

---

#### **2. Enhanced JWT Payload Encryption** 🟡 (Optional Security)

**Why:** Extra security layer for token payloads

**Steps:**
1. Create encryption utilities (similar to Flowise's tempTokenUtils)
2. Modify JWT generation to encrypt user metadata
3. Add validation in JWT strategy

**Benefit:** Harder to forge tokens even if secret is compromised

---

#### **3. Extended User Context** 🟡 (If Needed)

**Why:** Track organization, subscriptions, feature flags

**Steps:**
1. Add organization/subscription tables (if not exist)
2. Extend User entity
3. Add permissions array
4. Load features from license

**Benefit:** Better multi-org support, feature flagging

---

### **What NOT to Implement:**

#### **1. Subdomain Multi-Tenancy** ❌

**Why:** 
- ⚠️ **Massive architectural change**
- Requires dynamic DataSource per request
- n8n is designed as single-tenant
- Would break many existing features

**Alternative:**
- Use n8n's existing project-based isolation
- Use separate n8n instances for true multi-tenancy

---

#### **2. Multiple Session Stores** ❌

**Why:**
- n8n already has session persistence
- Adding Redis/MySQL/SQLite stores is complex
- Not necessary unless specific requirement

**Alternative:**
- Use n8n's existing database session store

---

## 📊 Implementation Complexity Matrix

| Feature | Effort | Value | Recommendation |
|---------|--------|-------|----------------|
| Request Context Middleware | 🟢 Low | High | ✅ Implement |
| Token Payload Encryption | 🟡 Medium | Medium | 🟡 Optional |
| Extended User Object | 🟡 Medium | Medium | 🟡 If needed |
| API Key Fallback | 🟢 Low | High | ✅ Check existing |
| Subdomain Multi-Tenancy | 🔴 High | Low* | ❌ Skip |
| Multiple Session Stores | 🟡 Medium | Low | ❌ Skip |

*Low value because n8n's project system already provides isolation

---

## 🎯 Recommended Action Plan

### **Phase 1: Analysis** (Current)
- [x] Study Flowise authentication
- [ ] Study n8n's existing authentication
- [ ] Identify gaps/improvements

### **Phase 2: Low-Effort Improvements**
- [ ] Implement Request Context Middleware
- [ ] Verify JWT + Cookie support
- [ ] Verify API Key fallback

### **Phase 3: Medium-Effort Enhancements** (Optional)
- [ ] Add token payload encryption
- [ ] Extend User object with permissions array
- [ ] Add feature flags system

### **Phase 4: Testing**
- [ ] Test authentication flow
- [ ] Test token refresh
- [ ] Test API key fallback
- [ ] Load testing

---

## 📚 Next Steps

**Tell me what you want to implement:**

1. **Request Context Middleware?** (Easy, useful)
2. **Token encryption?** (Medium, security enhancement)
3. **Extended user permissions?** (Medium, depends on your needs)
4. **Study n8n's auth first?** (Recommended - see what exists)

**I'm ready to help you implement any of these!** 🚀

---

## 🔍 Files to Study in n8n

Before implementing, let's check what n8n already has:

```
packages/cli/src/
├── auth/
│   ├── auth.service.ts
│   ├── jwt.service.ts
│   └── ...
├── middlewares/
│   ├── auth.middleware.ts
│   └── ...
├── controllers/
│   ├── auth.controller.ts
│   └── ...
└── services/
    ├── user.service.ts
    └── ...
```

**Want me to analyze n8n's existing authentication system first?** 🔍

