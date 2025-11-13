# Multitenant Base Repository Solution

## Overview

This document describes the **BaseRepository** pattern for automatic multitenant database routing in n8n. This solution eliminates the need to pass `DataSource` or `EntityManager` through every controller, service, and repository method.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    HTTP Request Flow                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. requestContextMiddleware                                      │
│    - Creates AsyncLocalStorage context                           │
│    - Stores request object in context                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. subdomainValidationMiddleware                                 │
│    - Extracts subdomain from hostname                            │
│    - Queries Elevate DB for company                              │
│    - Gets/creates tenant DataSource                              │
│    - Sets req.dataSource = tenantDataSource                      │
│    - Sets req.subdomain = "client1"                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. dotnetJwtAuthMiddleware (optional)                            │
│    - Validates JWT token                                         │
│    - Sets req.user                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Controllers → Services → Repositories                         │
│    NO CHANGES NEEDED!                                            │
│    BaseRepository automatically uses correct tenant database     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ BaseRepository.getContextManager()                               │
│    - Reads tenant DataSource from AsyncLocalStorage              │
│    - Returns tenant-specific EntityManager                       │
│    - Falls back to default for non-request contexts              │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. BaseRepository

**Location:** `packages/@n8n/db/src/repositories/base.repository.ts`

Abstract base class that all repositories should extend. Automatically routes queries to the correct tenant database based on request context.

**Features:**
- ✅ Zero-configuration multitenant support
- ✅ Automatic fallback for CLI, background jobs, cron tasks
- ✅ Validates DataSource initialization
- ✅ Type-safe EntityManager access
- ✅ Debug helpers for troubleshooting
- ✅ Never throws - always returns valid manager
- ✅ O(1) performance via AsyncLocalStorage

### 2. Request Context Middleware

**Location:** `packages/cli/src/middlewares/requestContext.ts`

Uses Node.js AsyncLocalStorage to store request-scoped data. Must be registered **first** in the middleware chain.

### 3. Subdomain Validation Middleware

**Location:** `packages/cli/src/middlewares/subdomain-validation.middleware.ts`

Validates tenant subdomain and attaches the tenant-specific DataSource to `req.dataSource`.

## Usage Guide

### For New Repositories

Simply extend `BaseRepository` instead of `Repository`:

```typescript
import { Service } from '@n8n/di';
import { DataSource } from '@n8n/typeorm';
import { MyEntity } from '../entities';
import { BaseRepository } from './base.repository';

@Service()
export class MyRepository extends BaseRepository<MyEntity> {
	constructor(dataSource: DataSource) {
		super(MyEntity, dataSource);
	}

	async findByCustomLogic(id: string) {
		// Automatically uses tenant-specific database!
		const em = this.getContextManager();
		return await em.findOne(MyEntity, { where: { id } });
	}

	// For methods that already accept entityManager parameter
	async findWithTransaction(id: string, entityManager?: EntityManager) {
		// Falls back to context manager if not provided
		const em = entityManager ?? this.getContextManager();
		return await em.findOne(MyEntity, { where: { id } });
	}
}
```

### Migrating Existing Repositories

**Before:**
```typescript
export class ProjectRepository extends Repository<Project> {
	constructor(dataSource: DataSource) {
		super(Project, dataSource.manager);
	}

	async getPersonalProjectForUser(userId: string, entityManager?: EntityManager) {
		const em = entityManager ?? this.manager; // ❌ Always uses default DB
		return await em.findOne(Project, { where: { ... } });
	}
}
```

**After:**
```typescript
export class ProjectRepository extends BaseRepository<Project> {
	constructor(dataSource: DataSource) {
		super(Project, dataSource); // Changed: pass dataSource, not dataSource.manager
	}

	async getPersonalProjectForUser(userId: string, entityManager?: EntityManager) {
		const em = entityManager ?? this.getContextManager(); // ✅ Uses tenant DB
		return await em.findOne(Project, { where: { ... } });
	}
}
```

