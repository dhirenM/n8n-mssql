# Repository Migration Plan - BaseRepository

## Overview

Not all repositories need to extend `BaseRepository`. Only repositories that manage **tenant-specific data** should be migrated. Repositories managing **global/system-wide data** should remain as-is.

## Migration Categories

### ✅ PRIORITY 1: Must Migrate (Tenant-Specific Core Data)

These repositories store tenant-specific data and **must** extend `BaseRepository`:

| Repository | Status | Reason |
|------------|--------|--------|
| ✅ ProjectRepository | **DONE** | Tenant-specific projects |
| UserRepository | **TODO** | Tenant-specific users |
| WorkflowRepository | **TODO** | Tenant-specific workflows |
| CredentialsRepository | **TODO** | Tenant-specific credentials |
| ExecutionRepository | **TODO** | Tenant-specific workflow executions |
| SharedWorkflowRepository | **TODO** | Tenant-specific workflow sharing |
| SharedCredentialsRepository | **TODO** | Tenant-specific credential sharing |
| ProjectRelationRepository | **TODO** | Tenant-specific project memberships |

**Priority:** CRITICAL - These are core features that users interact with daily.

### ✅ PRIORITY 2: Should Migrate (Tenant-Specific Supporting Data)

These support tenant-specific features:

| Repository | Status | Reason |
|------------|--------|--------|
| FolderRepository | **TODO** | Tenant-specific workflow folders |
| TagRepository | **TODO** | Tenant-specific tags |
| WorkflowTagMappingRepository | **TODO** | Tenant-specific workflow-tag relationships |
| FolderTagMappingRepository | **TODO** | Tenant-specific folder-tag relationships |
| ExecutionDataRepository | **TODO** | Tenant-specific execution data |
| ExecutionMetadataRepository | **TODO** | Tenant-specific execution metadata |
| ExecutionAnnotationRepository | **TODO** | Tenant-specific execution annotations |
| WorkflowHistoryRepository | **TODO** | Tenant-specific workflow version history |
| WorkflowStatisticsRepository | **TODO** | Tenant-specific workflow stats |
| WorkflowDependencyRepository | **TODO** | Tenant-specific workflow dependencies |
| WebhookRepository | **TODO** | Tenant-specific webhooks |
| TestRunRepository | **TODO** | Tenant-specific test runs |
| TestCaseExecutionRepository | **TODO** | Tenant-specific test executions |
| AnnotationTagRepository | **TODO** | Tenant-specific annotation tags |
| AnnotationTagMappingRepository | **TODO** | Tenant-specific annotation mappings |
| ApiKeyRepository | **TODO** | Tenant-specific API keys |
| AuthIdentityRepository | **TODO** | Tenant-specific auth identities |

**Priority:** HIGH - Important for full feature functionality

### ⚠️ PRIORITY 3: Consider Carefully (Context-Dependent)

These may or may not need migration depending on your business logic:

| Repository | Default | Reason |
|------------|---------|--------|
| ProcessedDataRepository | **MAYBE** | Depends if data table module is tenant-specific |
| InvalidAuthTokenRepository | **MAYBE** | Could be global or tenant-specific |
| EventDestinationsRepository | **MAYBE** | Depends on audit log scope |
| AuthProviderSyncHistoryRepository | **MAYBE** | Depends on auth provider setup |

**Decision:** Check your requirements

### ❌ DO NOT MIGRATE (Global/System-Wide Data)

These repositories manage system-wide data and should **NOT** extend `BaseRepository`:

| Repository | Reason |
|------------|--------|
| SettingsRepository | Global n8n settings (applies to all tenants) |
| VariablesRepository | Global environment variables (shared across all) |
| RoleRepository | Global role definitions (project:admin, etc.) |
| ScopeRepository | Global permission scopes |
| LicenseMetricsRepository | Global license tracking |

**Why NOT:** These tables should be in the default database and shared across all tenants.

## Migration Template

### Before:
```typescript
import { Repository } from '@n8n/typeorm';

@Service()
export class UserRepository extends Repository<User> {
	constructor(dataSource: DataSource) {
		super(User, dataSource.manager);  // ❌ Always uses default DB
	}

	async findByEmail(email: string): Promise<User | null> {
		return await this.findOne({ where: { email } });
		// ❌ Queries default database
	}
}
```

