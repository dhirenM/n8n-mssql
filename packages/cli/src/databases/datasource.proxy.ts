/**
 * DataSource Container Proxy
 * 
 * This is the KEY to multi-tenant support without refactoring all n8n services!
 * 
 * How it works:
 * 1. Intercepts Container.get(DataSource) calls
 * 2. Returns request-specific Voyager DataSource if in request context
 * 3. Falls back to default DataSource for non-request contexts (migrations, CLI, etc.)
 * 
 * This allows existing n8n code to work without changes:
 *   const dataSource = Container.get(DataSource);  // ← Still works!
 *   // But now returns the RIGHT database for the current subdomain!
 */

import { Container } from '@n8n/di';
import { DataSource } from '@n8n/typeorm';
import { getRequestDataSource } from '@/middlewares/requestContext';
import { Logger } from '@n8n/backend-common';

// Store original Container.get method
const originalContainerGet = Container.get.bind(Container);

// Track if proxy is installed
let proxyInstalled = false;

/**
 * Install the DataSource proxy
 * Call this during n8n startup AFTER initializing databases
 */
export function installDataSourceProxy() {
  if (proxyInstalled) {
    return;
  }
  
  const logger = Container.get(Logger);
  logger.info('Installing multi-tenant DataSource proxy...');
  
  // Override Container.get to intercept DataSource requests
  (Container as any).get = function<T>(serviceIdentifier: any): T {
    // Only intercept DataSource requests
    if (serviceIdentifier === DataSource || serviceIdentifier.name === 'DataSource') {
      try {
        // Try to get request-specific DataSource (multi-tenant)
        const requestDataSource = getRequestDataSource();
        
        if (requestDataSource) {
          logger.debug('Using request-specific Voyager DataSource');
          return requestDataSource as T;
        }
      } catch (error) {
        // No request context - fall back to default
        logger.debug('No request context - using default DataSource');
      }
    }
    
    // For all other services or when no request context, use original
    return originalContainerGet(serviceIdentifier);
  };
  
  proxyInstalled = true;
  logger.info('✅ Multi-tenant DataSource proxy installed');
}

/**
 * Uninstall the proxy (for testing)
 */
export function uninstallDataSourceProxy() {
  if (!proxyInstalled) {
    return;
  }
  
  (Container as any).get = originalContainerGet;
  proxyInstalled = false;
  
  const logger = Container.get(Logger);
  logger.info('DataSource proxy uninstalled');
}

/**
 * Check if proxy is installed
 */
export function isProxyInstalled(): boolean {
  return proxyInstalled;
}

