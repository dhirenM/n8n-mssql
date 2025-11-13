/**
 * Request Context Middleware
 * 
 * Uses AsyncLocalStorage to store per-request data throughout the entire request lifecycle.
 * This allows accessing request-specific data (like DataSource, subdomain, user) from anywhere
 * in the code without passing it through every function.
 * 
 * Usage:
 *   const dataSource = getRequestDataSource();
 *   const subdomain = getSubdomain();
 */

import { AsyncLocalStorage } from 'async_hooks';
import type { Request, Response, NextFunction } from 'express';
import type { DataSource } from '@n8n/typeorm';
import type { User } from '@n8n/db';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

/**
 * Expose AsyncLocalStorage globally for BaseRepository access
 * This allows repositories to access request context without circular dependencies
 */
(globalThis as any).__requestContext = asyncLocalStorage;

/**
 * Middleware to initialize request context
 * Must be registered early in the middleware chain
 */
export const requestContextMiddleware = (req: any, res: Response, next: NextFunction) => {
  const store = new Map<string, any>();
  store.set('request', req);
  
  asyncLocalStorage.run(store, () => {
    next();
  });
};

/**
 * Get the current request context store
 */
export const getContext = (): Map<string, any> | undefined => {
  return asyncLocalStorage.getStore();
};

/**
 * Get the current request object
 */
export const getRequest = (): Request | undefined => {
  const store = asyncLocalStorage.getStore();
  return store?.get('request');
};

/**
 * Get the Voyager DataSource for the current request
 * This is the multi-tenant database connection specific to the subdomain
 */
export const getRequestDataSource = (): DataSource => {
  const store = asyncLocalStorage.getStore();
  const dataSource = store?.get('request')?.dataSource;
  
  if (!dataSource) {
    throw new Error('No DataSource found in request context. Is subdomain validation middleware configured?');
  }
  
  return dataSource as DataSource;
};

/**
 * Get the subdomain for the current request
 */
export const getSubdomain = (): string | undefined => {
  const store = asyncLocalStorage.getStore();
  return store?.get('request')?.subdomain;
};

/**
 * Get the authenticated user for the current request
 */
export const getUser = (): User | undefined => {
  const store = asyncLocalStorage.getStore();
  return store?.get('request')?.user;
};

/**
 * Get the .NET JWT payload for the current request
 */
export const getDotNetJwtPayload = (): any | undefined => {
  const store = asyncLocalStorage.getStore();
  return store?.get('request')?.dotnetJwtPayload;
};

/**
 * Set a value in the request context
 */
export const setContextValue = (key: string, value: any): void => {
  const store = asyncLocalStorage.getStore();
  if (store) {
    store.set(key, value);
  }
};

/**
 * Get a value from the request context
 */
export const getContextValue = <T = any>(key: string): T | undefined => {
  const store = asyncLocalStorage.getStore();
  return store?.get(key);
};

