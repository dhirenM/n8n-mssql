# 🔐 n8n vs Flowise Authentication - Complete Comparison

## Executive Summary

Both n8n and Flowise have robust authentication systems, but with different architectures and features.

**Key Finding:** 🎉 **n8n already has 90% of Flowise's authentication features!**

---

## 📊 Feature Comparison Matrix

| Feature | n8n | Flowise | Winner |
|---------|-----|---------|--------|
| **JWT Authentication** | ✅ Yes | ✅ Yes | 🟰 Tie |
| **Cookie-based Auth** | ✅ Yes (`n8n-auth`) | ✅ Yes (`token`) | 🟰 Tie |
| **Token Refresh** | ✅ Auto-refresh | ✅ Separate refresh token | 🏆 n8n (simpler) |
| **MFA Support** | ✅ Yes (TOTP) | ❌ No | 🏆 n8n |
| **SSO** | ✅ SAML + OIDC | ✅ OAuth (custom) | 🏆 n8n (more complete) |
| **LDAP** | ✅ Yes | ❌ No | 🏆 n8n |
| **API Key Auth** | ✅ Yes | ✅ Yes | 🟰 Tie |
| **Password Reset** | ✅ Email + Token | ❓ Unknown | 🏆 n8n |
| **Session Hijacking Prevention** | ✅ Yes (browserId) | ❓ Partial | 🏆 n8n |
| **Role-Based Access** | ✅ Yes (projects/scopes) | ✅ Yes (workspaces) | 🟰 Tie |
| **License Quota** | ✅ Yes | ✅ Yes | 🟰 Tie |
| **Multi-Tenancy** | ❌ No (single DB) | ✅ Yes (per subdomain) | 🏆 Flowise |
| **Request Context** | ❌ No | ✅ Yes (AsyncLocalStorage) | 🏆 Flowise |
| **Token Encryption** | ✅ Hash-based | ✅ AES encryption | 🟰 Tie |
| **Passport.js** | ❌ No (custom) | ✅ Yes | 🏆 Flowise |

---

## 🏗️ Architecture Comparison

### **n8n Authentication Architecture**

```
Request → Express App
    ↓
ControllerRegistry
    ↓
Route Metadata (@Get, @Post decorators)
    ↓
Middleware Stack:
  1. Rate Limiting (if enabled)
  2. AuthService.createAuthMiddleware()
     - Read cookie: n8n-auth
     - Verify JWT token
     - Check invalid token table
     - Validate browserId (session hijacking prevention)
     - Check MFA if enforced
     - Auto-refresh token if near expiry
     - Set req.user
  3. LastActiveAt tracking
  4. License feature check (if required)
  5. Access scope validation (if required)
  6. Controller middlewares
    ↓
Route Handler (Controller method)
```

### **Flowise Authentication Architecture**

```
Request → Express App
    ↓
Middleware Stack (in order):
  1. Body parser + CORS
  2. Cookie parser
  3. Request logger
  4. queryParamsStore
  5. requestContextMiddleware (AsyncLocalStorage)
  6. validateSubdomain
     - Extract subdomain
     - Query company from elevate DB
     - Get subdomain-specific DataSource
     - Set req.dataSource
  7. initializeJwtCookieMiddleware (Passport)
  8. Custom auth logic:
     - Check if URL whitelisted
     - If not: JWT or API Key required
     - Set req.user
    ↓
Route Handler
```

---

## 🔍 Detailed Feature Analysis

### **1. JWT Implementation**

#### **n8n**

**Location:** `packages/cli/src/services/jwt.service.ts`

```typescript
@Service()
export class JwtService {
    jwtSecret: string  // Auto-generated from encryption key or config
    
    sign(payload, options): string
    verify<T>(token, options): T
    decode<T>(token): T
}
```

