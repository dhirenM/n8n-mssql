import { Service } from '@n8n/di';
import type { CredentialSharingRole } from '@n8n/permissions';
import type { EntityManager, FindOptionsWhere } from '@n8n/typeorm';
import { DataSource, In, Not } from '@n8n/typeorm';

import type { Project } from '../entities';
import { SharedCredentials } from '../entities';
import { BaseRepository } from './base.repository';

@Service()
export class SharedCredentialsRepository extends BaseRepository<SharedCredentials> {
	constructor(dataSource: DataSource) {
		super(SharedCredentials, dataSource);
	}

	async findByCredentialIds(credentialIds: string[], role: CredentialSharingRole) {
		const em = this.getContextManager();
		return await em.find(SharedCredentials, {
			relations: { credentials: true, project: { projectRelations: { user: true, role: true } } },
			where: {
				credentialsId: In(credentialIds),
				role,
			},
		});
	}

	async makeOwnerOfAllCredentials(project: Project) {
		const em = this.getContextManager();
		return await em.update(
			SharedCredentials,
			{
				projectId: Not(project.id),
				role: 'credential:owner',
			},
			{ project },
		);
	}

	async makeOwner(credentialIds: string[], projectId: string, trx?: EntityManager) {
		const em = trx ?? this.getContextManager();
		return await em.upsert(
			SharedCredentials,
			credentialIds.map(
				(credentialsId) =>
					({
						projectId,
						credentialsId,
						role: 'credential:owner',
					}) as const,
			),
			['projectId', 'credentialsId'],
		);
	}

	async deleteByIds(sharedCredentialsIds: string[], projectId: string, trx?: EntityManager) {
		const em = trx ?? this.getContextManager();

		return await em.delete(SharedCredentials, {
			projectId,
			credentialsId: In(sharedCredentialsIds),
		});
	}

	async getFilteredAccessibleCredentials(
		projectIds: string[],
		credentialsIds: string[],
	): Promise<string[]> {
		const em = this.getContextManager();
		return (
			await em.find(SharedCredentials, {
				where: {
					projectId: In(projectIds),
					credentialsId: In(credentialsIds),
				},
				select: ['credentialsId'],
			})
		).map((s) => s.credentialsId);
	}

	async findCredentialOwningProject(credentialsId: string) {
		const em = this.getContextManager();
		return (
			await em.findOne(SharedCredentials, {
				where: { credentialsId, role: 'credential:owner' },
				relations: { project: true },
			})
		)?.project;
	}

	async getAllRelationsForCredentials(credentialIds: string[]) {
		const em = this.getContextManager();
		return await em.find(SharedCredentials, {
			where: {
				credentialsId: In(credentialIds),
			},
			relations: ['project'],
		});
	}

	async findCredentialsWithOptions(
		where: FindOptionsWhere<SharedCredentials> = {},
		trx?: EntityManager,
	) {
		const em = trx ?? this.getContextManager();

		return await em.find(SharedCredentials, {
			where,
			relations: {
				credentials: {
					shared: { project: { projectRelations: { user: true } } },
				},
			},
		});
	}

	async findCredentialsByRoles(
		userIds: string[],
		projectRoles: string[],
		credentialRoles: string[],
		trx?: EntityManager,
	) {
		const em = trx ?? this.getContextManager();

		return await em.find(SharedCredentials, {
			where: {
				role: In(credentialRoles),
				project: {
					projectRelations: {
						userId: In(userIds),
						role: { slug: In(projectRoles) },
					},
				},
			},
		});
	}
}
