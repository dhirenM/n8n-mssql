import type { MigrationContext, ReversibleMigration } from '../migration-types';

/**
 * Convert ntext columns to nvarchar(max) for SQL Server
 *
 * ntext is deprecated in SQL Server and has limitations with parameterized queries.
 * nvarchar(max) is the modern replacement that handles large text data better.
 *
 * This migration converts all ntext columns to nvarchar(max) for:
 * - workflow_entity (nodes, connections, settings, staticData, meta, pinData)
 * - workflow_history (nodes, connections)
 * - execution_data (workflowData)
 * - user (personalizationAnswers, settings)
 * - event_destinations (destination)
 * - user_api_keys (scopes)
 * - processed_data (value)
 * - test_definition (evaluationWorkflow)
 * - test_run (metrics, errorDetails)
 * - test_case_execution (errorDetails, metrics, inputs, outputs)
 * - chat_hub_agents (modelConfig, systemMessage)
 */
export class ConvertNtextToNvarcharMax1760965143000 implements ReversibleMigration {
	async up({ queryRunner, tablePrefix }: MigrationContext): Promise<void> {
		const isMssql = (queryRunner.connection.options.type as string) === 'mssqldb';
		if (!isMssql) {
			return; // Only run on SQL Server
		}

		// List of tables and their ntext columns to convert
		const conversions = [
			// workflow_entity
			{ table: `${tablePrefix}workflow_entity`, column: 'nodes' },
			{ table: `${tablePrefix}workflow_entity`, column: 'connections' },
			{ table: `${tablePrefix}workflow_entity`, column: 'settings' },
			{ table: `${tablePrefix}workflow_entity`, column: 'staticData' },
			{ table: `${tablePrefix}workflow_entity`, column: 'meta' },
			{ table: `${tablePrefix}workflow_entity`, column: 'pinData' },

			// workflow_history
			{ table: `${tablePrefix}workflow_history`, column: 'nodes' },
			{ table: `${tablePrefix}workflow_history`, column: 'connections' },

			// execution_data
			{ table: `${tablePrefix}execution_data`, column: 'workflowData' },

			// user
			{ table: `${tablePrefix}user`, column: 'personalizationAnswers' },
			{ table: `${tablePrefix}user`, column: 'settings' },

			// event_destinations
			{ table: `${tablePrefix}event_destinations`, column: 'destination' },

			// user_api_keys
			{ table: `${tablePrefix}user_api_keys`, column: 'scopes' },

			// processed_data
			{ table: `${tablePrefix}processed_data`, column: 'value' },

			// test_definition
			{ table: `${tablePrefix}test_definition`, column: 'evaluationWorkflow' },

			// test_run
			{ table: `${tablePrefix}test_run`, column: 'metrics' },
			{ table: `${tablePrefix}test_run`, column: 'errorDetails' },

			// test_case_execution
			{ table: `${tablePrefix}test_case_execution`, column: 'errorDetails' },
			{ table: `${tablePrefix}test_case_execution`, column: 'metrics' },
			{ table: `${tablePrefix}test_case_execution`, column: 'inputs' },
			{ table: `${tablePrefix}test_case_execution`, column: 'outputs' },

			// chat_hub_agents
			{ table: `${tablePrefix}chat_hub_agents`, column: 'modelConfig' },
			{ table: `${tablePrefix}chat_hub_agents`, column: 'systemMessage' },
		];

		for (const { table, column } of conversions) {
			// Check if table exists
			const tableExists = await queryRunner.hasTable(table);
			if (!tableExists) {
				continue;
			}

			// Check if column exists
			const tableObj = await queryRunner.getTable(table);
			const columnObj = tableObj?.findColumnByName(column);
			if (!columnObj) {
				continue;
			}

			// Only convert if current type is ntext
			if (columnObj.type === 'ntext') {
				const isNullable = columnObj.isNullable ? 'NULL' : 'NOT NULL';
				await queryRunner.query(
					`ALTER TABLE ${table} ALTER COLUMN [${column}] nvarchar(max) ${isNullable}`,
				);
			}
		}
	}

	async down({ queryRunner, tablePrefix }: MigrationContext): Promise<void> {
		const isMssql = (queryRunner.connection.options.type as string) === 'mssqldb';
		if (!isMssql) {
			return; // Only run on SQL Server
		}

		// Reverse: convert nvarchar(max) back to ntext
		// Note: This is generally not recommended as ntext is deprecated
		const conversions = [
			// workflow_entity
			{ table: `${tablePrefix}workflow_entity`, column: 'nodes' },
			{ table: `${tablePrefix}workflow_entity`, column: 'connections' },
			{ table: `${tablePrefix}workflow_entity`, column: 'settings' },
			{ table: `${tablePrefix}workflow_entity`, column: 'staticData' },
			{ table: `${tablePrefix}workflow_entity`, column: 'meta' },
			{ table: `${tablePrefix}workflow_entity`, column: 'pinData' },

			// workflow_history
			{ table: `${tablePrefix}workflow_history`, column: 'nodes' },
			{ table: `${tablePrefix}workflow_history`, column: 'connections' },

			// execution_data
			{ table: `${tablePrefix}execution_data`, column: 'workflowData' },

			// user
			{ table: `${tablePrefix}user`, column: 'personalizationAnswers' },
			{ table: `${tablePrefix}user`, column: 'settings' },

			// event_destinations
			{ table: `${tablePrefix}event_destinations`, column: 'destination' },

			// user_api_keys
			{ table: `${tablePrefix}user_api_keys`, column: 'scopes' },

			// processed_data
			{ table: `${tablePrefix}processed_data`, column: 'value' },

			// test_definition
			{ table: `${tablePrefix}test_definition`, column: 'evaluationWorkflow' },

			// test_run
			{ table: `${tablePrefix}test_run`, column: 'metrics' },
			{ table: `${tablePrefix}test_run`, column: 'errorDetails' },

			// test_case_execution
			{ table: `${tablePrefix}test_case_execution`, column: 'errorDetails' },
			{ table: `${tablePrefix}test_case_execution`, column: 'metrics' },
			{ table: `${tablePrefix}test_case_execution`, column: 'inputs' },
			{ table: `${tablePrefix}test_case_execution`, column: 'outputs' },

			// chat_hub_agents
			{ table: `${tablePrefix}chat_hub_agents`, column: 'modelConfig' },
			{ table: `${tablePrefix}chat_hub_agents`, column: 'systemMessage' },
		];

		for (const { table, column } of conversions) {
			const tableExists = await queryRunner.hasTable(table);
			if (!tableExists) {
				continue;
			}

			const tableObj = await queryRunner.getTable(table);
			const columnObj = tableObj?.findColumnByName(column);
			if (!columnObj) {
				continue;
			}

			if (columnObj.type === 'nvarchar') {
				const isNullable = columnObj.isNullable ? 'NULL' : 'NOT NULL';
				await queryRunner.query(
					`ALTER TABLE ${table} ALTER COLUMN [${column}] ntext ${isNullable}`,
				);
			}
		}
	}
}