**JWT Payload:**
```typescript
interface AuthJwtPayload {
    id: string;          // User ID
    hash: string;        // Hash of email:password:mfa
    browserId?: string;  // Browser fingerprint (session hijacking prevention)
    usedMfa?: boolean;   // MFA used during login
}
```

**Key Features:**
- ✅ Auto-generates secret from encryption key
- ✅ Hash includes email + password + MFA secret
- ✅ Browser ID validation (prevents session hijacking)
- ✅ MFA tracking in token
- ✅ Token invalidation table (`InvalidAuthToken`)
- ✅ Auto-refresh before expiry

---

#### **Flowise**

**Location:** `packages/server/src/middleware/authenticateJWT.ts`

```typescript
const jwt = require('jsonwebtoken');

// JWT payload (custom)
{
    id: userId,
    username: userName,
    meta: encrypted(userId:workspaceId),  // Encrypted metadata
    exp: timestamp,
    iat: timestamp,
    aud: audience,
    iss: issuer
}
```

**Key Features:**
- ✅ Encrypted metadata in payload
- ✅ Custom audience/issuer validation
- ✅ Multiple secret support (VirtuosoAI vs regular)
- ✅ Cookie + Bearer token support
- ❌ No browser ID tracking
- ✅ Separate refresh token (90 days)

---

### **2. Cookie Management**

#### **n8n**

**Cookie Name:** `n8n-auth`

**Configuration:**
```typescript
// From GlobalConfig
res.cookie(AUTH_COOKIE_NAME, token, {
    maxAge: jwtSessionDurationHours * 3600 * 1000,
    httpOnly: true,
    sameSite: config.auth.cookie.samesite,  // 'lax' or 'strict'
    secure: config.auth.cookie.secure       // true for HTTPS
});
```

**Features:**
- ✅ Single cookie (token auto-refreshes)
- ✅ Configurable via environment
- ✅ Auto-clear on logout/error
- ✅ Secure defaults

---

#### **Flowise**

**Cookie Names:** `token` + `refreshToken`

```typescript
// Access Token
res.cookie('token', accessToken, {
    httpOnly: true,
    secure: secureCookie,  // Based on APP_URL
    sameSite: 'lax'
});

// Refresh Token
res.cookie('refreshToken', refreshToken, {
    httpOnly: true,
    secure: secureCookie,
    sameSite: 'lax'
});
```

**Features:**
- ✅ Dual cookie system (access + refresh)
- ✅ Long-lived refresh token (90 days)
- ✅ Separate refresh endpoint
- ❌ More complex (two cookies to manage)

---

### **3. Authentication Middleware**

#### **n8n**

**Location:** `packages/cli/src/auth/auth.service.ts`

```typescript
createAuthMiddleware(options: {
    allowSkipMFA: boolean;
    allowSkipPreviewAuth?: boolean;
    allowUnauthenticated?: boolean;
}) {
    return async (req, res, next) => {
        const token = req.cookies[AUTH_COOKIE_NAME];
        
        if (token) {
            // Check if token is in invalid list
            const isInvalid = await this.invalidAuthTokenRepository.existsBy({ token });
            if (isInvalid) throw new AuthError('Unauthorized');
            
            // Resolve JWT and get user
            const [user, { usedMfa }] = await this.resolveJwt(token, req, res);
            
            // Check MFA enforcement
            if (mfaEnforced && !usedMfa && !allowSkipMFA) {
                if (user.mfaEnabled) {
                    throw new AuthError('MFA not used');
                } else {
                    return res.status(401).json({ mfaRequired: true });
                }
            }
            
            req.user = user;
            req.authInfo = { usedMfa };
        }
        
        // Handle unauthenticated requests
        if (req.user) next();
        else if (shouldSkipAuth) next();
        else res.status(401).json({ message: 'Unauthorized' });
    };
}
```

**Applied Per-Route:**
```typescript
@Get('/workflows')  // Auth enabled by default
@Get('/public-workflows', { skipAuth: true })  // Public endpoint
@Post('/login', { skipAuth: true, rateLimit: true })  // Login endpoint
```

