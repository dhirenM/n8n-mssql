# Quick Start: Implementing Flowise Multi-Tenant Patterns in N8N

This guide provides a step-by-step approach to start implementing the multi-tenant architecture from Flowise into your n8n-mssql project.

---

## Prerequisites

Before you begin:
- [x] Flowise source code accessible at `C:\Git\Flowise-Main\`
- [x] N8N source code accessible at `C:\Git\n8n-mssql\`
- [ ] Elevate database server setup and accessible
- [ ] Understanding of TypeScript, Express, and TypeORM
- [ ] Node.js and pnpm installed

---

## Phase 1: Foundation (Start Here)

### Step 1.1: Set Up Environment Variables

Create a new file for multi-tenant environment variables:

**File:** `.env.multi-tenant.example`

```env
# Multi-Tenant Configuration
N8N_MODE=multi_tenant  # Options: standalone, multi_tenant
USE_AUTH=true

# JWT Settings
JWT_AUTH_TOKEN_SECRET=your-secret-key-change-this
JWT_REFRESH_TOKEN_SECRET=your-refresh-secret-change-this
JWT_AUDIENCE=n8n-audience
JWT_ISSUER=n8n-issuer
JWT_TOKEN_EXPIRY_IN_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRY_IN_MINUTES=129600

# Elevate Database (Central Metadata)
ELEVATE_DATABASE_HOST=your-elevate-db-host
ELEVATE_DATABASE_PORT=1433
ELEVATE_DATABASE_NAME=ElevateMetadata
ELEVATE_DATABASE_USER=elevate_user
ELEVATE_DATABASE_PASSWORD=elevate_password
ELEVATE_DATABASE_SSL=true
ELEVATE_PASSPHRASE=your-encryption-passphrase

# Optional: VirtuosoAI Mode
IS_VIRTUOSO_AI=false
IS_ELEVATE=false
SYMMETRIC_KEY=
AUDIENCE_ID=
AUDIENCE_SECRET=
```

**Action Items:**
1. Copy this to `.env.multi-tenant.example`
2. Copy to `.env` and fill in actual values
3. Add to `.gitignore` (ensure `.env` is ignored)

---

### Step 1.2: Create AppConfig Service

**File:** `packages/cli/src/config/app.config.ts`

```typescript
import { Service } from '@n8n/di';

interface AuthSettings {
  symmetricKey: string;
  issuer: string;
  audienceId: string;
  audienceSecret: string;
  jwtAuthTokenSecret: string;
  jwtRefreshTokenSecret: string;
  tokenExpiryMinutes: number;
  refreshTokenExpiryMinutes: number;
}

@Service()
export class AppConfig {
  get isMultiTenantMode(): boolean {
    return process.env.N8N_MODE === 'multi_tenant';
  }

  get useAuth(): boolean {
    return process.env.USE_AUTH === 'true';
  }

  get isVirtuosoAI(): boolean {
    return process.env.IS_VIRTUOSO_AI === 'true';
  }

  get isElevate(): boolean {
    return process.env.IS_ELEVATE === 'true';
  }

  get authSettings(): AuthSettings {
    return {
      symmetricKey: process.env.SYMMETRIC_KEY || '',
      issuer: process.env.ISSUER || process.env.JWT_ISSUER || 'n8n',
      audienceId: process.env.AUDIENCE_ID || process.env.JWT_AUDIENCE || 'n8n-api',
      audienceSecret: process.env.AUDIENCE_SECRET || '',
      jwtAuthTokenSecret: process.env.JWT_AUTH_TOKEN_SECRET || 'change-me',
      jwtRefreshTokenSecret: 
        process.env.JWT_REFRESH_TOKEN_SECRET || 
        process.env.JWT_AUTH_TOKEN_SECRET || 
        'change-me',
      tokenExpiryMinutes: parseInt(process.env.JWT_TOKEN_EXPIRY_IN_MINUTES || '60'),
      refreshTokenExpiryMinutes: parseInt(
        process.env.JWT_REFRESH_TOKEN_EXPIRY_IN_MINUTES || '129600'
      ),
    };
  }
}
```

**File:** `packages/cli/src/config/multi-tenant.config.ts`

```typescript
import { Service } from '@n8n/di';

interface ElevateConfig {
  host: string;
  port: number;
  database: string;
  username: string;
  password: string;
  ssl: boolean;
  passphrase: string;
}

@Service()
export class MultiTenantConfig {
  get isMultiTenantMode(): boolean {
    return process.env.N8N_MODE === 'multi_tenant';
  }

