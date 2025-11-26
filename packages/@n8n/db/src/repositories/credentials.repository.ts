import { GlobalConfig } from '@n8n/config';
import { Container } from '@n8n/di';
import { Service } from '@n8n/di';
import { DataSource, In, Like } from '@n8n/typeorm';
import type { FindManyOptions } from '@n8n/typeorm';

import { CredentialsEntity } from '../entities';
import type { User } from '../entities';
import type { ListQuery } from '../entities/types-db';
import { BaseRepository } from './base.repository';

@Service()
export class CredentialsRepository extends BaseRepository<CredentialsEntity> {
	constructor(dataSource: DataSource) {
		super(CredentialsEntity, dataSource);
	}

	/**
	 * Override update to handle nvarchar(MAX) correctly for SQL Server
	 * TypeORM may not properly handle nvarchar(MAX) parameters, so we use raw SQL for SQL Server
	 * when updating the data field to ensure the full encrypted credential data is saved
	 */
	override async update(
		criteria: string | Partial<CredentialsEntity>,
		partialEntity: Partial<CredentialsEntity>,
	): Promise<any> {
		const dbType = Container.get(GlobalConfig).database.type;

		// For SQL Server, use raw query to ensure nvarchar(MAX) is handled correctly
		// This is necessary because TypeORM may truncate data when using parameterized queries
		// with nvarchar columns that don't explicitly specify MAX length
		if (dbType === 'mssqldb' && 'data' in partialEntity && partialEntity.data !== undefined) {
			const em = this.getContextManager();
			const tableName = em.getRepository(CredentialsEntity).metadata.tableName;
			const schema = em.getRepository(CredentialsEntity).metadata.schema;
			const fullTableName = schema ? `[${schema}].[${tableName}]` : `[${tableName}]`;

			// Build WHERE clause
			let whereClause = '';
			const params: any[] = [];
			if (typeof criteria === 'string') {
				whereClause = '[id] = @0';
				params.push(criteria);
			} else {
				const conditions: string[] = [];
				let paramIndex = 0;
				for (const [key, value] of Object.entries(criteria)) {
					conditions.push(`[${key}] = @${paramIndex}`);
					params.push(value);
					paramIndex++;
				}
				whereClause = conditions.join(' AND ');
			}

			// Build SET clause with direct value embedding for data field
			// We cannot use parameterized queries for NVARCHAR(MAX) as they truncate at ~500 chars
			// Instead, we use quoted string literals for the data field
			const setClauses: string[] = [];
			let setParamIndex = params.length;
			for (const [key, value] of Object.entries(partialEntity)) {
				if (key === 'data') {
					// Use quoted string literal instead of parameter to avoid truncation
					// Escape single quotes by doubling them
					const escapedValue = String(value).replace(/'/g, "''");
					setClauses.push(`[data] = N'${escapedValue}'`);
				} else {
					setClauses.push(`[${key}] = @${setParamIndex}`);
					params.push(value);
					setParamIndex++;
				}
			}

			const sql = `UPDATE ${fullTableName} SET ${setClauses.join(', ')} WHERE ${whereClause}`;
			await em.query(sql, params);
			return { affected: 1 };
		}

		// For other databases, use standard TypeORM update
		return await super.update(criteria, partialEntity);
	}

	async findStartingWith(credentialName: string) {
		const em = this.getContextManager();
		return await em.find(CredentialsEntity, {
			select: ['name'],
			where: { name: Like(`${credentialName}%`) },
		});
	}

	async findMany(
		listQueryOptions?: ListQuery.Options & { includeData?: boolean; user?: User },
		credentialIds?: string[],
	) {
		const em = this.getContextManager();
		const findManyOptions = this.toFindManyOptions(listQueryOptions);

		if (credentialIds) {
			findManyOptions.where = { ...findManyOptions.where, id: In(credentialIds) };
		}

		return await em.find(CredentialsEntity, findManyOptions);
	}

	private toFindManyOptions(listQueryOptions?: ListQuery.Options & { includeData?: boolean }) {
		const findManyOptions: FindManyOptions<CredentialsEntity> = {};

		type Select = Array<keyof CredentialsEntity>;

		const defaultRelations = ['shared', 'shared.project', 'shared.project.projectRelations'];
		const defaultSelect: Select = ['id', 'name', 'type', 'isManaged', 'createdAt', 'updatedAt'];

		if (!listQueryOptions) return { select: defaultSelect, relations: defaultRelations };

		const { filter, select, take, skip } = listQueryOptions;

		if (typeof filter?.name === 'string' && filter?.name !== '') {
			filter.name = Like(`%${filter.name}%`);
		}

		if (typeof filter?.type === 'string' && filter?.type !== '') {
			filter.type = Like(`%${filter.type}%`);
		}

		this.handleSharedFilters(listQueryOptions);

		if (filter) findManyOptions.where = filter;
		if (select) findManyOptions.select = select;
		if (take) findManyOptions.take = take;
		if (skip) findManyOptions.skip = skip;

		if (take && select && !select?.id) {
			findManyOptions.select = { ...findManyOptions.select, id: true }; // pagination requires id
		}

		if (!findManyOptions.select) {
			findManyOptions.select = defaultSelect;
			findManyOptions.relations = defaultRelations;
		}

		if (listQueryOptions.includeData) {
			if (Array.isArray(findManyOptions.select)) {
				findManyOptions.select.push('data');
			} else {
				findManyOptions.select.data = true;
			}
		}

		return findManyOptions;
	}

	private handleSharedFilters(
		listQueryOptions?: ListQuery.Options & { includeData?: boolean },
	): void {
		if (!listQueryOptions?.filter) return;

		const { filter } = listQueryOptions;

		if (typeof filter.projectId === 'string' && filter.projectId !== '') {
			filter.shared = {
				projectId: filter.projectId,
			};
			delete filter.projectId;
		}

		if (typeof filter.withRole === 'string' && filter.withRole !== '') {
			filter.shared = {
				...(filter?.shared ? filter.shared : {}),
				role: filter.withRole,
			};
			delete filter.withRole;
		}

		if (
			filter.user &&
			typeof filter.user === 'object' &&
			'id' in filter.user &&
			typeof filter.user.id === 'string'
		) {
			filter.shared = {
				...(filter?.shared ? filter.shared : {}),
				project: {
					projectRelations: {
						userId: filter.user.id,
					},
				},
			};
			delete filter.user;
		}
	}

	async getManyByIds(ids: string[], { withSharings } = { withSharings: false }) {
		const em = this.getContextManager();
		const findManyOptions: FindManyOptions<CredentialsEntity> = { where: { id: In(ids) } };

		if (withSharings) {
			findManyOptions.relations = {
				shared: {
					project: true,
				},
			};
		}

		return await em.find(CredentialsEntity, findManyOptions);
	}

	/**
	 * Find all credentials that are owned by a personal project.
	 */
	async findAllPersonalCredentials(): Promise<CredentialsEntity[]> {
		const em = this.getContextManager();
		return await em.findBy(CredentialsEntity, { shared: { project: { type: 'personal' } } });
	}

	/**
	 * Find all credentials that are part of any project that the workflow is
	 * part of.
	 *
	 * This is useful to for finding credentials that can be used in the
	 * workflow.
	 */
	async findAllCredentialsForWorkflow(workflowId: string): Promise<CredentialsEntity[]> {
		const em = this.getContextManager();
		return await em.findBy(CredentialsEntity, {
			shared: { project: { sharedWorkflows: { workflowId } } },
		});
	}

	/**
	 * Find all credentials that are part of that project.
	 *
	 * This is useful for finding credentials that can be used in workflows that
	 * are part of this project.
	 */
	async findAllCredentialsForProject(projectId: string): Promise<CredentialsEntity[]> {
		const em = this.getContextManager();
		return await em.findBy(CredentialsEntity, { shared: { projectId } });
	}
}