**Features:**
- ✅ Decorator-based auth control
- ✅ Per-route MFA enforcement
- ✅ Browser ID validation
- ✅ Auto token refresh
- ✅ Invalid token tracking
- ✅ Optional authentication mode
- ✅ Preview mode skip auth

---

#### **Flowise**

**Location:** `packages/server/src/middleware/authenticateJWT.ts`

```typescript
export const authenticateJWT = async (req, res, next) => {
    // Get token from header or cookie
    let authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        authHeader = getCookie(req, 'token');
    }
    
    const token = authHeader.startsWith("Bearer ") 
        ? authHeader.split(" ")[1] 
        : authHeader;
    
    // Verify token
    const decodedToken = jwt.verify(token, secret, {
        algorithms: ["HS256"],
        issuer: issuer,
        audience: audience
    });
    
    // Falls back to API Key if JWT fails
    if (error && appConfig.UseAuth) {
        const isKeyValidated = await validateAPIKey(req);
        if (!isKeyValidated) {
            return res.status(403).json({ message: 'Forbidden' });
        }
    }
    
    next();
};
```

**Applied Globally:**
```typescript
// In index.ts (lines 263-367)
app.use(async (req, res, next) => {
    if (req.path.includes('/api/v1')) {
        const isWhitelisted = whitelistURLs.some(url => req.path.startsWith(url));
        
        if (isWhitelisted) {
            next();
        } else {
            // Check JWT, then API Key
            authenticateJWT(req, res, next);
        }
    } else {
        next();  // Assets, etc.
    }
});
```

**Features:**
- ✅ Dual token source (cookie + Bearer)
- ✅ API Key fallback
- ✅ Whitelist system
- ❌ No per-route control
- ❌ No MFA support
- ❌ No browser ID validation

---

### **4. User Object / Request Extensions**

#### **n8n**

```typescript
// User Entity (packages/@n8n/db/src/entities/user.ts)
export class User extends WithTimestamps implements IUser {
    id: string;
    email: string;
    firstName: string;
    lastName: string;
    password: string | null;
    personalizationAnswers: IPersonalizationSurveyAnswers | null;
    settings: IUserSettings | null;
    
    // MFA
    mfaEnabled: boolean;
    mfaSecret: string | null;
    mfaRecoveryCodes: string[] | null;
    
    // Relations
    role: Role;              // User role (owner, member, etc.)
    authIdentities: AuthIdentity[];  // SSO identities
    
    disabled: boolean;
    lastActiveAt: Date;
}

// Authenticated Request
interface AuthenticatedRequest extends Request {
    user: User;           // Full user object
    browserId?: string;   // Browser fingerprint
    authInfo?: {
        usedMfa: boolean;
    };
}
```

---

#### **Flowise**

```typescript
// LoggedInUser (Interface.Enterprise.ts)
interface LoggedInUser {
    id: string;
    email: string;
    name: string;
    roleId: string;
    
    // Organization context
    activeOrganizationId: string;
    activeOrganizationSubscriptionId: string;
    activeOrganizationCustomerId: string;
    activeOrganizationProductId: string;
    isOrganizationAdmin: boolean;
    
    // Workspace context
    activeWorkspaceId: string;
    activeWorkspace: string;
    assignedWorkspaces: IAssignedWorkspace[];
    
    // Permissions & Features
    permissions: string[];              // Array of permission strings
    features: Record<string, string>;   // Feature flags from subscription
    
    // Auth metadata
    isApiKeyValidated: boolean;
    ssoRefreshToken?: string;
    ssoToken?: string;
    ssoProvider?: string;
}

// Request Extension
interface Request {
    user?: LoggedInUser;
    subdomain?: string;
    company?: any;
    dataSource?: DataSource;  // Dynamic per subdomain!
    queryStore?: any;
}
```

