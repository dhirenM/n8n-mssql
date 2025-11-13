/**
 * Base Repository for Multitenant Support
 * 
 * Provides automatic tenant-aware database routing using AsyncLocalStorage.
 * All repositories extending this base will automatically use the correct
 * tenant database based on the request context.
 * 
 * Architecture:
 * 1. Subdomain middleware validates tenant and sets req.dataSource
 * 2. RequestContext middleware stores DataSource in AsyncLocalStorage
 * 3. BaseRepository.getContextManager() retrieves tenant-specific manager
 * 4. Automatic fallback to default manager for non-request contexts
 * 
 * Features:
 * - Zero-config multitenant support - just extend BaseRepository
 * - Safe fallback for background jobs, CLI commands, cron tasks
 * - Validates DataSource initialization before use
 * - Type-safe EntityManager access
 * - Debug helpers for troubleshooting
 * 
 * Usage Example:
 * ```typescript
 * @Service()
 * export class MyRepository extends BaseRepository<MyEntity> {
 *   constructor(dataSource: DataSource) {
 *     super(MyEntity, dataSource);
 *   }
 * 
 *   async findByCustomLogic(id: string) {
 *     // Automatically uses tenant-specific database!
 *     const em = this.getContextManager();
 *     return await em.findOne(MyEntity, { where: { id } });
 *   }
 * 
 *   // For methods that already accept entityManager parameter
 *   async findWithOptionalEM(id: string, entityManager?: EntityManager) {
 *     const em = entityManager ?? this.getContextManager();
 *     return await em.findOne(MyEntity, { where: { id } });
 *   }
 * }
 * ```
 * 
 * Migration from Standard Repository:
 * 1. Change: `extends Repository<Entity>` → `extends BaseRepository<Entity>`
 * 2. Update constructor to call: `super(EntityClass, dataSource)`
 * 3. Replace: `this.manager` → `this.getContextManager()`
 * 4. Keep entityManager parameters for transactional support
 * 
 * @see RequestContextService for context management
 */

import type { DataSource, EntityManager, EntityTarget, ObjectLiteral } from '@n8n/typeorm';
import { Repository } from '@n8n/typeorm';

export abstract class BaseRepository<Entity extends ObjectLiteral> extends Repository<Entity> {
	protected defaultDataSource: DataSource;

	constructor(entity: EntityTarget<Entity>, dataSource: DataSource) {
		super(entity, dataSource.manager);
		this.defaultDataSource = dataSource;
	}

	/**
	 * Get the appropriate EntityManager for the current request context.
	 * 
	 * Behavior:
	 * - In HTTP request context: Returns tenant-specific manager
	 * - In background/CLI context: Returns default manager
	 * - Validates DataSource is initialized before returning
	 * - Never returns null/undefined - always returns a valid manager
	 * 
	 * This method should be used instead of `this.manager` in all repository methods
	 * to ensure correct database routing in multitenant environments.
	 * 
	 * Performance: O(1) lookup via AsyncLocalStorage (native Node.js)
	 * 
	 * @returns EntityManager for the current tenant or default
	 * @throws Never throws - always falls back to default manager
	 */
	protected getContextManager(): EntityManager {
		try {
			// Try to get tenant-specific DataSource from AsyncLocalStorage
			// The requestContext middleware stores the entire request object in AsyncLocalStorage
			const requestContext = (globalThis as any).__requestContext;
			if (!requestContext) {
				// AsyncLocalStorage not available (should not happen in production)
				console.log('[BaseRepository] ⚠️ No requestContext found, using default DB');
				return this.manager;
			}

			const store = requestContext.getStore?.();
			if (!store) {
				// Not in request context (background job, CLI, etc.)
				console.log('[BaseRepository] ⚠️ No store found (not in request context), using default DB');
				return this.manager;
			}

			// Get the request object from store
			const request = store.get?.('request');
			if (!request) {
				console.log('[BaseRepository] ⚠️ No request found in store, using default DB');
				return this.manager;
			}

			const contextDataSource = request.dataSource as DataSource | undefined;
			if (!contextDataSource) {
				// Request context exists but no DataSource set
				// This can happen for public routes or routes that skip subdomain middleware
				console.log('[BaseRepository] ⚠️ No dataSource in request, using default DB', {
					subdomain: request.subdomain,
					path: request.path,
				});
				return this.manager;
			}

			// Validate DataSource is initialized
			if (!contextDataSource.isInitialized) {
				console.warn(`[BaseRepository] ⚠️ DataSource for subdomain "${request.subdomain}" is not initialized, falling back to default`);
				return this.manager;
			}

			// Return tenant-specific manager
			const dbName = (contextDataSource.options as any).database;
			console.log(`[BaseRepository] ✅ Using tenant DB: ${dbName} (subdomain: ${request.subdomain})`);
			return contextDataSource.manager;

		} catch (error) {
			// If anything goes wrong, fall back to default manager
			// This ensures the application continues to work even if context retrieval fails
			console.error('[BaseRepository] ❌ Error getting context manager, falling back to default:', error);
			return this.manager;
		}
	}

	/**
	 * Check if we're currently executing in a tenant-specific context.
	 * 
	 * A tenant context exists when:
	 * - We're in an HTTP request context
	 * - The request has a valid tenant DataSource
	 * - The DataSource is initialized
	 * 
	 * Use this for:
	 * - Conditional logic based on tenant vs default database
	 * - Debugging and logging
	 * - Validation checks
	 * 
	 * @returns true if in tenant context, false if using default database
	 */
	protected isInTenantContext(): boolean {
		try {
			const requestContext = (globalThis as any).__requestContext;
			if (!requestContext) return false;

			const store = requestContext.getStore?.();
			if (!store) return false;

			const request = store.get?.('request');
			if (!request) return false;

			const contextDataSource = request.dataSource as DataSource | undefined;
			return !!contextDataSource && contextDataSource.isInitialized;
		} catch {
			return false;
		}
	}

	/**
	 * Get the current tenant subdomain from request context.
	 * 
	 * Returns:
	 * - Subdomain string if in tenant context
	 * - undefined if in default context
	 * 
	 * Useful for:
	 * - Logging tenant-specific operations
	 * - Error messages with tenant information
	 * - Debugging multitenant issues
	 * 
	 * @returns Current subdomain or undefined
	 */
	protected getCurrentSubdomain(): string | undefined {
		try {
			const requestContext = (globalThis as any).__requestContext;
			if (!requestContext) return undefined;

			const store = requestContext.getStore?.();
			if (!store) return undefined;

			const request = store.get?.('request');
			return request?.subdomain;
		} catch {
			return undefined;
		}
	}

	/**
	 * Get debug information about the current repository context.
	 * Useful for troubleshooting multitenant database routing issues.
	 * 
	 * @returns Debug information object
	 */
	protected getContextDebugInfo() {
		const subdomain = this.getCurrentSubdomain();
		const isInTenantContext = this.isInTenantContext();
		const hasRequestContext = !!(globalThis as any).__requestContext?.getStore?.();
		
		return {
			subdomain,
			isInTenantContext,
			hasRequestContext,
			defaultDatabase: this.defaultDataSource.options.database,
			entityName: this.metadata.name,
		};
	}
}

