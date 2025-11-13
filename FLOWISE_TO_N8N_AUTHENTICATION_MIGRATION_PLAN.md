# Flowise to N8N Authentication & Multi-Tenant Migration Plan

## Executive Summary
This document outlines the plan to migrate Flowise's authentication and multi-tenant architecture patterns into the n8n-mssql project. The goal is to implement JWT-based authentication, runtime multi-tenant database connections, and company/user-specific record filtering.

---

## Table of Contents
1. [Flowise Architecture Analysis](#flowise-architecture-analysis)
2. [N8N Current Architecture](#n8n-current-architecture)
3. [Key Concepts to Implement](#key-concepts-to-implement)
4. [Implementation Plan](#implementation-plan)
5. [File Structure](#file-structure)
6. [Environment Variables](#environment-variables)

---

## Flowise Architecture Analysis

### 1. **Multi-Tenant Database Architecture**

**Location:** `C:\Git\Flowise-Main\packages\server\src\DataSource.ts`

**Key Features:**
- **Dual Database System:**
  - `ElevateDataSource`: Central metadata database containing company/tenant configurations
  - `TenantDataSource`: Individual tenant databases (runtime-created based on subdomain)

- **Runtime Connection Creation:**
  - Connections are created on-demand per request
  - Cached in a `Map<string, DataSource>` for reuse
  - Connection key based on: `${host}_${username}_${database}`

**Code Pattern:**
```typescript
// Initialize both databases
await init()  // Creates ElevateDataSource + DefaultDataSource (if env vars present)

// Get tenant-specific connection at runtime
const dataSource = await getDataSourceForSubdomain(subdomain, req)
```

**Database Configuration Lookup:**
```sql
SELECT db.instance, db.[database],
       CAST(DecryptByPassphrase(@passphrase + '-' + c.[guid], cred.[user]) AS VARCHAR) AS [user],
       CAST(DecryptByPassphrase(@passphrase + '-' + c.[guid], cred.[pass]) AS VARCHAR) AS pass
FROM voyagerdb db
JOIN voyagerdbcred cred ON cred.voyagerdbid = db.id
JOIN company c ON c.id = db.companyid
WHERE db.[name] = @databaseName OR db.[guid] = @databaseGUID
```

**Configuration Sources (Priority Order):**
1. Direct env variables (`DATABASE_HOST`, `DATABASE_NAME`, etc.) - for local dev
2. Elevate database lookup via subdomain/DatabaseGUID

---

### 2. **Middleware Stack**

**Location:** `C:\Git\Flowise-Main\packages\server\src\index.ts` (lines 196-367)

**Middleware Order:**
```typescript
// 1. Body parser
app.use(express.json({ limit: '50mb' }))

// 2. Trust proxy (for load balancer)
app.set('trust proxy', true)

// 3. CORS
app.use(cors(getCorsOptions()))

// 4. Cookie parser
app.use(cookieParser())

// 5. Request logging
app.use(expressRequestLogger)

// 6. Query params store
app.use(queryParamsStore)

// 7. Request context (AsyncLocalStorage)
app.use(requestContextMiddleware)

// 8. XSS sanitization
app.use(sanitizeMiddleware)

// 9. Subdomain validation & DB connection setup
app.use(validateSubdomain)

// 10. JWT Cookie middleware initialization
await initializeJwtCookieMiddleware(app, identityManager)

// 11. Authentication logic (lines 263-367)
app.use(async (req, res, next) => {
  // Complex authentication flow here
})

// 12. SSO initialization
await identityManager.initializeSSO(app)

// 13. Routes
app.use('/api/v1', flowiseApiV1Router)
```

---

### 3. **Request Context Middleware**

**Location:** `C:\Git\Flowise-Main\packages\server\src\middleware\requestContext.ts`

**Purpose:** Uses Node.js `AsyncLocalStorage` to maintain request-scoped data throughout async operations.

**Key Functions:**
```typescript
// Store request and dataSource in async context
export const requestContextMiddleware = (req, res, next) => {
  const store = new Map<string, any>()
  store.set('request', req)
  asyncLocalStorage.run(store, () => next())
}

// Retrieve request from anywhere in the call stack
export const getRequest = () => {
  const store = asyncLocalStorage.getStore()
  return store?.get('request')
}

// Retrieve dataSource from anywhere in the call stack
export const getRequestDataSource = () => {
  const store = asyncLocalStorage.getStore()
  return store?.get('request')?.dataSource as DataSource
}
```

**Benefits:**
- Access tenant database connection without passing it through every function
- Maintains clean separation of concerns
- Eliminates "prop drilling"

---

### 4. **Subdomain Validation Middleware**

**Location:** `C:\Git\Flowise-Main\packages\server\src\middleware\SubdomainValidation.ts`

**Flow:**
1. Extract subdomain from host header
2. Check if localhost/127.0.0.1 → use default connection
3. Check for `DatabaseGUID` query param → direct database access
4. Query Elevate database for company by domain:
   ```sql
   SELECT * FROM company WHERE domain = @subdomain
   ```
5. Validate company is active
6. Get tenant database connection
7. Attach to request:
   ```typescript
   req.subdomain = subdomain
   req.company = company
   req.dataSource = dataSource
   ```

---

### 5. **JWT Authentication**

**Location:** `C:\Git\Flowise-Main\packages\server\src\middleware\authenticateJWT.ts`

**JWT Token Sources (Priority Order):**
1. `Authorization` header: `Bearer <token>`
2. Cookie: `token`

**Validation:**
```typescript
jwt.verify(token, secret, {
  algorithms: ["HS256"],
  issuer: requestHost,
  audience: encodeToBase64(getSubDomain(requestHost))
})
```

**Configuration Modes:**
- **VirtuosoAI Mode:** Uses `AUDIENCE_SECRET`, fixed issuer/audience
- **Multi-Tenant Mode:** Uses BASE64 secret, subdomain-based audience

**Fallback:** If JWT fails and not in VirtuosoAI/UseAuth mode, falls back to API key validation.

---

### 6. **JWT Cookie Middleware (Enterprise)**

**Location:** `C:\Git\Flowise-Main\packages\server\src\enterprise\middleware\passport\index.ts`

**Key Features:**
- Passport.js integration
- Express session with Redis/DB store
- Cookie-based JWT tokens
- Refresh token mechanism

**Token Types:**
1. **Auth Token:** Short-lived (default 60 min), stored in `token` cookie
2. **Refresh Token:** Long-lived (default 90 days), stored in `refreshToken` cookie

**Cookies Configuration:**
```typescript
{
  httpOnly: true,
  secure: process.env.APP_URL?.startsWith('https'),
  sameSite: 'lax'
}
```

**User Object Structure:**
```typescript
interface LoggedInUser {
  id: string
  email: string
  name: string
  roleId: string
  activeOrganizationId: string
  activeOrganizationSubscriptionId: string
  activeOrganizationCustomerId: string
  activeOrganizationProductId: string
  isOrganizationAdmin: boolean
  activeWorkspaceId: string
  activeWorkspace: string
  assignedWorkspaces: IAssignedWorkspace[]
  isApiKeyValidated: boolean
  permissions: string[]
  features: any
}
```

---

### 7. **Authentication Flow**

**Location:** `C:\Git\Flowise-Main\packages\server\src\index.ts` (lines 263-367)

**Whitelist URLs:** Certain endpoints bypass authentication (e.g., `/api/v1/health`, `/api/v1/version`)

**Authentication Hierarchy:**
```
1. Check if URL is whitelisted → Allow
2. Check if VirtuosoAI or UseAuth mode:
   a. Scheduler auth key validation (internal requests)
   b. JWT token validation (user, auth header, or cookie)
   c. Fallback to JWT middleware
3. If not VirtuosoAI/UseAuth:
   a. Check platform license validity
   b. API key validation
   c. Build user context from API key workspace
```

**API Key Workspace Context:**
When using API key authentication, the system:
1. Validates API key
2. Retrieves workspace from API key
3. Finds organization owner role
4. Gets organization details
5. Fetches subscription features
6. Builds pseudo-user object with permissions

---

### 8. **AppConfig**

**Location:** `C:\Git\Flowise-Main\packages\server\src\AppConfig.ts`

**Configuration Interface:**
```typescript
interface IAppConfig {
  apiKeys: {
    storageType: 'json' | 'database'
  }
  authSettings: {
    SymmetricKey: string
    Issuer: string
    AudienceId: string
    AudienceSecret: string
  }
  UseAuth: boolean
  isVirtuosoAI: boolean
  isElevate: boolean
}
```

---

## N8N Current Architecture

### 1. **Server Structure**

**Location:** `C:\Git\n8n-mssql\packages\cli\src\server.ts`

**Key Components:**
- Extends `AbstractServer`
- Uses dependency injection with `@n8n/di`
- Controller-based routing
- Helmet for security
- Cookie parser included

**Current Auth System:**
- `AuthService` at `@/auth/auth.service`
- JWT-based authentication (`@/auth/jwt.ts`)
- Email authentication method

### 2. **Existing Middlewares**

**Location:** `C:\Git\n8n-mssql\packages\cli\src\middlewares\`

**Available:**
- `body-parser.ts`
- `cors.ts`
- `list-query/` - Complex filtering system

**Missing (from Flowise):**
- Request context (AsyncLocalStorage)
- Subdomain validation
- Multi-tenant DB routing

### 3. **Database Connection**

**Current State:**
- Single database connection per instance
- Configured via environment variables or config schema
- No runtime connection switching

**Location:** `C:\Git\n8n-mssql\packages\@n8n\db\`

---

## Key Concepts to Implement

### 1. **Multi-Tenant Database Manager**
   - Create `TenantDataSourceManager` service
   - Implement connection pooling per tenant
   - Cache connections by key

### 2. **Request Context Service**
   - Implement AsyncLocalStorage pattern
   - Store: request, dataSource, user, company, subdomain

### 3. **Subdomain Validation Middleware**
   - Extract subdomain from host header
   - Query central database for company/tenant config
   - Retrieve tenant database credentials
   - Initialize tenant-specific connection

### 4. **Enhanced JWT Middleware**
   - Cookie-based JWT tokens
   - Subdomain-aware audience validation
   - Refresh token mechanism

### 5. **Company/User Record Filtering**
   - Inject tenant context into TypeORM queries
   - Global query filters by company/user
   - Automatic scope enforcement

### 6. **Dual-Mode Operation**
   - **Standalone Mode:** Direct DB connection (current behavior)
   - **Multi-Tenant Mode:** Elevate + tenant databases

---

## Implementation Plan

### Phase 1: Foundation (1-2 weeks)

#### 1.1 Create Configuration System
- [ ] Create `AppConfig` service similar to Flowise
- [ ] Add environment variables for auth settings
- [ ] Add environment variables for Elevate database
- [ ] Create mode detection (`STANDALONE` vs `MULTI_TENANT`)

**Files to Create:**
```
packages/cli/src/config/app.config.ts
packages/cli/src/config/multi-tenant.config.ts
```

#### 1.2 Implement Request Context
- [ ] Create `RequestContextMiddleware`
- [ ] Implement AsyncLocalStorage wrapper
- [ ] Create context accessors:
  - `getRequestContext()`
  - `getRequestDataSource()`
  - `getRequestUser()`
  - `getRequestCompany()`

**Files to Create:**
```
packages/cli/src/middlewares/request-context.middleware.ts
packages/cli/src/services/request-context.service.ts
```

#### 1.3 Create Multi-Tenant Database Manager
- [ ] Create `TenantDataSourceManager` service
- [ ] Implement `initializeElevateDatabase()`
- [ ] Implement `getDataSourceForTenant(subdomain, req)`
- [ ] Implement connection caching
- [ ] Implement encrypted credential retrieval

**Files to Create:**
```
packages/cli/src/services/tenant-datasource-manager.service.ts
packages/cli/src/services/tenant-config.service.ts
```

**Database Schema Requirements (Elevate DB):**
```sql
-- Company table
CREATE TABLE company (
  id INT PRIMARY KEY,
  domain NVARCHAR(255),
  name NVARCHAR(255),
  guid UNIQUEIDENTIFIER,
  inactive BIT,
  ...
)

-- Tenant database registry
CREATE TABLE voyagerdb (
  id INT PRIMARY KEY,
  name NVARCHAR(255),
  guid UNIQUEIDENTIFIER,
  instance NVARCHAR(255),  -- SQL Server host
  [database] NVARCHAR(255), -- Database name
  companyid INT
)

-- Encrypted credentials
CREATE TABLE voyagerdbcred (
  id INT PRIMARY KEY,
  voyagerdbid INT,
  [user] VARBINARY(MAX),   -- Encrypted username
  [pass] VARBINARY(MAX)    -- Encrypted password
)
```

---

### Phase 2: Middleware Implementation (1-2 weeks)

#### 2.1 Subdomain Validation Middleware
- [ ] Create `SubdomainValidationMiddleware`
- [ ] Extract subdomain from host header
- [ ] Query company from Elevate DB
- [ ] Validate company status
- [ ] Get tenant database connection
- [ ] Attach to request context

**Files to Create:**
```
packages/cli/src/middlewares/subdomain-validation.middleware.ts
```

**TypeScript Declarations:**
```typescript
declare global {
  namespace Express {
    interface Request {
      subdomain?: string
      company?: Company
      dataSource?: DataSource
      queryStore?: Record<string, any>
    }
  }
}
```

#### 2.2 Query Params Store Middleware
- [ ] Create `QueryParamsStoreMiddleware`
- [ ] Store query params for request lifetime

**Files to Create:**
```
packages/cli/src/middlewares/query-params-store.middleware.ts
```

#### 2.3 Enhanced JWT Authentication
- [ ] Extend `AuthService` to support cookie-based JWT
- [ ] Add subdomain-based audience validation
- [ ] Implement refresh token mechanism
- [ ] Add VirtuosoAI mode support

**Files to Modify:**
```
packages/cli/src/auth/auth.service.ts
packages/cli/src/auth/jwt.ts
```

**Files to Create:**
```
packages/cli/src/auth/jwt-cookie.strategy.ts
packages/cli/src/auth/refresh-token.service.ts
```

---

### Phase 3: Integration (2-3 weeks)

#### 3.1 Modify Server Bootstrap
- [ ] Add request context middleware early in chain
- [ ] Add subdomain validation middleware
- [ ] Add query params store middleware
- [ ] Update authentication middleware order

**Files to Modify:**
```
packages/cli/src/server.ts
packages/cli/src/abstract-server.ts
```

**Middleware Order:**
```typescript
// 1. Body parser (existing)
// 2. Cookie parser (existing)
// 3. Helmet (existing)
// 4. CORS (existing)
// 5. Request context ← NEW
// 6. Query params store ← NEW
// 7. Subdomain validation ← NEW
// 8. JWT/Auth (modified)
// 9. Controllers (existing)
```

#### 3.2 Update Database Access Patterns
- [ ] Create `getDatabaseConnection()` helper
- [ ] Update repositories to use request-scoped connection
- [ ] Add global query filters for company/user scope

**Pattern:**
```typescript
// Before
const repository = Container.get(DatabaseService).connection.getRepository(Entity)

// After
const repository = getRequestDataSource().getRepository(Entity)
```

#### 3.3 Add Company/User Scoping
- [ ] Add `companyId` column to relevant entities
- [ ] Add `userId` column where applicable
- [ ] Implement global TypeORM filters
- [ ] Create `@CompanyScoped()` decorator
- [ ] Create `@UserScoped()` decorator

**Example:**
```typescript
@Entity()
@CompanyScoped()
export class Workflow {
  @Column()
  companyId: string;
  
  // ... other columns
}
```

---

### Phase 4: API Key Multi-Tenancy (1 week)

#### 4.1 API Key Workspace Context
- [ ] Store workspace/organization in API key
- [ ] Build user context from API key
- [ ] Load permissions from role
- [ ] Load features from subscription

**Files to Modify:**
```
packages/cli/src/services/api-key.service.ts
```

---

### Phase 5: Testing & Documentation (1-2 weeks)

#### 5.1 Unit Tests
- [ ] Test request context isolation
- [ ] Test subdomain validation
- [ ] Test database connection switching
- [ ] Test JWT token validation
- [ ] Test company/user scoping

#### 5.2 Integration Tests
- [ ] Test multi-tenant workflow isolation
- [ ] Test subdomain-based routing
- [ ] Test API key with multi-tenancy

#### 5.3 Documentation
- [ ] Environment variables guide
- [ ] Multi-tenant setup guide
- [ ] Migration guide
- [ ] Troubleshooting guide

---

## File Structure

```
packages/cli/src/
├── auth/
│   ├── auth.service.ts (MODIFY)
│   ├── jwt.ts (MODIFY)
│   ├── jwt-cookie.strategy.ts (NEW)
│   └── refresh-token.service.ts (NEW)
├── config/
│   ├── app.config.ts (NEW)
│   └── multi-tenant.config.ts (NEW)
├── middlewares/
│   ├── request-context.middleware.ts (NEW)
│   ├── subdomain-validation.middleware.ts (NEW)
│   ├── query-params-store.middleware.ts (NEW)
│   └── company-scope.middleware.ts (NEW)
├── services/
│   ├── tenant-datasource-manager.service.ts (NEW)
│   ├── tenant-config.service.ts (NEW)
│   └── request-context.service.ts (NEW)
├── decorators/
│   ├── company-scoped.decorator.ts (NEW)
│   └── user-scoped.decorator.ts (NEW)
└── server.ts (MODIFY)
```

---

## Environment Variables

### Standalone Mode (Current)
```env
# Database
DB_TYPE=mssql
DB_MSSQL_HOST=localhost
DB_MSSQL_PORT=1433
DB_MSSQL_DATABASE=n8n
DB_MSSQL_USER=sa
DB_MSSQL_PASSWORD=yourpassword
```

### Multi-Tenant Mode (New)

```env
# Mode Configuration
N8N_MODE=multi_tenant  # or 'standalone'
USE_AUTH=true

# Auth Settings
JWT_AUTH_TOKEN_SECRET=your-secret-key
JWT_REFRESH_TOKEN_SECRET=your-refresh-secret
JWT_AUDIENCE=n8n-audience
JWT_ISSUER=n8n-issuer
JWT_TOKEN_EXPIRY_IN_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRY_IN_MINUTES=129600

# Session
EXPRESS_SESSION_SECRET=your-session-secret
EXPIRE_AUTH_TOKENS_ON_RESTART=false

# Cookies
SECURE_COOKIE=true  # auto-detect from N8N_HOST if not set

# VirtuosoAI Mode (Optional)
IS_VIRTUOSO_AI=false
IS_ELEVATE=false

# Legacy JWT Settings (for existing tokens)
SYMMETRIC_KEY=base64-encoded-key
AUDIENCE_ID=audience-id
AUDIENCE_SECRET=base64-encoded-secret

# Elevate Database (Central Metadata)
ELEVATE_DATABASE_TYPE=mssql
ELEVATE_DATABASE_HOST=central-db.example.com
ELEVATE_DATABASE_PORT=1433
ELEVATE_DATABASE_NAME=ElevateMetadata
ELEVATE_DATABASE_USER=elevate_user
ELEVATE_DATABASE_PASSWORD=elevate_password
ELEVATE_DATABASE_SSL=true
ELEVATE_PASSPHRASE=encryption-passphrase

# Default Database (Optional - for local dev)
DATABASE_TYPE=mssql
DATABASE_HOST=localhost
DATABASE_PORT=1433
DATABASE_NAME=n8n_default
DATABASE_USER=sa
DATABASE_PASSWORD=password

# Scheduler Auth (Internal requests)
SCHEDULER_AUTH_KEY=internal-scheduler-key
```

---

## Migration Strategy

### Option 1: Dual Mode Support (Recommended)
- Keep existing standalone mode functional
- Add multi-tenant mode as opt-in
- Detect mode based on `N8N_MODE` environment variable
- Use feature flags for gradual rollout

### Option 2: Full Migration
- Migrate all deployments to multi-tenant architecture
- Require Elevate database for all instances
- Single company for existing deployments

**Recommendation:** Start with Option 1, allows existing deployments to continue working.

---

## Database Schema Changes

### Required Entity Modifications

```typescript
// Add to WorkflowEntity
@Column({ nullable: true })
companyId?: string;

// Add to CredentialsEntity
@Column({ nullable: true })
companyId?: string;

// Add to ExecutionEntity
@Column({ nullable: true })
companyId?: string;

// Add to UserEntity (if not exists)
@Column({ nullable: true })
organizationId?: string;
```

### Migration Script
```sql
-- Add company scoping columns
ALTER TABLE workflow ADD companyId NVARCHAR(36) NULL;
ALTER TABLE credentials ADD companyId NVARCHAR(36) NULL;
ALTER TABLE execution ADD companyId NVARCHAR(36) NULL;

-- Add indexes
CREATE INDEX idx_workflow_companyId ON workflow(companyId);
CREATE INDEX idx_credentials_companyId ON credentials(companyId);
CREATE INDEX idx_execution_companyId ON execution(companyId);
```

---

## Security Considerations

### 1. **Credential Encryption**
- Use `EncryptByPassphrase` / `DecryptByPassphrase` in SQL Server
- Store encrypted credentials in Elevate DB
- Use company GUID as part of encryption key

### 2. **Cross-Tenant Data Isolation**
- Always filter by `companyId`
- Use global TypeORM filters
- Validate tenant access on every request

### 3. **JWT Security**
- Use strong secrets (min 256-bit)
- Short-lived auth tokens (60 min)
- Refresh tokens with rotation
- HttpOnly cookies
- SameSite: 'lax'

### 4. **SQL Injection Prevention**
- Use parameterized queries
- Validate subdomain format
- Sanitize all user input

---

## Performance Considerations

### 1. **Connection Pooling**
- Cache tenant connections in Map
- Set reasonable pool size per tenant
- Implement connection timeout
- Monitor active connections

### 2. **AsyncLocalStorage Overhead**
- Minimal (~1-2% overhead)
- Benefits outweigh costs
- Alternative: Context parameter passing (verbose)

### 3. **Database Queries**
- Index `companyId` columns
- Optimize company lookup query
- Cache company metadata
- Use query result caching where appropriate

---

## Next Steps

1. **Review & Approve Architecture**
   - Stakeholder sign-off
   - Security review
   - Performance review

2. **Set Up Development Environment**
   - Create Elevate database
   - Populate test company data
   - Create test tenant databases

3. **Begin Phase 1 Implementation**
   - Start with AppConfig and environment setup
   - Implement request context
   - Create database manager

4. **Iterative Development**
   - Implement one phase at a time
   - Test thoroughly between phases
   - Document as you go

---

## Questions to Address

1. **Subdomain Strategy:**
   - Will subdomains be pre-registered or dynamic?
   - What happens with invalid subdomains?
   - How to handle localhost development?

2. **Database Strategy:**
   - One database per tenant or shared with schema separation?
   - How to handle tenant database migrations?
   - What's the onboarding process for new tenants?

3. **Authentication Strategy:**
   - Support both cookie-based and header-based JWT?
   - API key authentication for programmatic access?
   - How to handle session persistence (Redis, DB, or memory)?

4. **Backward Compatibility:**
   - Support existing deployments without multi-tenancy?
   - Migration path for existing users?
   - Feature flags for gradual rollout?

---

## Success Criteria

- [ ] Support both standalone and multi-tenant modes
- [ ] Zero downtime deployment for existing instances
- [ ] Complete tenant data isolation
- [ ] Performance impact < 5%
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Security audit passed

---

## Resources

### Flowise Reference Files
```
C:\Git\Flowise-Main\packages\server\src\
├── index.ts (Main server setup)
├── DataSource.ts (Multi-tenant DB manager)
├── AppConfig.ts (Configuration)
├── middleware\
│   ├── authenticateJWT.ts
│   ├── SubdomainValidation.ts
│   ├── requestContext.ts
│   └── QueryParamsStore.ts
└── enterprise\middleware\passport\
    ├── index.ts (JWT Cookie middleware)
    └── AuthStrategy.ts
```

### N8N Reference Files
```
C:\Git\n8n-mssql\packages\cli\src\
├── server.ts
├── abstract-server.ts
├── auth\
│   ├── auth.service.ts
│   └── jwt.ts
└── middlewares\
```

---

## Contact & Support

For questions during implementation:
- Architecture questions: Review Flowise implementation
- n8n-specific questions: Review n8n documentation
- Database questions: Consult DBA team

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-07  
**Author:** AI Assistant  
**Status:** Draft - Pending Review