---

### **5. Authentication Flow Comparison**

#### **n8n Login Flow**

```
POST /rest/login
    ↓
AuthController.login()
    ↓
handleEmailLogin(email, password)
    ↓
Find user in DB + validate password
    ↓
Check MFA (if enabled)
    ↓
AuthService.issueCookie(user, usedMfa, browserId)
    ↓
Generate JWT with hash of (email:password:mfa)
    ↓
Set cookie: n8n-auth
    ↓
Return PublicUser
```

#### **Flowise Login Flow**

```
POST /api/v1/auth/login
    ↓
Passport Local Strategy
    ↓
AccountService.login(email, password)
    ↓
Find user + validate password
    ↓
Load workspace, organization, role, permissions
    ↓
Fetch features from subscription
    ↓
Create LoggedInUser object
    ↓
Generate access token + refresh token
    ↓
Set cookies: token, refreshToken
    ↓
Return LoggedInUser
```

---

### **6. Key Architectural Differences**

| Aspect | n8n | Flowise |
|--------|-----|---------|
| **Framework** | Custom (decorators) | Passport.js |
| **Route Auth** | Per-route via @Get/@Post options | Global middleware + whitelist |
| **User Context** | `req.user` | `req.user` |
| **Database** | Single DataSource | Dynamic per subdomain |
| **Session Store** | Database only | Redis/DB/SQLite |
| **Token Strategy** | Single auto-refresh | Dual (access + refresh) |
| **Auth Extensibility** | Controller decorators | Middleware chain |

---

## 🎯 What n8n Has That Flowise Doesn't

### **1. MFA (Multi-Factor Authentication)** ✅

**Location:** `packages/cli/src/mfa/`

**Features:**
- TOTP (Time-based One-Time Password)
- Recovery codes
- MFA enforcement at instance level
- Per-user MFA enable/disable
- MFA tracking in JWT

**Value:** 🟢 **HIGH** - Critical security feature

---

### **2. Browser ID Session Hijacking Prevention** ✅

**Implementation:**
```typescript
// Generate browser fingerprint client-side
// Include in JWT payload as hashed browserId
// Validate on each request

if (jwtPayload.browserId && 
    jwtPayload.browserId !== this.hash(req.browserId)) {
    throw new AuthError('Unauthorized');
}
```

**Value:** 🟢 **HIGH** - Prevents stolen cookie attacks

---

### **3. Sophisticated SSO** ✅

**Supported:**
- SAML (Enterprise)
- OIDC/OAuth2 (Enterprise)
- Manual login bypass for owners

**Value:** 🟢 **HIGH** - Enterprise feature

---

### **4. Decorator-Based Route Configuration** ✅

```typescript
@Get('/workflows')  // Auth required
@Post('/login', { skipAuth: true, rateLimit: true })
@Get('/debug', { allowSkipMFA: true, licenseFeature: 'feat:debugging' })
```

**Value:** 🟢 **MEDIUM** - Clean, declarative

---

### **5. Auto Token Refresh** ✅

```typescript
// No need for refresh endpoint!
// Token auto-renews when < 25% of lifetime remaining

if (jwtPayload.exp * 1000 - Date.now() < this.jwtRefreshTimeout) {
    this.issueCookie(res, user, usedMfa, browserId);
}
```

**Value:** 🟢 **HIGH** - Better UX, less complexity

---

## 🎯 What Flowise Has That n8n Doesn't

### **1. Multi-Tenant Subdomain Architecture** 🏆

**Implementation:**
```typescript
// Each subdomain → separate database
validateSubdomain middleware:
  1. Extract subdomain from host
  2. Query company table in "elevate" DB
  3. Get company-specific DataSource
  4. Store in req.dataSource
  5. All subsequent queries use req.dataSource
```

**Value:** 🟡 **MEDIUM-HIGH** (depends on your use case)

