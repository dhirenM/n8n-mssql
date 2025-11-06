import { ModuleRegistry } from '@n8n/backend-common';
import { DatabaseConfig, InstanceSettingsConfig } from '@n8n/config';
import { Service } from '@n8n/di';
import type { DataSourceOptions, LoggerOptions } from '@n8n/typeorm';
import type { MysqlConnectionOptions } from '@n8n/typeorm/driver/mysql/MysqlConnectionOptions';
import type { PostgresConnectionOptions } from '@n8n/typeorm/driver/postgres/PostgresConnectionOptions';
import type { SqliteConnectionOptions } from '@n8n/typeorm/driver/sqlite/SqliteConnectionOptions';
import type { SqlitePooledConnectionOptions } from '@n8n/typeorm/driver/sqlite-pooled/SqlitePooledConnectionOptions';
import { UserError } from 'n8n-workflow';
import type { TlsOptions } from 'node:tls';
import path from 'path';

import { entities } from '../entities';
import { mssqlMigrations } from '../migrations/mssqldb';
import { mysqlMigrations } from '../migrations/mysqldb';
import { postgresMigrations } from '../migrations/postgresdb';
import { sqliteMigrations } from '../migrations/sqlite';
import { subscribers } from '../subscribers';

// MSSQL Connection Options (since @n8n/typeorm doesn't include SQL Server driver)
// This is a compatible subset that will work with the mssql driver at runtime
export interface MssqlConnectionOptions {
	type: 'mssql';
	server?: string;
	host?: string;
	port?: number;
	database?: string;
	username?: string;
	password?: string;
	schema?: string;
	entityPrefix?: string;
	entities?: any[];
	subscribers?: any[];
	migrations?: any[];
	migrationsTableName?: string;
	migrationsRun?: boolean;
	synchronize?: boolean;
	logging?: LoggerOptions;
	maxQueryExecutionTime?: number;
	pool?: {
		max?: number;
		min?: number;
		idleTimeoutMillis?: number;
	};
	options?: {
		encrypt?: boolean;
		trustServerCertificate?: boolean;
		enableArithAbort?: boolean;
		connectTimeout?: number;
	};
}

@Service()
export class DbConnectionOptions {
	constructor(
		private readonly config: DatabaseConfig,
		private readonly instanceSettingsConfig: InstanceSettingsConfig,
		private readonly moduleRegistry: ModuleRegistry,
	) {}

	getOverrides(dbType: 'postgresdb' | 'mysqldb' | 'mssqldb') {
		const dbConfig = this.config[dbType];
		return {
			database: dbConfig.database,
			host: dbConfig.host,
			port: dbConfig.port,
			username: dbConfig.user,
			password: dbConfig.password,
		};
	}

	getOptions(): DataSourceOptions | MssqlConnectionOptions {
		const { type: dbType } = this.config;
		switch (dbType) {
			case 'sqlite':
				return this.getSqliteConnectionOptions();
			case 'postgresdb':
				return this.getPostgresConnectionOptions();
			case 'mariadb':
			case 'mysqldb':
				return this.getMysqlConnectionOptions(dbType);
			case 'mssqldb':
				return this.getMssqlConnectionOptions();
			default:
				throw new UserError('Database type currently not supported', { extra: { dbType } });
		}
	}

	private getCommonOptions() {
		const { tablePrefix: entityPrefix, logging: loggingConfig } = this.config;

		let loggingOption: LoggerOptions = loggingConfig.enabled;
		if (loggingOption) {
			const optionsString = loggingConfig.options.replace(/\s+/g, '');
			if (optionsString === 'all') {
				loggingOption = optionsString;
			} else {
				loggingOption = optionsString.split(',') as LoggerOptions;
			}
		}

		return {
			entityPrefix,
			entities: [...Object.values(entities), ...this.moduleRegistry.entities],
			subscribers: Object.values(subscribers),
			migrationsTableName: `${entityPrefix}migrations`,
			migrationsRun: false,
			synchronize: false,
			maxQueryExecutionTime: loggingConfig.maxQueryExecutionTime,
			logging: loggingOption,
		};
	}

