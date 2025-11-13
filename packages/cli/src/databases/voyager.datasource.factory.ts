/**
 * Voyager Database DataSource Factory
 * 
 * Creates and caches dynamic DataSource connections per subdomain.
 * Each subdomain has its own Voyager database with n8n schema.
 * 
 * Uses Flowise-style database credential lookup:
 * - Supports header-based database selection (Database header)
 * - Supports encrypted credentials (DecryptByPassphrase)
 * - Queries voyagerdb, voyagerdbcred, and company tables
 * - Falls back to subdomain-based lookup if headers not provided
 * 
 * Flow:
 * 1. Request arrives for subdomain (e.g., "client1")
 * 2. Extract database name from headers/cookies/query params (or use subdomain)
 * 3. Query Elevate DB for Voyager credentials (with decryption)
 * 4. Create/get cached DataSource for that Voyager DB
 * 5. Return DataSource for use in request
 */

import { DataSource } from '@n8n/typeorm';
import { Logger } from '@n8n/backend-common';
import { Container } from '@n8n/di';
import { entities } from '@n8n/db';
import { getElevateDataSource } from './elevate.datasource';

interface VoyagerDbConfig {
  server: string;
  database: string;
  username: string;
  password: string;
  inactive: boolean;
}

export class VoyagerDataSourceFactory {
  // Cache DataSources per subdomain to avoid recreating connections
  private static cache = new Map<string, DataSource>();
  
  /**
   * Get or create Voyager DataSource for a subdomain
   * 
   * @param subdomain - The company subdomain (e.g., "client1")
   * @param req - Express request object (optional, for header-based lookup)
   * @returns DataSource configured for that company's Voyager database
   */
  static async getDataSourceForSubdomain(subdomain: string, req?: any): Promise<DataSource> {
    const logger = Container.get(Logger);
    
    // Check cache first
    const cached = this.cache.get(subdomain);
    if (cached?.isInitialized) {
      logger.debug(`Using cached Voyager DataSource for: ${subdomain}`);
      return cached;
    }
    
    logger.info(`Creating new Voyager DataSource for subdomain: ${subdomain}`);
    
    // Get Voyager DB config from Elevate DB
    const config = await this.getVoyagerConfig(subdomain, req);
    
    // Create new DataSource for this Voyager DB
    const dataSource = new DataSource({
      type: 'mssql' as any,  // TypeScript doesn't know about mssql yet (added via patch)
      host: config.server,
      port: 1433,
      database: config.database,
      username: config.username,
      password: config.password,
      schema: 'n8n',  // Always use n8n schema (flowise uses flowise schema)
      
      // Use all n8n entities
      entities: Object.values(entities),
      
      // n8n configuration
      synchronize: false,
      migrationsRun: false,
      logging: process.env.DB_LOGGING_ENABLED === 'true',
      maxQueryExecutionTime: parseInt(process.env.DB_LOGGING_MAX_EXECUTION_TIME || '0'),
      
      options: {
        encrypt: process.env.DB_MSSQLDB_ENCRYPT === 'true',
        trustServerCertificate: process.env.DB_MSSQLDB_TRUST_SERVER_CERTIFICATE === 'true',
        enableArithAbort: true,
        connectTimeout: parseInt(process.env.DB_MSSQLDB_CONNECTION_TIMEOUT || '20000')
      },
      
      pool: {
        max: parseInt(process.env.DB_MSSQLDB_POOL_SIZE || '10')
      }
    } as any);
    
    try {
      // Initialize connection
      await dataSource.initialize();
      
      // Cache it for future requests
      this.cache.set(subdomain, dataSource);
      
      logger.info(`✅ Voyager DataSource initialized successfully`);
      logger.info(`   Subdomain: ${subdomain}`);
      logger.info(`   Server: ${config.server}`);
      logger.info(`   Database: ${config.database}`);
      logger.info(`   Schema: n8n`);
      
      return dataSource;
      
    } catch (error) {
      logger.error(`❌ Failed to initialize Voyager DataSource for ${subdomain}`, error);
      throw new Error(`Failed to connect to Voyager database for subdomain: ${subdomain}`);
    }
  }
  
