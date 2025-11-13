# 🏗️ n8n Multi-Tenant Architecture Implementation

## ✅ Correct Architecture Understanding

```
┌──────────────────────────────────────────────────────────┐
│         .NET Core API (JWT Generator)                    │
│  Issues JWT tokens for all applications                  │
└───────────────────┬──────────────────────────────────────┘
                    │ JWT Token (shared)
                    ↓
        ┌───────────────────────┐
        │   User Request        │
        │   subdomain.domain.com│
        └───────┬───────────────┘
                │
    ┌───────────┴──────────────┐
    │                          │
    ↓                          ↓
┌─────────────┐          ┌─────────────┐
│  Flowise    │          │    n8n      │
│  (Working)  │          │   (To Do)   │
└─────┬───────┘          └─────┬───────┘
      │                        │
      └────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  ELEVATE DATABASE        │
    │  (Single Instance)       │
    │  ✅ Initialized ONCE     │
    │                          │
    │  Table: company          │
    │  ├─ domain (subdomain)   │
    │  ├─ db_server            │
    │  ├─ db_name              │
    │  ├─ db_user              │
    │  ├─ db_password          │
    │  └─ inactive             │
    └──────────┬───────────────┘
               │ Query: SELECT * FROM company WHERE domain = ?
               ↓
    ┌──────────────────────────┐
    │  VOYAGER DATABASE(S)     │
    │  (Per Client/Subdomain)  │
    │  ❗ DYNAMIC per request  │
    │                          │
    │  Client1 Voyager DB:     │
    │  ├── flowise.*          │
    │  └── n8n.*              │
    │                          │
    │  Client2 Voyager DB:     │
    │  ├── flowise.*          │
    │  └── n8n.*              │
    └──────────────────────────┘
```

---

## 🎯 Key Points

### **1. Elevate Database**
- ✅ **Single instance**
- ✅ **Initialized ONCE at startup**
- ✅ **Contains company table with Voyager DB credentials**
- ✅ **Shared by Flowise and n8n**

### **2. Voyager Database(s)**
- ❗ **One per client/subdomain** (or same DB, different credentials)
- ❗ **DYNAMIC - changes per request**
- ✅ **Contains TWO schemas:**
  - `flowise.*` - Flowise tables
  - `n8n.*` - n8n tables

### **3. Request Flow**

```
1. Request arrives: client1.domain.com
   ↓
2. Extract subdomain: "client1"
   ↓
3. Query Elevate DB: 
   SELECT db_server, db_name, db_user, db_password 
   FROM company WHERE domain = 'client1'
   ↓
4. Get/Create Voyager DataSource for client1
   {
     server: "client1-db-server",
     database: "client1_voyager",
     schema: "n8n"
   }
   ↓
5. Store in request context: req.dataSource
   ↓
6. All n8n queries use req.dataSource
   ↓
7. Queries hit: client1_voyager.n8n.workflow_entity
```

---

## 🔧 Implementation Steps

### **Phase 1: Elevate DataSource (Singleton)**

#### **1.1. Create Elevate DB Connection**

**File:** `packages/cli/src/databases/elevate.datasource.ts`

```typescript
import { DataSource } from '@n8n/typeorm';
import { Logger } from '@n8n/backend-common';
import { Service } from '@n8n/di';

@Service()
export class ElevateDataSource {
  private static instance: DataSource;
  
  static async initialize(): Promise<DataSource> {
    if (this.instance && this.instance.isInitialized) {
      return this.instance;
    }
    
    const logger = Container.get(Logger);
    
    this.instance = new DataSource({
      type: 'mssql',
      host: process.env.ELEVATE_DB_HOST || 'localhost',
      port: parseInt(process.env.ELEVATE_DB_PORT || '1433'),
      database: process.env.ELEVATE_DB_NAME || 'elevate',
      username: process.env.ELEVATE_DB_USER,
      password: process.env.ELEVATE_DB_PASSWORD,
      schema: 'dbo',  // Elevate uses default schema
      options: {
        encrypt: process.env.ELEVATE_DB_ENCRYPT === 'true',
        trustServerCertificate: process.env.ELEVATE_DB_TRUST_CERT === 'true',
        enableArithAbort: true
      },
      // No entities - we only run raw queries
      entities: [],
      synchronize: false
    });
    
    await this.instance.initialize();
    logger.info('✅ Elevate DataSource initialized');
    
    return this.instance;
  }
  
  static getInstance(): DataSource {
    if (!this.instance || !this.instance.isInitialized) {
      throw new Error('Elevate DataSource not initialized');
    }
    return this.instance;
  }
}
```