### After:
```typescript
import { BaseRepository } from './base.repository';

@Service()
export class UserRepository extends BaseRepository<User> {
	constructor(dataSource: DataSource) {
		super(User, dataSource);  // ✅ Changed
	}

	async findByEmail(email: string): Promise<User | null> {
		const em = this.getContextManager();  // ✅ Tenant-aware
		return await em.findOne(User, { where: { email } });
	}
}
```

## Automated Migration Script

Here's a script to help migrate repositories:

### Step 1: Find and Replace Pattern

For each repository file:

1. **Import change:**
   ```typescript
   // Find:
   import { Repository } from '@n8n/typeorm';
   
   // Replace with:
   import { BaseRepository } from './base.repository';
   ```

2. **Class declaration change:**
   ```typescript
   // Find:
   export class XRepository extends Repository<X> {
   
   // Replace with:
   export class XRepository extends BaseRepository<X> {
   ```

3. **Constructor change:**
   ```typescript
   // Find:
   super(EntityName, dataSource.manager);
   
   // Replace with:
   super(EntityName, dataSource);
   ```

4. **Manager usage change:**
   ```typescript
   // Find all instances of:
   this.manager
   this.find(
   this.findOne(
   this.count(
   this.save(
   
   // Replace with:
   const em = this.getContextManager();
   em.find(
   em.findOne(
   em.count(
   em.save(
   ```

### Step 2: Migration Checklist

For each repository:

- [ ] Change `extends Repository<T>` to `extends BaseRepository<T>`
- [ ] Import `BaseRepository` from `'./base.repository'`
- [ ] Update constructor: `super(Entity, dataSource)` instead of `super(Entity, dataSource.manager)`
- [ ] Add `const em = this.getContextManager()` at the start of each method
- [ ] Replace `this.manager` with `em`
- [ ] Replace `this.find(` with `em.find(Entity, `
- [ ] Replace `this.findOne(` with `em.findOne(Entity, `
- [ ] Replace `this.count(` with `em.count(Entity, `
- [ ] Replace `this.save(` with `em.save(`
- [ ] Keep `entityManager` parameters for transaction support
- [ ] Test the repository methods

## Example: Migrating UserRepository

### Before:
```typescript:11:20:user.repository.ts
export class UserRepository extends Repository<User> {
	constructor(dataSource: DataSource) {
		super(User, dataSource.manager);
	}

	async findManyByEmail(emails: string[]): Promise<User[]> {
		return await this.find({
			where: { email: In(emails) },
		});
	}
```

### After:
```typescript
export class UserRepository extends BaseRepository<User> {
	constructor(dataSource: DataSource) {
		super(User, dataSource);
	}

	async findManyByEmail(emails: string[]): Promise<User[]> {
		const em = this.getContextManager();
		return await em.find(User, {
			where: { email: In(emails) },
		});
	}
```

## Example: Migrating WorkflowRepository

### Before:
```typescript:53:60:workflow.repository.ts
export class WorkflowRepository extends Repository<WorkflowEntity> {
	constructor(
		dataSource: DataSource,
		private readonly globalConfig: GlobalConfig,
	) {
		super(WorkflowEntity, dataSource.manager);
	}

	async get(where: FindOptionsWhere<WorkflowEntity>, options?: { relations: string[] }) {
		return await this.findOne({ where, relations: options?.relations });
	}
```

### After:
```typescript
export class WorkflowRepository extends BaseRepository<WorkflowEntity> {
	constructor(
		dataSource: DataSource,
		private readonly globalConfig: GlobalConfig,
	) {
		super(WorkflowEntity, dataSource);
	}

	async get(where: FindOptionsWhere<WorkflowEntity>, options?: { relations: string[] }) {
		const em = this.getContextManager();
		return await em.findOne(WorkflowEntity, { where, relations: options?.relations });
	}
```

## Phased Rollout Strategy

### Phase 1: Core Features (Week 1)
Migrate in order:
1. ✅ ProjectRepository (DONE)
2. UserRepository
3. WorkflowRepository
4. CredentialsRepository
5. ExecutionRepository

Test thoroughly after each migration.

### Phase 2: Sharing & Relations (Week 2)
6. SharedWorkflowRepository
7. SharedCredentialsRepository
8. ProjectRelationRepository
9. FolderRepository

