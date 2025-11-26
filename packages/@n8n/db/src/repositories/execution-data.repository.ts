import { Service } from '@n8n/di';
import { DataSource, In, Repository } from '@n8n/typeorm';
import type { EntityManager } from '@n8n/typeorm';
import type { QueryDeepPartialEntity } from '@n8n/typeorm/query-builder/QueryPartialEntity';

import { ExecutionData } from '../entities';

@Service()
export class ExecutionDataRepository extends Repository<ExecutionData> {
	constructor(dataSource: DataSource) {
		super(ExecutionData, dataSource.manager);
	}

	async createExecutionDataForExecution(
		data: QueryDeepPartialEntity<ExecutionData>,
		transactionManager: EntityManager,
	) {
		// Bypass the idStringifier transformer for executionId since it's an nvarchar column
		// The transformer converts strings to numbers, but SQL Server expects a string for nvarchar
		// Use raw SQL to completely bypass the transformer and ensure string type
		const executionId = data.executionId ? String(data.executionId) : data.executionId;
		const metadata = transactionManager.getRepository(ExecutionData).metadata;
		const tableName = metadata.tableName;
		const schema = metadata.schema;
		const fullTableName = schema ? `"${schema}"."${tableName}"` : `"${tableName}"`;

		// Serialize workflowData if it's an object (JsonColumn handles this normally, but raw SQL needs manual serialization)
		const workflowDataValue =
			typeof data.workflowData === 'string'
				? data.workflowData
				: data.workflowData
					? JSON.stringify(data.workflowData)
					: null;

		// Use raw SQL with parameterized query to bypass transformer
		// executionId must be a string for nvarchar column, not a number
		await transactionManager.query(
			`INSERT INTO ${fullTableName} ("data", "workflowData", "executionId") VALUES (@0, @1, @2)`,
			[data.data ?? null, workflowDataValue, executionId ?? null],
		);

		return { identifiers: [{ executionId }], generatedMaps: [] };
	}

	async findByExecutionIds(executionIds: string[]) {
		return await this.find({
			select: ['workflowData'],
			where: {
				executionId: In(executionIds),
			},
		}).then((executionData) => executionData.map(({ workflowData }) => workflowData));
	}
}