  /**
   * Query Elevate DB for Voyager database credentials
   * Similar to Flowise DataSource pattern - uses header parameters for Role and Database
   * 
   * @param subdomain - Company subdomain
   * @param req - Express request object (optional, for header-based lookup)
   * @returns Voyager DB configuration
   */
  private static async getVoyagerConfig(subdomain: string, req?: any): Promise<VoyagerDbConfig> {
    const elevateDb = getElevateDataSource();
    const logger = Container.get(Logger);
    
    // Get database name from headers, cookies, or query parameters (Flowise pattern)
    let databaseName: string | undefined;
    let databaseGUID: string | undefined;
    
    if (req) {
      // Try to get from headers first
      databaseName = req.headers?.['database'] || req.headers?.['Database'];
      
      // Try to get from cookies (if cookie parser is available)
      if (!databaseName && req.cookies?.database) {
        databaseName = req.cookies.database;
      }
      
      // Try to get from query parameters
      if (!databaseName && req.query?.DatabaseGUID) {
        databaseGUID = req.query.DatabaseGUID;
      }
      
      logger.debug(`Database lookup params - Name: ${databaseName}, GUID: ${databaseGUID}`);
    }
    
    // If no database specified in request, use environment variable or subdomain-based lookup
    if (!databaseName && !databaseGUID) {
      databaseName = process.env.DEFAULT_DATABASE;
      
      // Fallback to subdomain-based lookup from company table
      if (!databaseName) {
        logger.debug(`Using subdomain-based lookup for: ${subdomain}`);
        return await this.getVoyagerConfigBySubdomain(subdomain);
      }
    }
    
    // Get passphrase for decryption (required for encrypted credentials)
    const passphrase = process.env.ELEVATE_PASSPHRASE;
    if (!passphrase) {
      logger.warn('ELEVATE_PASSPHRASE not set, falling back to subdomain lookup');
      return await this.getVoyagerConfigBySubdomain(subdomain);
    }
    
    logger.debug(`Querying Elevate DB with Flowise pattern - Database: ${databaseName || databaseGUID}`);
    
    try {
      // Use same SQL query pattern as Flowise DataSource
      const query = `SELECT TOP 1 
                        db.instance, 
                        db.[database],
                        CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[user]) AS VARCHAR(100)) AS [user],
                        CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[pass]) AS VARCHAR(100)) AS pass,
                        c.domain,
                        ISNULL(c.inactive, 0) as inactive
                      FROM voyagerdb db
                      JOIN voyagerdbcred cred ON cred.voyagerdbid = db.id
                      JOIN company c ON c.id = db.companyid
                      WHERE ${databaseGUID ? 'db.[guid] = @1' : 'db.[name] = @1'}`;
      
      const result = await elevateDb.query(query, [passphrase, databaseName || databaseGUID]);
      
      if (!result || result.length === 0) {
        logger.warn(`No database configuration found for: ${databaseName || databaseGUID}`);
        throw new Error(`No database configuration found for database: ${databaseName || databaseGUID}`);
      }
      
      const dbConfig = result[0];
      
      if (dbConfig.inactive) {
        logger.warn(`Company is inactive for database: ${databaseName || databaseGUID}`);
        throw new Error(`Company inactive for database: ${databaseName || databaseGUID}`);
      }
      
      logger.debug(`Found Voyager config using Flowise pattern:`, {
        instance: dbConfig.instance,
        database: dbConfig.database,
        user: dbConfig.user,
        domain: dbConfig.domain
      });
      
      return {
        server: dbConfig.instance,
        database: dbConfig.database,
        username: dbConfig.user,
        password: dbConfig.pass,
        inactive: dbConfig.inactive
      };
      
    } catch (error) {
      logger.error(`Error querying Elevate DB with Flowise pattern:`, error);
      throw error;
    }
  }
  