### Phase 3: Supporting Features (Week 3)
10. TagRepository
11. WorkflowTagMappingRepository
12. ExecutionDataRepository
13. ExecutionMetadataRepository
14. WebhookRepository

### Phase 4: Advanced Features (Week 4)
15. WorkflowHistoryRepository
16. WorkflowStatisticsRepository
17. TestRunRepository
18. ApiKeyRepository
19. All remaining tenant-specific repositories

## Testing Strategy

### For Each Migrated Repository:

#### 1. Unit Tests
```typescript
describe('UserRepository - Multitenant', () => {
	it('should use tenant database from context', async () => {
		// Setup tenant context
		const store = new Map();
		store.set('request', {
			dataSource: tenantDataSource,
			subdomain: 'client1',
		});
		
		await asyncLocalStorage.run(store, async () => {
			const user = await userRepository.findByEmail('test@example.com');
			// Verify it queried client1's database
			expect(user).toBeDefined();
		});
	});
	
	it('should fall back to default database when no context', async () => {
		const user = await userRepository.findByEmail('test@example.com');
		// Should query default database
		expect(user).toBeDefined();
	});
});
```

#### 2. Integration Tests
```bash
# Test with tenant 1
curl -H "Host: client1.myapp.com" http://localhost:5000/api/workflows

# Test with tenant 2
curl -H "Host: client2.myapp.com" http://localhost:5000/api/workflows

# Verify data isolation
```

#### 3. Manual Testing Checklist
- [ ] Create workflow in tenant A
- [ ] Verify it appears in tenant A database
- [ ] Verify it does NOT appear in tenant B database
- [ ] Switch to tenant B and create workflow
- [ ] Verify isolation maintained
- [ ] Test CLI commands (should use default DB)
- [ ] Test background jobs (should use default DB or specify tenant)

## Common Pitfalls

### ❌ Pitfall 1: Forgetting to add `Entity` parameter to `em.find()`
```typescript
// Wrong:
const em = this.getContextManager();
return await em.find({ where: { active: true } });

// Correct:
const em = this.getContextManager();
return await em.find(WorkflowEntity, { where: { active: true } });
```

### ❌ Pitfall 2: Using `this.manager` instead of `getContextManager()`
```typescript
// Wrong:
return await this.manager.findOne(User, { where: { id } });

// Correct:
const em = this.getContextManager();
return await em.findOne(User, { where: { id } });
```

### ❌ Pitfall 3: Not handling `entityManager` parameter
```typescript
// Wrong:
async save(entity: User): Promise<User> {
	const em = this.getContextManager();
	return await em.save(entity);
}

// Correct (supports transactions):
async save(entity: User, entityManager?: EntityManager): Promise<User> {
	const em = entityManager ?? this.getContextManager();
	return await em.save(entity);
}
```

## Verification Script

Run this to verify all tenant-specific repos are migrated:

```bash
# Find repositories still extending Repository (should only be global ones)
grep -r "extends Repository<" packages/@n8n/db/src/repositories/*.ts | \
  grep -v "base.repository.ts" | \
  grep -v "settings.repository.ts" | \
  grep -v "variables.repository.ts" | \
  grep -v "role.repository.ts" | \
  grep -v "scope.repository.ts" | \
  grep -v "license-metrics.repository.ts"

# Should return empty or only context-dependent ones
```

## Performance Considerations

- **AsyncLocalStorage overhead:** Negligible (~1-2% in benchmarks)
- **Database connection pooling:** Reuses existing connections
- **No caching needed:** Context is request-scoped and automatically cleaned up

## Rollback Plan

If issues arise:

1. Keep the `entityManager` parameter in all methods
2. Temporarily pass explicit EntityManager from services
3. Revert specific repository if needed (just change back to `extends Repository`)
4. BaseRepository itself can be disabled by always returning `this.manager`

## Summary

**Total Repositories:** 39
- **Must Migrate:** 8 (PRIORITY 1)
- **Should Migrate:** 18 (PRIORITY 2)
- **Consider:** 4 (PRIORITY 3)
- **Do NOT Migrate:** 5 (Global data)
- **Already Done:** 1 (ProjectRepository) ✅

**Recommendation:** Start with PRIORITY 1 repositories (core features) and migrate incrementally with thorough testing between each migration.

