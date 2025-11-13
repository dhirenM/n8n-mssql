import { Service } from '@n8n/di';
import { PROJECT_OWNER_ROLE_SLUG } from '@n8n/permissions';
import type { EntityManager } from '@n8n/typeorm';
import { DataSource } from '@n8n/typeorm';

import { Project } from '../entities';
import { BaseRepository } from './base.repository';

@Service()
export class ProjectRepository extends BaseRepository<Project> {
	constructor(dataSource: DataSource) {
		super(Project, dataSource);
	}

	async getPersonalProjectForUser(userId: string, entityManager?: EntityManager) {
		const em = entityManager ?? this.getContextManager();

		// Debug logging
		const debugInfo = this.getContextDebugInfo();
		console.log('[ProjectRepository] getPersonalProjectForUser - Context:', debugInfo);

		return await em.findOne(Project, {
			where: {
				type: 'personal',
				projectRelations: { userId, role: { slug: PROJECT_OWNER_ROLE_SLUG } },
			},
			relations: ['projectRelations.role'],
		});
	}

	async getPersonalProjectForUserOrFail(userId: string, entityManager?: EntityManager) {
		const em = entityManager ?? this.getContextManager();

		return await em.findOneOrFail(Project, {
			where: {
				type: 'personal',
				projectRelations: { userId, role: { slug: PROJECT_OWNER_ROLE_SLUG } },
			},
		});
	}

	// This returns personal projects of ALL users OR shared projects of the user
	async getAccessibleProjects(userId: string, entityManager?: EntityManager) {
		const em = entityManager ?? this.getContextManager();

		return await em.find(Project, {
			where: [
				{ type: 'personal' },
				{
					projectRelations: {
						userId,
					},
				},
			],
		});
	}

	async getProjectCounts(entityManager?: EntityManager) {
		const em = entityManager ?? this.getContextManager();

		return {
			personal: await em.count(Project, { where: { type: 'personal' } }),
			team: await em.count(Project, { where: { type: 'team' } }),
		};
	}
}