**For n8n:** ⚠️ **Very difficult** to implement
- n8n's DataSource is initialized once at startup
- Would require refactoring entire DB access pattern
- Alternative: Use n8n's project-based isolation

---

### **2. Request Context (AsyncLocalStorage)** 🏆

**Implementation:**
```typescript
// packages/server/src/middleware/requestContext.ts
import { AsyncLocalStorage } from 'async_hooks';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

export const requestContextMiddleware = (req, res, next) => {
  const store = new Map();
  store.set('request', req);
  
  asyncLocalStorage.run(store, () => {
    next();
  });
};

// Access anywhere in the call stack
export const getRequestDataSource = () => {
  const store = asyncLocalStorage.getStore();
  return store?.get('request')?.dataSource;
};
```

**Value:** 🟢 **HIGH** - Very useful!

**For n8n:** ✅ **Easy to implement**
- Can access req.user anywhere
- No need to pass request through functions
- Clean architecture

**Recommendation:** ✅ **IMPLEMENT THIS!**

---

### **3. Passport.js Integration** 🏆

**Implementation:**
```typescript
// Passport Local Strategy for login
// Passport JWT Strategy for token validation
// Session management with express-session
// Multiple session stores (Redis/DB/SQLite)
```

**Value:** 🟡 **MEDIUM** - n8n's custom solution works fine

**For n8n:** ❌ **Not needed**
- n8n's custom auth is already robust
- No benefit to adding Passport.js

---

### **4. Encrypted Token Metadata** 🏆

**Implementation:**
```typescript
// Token payload includes encrypted user metadata
const encryptedUserInfo = encryptToken(userId + ':' + workspaceId);
const token = sign({ 
    id: userId, 
    username: userName, 
    meta: encryptedUserInfo 
}, secret);

// Validation
const meta = decryptToken(payload.meta);
const ids = meta.split(':');
if (req.user.id !== ids[0]) {
    throw new Error('Unauthorized');
}
```

**Value:** 🟡 **MEDIUM** - Extra security layer

**For n8n:** 🟡 **Optional**
- n8n already uses hash validation
- Encryption adds marginal benefit
- Increases complexity

**Recommendation:** 🟡 **Skip unless specific security requirement**

---

### **5. Separate Refresh Token** 🏆

**Implementation:**
- Access token: 60 minutes
- Refresh token: 90 days
- Refresh endpoint: `/api/v1/auth/refreshToken`

**Value:** 🟡 **MEDIUM** - n8n's auto-refresh is simpler

**For n8n:** ❌ **Not needed**
- n8n's auto-refresh is better UX
- Less complexity
- Fewer attack vectors (one token vs two)

---

### **6. Extended User Permissions & Features** 🏆

```typescript
interface LoggedInUser {
    permissions: string[];  // e.g., ['chatflow.create', 'chatflow.delete']
    features: Record<string, string>;  // From subscription/license
}
```

**Value:** 🟢 **HIGH** (for granular permissions)

**For n8n:** 🟡 **Partially exists**
- n8n has scopes system
- Could be enhanced with feature flags

**Recommendation:** 🟡 **Consider if you need granular permissions**

---

## 💡 Recommendations for n8n

### **✅ IMPLEMENT (Easy Wins)**

#### **1. Request Context Middleware** 
**Effort:** 🟢 Low | **Value:** 🟢 High

```typescript
// Create: packages/cli/src/middlewares/requestContext.ts

import { AsyncLocalStorage } from 'async_hooks';
import type { AuthenticatedRequest } from '@n8n/db';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

export const requestContextMiddleware = (req, res, next) => {
  const store = new Map();
  store.set('request', req);
  store.set('user', req.user);
  
  asyncLocalStorage.run(store, () => {
    next();
  });
};

export const getRequest = () => {
  return asyncLocalStorage.getStore()?.get('request') as AuthenticatedRequest;
};

export const getUser = () => {
  return asyncLocalStorage.getStore()?.get('user');
};
```