  /**
   * Fallback method: Query using subdomain (same pattern as Flowise)
   * Used when header-based lookup is not available
   * 
   * @param subdomain - Company subdomain
   * @returns Voyager DB configuration
   */
  private static async getVoyagerConfigBySubdomain(subdomain: string): Promise<VoyagerDbConfig> {
    const elevateDb = getElevateDataSource();
    const logger = Container.get(Logger);
    
    // Get passphrase for decryption (required for encrypted credentials)
    const passphrase = process.env.ELEVATE_PASSPHRASE;
    if (!passphrase) {
      logger.error('ELEVATE_PASSPHRASE environment variable is not set');
      throw new Error('ELEVATE_PASSPHRASE environment variable is not set');
    }
    
    logger.debug(`Using subdomain-based lookup with Flowise pattern for: ${subdomain}`);
    
    try {
      // Use same query pattern as Flowise - lookup by company domain
      // First get the company to find the default database
      const companyResult = await elevateDb.query(
        `SELECT TOP 1 c.id, c.[guid], c.domain, ISNULL(c.inactive, 0) as inactive
         FROM company c
         WHERE c.domain = @0`,
        [subdomain]
      );
      
      if (!companyResult || companyResult.length === 0) {
        logger.warn(`Company not found for subdomain: ${subdomain}`);
        throw new Error(`Company not found for subdomain: ${subdomain}`);
      }
      
      const company = companyResult[0];
      
      if (company.inactive) {
        logger.warn(`Company is inactive: ${subdomain}`);
        throw new Error(`Company inactive for subdomain: ${subdomain}`);
      }
      
      // Now get the voyager database for this company (same pattern as Flowise)
      const query = `SELECT TOP 1 
                        db.instance, 
                        db.[database],
                        CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[user]) AS VARCHAR(100)) AS [user],
                        CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[pass]) AS VARCHAR(100)) AS pass,
                        c.domain,
                        ISNULL(c.inactive, 0) as inactive
                      FROM voyagerdb db
                      JOIN voyagerdbcred cred ON cred.voyagerdbid = db.id
                      JOIN company c ON c.id = db.companyid
                      WHERE c.domain = @1`;
      
      const result = await elevateDb.query(query, [passphrase, subdomain]);
      
      if (!result || result.length === 0) {
        logger.warn(`No database configuration found for subdomain: ${subdomain}`);
        throw new Error(`No database configuration found for subdomain: ${subdomain}`);
      }
      
      const dbConfig = result[0];
      
      logger.debug(`Found Voyager config for ${subdomain} using Flowise pattern:`, {
        instance: dbConfig.instance,
        database: dbConfig.database,
        user: dbConfig.user,
        domain: dbConfig.domain
      });
      
      return {
        server: dbConfig.instance,
        database: dbConfig.database,
        username: dbConfig.user,
        password: dbConfig.pass,
        inactive: dbConfig.inactive
      };
      
    } catch (error) {
      logger.error(`Error querying Elevate DB for subdomain: ${subdomain}`, error);
      throw error;
    }
  }
  
  /**
   * Clear cached DataSource (for testing or company updates)
   * 
   * @param subdomain - Optional specific subdomain to clear, or clear all if undefined
   */
  static async clearCache(subdomain?: string): Promise<void> {
    const logger = Container.get(Logger);
    
    if (subdomain) {
      const ds = this.cache.get(subdomain);
      if (ds?.isInitialized) {
        await ds.destroy();
        logger.info(`Cleared Voyager DataSource cache for: ${subdomain}`);
      }
      this.cache.delete(subdomain);
    } else {
      // Clear all cached DataSources
      logger.info(`Clearing all Voyager DataSource cache (${this.cache.size} connections)`);
      
      for (const [, ds] of this.cache.entries()) {
        if (ds?.isInitialized) {
          await ds.destroy();
        }
      }
      this.cache.clear();
      
      logger.info('✅ All Voyager DataSource cache cleared');
    }
  }
  
  /**
   * Get all cached subdomains
   */
  static getCachedSubdomains(): string[] {
    return Array.from(this.cache.keys());
  }
  
  /**
   * Get cache statistics
   */
  static getCacheStats() {
    return {
      size: this.cache.size,
      subdomains: this.getCachedSubdomains()
    };
  }
}

