import { Service } from '@n8n/di';
import { PROJECT_OWNER_ROLE_SLUG, type WorkflowSharingRole } from '@n8n/permissions';
import { DataSource, In, Not } from '@n8n/typeorm';
import type { EntityManager, FindManyOptions, FindOptionsWhere } from '@n8n/typeorm';

import type { Project } from '../entities';
import { SharedWorkflow } from '../entities';
import { BaseRepository } from './base.repository';

@Service()
export class SharedWorkflowRepository extends BaseRepository<SharedWorkflow> {
	constructor(dataSource: DataSource) {
		super(SharedWorkflow, dataSource);
	}

	async getSharedWorkflowIds(workflowIds: string[]) {
		const em = this.getContextManager();
		const sharedWorkflows = await em.find(SharedWorkflow, {
			select: ['workflowId'],
			where: {
				workflowId: In(workflowIds),
			},
		});
		return sharedWorkflows.map((sharing) => sharing.workflowId);
	}

	async findByWorkflowIds(workflowIds: string[]) {
		const em = this.getContextManager();
		return await em.find(SharedWorkflow, {
			where: {
				role: 'workflow:owner',
				workflowId: In(workflowIds),
			},
			relations: { project: { projectRelations: { user: true, role: true } } },
		});
	}

	async findSharingRole(
		userId: string,
		workflowId: string,
	): Promise<WorkflowSharingRole | undefined> {
		const em = this.getContextManager();
		const sharing = await em.findOne(SharedWorkflow, {
			// NOTE: We have to select everything that is used in the `where` clause. Otherwise typeorm will create an invalid query and we get this error:
			//       QueryFailedError: SQLITE_ERROR: no such column: distinctAlias.SharedWorkflow_...
			select: {
				role: true,
				workflowId: true,
				projectId: true,
			},
			where: {
				workflowId,
				project: { projectRelations: { role: { slug: PROJECT_OWNER_ROLE_SLUG }, userId } },
			},
		});

		return sharing?.role;
	}

	async makeOwnerOfAllWorkflows(project: Project) {
		const em = this.getContextManager();
		return await em.update(
			SharedWorkflow,
			{
				projectId: Not(project.id),
				role: 'workflow:owner',
			},
			{ project },
		);
	}

	async makeOwner(workflowIds: string[], projectId: string, trx?: EntityManager) {
		const em = trx ?? this.getContextManager();

		return await em.upsert(
			SharedWorkflow,
			workflowIds.map(
				(workflowId) =>
					({
						workflowId,
						projectId,
						role: 'workflow:owner',
					}) as const,
			),

			['projectId', 'workflowId'],
		);
	}

	async findWithFields(
		workflowIds: string[],
		{ select }: Pick<FindManyOptions<SharedWorkflow>, 'select'>,
	) {
		const em = this.getContextManager();
		return await em.find(SharedWorkflow, {
			where: {
				workflowId: In(workflowIds),
			},
			select,
		});
	}

	async deleteByIds(sharedWorkflowIds: string[], projectId: string, trx?: EntityManager) {
		const em = trx ?? this.getContextManager();

		return await em.delete(SharedWorkflow, {
			projectId,
			workflowId: In(sharedWorkflowIds),
		});
	}

	/**
	 * Find the IDs of all the projects where a workflow is accessible.
	 */
	async findProjectIds(workflowId: string) {
		const em = this.getContextManager();
		const rows = await em.find(SharedWorkflow, { where: { workflowId }, select: ['projectId'] });

		const projectIds = rows.reduce<string[]>((acc, row) => {
			if (row.projectId) acc.push(row.projectId);
			return acc;
		}, []);

		return [...new Set(projectIds)];
	}

	async getWorkflowOwningProject(workflowId: string) {
		const em = this.getContextManager();
		return (
			await em.findOne(SharedWorkflow, {
				where: { workflowId, role: 'workflow:owner' },
				relations: { project: true },
			})
		)?.project;
	}

	async getRelationsByWorkflowIdsAndProjectIds(workflowIds: string[], projectIds: string[]) {
		const em = this.getContextManager();
		return await em.find(SharedWorkflow, {
			where: {
				workflowId: In(workflowIds),
				projectId: In(projectIds),
			},
		});
	}

	async getAllRelationsForWorkflows(workflowIds: string[]) {
		const em = this.getContextManager();
		return await em.find(SharedWorkflow, {
			where: {
				workflowId: In(workflowIds),
			},
			relations: ['project'],
		});
	}

	async findWorkflowWithOptions(
		workflowId: string,
		options: {
			where?: FindOptionsWhere<SharedWorkflow>;
			includeTags?: boolean;
			includeParentFolder?: boolean;
			em?: EntityManager;
		} = {},
	) {
		const {
			where = {},
			includeTags = false,
			includeParentFolder = false,
			em = this.getContextManager(),
		} = options;

		return await em.findOne(SharedWorkflow, {
			where: {
				workflowId,
				...where,
			},
			relations: {
				workflow: {
					shared: { project: { projectRelations: { user: true } } },
					tags: includeTags,
					parentFolder: includeParentFolder,
				},
			},
		});
	}
}