  get elevate(): ElevateConfig {
    return {
      host: process.env.ELEVATE_DATABASE_HOST || '',
      port: parseInt(process.env.ELEVATE_DATABASE_PORT || '1433'),
      database: process.env.ELEVATE_DATABASE_NAME || '',
      username: process.env.ELEVATE_DATABASE_USER || '',
      password: process.env.ELEVATE_DATABASE_PASSWORD || '',
      ssl: process.env.ELEVATE_DATABASE_SSL === 'true',
      passphrase: process.env.ELEVATE_PASSPHRASE || '',
    };
  }

  validate(): void {
    if (!this.isMultiTenantMode) return;

    const required = [
      'ELEVATE_DATABASE_HOST',
      'ELEVATE_DATABASE_NAME',
      'ELEVATE_DATABASE_USER',
      'ELEVATE_DATABASE_PASSWORD',
      'ELEVATE_PASSPHRASE',
    ];

    const missing = required.filter(key => !process.env[key]);
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
  }
}
```

**Test:**
```bash
# In packages/cli directory
pnpm build
# Should compile without errors
```

---

### Step 1.3: Create Request Context Service

**File:** `packages/cli/src/services/request-context.service.ts`

```typescript
import { AsyncLocalStorage } from 'async_hooks';
import { Request } from 'express';
import { Service } from '@n8n/di';
import type { DataSource } from '@n8n/typeorm';

@Service()
export class RequestContextService {
  private static storage = new AsyncLocalStorage<Map<string, any>>();

  getStore(): Map<string, any> | undefined {
    return RequestContextService.storage.getStore();
  }

  run(store: Map<string, any>, callback: () => void): void {
    RequestContextService.storage.run(store, callback);
  }

  getRequest(): Request | undefined {
    const store = this.getStore();
    return store?.get('request');
  }

  getDataSource(): DataSource | undefined {
    const store = this.getStore();
    return store?.get('request')?.dataSource;
  }

  getUser(): any {
    const store = this.getStore();
    return store?.get('request')?.user;
  }

  getCompany(): any {
    const store = this.getStore();
    return store?.get('request')?.company;
  }

  getSubdomain(): string | undefined {
    const store = this.getStore();
    return store?.get('request')?.subdomain;
  }
}

// Helper functions for easy access without DI
export function getRequestDataSource(): DataSource | undefined {
  const store = RequestContextService['storage'].getStore();
  return store?.get('request')?.dataSource;
}

export function getRequestUser(): any {
  const store = RequestContextService['storage'].getStore();
  return store?.get('request')?.user;
}

export function getRequestCompany(): any {
  const store = RequestContextService['storage'].getStore();
  return store?.get('request')?.company;
}

export function getRequest(): Request | undefined {
  const store = RequestContextService['storage'].getStore();
  return store?.get('request');
}
```

**File:** `packages/cli/src/middlewares/request-context.middleware.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import { Service } from '@n8n/di';
import { RequestContextService } from '@/services/request-context.service';

@Service()
export class RequestContextMiddleware {
  constructor(private readonly contextService: RequestContextService) {}

  handler() {
    return (req: Request, res: Response, next: NextFunction) => {
      const store = new Map<string, any>();
      store.set('request', req);

      this.contextService.run(store, () => {
        next();
      });
    };
  }
}

// Standalone middleware function (if not using DI)
export function requestContextMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const store = new Map<string, any>();
  store.set('request', req);

  // Access the static storage directly
  const AsyncLocalStorage = require('async_hooks').AsyncLocalStorage;
  const storage = new AsyncLocalStorage<Map<string, any>>();
  
  storage.run(store, () => {
    next();
  });
}
```

**Test:**
Create a simple test file to verify the context works:

**File:** `packages/cli/src/services/__tests__/request-context.test.ts`

```typescript
import { RequestContextService } from '../request-context.service';

describe('RequestContextService', () => {
  it('should store and retrieve context', () => {
    const service = new RequestContextService();
    const store = new Map<string, any>();
    store.set('test', 'value');

    service.run(store, () => {
      expect(service.getStore()?.get('test')).toBe('value');
    });
  });
});
```

Run test:
```bash
pnpm test request-context
```

---

### Step 1.4: TypeScript Type Declarations

**File:** `packages/cli/src/types/express.d.ts`

```typescript
import type { DataSource } from '@n8n/typeorm';

declare global {
  namespace Express {
    interface Request {
      subdomain?: string;
      company?: {
        id: string;
        name: string;
        domain: string;
        guid: string;
        inactive: boolean;
      };
      dataSource?: DataSource;
      queryStore?: Record<string, any>;
    }
  }
}
```

---

## Testing Phase 1

Create a simple test endpoint to verify everything compiles:

**File:** `packages/cli/src/controllers/multi-tenant-test.controller.ts`

```typescript
import { Get, RestController } from '@/decorators';
import { Service } from '@n8n/di';
import { AppConfig } from '@/config/app.config';
import { MultiTenantConfig } from '@/config/multi-tenant.config';
import { RequestContextService } from '@/services/request-context.service';