#### **1.2. Initialize at Startup**

**File:** `packages/cli/src/Server.ts` (or main startup file)

```typescript
import { ElevateDataSource } from '@/databases/elevate.datasource';

// In server initialization:
async init() {
  // ... existing n8n initialization
  
  // Initialize Elevate DB
  await ElevateDataSource.initialize();
  
  // ... continue
}
```

---

### **Phase 2: Dynamic Voyager DataSource (Per Request)**

#### **2.1. Create Voyager DataSource Factory**

**File:** `packages/cli/src/databases/voyager.datasource.factory.ts`

```typescript
import { DataSource } from '@n8n/typeorm';
import { Service } from '@n8n/di';
import { Logger } from '@n8n/backend-common';
import { entities } from '@n8n/db';
import { ElevateDataSource } from './elevate.datasource';

interface CompanyDbConfig {
  server: string;
  database: string;
  username: string;
  password: string;
  schema: string;
}

@Service()
export class VoyagerDataSourceFactory {
  // Cache DataSources per subdomain
  private static dataSourceCache: Map<string, DataSource> = new Map();
  
  /**
   * Get or create Voyager DataSource for a subdomain
   */
  static async getDataSource(subdomain: string): Promise<DataSource> {
    const logger = Container.get(Logger);
    
    // Check cache first
    if (this.dataSourceCache.has(subdomain)) {
      const cached = this.dataSourceCache.get(subdomain)!;
      if (cached.isInitialized) {
        logger.debug(`Using cached Voyager DataSource for: ${subdomain}`);
        return cached;
      }
    }
    
    logger.info(`Creating new Voyager DataSource for: ${subdomain}`);
    
    // Query Elevate DB for company credentials
    const company = await this.getCompanyConfig(subdomain);
    
    if (!company) {
      throw new Error(`Company not found for subdomain: ${subdomain}`);
    }
    
    if (company.inactive) {
      throw new Error(`Company is inactive: ${subdomain}`);
    }
    
    // Create new DataSource for this Voyager DB
    const dataSource = new DataSource({
      type: 'mssql',
      host: company.server,
      port: 1433,
      database: company.database,
      username: company.username,
      password: company.password,
      schema: 'n8n',  // Always use n8n schema
      
      // Use n8n's entities
      entities: Object.values(entities),
      
      // Same config as main n8n DB
      synchronize: false,
      logging: process.env.DB_LOGGING_ENABLED === 'true',
      
      options: {
        encrypt: process.env.DB_MSSQLDB_ENCRYPT === 'true',
        trustServerCertificate: process.env.DB_MSSQLDB_TRUST_SERVER_CERTIFICATE === 'true',
        enableArithAbort: true,
        connectTimeout: parseInt(process.env.DB_MSSQLDB_CONNECTION_TIMEOUT || '20000')
      },
      
      pool: {
        max: parseInt(process.env.DB_MSSQLDB_POOL_SIZE || '10')
      }
    });
    
    // Initialize connection
    await dataSource.initialize();
    
    // Cache it
    this.dataSourceCache.set(subdomain, dataSource);
    
    logger.info(`✅ Voyager DataSource initialized for: ${subdomain}`);
    
    return dataSource;
  }
  
  /**
   * Query Elevate DB for company/Voyager DB config
   */
  private static async getCompanyConfig(subdomain: string): Promise<CompanyDbConfig | null> {
    const elevateDb = ElevateDataSource.getInstance();
    
    const result = await elevateDb.query(
      `SELECT 
         domain,
         db_server as server,
         db_name as database,
         db_user as username,
         db_password as password,
         inactive,
         issql
       FROM company 
       WHERE domain = @0`,
      [subdomain]
    );
    
    if (!result || result.length === 0) {
      return null;
    }
    
    const company = result[0];
    
    return {
      server: company.server,
      database: company.database,
      username: company.username,
      password: company.password,
      schema: 'n8n',
      inactive: company.inactive
    };
  }
  
  /**
   * Clear cache (for testing or company updates)
   */
  static async clearCache(subdomain?: string) {
    if (subdomain) {
      const ds = this.dataSourceCache.get(subdomain);
      if (ds?.isInitialized) {
        await ds.destroy();
      }
      this.dataSourceCache.delete(subdomain);
    } else {
      // Clear all
      for (const [key, ds] of this.dataSourceCache.entries()) {
        if (ds.isInitialized) {
          await ds.destroy();
        }
      }
      this.dataSourceCache.clear();
    }
  }
}
```