**Migration Steps:**
1. Change `extends Repository<Entity>` → `extends BaseRepository<Entity>`
2. Import `BaseRepository` from `'./base.repository'`
3. Update constructor: `super(Entity, dataSource.manager)` → `super(Entity, dataSource)`
4. Replace `this.manager` → `this.getContextManager()`
5. Keep `entityManager` parameters for transaction support

### Controllers and Services

**No changes needed!** Controllers and services continue to work as before:

```typescript
// ✅ Controller - No changes
@Get('/personal')
async getPersonalProject(req: AuthenticatedRequest) {
	const project = await this.projectsService.getPersonalProject(req.user);
	if (!project) {
		throw new NotFoundError('Could not find a personal project');
	}
	return project;
}

// ✅ Service - No changes
async getPersonalProject(user: User): Promise<Project | null> {
	return await this.projectRepository.getPersonalProjectForUser(user.id);
}

// ✅ Repository - Automatic tenant routing
async getPersonalProjectForUser(userId: string, entityManager?: EntityManager) {
	const em = entityManager ?? this.getContextManager(); // 🎯 Magic happens here
	return await em.findOne(Project, { ... });
}
```

## How It Works

### Request Lifecycle

1. **Request arrives:** `client1.myapp.com/api/projects/personal`

2. **requestContextMiddleware** stores request in AsyncLocalStorage
   ```typescript
   asyncLocalStorage.run(store, () => next());
   ```

3. **subdomainValidationMiddleware** sets tenant DataSource
   ```typescript
   req.dataSource = await getDataSourceForSubdomain('client1');
   req.subdomain = 'client1';
   ```

4. **Repository accesses database**
   ```typescript
   const em = this.getContextManager();
   // → Reads req.dataSource from AsyncLocalStorage
   // → Returns client1's EntityManager
   // → Query goes to client1's database ✅
   ```

### Fallback Behavior

For non-request contexts (CLI, cron, background jobs):

```typescript
protected getContextManager(): EntityManager {
	try {
		const store = asyncLocalStorage.getStore();
		if (!store) return this.manager; // ✅ Fallback to default DB
		
		const request = store.get('request');
		if (!request?.dataSource) return this.manager; // ✅ Fallback
		
		return request.dataSource.manager; // 🎯 Tenant DB
	} catch {
		return this.manager; // ✅ Always safe
	}
}
```

**Never throws, always returns a valid EntityManager.**

## Debug Helpers

### Check Current Context

```typescript
// In any repository method:
if (this.isInTenantContext()) {
	console.log(`Using tenant: ${this.getCurrentSubdomain()}`);
} else {
	console.log('Using default database');
}
```

### Get Debug Info

```typescript
const debugInfo = this.getContextDebugInfo();
console.log(debugInfo);
// {
//   subdomain: 'client1',
//   isInTenantContext: true,
//   hasRequestContext: true,
//   defaultDatabase: 'dmnen_test',
//   entityName: 'Project'
// }
```

## Testing

### Unit Tests

Mock the request context:

```typescript
// Setup mock context
(globalThis as any).__requestContext = {
	getStore: () => ({
		get: (key: string) => {
			if (key === 'request') {
				return {
					dataSource: mockTenantDataSource,
					subdomain: 'testclient',
				};
			}
		},
	}),
};

// Your test
const result = await repository.getPersonalProjectForUser('user123');
expect(result).toBeDefined();
```

### Integration Tests

Ensure middleware is registered:

```typescript
beforeAll(async () => {
	app.use(requestContextMiddleware);
	app.use(subdomainValidationMiddleware);
});

test('should use correct tenant database', async () => {
	const response = await request(app)
		.get('/api/projects/personal')
		.set('Host', 'client1.myapp.com')
		.expect(200);
	
	expect(response.body.tenant).toBe('client1');
});
```

## Performance

