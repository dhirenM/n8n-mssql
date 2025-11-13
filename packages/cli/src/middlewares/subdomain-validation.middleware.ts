/**
 * Subdomain Validation Middleware
 * 
 * Extracts subdomain from hostname, queries Elevate DB for company,
 * and gets the appropriate Voyager DataSource for that company.
 * 
 * Flow:
 * 1. Extract subdomain from hostname (e.g., client1.domain.com → "client1")
 * 2. Query Elevate DB: SELECT * FROM company WHERE domain = 'client1'
 * 3. Get Voyager DB credentials from company record
 * 4. Create/get DataSource for that Voyager DB
 * 5. Store in req.dataSource for use by n8n
 */

import type { Request, Response, NextFunction } from 'express';
import { Logger } from '@n8n/backend-common';
import { Container } from '@n8n/di';
import { VoyagerDataSourceFactory } from '@/databases/voyager.datasource.factory';
import type { DataSource } from '@n8n/typeorm';

export const subdomainValidationMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const logger = Container.get(Logger);
  
  try {
    // Skip validation for asset URLs, static content, and public endpoints
    // Note: These paths work regardless of N8N_PATH base path
    if (
      req.url.includes('/assets/') ||
      req.url.includes('/static/') ||
      req.url.includes('/node-icon/') ||
      req.url.includes('/types/') ||
      req.url.includes('/favicon.ico') ||
      req.url.includes('/rest/settings') ||     // Public settings endpoint
      req.url.includes('/rest/push') ||         // Push/WebSocket endpoint (handled by push auth)
      req.headers.upgrade === 'websocket' ||    // WebSocket upgrade requests
      (req.url.includes('/rest/login') && req.method === 'POST') || // Username/password login (POST only)
      req.url.includes('/rest/oauth') ||        // OAuth endpoints
      req.url.includes('/rest/forgot-password') || // Password reset
      req.url.includes('/rest/resolve-signup-token') || // Signup
      req.url.includes('/healthz') ||           // Health check
      req.url.includes('/metrics') ||           // Metrics endpoint
      req.dataSource  // Already validated
    ) {
      return next();
    }
    
    // Get hostname - check X-Forwarded-Host first (from nginx/proxy)
    const forwardedHost = req.get('x-forwarded-host');
    const host = forwardedHost || req.hostname || req.get('host') || '';
    logger.info(`[SubdomainValidation] 🔍 Validating host: ${host} (forwarded: ${forwardedHost}, path: ${req.path})`);
    
    // Handle localhost (development mode)
    if (host.includes('localhost') || host.includes('127.0.0.1')) {
      logger.debug('Localhost detected - using default subdomain');
      const defaultSubdomain = process.env.DEFAULT_SUBDOMAIN || 'pmgroup';
      
      try {
        const dataSource = await VoyagerDataSourceFactory.getDataSourceForSubdomain(defaultSubdomain);
        
        (req as any).subdomain = defaultSubdomain;
        (req as any).dataSource = dataSource;
        
        logger.debug(`Using default subdomain: ${defaultSubdomain}`);
        return next();
      } catch (error) {
        logger.error(`Failed to get DataSource for default subdomain: ${defaultSubdomain}`, error);
        return res.status(500).json({
          error: 'Configuration Error',
          message: 'Failed to connect to default database.'
        });
      }
    }
    requestContextMiddleware
    // Extract subdomain from hostname
    // Format: subdomain.domain.com or subdomain.domain.com:port
    const parts = host.split(':')[0].split('.');  // Remove port if present
    const subdomain = parts[0];
    
    logger.info(`[SubdomainValidation] 🎯 Extracted subdomain: "${subdomain}" from host: "${host}"`);
    
    // Get Voyager DataSource for this subdomain
    try {
      const dataSource = await VoyagerDataSourceFactory.getDataSourceForSubdomain(subdomain);
      
      // Store in request for later use
      (req as any).subdomain = subdomain;
      (req as any).dataSource = dataSource;
      
      const dbName = (dataSource.options as any).database;
      logger.info(`[SubdomainValidation] ✅ DataSource ready - subdomain: "${subdomain}", database: "${dbName}"`);
      
      next();
      
    } catch (error: any) {
      logger.error(`Failed to get Voyager DataSource for subdomain: ${subdomain}`, error);
      
      // Check error type and return appropriate response
      if (error.message.includes('not found')) {
        return res.status(403).json({
          error: 'Invalid Subdomain',
          message: 'Access denied. Invalid company domain.'
        });
      }
      
      if (error.message.includes('inactive')) {
        return res.status(403).json({
          error: 'Company Inactive',
          message: 'Access denied. Company account is inactive.'
        });
      }
      
      return res.status(500).json({
        error: 'Database Connection Error',
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

// Extend Express Request type to include subdomain and dataSource
declare global {
  namespace Express {
    interface Request {
      subdomain?: string;
      dataSource?: DataSource;
      dotnetJwtPayload?: any;
    }
  }
}