---

### **Phase 3: Subdomain Validation Middleware**

#### **3.1. Extract Subdomain and Get Voyager DataSource**

**File:** `packages/cli/src/middlewares/subdomain-validation.middleware.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import { Logger } from '@n8n/backend-common';
import { Container } from '@n8n/di';
import { VoyagerDataSourceFactory } from '@/databases/voyager.datasource.factory';

export const subdomainValidationMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const logger = Container.get(Logger);
  
  try {
    // Skip for assets and static files
    if (req.url.includes('/assets/') || 
        req.url.includes('/node-icon/') ||
        req.url.includes('/types/')) {
      return next();
    }
    
    // Get hostname
    const host = req.hostname || req.get('host') || '';
    logger.debug(`Subdomain validation for host: ${host}`);
    
    // Handle localhost (development)
    if (host.includes('localhost') || host.includes('127.0.0.1')) {
      logger.debug('Localhost detected - using default subdomain');
      const subdomain = process.env.DEFAULT_SUBDOMAIN || 'default';
      const dataSource = await VoyagerDataSourceFactory.getDataSource(subdomain);
      
      req.subdomain = subdomain;
      req.dataSource = dataSource;
      return next();
    }
    
    // Extract subdomain from host
    // Example: client1.yourdomain.com → "client1"
    const parts = host.split('.');
    const subdomain = parts[0];
    
    logger.debug(`Extracted subdomain: ${subdomain}`);
    
    // Get Voyager DataSource for this subdomain
    try {
      const dataSource = await VoyagerDataSourceFactory.getDataSource(subdomain);
      
      // Store in request for later use
      req.subdomain = subdomain;
      req.dataSource = dataSource;
      
      logger.debug(`Voyager DataSource set for subdomain: ${subdomain}`);
      
      next();
      
    } catch (error: any) {
      logger.error(`Failed to get DataSource for subdomain: ${subdomain}`, error);
      
      if (error.message.includes('not found')) {
        return res.status(403).json({
          error: 'Invalid subdomain',
          message: 'Access denied. Invalid company domain.'
        });
      }
      
      if (error.message.includes('inactive')) {
        return res.status(403).json({
          error: 'Company inactive',
          message: 'Access denied. Company account is inactive.'
        });
      }
      
      return res.status(500).json({
        error: 'Database connection error',
        message: 'Failed to connect to company database.'
      });
    }
    
  } catch (error) {
    logger.error('Subdomain validation error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Error validating company domain.'
    });
  }
};

// Extend Express Request type
declare global {
  namespace Express {
    interface Request {
      subdomain?: string;
      dataSource?: DataSource;
      dotnetJwtPayload?: any;
    }
  }
}
```

---

### **Phase 4: Request Context for DataSource**

#### **4.1. Request Context Middleware**

**File:** `packages/cli/src/middlewares/requestContext.ts`

```typescript
import { AsyncLocalStorage } from 'async_hooks';
import { Request } from 'express';
import { DataSource } from '@n8n/typeorm';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

export const requestContextMiddleware = (req: any, res: any, next: any) => {
  const store = new Map<string, any>();
  store.set('request', req);
  store.set('dataSource', req.dataSource);  // Voyager DB for this subdomain
  store.set('subdomain', req.subdomain);
  
  asyncLocalStorage.run(store, () => {
    next();
  });
};

/**
 * Get Voyager DataSource for current request
 * Use this instead of Container.get(DataSource) for multi-tenant queries
 */
export const getRequestDataSource = (): DataSource => {
  const store = asyncLocalStorage.getStore();
  const dataSource = store?.get('dataSource');
  
  if (!dataSource) {
    throw new Error('No DataSource in request context. Is middleware configured?');
  }
  
  return dataSource;
};

export const getSubdomain = (): string | undefined => {
  const store = asyncLocalStorage.getStore();
  return store?.get('subdomain');
};

export const getRequest = () => {
  const store = asyncLocalStorage.getStore();
  return store?.get('request') as Request;
};
```

---

### **Phase 5: Middleware Integration**

#### **5.1. Middleware Order (Critical!)**

**File:** `packages/cli/src/Server.ts` or main server setup