	private getSqliteConnectionOptions(): SqliteConnectionOptions | SqlitePooledConnectionOptions {
		const { sqlite: sqliteConfig } = this.config;
		const { n8nFolder } = this.instanceSettingsConfig;

		const commonOptions = {
			...this.getCommonOptions(),
			database: path.resolve(n8nFolder, sqliteConfig.database),
			migrations: sqliteMigrations,
		};

		if (sqliteConfig.poolSize > 0) {
			return {
				type: 'sqlite-pooled',
				poolSize: sqliteConfig.poolSize,
				enableWAL: true,
				acquireTimeout: 60_000,
				destroyTimeout: 5_000,
				...commonOptions,
			};
		} else {
			return {
				type: 'sqlite',
				enableWAL: sqliteConfig.enableWAL,
				...commonOptions,
			};
		}
	}

	private getPostgresConnectionOptions(): PostgresConnectionOptions {
		const { postgresdb: postgresConfig } = this.config;
		const {
			ssl: { ca: sslCa, cert: sslCert, key: sslKey, rejectUnauthorized: sslRejectUnauthorized },
		} = postgresConfig;

		let ssl: TlsOptions | boolean = postgresConfig.ssl.enabled;
		if (sslCa !== '' || sslCert !== '' || sslKey !== '' || !sslRejectUnauthorized) {
			ssl = {
				ca: sslCa || undefined,
				cert: sslCert || undefined,
				key: sslKey || undefined,
				rejectUnauthorized: sslRejectUnauthorized,
			};
		}

		return {
			type: 'postgres',
			...this.getCommonOptions(),
			...this.getOverrides('postgresdb'),
			schema: postgresConfig.schema,
			poolSize: postgresConfig.poolSize,
			migrations: postgresMigrations,
			connectTimeoutMS: postgresConfig.connectionTimeoutMs,
			ssl,
			extra: {
				idleTimeoutMillis: postgresConfig.idleTimeoutMs,
			},
		};
	}

	private getMysqlConnectionOptions(dbType: 'mariadb' | 'mysqldb'): MysqlConnectionOptions {
		const { mysqldb: mysqlConfig } = this.config;
		return {
			type: dbType === 'mysqldb' ? 'mysql' : 'mariadb',
			...this.getCommonOptions(),
			...this.getOverrides('mysqldb'),
			poolSize: mysqlConfig.poolSize,
			migrations: mysqlMigrations,
			timezone: 'Z', // set UTC as default
		};
	}

	private getMssqlConnectionOptions(): MssqlConnectionOptions {
		const { mssqldb: mssqlConfig } = this.config;
		const commonOptions = this.getCommonOptions();
		
		// MSSQL connection - based on Flowise implementation
		// NOTE: Base schema must be created manually via n8n_schema_idempotent.sql
		// Migrations are disabled because schema is created manually
		return {
			type: 'mssql',
			host: mssqlConfig.host,
			port: mssqlConfig.port,
			database: mssqlConfig.database,
			username: mssqlConfig.user,
			password: mssqlConfig.password,
			schema: mssqlConfig.schema,
			entityPrefix: commonOptions.entityPrefix,
			entities: commonOptions.entities,
			subscribers: commonOptions.subscribers,
			migrationsTableName: commonOptions.migrationsTableName,
			migrationsRun: false,  // Disabled - schema created manually
			synchronize: false,
			maxQueryExecutionTime: commonOptions.maxQueryExecutionTime,
			logging: commonOptions.logging,
			pool: {
				max: mssqlConfig.poolSize,
			},
			migrations: [], // Empty - schema created manually
			options: {
				encrypt: mssqlConfig.encrypt,
				trustServerCertificate: mssqlConfig.trustServerCertificate,
				enableArithAbort: true,
				connectTimeout: mssqlConfig.connectionTimeoutMs,
			},
		};
	}
}