@Service()
@RestController('/test/multi-tenant')
export class MultiTenantTestController {
  constructor(
    private readonly appConfig: AppConfig,
    private readonly multiTenantConfig: MultiTenantConfig,
    private readonly requestContext: RequestContextService,
  ) {}

  @Get('/config')
  getConfig() {
    return {
      mode: this.appConfig.isMultiTenantMode ? 'multi-tenant' : 'standalone',
      useAuth: this.appConfig.useAuth,
      isVirtuosoAI: this.appConfig.isVirtuosoAI,
      elevateHost: this.multiTenantConfig.elevate.host,
    };
  }

  @Get('/context')
  getContext() {
    return {
      hasContext: !!this.requestContext.getStore(),
      hasRequest: !!this.requestContext.getRequest(),
      hasUser: !!this.requestContext.getUser(),
    };
  }
}
```

**Build and Run:**
```bash
cd packages/cli
pnpm build
pnpm start
```

**Test:**
```bash
curl http://localhost:5678/test/multi-tenant/config
# Should return configuration
```

---

## Phase 2: Next Steps (After Phase 1 is Complete)

Once Phase 1 is complete and tested, proceed to:

### Step 2.1: Create Tenant DataSource Manager

Reference: See `FLOWISE_TO_N8N_AUTHENTICATION_MIGRATION_PLAN.md` Phase 1.3

**Key Files to Create:**
- `packages/cli/src/services/tenant-datasource-manager.service.ts`
- `packages/cli/src/services/tenant-config.service.ts`

### Step 2.2: Create Middleware Chain

**Key Files to Create:**
- `packages/cli/src/middlewares/subdomain-validation.middleware.ts`
- `packages/cli/src/middlewares/query-params-store.middleware.ts`

### Step 2.3: Integrate into Server

**Key Files to Modify:**
- `packages/cli/src/server.ts`

---

## Common Issues & Troubleshooting

### Issue: Build Errors

**Problem:** TypeScript compilation errors about missing types

**Solution:**
```bash
# Rebuild all packages
pnpm -r build

# Clear build cache
rm -rf packages/cli/dist
pnpm build
```

### Issue: Service Not Injected

**Problem:** `Container.get()` returns undefined

**Solution:**
- Ensure class has `@Service()` decorator
- Import the service file in `server.ts`
- Check DI container initialization

### Issue: Environment Variables Not Loading

**Problem:** Config returns empty values

**Solution:**
```bash
# Check .env file exists
ls -la .env

# Verify it's being loaded
console.log(process.env.N8N_MODE);
```

---

## Development Workflow

### 1. Make Changes
```bash
# Edit files in packages/cli/src/
```

### 2. Build
```bash
cd packages/cli
pnpm build
```

### 3. Test
```bash
# Unit tests
pnpm test

# Integration tests
pnpm test:integration

# Manual testing
pnpm start
```

### 4. Debug
```bash
# Run with debugger
pnpm start:debug

# Or use VS Code launch.json
# F5 to start debugging
```

---

## Verification Checklist

Before moving to Phase 2:

- [ ] All Phase 1 files created
- [ ] No TypeScript compilation errors
- [ ] All tests passing
- [ ] AppConfig service working
- [ ] MultiTenantConfig service working
- [ ] RequestContext service working
- [ ] Test endpoint returns expected data
- [ ] Environment variables loading correctly
- [ ] No runtime errors on startup

---

## Next Document to Reference

Once Phase 1 is complete, refer to:
1. `FLOWISE_TO_N8N_AUTHENTICATION_MIGRATION_PLAN.md` - Full implementation plan
2. `FLOWISE_N8N_CODE_REFERENCE.md` - Code examples for each pattern

---

## Questions?

Review the Flowise implementation:
```bash
# Open Flowise files for reference
code C:\Git\Flowise-Main\packages\server\src\AppConfig.ts
code C:\Git\Flowise-Main\packages\server\src\middleware\requestContext.ts
```

Compare with existing n8n patterns:
```bash
# Check n8n auth implementation
code C:\Git\n8n-mssql\packages\cli\src\auth\
```

---

## Tips for Success

1. **Incremental Implementation:** Complete one step fully before moving to the next
2. **Test Early:** Write tests as you implement, not after
3. **Reference Flowise:** Keep Flowise code open for reference
4. **Maintain Compatibility:** Always check that standalone mode still works
5. **Document as You Go:** Update this guide with any issues/solutions you find
6. **Commit Often:** Small, logical commits make debugging easier

---

## Ready to Start?

Begin with Step 1.1 (Environment Variables) and work your way through Phase 1.

Good luck! 🚀