- **AsyncLocalStorage:** Native Node.js, zero overhead
- **Lookup:** O(1) via hash map
- **Memory:** Minimal - context lives only during request
- **No cache needed:** DataSource is reused from connection pool

## Troubleshooting

### Issue: "Using default database instead of tenant"

**Check:**
1. ✅ Middleware order correct?
2. ✅ `subdomainValidationMiddleware` running before routes?
3. ✅ `req.dataSource` being set?

**Debug:**
```typescript
// In repository:
console.log(this.getContextDebugInfo());
```

### Issue: "DataSource not initialized"

**Solution:** Ensure VoyagerDataSourceFactory properly initializes DataSource:

```typescript
const dataSource = await VoyagerDataSourceFactory.getDataSourceForSubdomain(subdomain);
if (!dataSource.isInitialized) {
	await dataSource.initialize();
}
```

### Issue: "Background jobs using wrong database"

This is **correct behavior**. Background jobs should use the default database unless you explicitly pass a DataSource:

```typescript
// Option 1: Pass EntityManager explicitly
await repository.findByCustomLogic(id, tenantEntityManager);

// Option 2: Run in request context
const store = new Map();
store.set('request', { dataSource: tenantDataSource });
asyncLocalStorage.run(store, async () => {
	await repository.findByCustomLogic(id); // Uses tenant DB
});
```

## Middleware Registration

**Current setup in `server.ts`:**

```typescript
if (process.env.ENABLE_MULTI_TENANT === 'true') {
	const { requestContextMiddleware } = await import('@/middlewares/requestContext');
	const { subdomainValidationMiddleware } = await import('@/middlewares/subdomain-validation.middleware');
	const { dotnetJwtAuthMiddleware } = await import('@/middlewares/dotnet-jwt-auth.middleware');
	
	this.app.use(requestContextMiddleware);          // 1. Setup AsyncLocalStorage
	this.app.use(subdomainValidationMiddleware);     // 2. Validate subdomain → get Voyager DB
	this.app.use(dotnetJwtAuthMiddleware);           // 3. Validate .NET JWT tokens
	
	this.logger.info('✅ Multi-tenant middleware registered');
}
```

**Order is critical!** requestContextMiddleware must run first.

## Benefits

### ✅ Clean Architecture
- No DataSource passing through layers
- Controllers/Services unchanged
- Repositories automatically tenant-aware

### ✅ Maintainable
- Single change point (BaseRepository)
- Consistent pattern across all repositories
- Easy to add new repositories

### ✅ Robust
- Never throws exceptions
- Graceful fallback to default DB
- Works in all contexts (HTTP, CLI, cron)

### ✅ Type-Safe
- Full TypeScript support
- EntityManager properly typed
- No `any` types needed

### ✅ Performant
- O(1) lookup
- Native Node.js AsyncLocalStorage
- No additional overhead

## Examples

### Example: User Repository

```typescript
@Service()
export class UserRepository extends BaseRepository<User> {
	constructor(dataSource: DataSource) {
		super(User, dataSource);
	}

	async findByEmail(email: string): Promise<User | null> {
		const em = this.getContextManager(); // 🎯 Tenant-aware
		return await em.findOne(User, { where: { email } });
	}
}
```

### Example: Workflow Repository

```typescript
@Service()
export class WorkflowRepository extends BaseRepository<WorkflowEntity> {
	constructor(dataSource: DataSource) {
		super(WorkflowEntity, dataSource);
	}

	async getActiveWorkflows(): Promise<WorkflowEntity[]> {
		const em = this.getContextManager(); // 🎯 Tenant-aware
		return await em.find(WorkflowEntity, { where: { active: true } });
	}
}
```

## Summary

The **BaseRepository** pattern provides:
- ✅ Zero-config multitenant support
- ✅ No controller/service changes needed
- ✅ Automatic tenant routing
- ✅ Robust error handling
- ✅ Full backward compatibility
- ✅ Production-ready

Just extend `BaseRepository` and replace `this.manager` with `this.getContextManager()`. That's it!