**Benefits:**
- Access user/request anywhere
- Cleaner service layer code
- Better testability
- No breaking changes

---

### **🟡 CONSIDER (Medium Effort)**

#### **2. Extended User Context for Permissions**

**Current n8n:**
```typescript
user.role.slug  // 'global:owner', 'global:member', etc.
// Scopes checked separately
```

**Flowise-style enhancement:**
```typescript
interface EnhancedUser extends User {
    permissions: string[];  // Computed from role + scopes
    features: Record<string, string>;  // From license
}

// Usage:
if (user.permissions.includes('workflow:delete')) {
    // Allow deletion
}

if (user.features.advancedNodes === 'enabled') {
    // Show advanced nodes
}
```

**Effort:** 🟡 Medium | **Value:** 🟡 Medium-High

---

### **❌ SKIP (Not Worth It)**

#### **1. Subdomain Multi-Tenancy**
**Reason:** Massive architectural change, n8n has projects

#### **2. Passport.js Migration**
**Reason:** n8n's auth works great, no benefit

#### **3. Separate Refresh Tokens**
**Reason:** Auto-refresh is better UX

#### **4. Token Metadata Encryption**
**Reason:** Hash-based validation is sufficient

---

## 📋 Implementation Priority

### **Phase 1: Quick Wins** (1-2 days)

1. ✅ **Request Context Middleware**
   - Create middleware file
   - Add to Express app
   - Use in services

2. ✅ **Verify Cookie + Bearer Support**
   - Test if n8n accepts both
   - If not, add dual token extraction

---

### **Phase 2: Enhancements** (3-5 days)

3. 🟡 **Extended User Permissions**
   - Add permissions array to User
   - Compute from role + scopes
   - Add feature flags from license

4. 🟡 **Enhanced Auth Error Messages**
   - Match Flowise's detailed error codes
   - Better client-side handling

---

### **Phase 3: Advanced** (Optional)

5. 🟡 **Token Metadata Encryption**
   - Add encryption utilities
   - Modify JWT payload
   - Add validation

---

## 🔍 Files to Modify in n8n

### **For Request Context:**

```
packages/cli/src/
├── middlewares/
│   ├── index.ts                    # Export requestContext
│   └── requestContext.ts           # NEW FILE
└── Server.ts                        # Add middleware to Express app
```

### **For Extended Permissions:**

```
packages/@n8n/db/src/
└── entities/
    └── user.ts                      # Add permissions array

packages/cli/src/
└── services/
    └── user.service.ts              # Compute permissions from role
```

---

## 🎯 Next Steps

### **Option A: Implement Request Context** (Recommended)
**Time:** ~2 hours
**Benefit:** Immediate code quality improvement

### **Option B: Analyze n8n's Existing Auth More**
**Dive deeper into:**
- API Key implementation
- SSO flows (SAML/OIDC)
- MFA implementation
- Scopes/permissions system

### **Option C: Plan Custom Implementation**
**Tell me what specific auth features you need**

---

## 📝 Summary

### **What n8n Already Has:**
✅ Robust JWT authentication
✅ Cookie-based sessions
✅ MFA support
✅ SSO (SAML + OIDC)
✅ LDAP integration
✅ API Key fallback
✅ Browser ID validation
✅ Auto token refresh
✅ Role-based access control
✅ License quota enforcement

### **What Flowise Has That's Better:**
🏆 Multi-tenant architecture (subdomain → DB)
🏆 Request Context (AsyncLocalStorage)
🏆 Passport.js integration
🏆 Explicit permissions array
🏆 Feature flags in user context

### **Recommendation:**
✅ **Implement Request Context Middleware** - Easy, high value
🟡 **Consider Extended Permissions** - If you need granular control
❌ **Skip Multi-Tenancy** - Use n8n's projects instead

---

**Want me to implement the Request Context Middleware now?** 🚀

