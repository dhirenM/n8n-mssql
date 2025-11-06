import { GlobalConfig } from '@n8n/config';
import { Container } from '@n8n/di';
import type { ColumnOptions } from '@n8n/typeorm';
import {
	BeforeInsert,
	BeforeUpdate,
	Column,
	CreateDateColumn,
	PrimaryColumn,
	UpdateDateColumn,
} from '@n8n/typeorm';
import type { Class } from 'n8n-core';

import { generateNanoId } from '../utils/generators';

export const { type: dbType } = Container.get(GlobalConfig).database;

const timestampSyntax = {
	sqlite: "STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')",
	postgresdb: 'CURRENT_TIMESTAMP(3)',
	mysqldb: 'CURRENT_TIMESTAMP(3)',
	mariadb: 'CURRENT_TIMESTAMP(3)',
	mssqldb: 'CURRENT_TIMESTAMP',
}[dbType];

export const jsonColumnType = (dbType === 'sqlite' || dbType === 'mssqldb') ? 'simple-json' : 'json';
export const datetimeColumnType = dbType === 'postgresdb' ? 'timestamptz' : 'datetime';

export function JsonColumn(options?: Omit<ColumnOptions, 'type'>) {
	return Column({
		...options,
		type: jsonColumnType,
	});
}

export function DateTimeColumn(options?: Omit<ColumnOptions, 'type'>) {
	return Column({
		...options,
		type: datetimeColumnType,
	});
}

// For MSSQL, we use 'datetime' type which TypeORM will convert to 'datetime2' in the actual SQL
const tsColumnOptions: ColumnOptions = {
	precision: 3,
	default: () => timestampSyntax,
	type: datetimeColumnType,
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mixinStringId<T extends Class<{}, any[]>>(base: T) {
	class Derived extends base {
		@PrimaryColumn('varchar')
		id: string;

		@BeforeInsert()
		generateId() {
			if (!this.id) {
				this.id = generateNanoId();
			}
		}
	}
	return Derived;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mixinUpdatedAt<T extends Class<{}, any[]>>(base: T) {
	class Derived extends base {
		@UpdateDateColumn(tsColumnOptions)
		updatedAt: Date;

		@BeforeUpdate()
		setUpdateDate(): void {
			this.updatedAt = new Date();
		}
	}
	return Derived;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mixinCreatedAt<T extends Class<{}, any[]>>(base: T) {
	class Derived extends base {
		@CreateDateColumn(tsColumnOptions)
		createdAt: Date;
	}
	return Derived;
}

class BaseEntity {}

export const WithStringId = mixinStringId(BaseEntity);
export const WithCreatedAt = mixinCreatedAt(BaseEntity);
export const WithUpdatedAt = mixinUpdatedAt(BaseEntity);
export const WithTimestamps = mixinCreatedAt(mixinUpdatedAt(BaseEntity));
export const WithTimestampsAndStringId = mixinStringId(WithTimestamps);