```typescript
import cookieParser from 'cookie-parser';
import { requestContextMiddleware } from '@/middlewares/requestContext';
import { subdomainValidationMiddleware } from '@/middlewares/subdomain-validation.middleware';
import { dotnetJwtAuthMiddleware } from '@/middlewares/dotnet-jwt-auth.middleware';

// Setup middleware in this EXACT order:
app.use(cookieParser());                      // 1. Parse cookies
app.use(requestContextMiddleware);            // 2. Setup AsyncLocalStorage
app.use(subdomainValidationMiddleware);       // 3. Get Voyager DB for subdomain
app.use(dotnetJwtAuthMiddleware);             // 4. Validate .NET JWT
// ... n8n's existing middleware                5. n8n routes, etc.
```

**Why this order?**
1. **cookieParser** - Must be first (read cookies)
2. **requestContextMiddleware** - Setup storage for request data
3. **subdomainValidationMiddleware** - Query Elevate DB, get Voyager DataSource
4. **dotnetJwtAuthMiddleware** - Validate JWT, load user from Voyager DB
5. **n8n routes** - Handle requests with authenticated user

---

### **Phase 6: Refactor Database Access**

#### **Challenge: n8n uses singleton DataSource**

**Current n8n code:**
```typescript
// BAD for multi-tenant:
const dataSource = Container.get(DataSource);
const users = await dataSource.getRepository(User).find();
```

**Multi-tenant code:**
```typescript
// GOOD for multi-tenant:
import { getRequestDataSource } from '@/middlewares/requestContext';

const dataSource = getRequestDataSource();  // Gets Voyager DB for this request!
const users = await dataSource.getRepository(User).find();
```

#### **6.1. Create Helper Service**

**File:** `packages/cli/src/services/datasource.service.ts`

```typescript
import { Service } from '@n8n/di';
import { getRequestDataSource } from '@/middlewares/requestContext';
import type { DataSource } from '@n8n/typeorm';

@Service()
export class DataSourceService {
  /**
   * Get DataSource for current request
   * Falls back to Container.get(DataSource) for backwards compatibility
   */
  getDataSource(): DataSource {
    try {
      // Try to get request-specific DataSource (multi-tenant)
      return getRequestDataSource();
    } catch {
      // Fallback to singleton (single-tenant mode)
      return Container.get(DataSource);
    }
  }
  
  /**
   * Get repository for current request
   */
  getRepository<T>(entity: any) {
    return this.getDataSource().getRepository<T>(entity);
  }
}
```

#### **6.2. Update Services to Use Request DataSource**

**Example: Workflow Service**

```typescript
// OLD (single-tenant):
@Service()
export class WorkflowService {
  constructor(
    private readonly dataSource: DataSource  // ❌ Singleton!
  ) {}
  
  async getWorkflows() {
    return this.dataSource.getRepository(Workflow).find();  // ❌ Wrong DB!
  }
}

// NEW (multi-tenant):
@Service()
export class WorkflowService {
  constructor(
    private readonly dataSourceService: DataSourceService  // ✅ Request-aware!
  ) {}
  
  async getWorkflows() {
    const ds = this.dataSourceService.getDataSource();  // ✅ Right DB!
    return ds.getRepository(Workflow).find();
  }
}
```

⚠️ **This requires updating MANY files in n8n!**

---

## 🚀 Simplified Approach (Recommended)

### **If Refactoring All Services is Too Much:**

#### **Option A: Proxy the Container**

**File:** `packages/cli/src/databases/datasource-proxy.ts`

```typescript
import { Container } from '@n8n/di';
import { DataSource } from '@n8n/typeorm';
import { getRequestDataSource } from '@/middlewares/requestContext';

// Override Container.get(DataSource) behavior
const originalGet = Container.get.bind(Container);

Container.get = function<T>(identifier: any): T {
  if (identifier === DataSource) {
    try {
      // Try to get request-specific DataSource
      return getRequestDataSource() as T;
    } catch {
      // Fallback to original
      return originalGet(identifier);
    }
  }
  return originalGet(identifier);
} as any;
```

**Pros:**
- ✅ No code changes in services
- ✅ Works automatically
- ✅ Backwards compatible

**Cons:**
- ⚠️ Hacky
- ⚠️ May have edge cases

---

#### **Option B: Hybrid Approach**

**Keep n8n single-tenant for now, but prepare for multi-tenant:**

1. ✅ Implement Elevate DB (singleton)
2. ✅ Implement subdomain validation
3. ✅ Store subdomain in request context
4. ⏳ **Don't switch DataSource yet**
5. ✅ Manually use `req.dataSource` only in new routes/services

**Benefits:**
- Works immediately
- Can migrate gradually
- No breaking changes

---

## 📋 Environment Variables Needed

