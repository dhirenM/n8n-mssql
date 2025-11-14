import { Service } from '@n8n/di';
import { PROJECT_OWNER_ROLE_SLUG, type ProjectRole } from '@n8n/permissions';
import { DataSource, In } from '@n8n/typeorm';

import { ProjectRelation } from '../entities';
import { BaseRepository } from './base.repository';

@Service()
export class ProjectRelationRepository extends BaseRepository<ProjectRelation> {
	constructor(dataSource: DataSource) {
		super(ProjectRelation, dataSource);
	}

	async getPersonalProjectOwners(projectIds: string[]) {
		const em = this.getContextManager();
		return await em.find(ProjectRelation, {
			where: {
				projectId: In(projectIds),
				role: { slug: PROJECT_OWNER_ROLE_SLUG },
			},
			relations: {
				user: {
					role: true,
				},
			},
		});
	}

	async getPersonalProjectsForUsers(userIds: string[]) {
		const em = this.getContextManager();
		const projectRelations = await em.find(ProjectRelation, {
			where: {
				userId: In(userIds),
				role: { slug: PROJECT_OWNER_ROLE_SLUG },
			},
		});

		return projectRelations.map((pr) => pr.projectId);
	}

	async getAccessibleProjectsByRoles(userId: string, roles: string[]) {
		const em = this.getContextManager();
		const projectRelations = await em.find(ProjectRelation, {
			where: { userId, role: { slug: In(roles) } },
		});

		return projectRelations.map((pr) => pr.projectId);
	}

	/**
	 * Find the role of a user in a project.
	 */
	async findProjectRole({ userId, projectId }: { userId: string; projectId: string }) {
		const em = this.getContextManager();
		const relation = await em.findOneBy(ProjectRelation, { projectId, userId });

		return relation?.role ?? null;
	}

	/** Counts the number of users in each role, e.g. `{ admin: 2, member: 6, owner: 1 }` */
	async countUsersByRole() {
		const em = this.getContextManager();
		const rows = (await em
			.createQueryBuilder(ProjectRelation, 'project_relation')
			.select(['role', 'COUNT(role) as count'])
			.groupBy('role')
			.execute()) as Array<{ role: ProjectRole; count: string }>;
		return rows.reduce(
			(acc, row) => {
				acc[row.role] = parseInt(row.count, 10);
				return acc;
			},
			{} as Record<ProjectRole, number>,
		);
	}

	async findUserIdsByProjectId(projectId: string): Promise<string[]> {
		const em = this.getContextManager();
		const rows = await em.find(ProjectRelation, {
			select: ['userId'],
			where: { projectId },
		});

		return [...new Set(rows.map((r) => r.userId))];
	}

	async findAllByUser(userId: string) {
		const em = this.getContextManager();
		return await em.find(ProjectRelation, {
			where: {
				userId,
			},
			relations: { role: true },
		});
	}
}
