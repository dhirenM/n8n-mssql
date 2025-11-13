/**
 * Elevate Database Connection (Singleton)
 * 
 * This is the central multi-tenant database that stores:
 * - Company information
 * - Voyager database credentials per subdomain
 * 
 * Initialized ONCE at n8n startup.
 */

import { DataSource } from '@n8n/typeorm';
import { Logger } from '@n8n/backend-common';
import { Container } from '@n8n/di';

let elevateDataSource: DataSource | null = null;

export async function initializeElevateDataSource(): Promise<DataSource> {
  if (elevateDataSource?.isInitialized) {
    const logger = Container.get(Logger);
    logger.debug('Elevate DataSource already initialized');
    return elevateDataSource;
  }
  
  const logger = Container.get(Logger);
  logger.info('Initializing Elevate DataSource...');
  
  elevateDataSource = new DataSource({
    type: 'mssql',
    host: process.env.ELEVATE_DB_HOST || '10.242.1.65\\SQL2K19',
    port: parseInt(process.env.ELEVATE_DB_PORT || '1433'),
    database: process.env.ELEVATE_DB_NAME || 'elevate_multitenant_mssql_dev',
    username: process.env.ELEVATE_DB_USER || 'elevate_multitenant_mssql_dev',
    password: process.env.ELEVATE_DB_PASSWORD || 'q9Q68cKQdBFIzC',
    schema: 'dbo',
    
    // No entities - we only run raw SQL queries
    entities: [],
    synchronize: false,
    logging: process.env.DB_LOGGING_ENABLED === 'true',
    
    options: {
      encrypt: process.env.ELEVATE_DB_ENCRYPT === 'true',
      trustServerCertificate: process.env.ELEVATE_DB_TRUST_CERT === 'true',
      enableArithAbort: true,
      connectTimeout: parseInt(process.env.ELEVATE_DB_CONNECTION_TIMEOUT || '20000')
    },
    
    pool: {
      max: parseInt(process.env.ELEVATE_DB_POOL_SIZE || '5')
    }
  } as any);  // Cast entire config - MSSQL support added via typeorm patch
  
  try {
    await elevateDataSource.initialize();
    logger.info('✅ Elevate DataSource initialized successfully');
    logger.info(`   Server: ${process.env.ELEVATE_DB_HOST}`);
    logger.info(`   Database: ${process.env.ELEVATE_DB_NAME}`);
  } catch (error) {
    logger.error('❌ Failed to initialize Elevate DataSource', error);
    throw error;
  }
  
  return elevateDataSource;
}

export function getElevateDataSource(): DataSource {
  if (!elevateDataSource || !elevateDataSource.isInitialized) {
    throw new Error('Elevate DataSource not initialized. Call initializeElevateDataSource() first.');
  }
  return elevateDataSource;
}

export async function closeElevateDataSource(): Promise<void> {
  if (elevateDataSource?.isInitialized) {
    await elevateDataSource.destroy();
    elevateDataSource = null;
  }
}