```powershell
# Add to START_N8N_MSSQL.ps1

# ============================================================
# Elevate Database (Central - Singleton)
# ============================================================
$env:ELEVATE_DB_HOST = "10.242.218.73"      # Elevate DB server
$env:ELEVATE_DB_PORT = "1433"
$env:ELEVATE_DB_NAME = "elevate"            # Elevate database name
$env:ELEVATE_DB_USER = "qa"
$env:ELEVATE_DB_PASSWORD = "bestqateam"
$env:ELEVATE_DB_ENCRYPT = "false"
$env:ELEVATE_DB_TRUST_CERT = "true"

# ============================================================
# .NET Core JWT Settings (Same as Flowise)
# ============================================================
$env:DOTNET_AUDIENCE_ID = "<from-flowise-env>"
$env:DOTNET_AUDIENCE_SECRET = "<from-flowise-env>"
$env:DOTNET_ISSUER = "<from-flowise-env>"
$env:DOTNET_SYMMETRIC_KEY = "<from-flowise-env>"
$env:IS_VIRTUOSO_AI = "false"  # or "true"

# ============================================================
# Multi-Tenant Settings
# ============================================================
$env:ENABLE_MULTI_TENANT = "true"
$env:DEFAULT_SUBDOMAIN = "default"  # For localhost

# ============================================================
# Voyager Database (Dynamic per subdomain)
# Note: These are defaults, overridden per subdomain from Elevate DB
# ============================================================
$env:DB_MSSQLDB_SCHEMA = "n8n"  # ✅ Already set!
```

---

## 🎯 Implementation Priority

### **Quick Implementation (2-3 days):**

**Step 1:** Elevate DB Connection (4 hours)
- [x] Create `elevate.datasource.ts`
- [ ] Initialize at startup
- [ ] Test connection

**Step 2:** Voyager DataSource Factory (4 hours)
- [ ] Create `voyager.datasource.factory.ts`
- [ ] Query Elevate DB for company
- [ ] Create/cache Voyager DataSource
- [ ] Test with multiple subdomains

**Step 3:** Middleware Integration (4 hours)
- [ ] Create subdomain validation middleware
- [ ] Create request context middleware
- [ ] Create .NET JWT auth middleware
- [ ] Add to Express app in correct order

**Step 4:** Container Proxy (2 hours)
- [ ] Override `Container.get(DataSource)`
- [ ] Return request-specific DataSource
- [ ] Test existing n8n code works

**Step 5:** Testing (4 hours)
- [ ] Test localhost
- [ ] Test subdomain1.domain.com
- [ ] Test subdomain2.domain.com
- [ ] Verify data isolation
- [ ] Test JWT from .NET API

**Total:** ~18 hours (2-3 days)

---

## 🔍 Critical Decision Points

### **✅ CONFIRMED: Your Architecture**

**Each client has their own Voyager database:**

```
client1.domain.com → client1_voyager database
  ├── flowise.* schema (Flowise data for client1)
  └── n8n.* schema     (n8n data for client1)

client2.domain.com → client2_voyager database
  ├── flowise.* schema (Flowise data for client2)
  └── n8n.* schema     (n8n data for client2)
```

**Complete data isolation per client!** ✅

**Implementation Required:** Full dynamic DataSource (like Flowise)

---

### **Question 2: How Isolated Are Tenants?**

**Do different subdomains share:**
- [ ] Same Voyager database, different schemas? (EASY)
- [ ] Different Voyager databases? (COMPLEX)
- [ ] Different SQL Servers? (VERY COMPLEX)

---

## 📝 Summary

### **Your Architecture:**

1. ✅ **Elevate DB** - Single instance, initialized once
   - Contains company table
   - Stores Voyager DB credentials per subdomain

2. ❗ **Voyager DB(s)** - Per client/subdomain
   - Need to determine: Same DB or different DBs?
   - Contains flowise.* and n8n.* schemas

3. ✅ **.NET Core JWT** - Shared authentication
   - Same token works for Flowise and n8n

### **What I Need to Know:**

1. **Is Voyager DB the same for all subdomains?**
   - If YES → Simple (schema isolation only)
   - If NO → Complex (dynamic DB per request)

2. **What does the Elevate `company` table return?**
   - Is `db_server` the same for all companies?
   - Is `db_name` the same or different per company?

3. **Do you want to start simple or full implementation?**
   - Simple: Container proxy (works immediately)
   - Full: Refactor all services (takes longer, cleaner)

**Please clarify these points and I'll create the exact implementation!** 🎯

