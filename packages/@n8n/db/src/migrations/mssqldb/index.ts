/**
 * MSSQL Migrations
 * 
 * Note: MSSQL support is EXPERIMENTAL and not officially supported by n8n.
 * 
 * For initial setup, you must manually run the schema creation script:
 * - n8n_schema_idempotent.sql (located in your SQL Server Management Studio folder)
 * 
 * After the initial schema is created, these migrations will handle future updates.
 * Most migrations are shared with MySQL in the ../common folder.
 */

import type { Migration } from '../migration-types';

// Import common migrations that are database-agnostic
import { CreateLdapEntities1674509946020 } from '../common/1674509946020-CreateLdapEntities';
import { PurgeInvalidWorkflowConnections1675940580449 } from '../common/1675940580449-PurgeInvalidWorkflowConnections';
import { RemoveResetPasswordColumns1690000000030 } from '../common/1690000000030-RemoveResetPasswordColumns';
import { AddMfaColumns1690000000030 } from '../common/1690000000040-AddMfaColumns';
import { CreateWorkflowNameIndex1691088862123 } from '../common/1691088862123-CreateWorkflowNameIndex';
import { CreateWorkflowHistoryTable1692967111175 } from '../common/1692967111175-CreateWorkflowHistoryTable';
import { ExecutionSoftDelete1693491613982 } from '../common/1693491613982-ExecutionSoftDelete';
import { DisallowOrphanExecutions1693554410387 } from '../common/1693554410387-DisallowOrphanExecutions';
import { AddWorkflowMetadata1695128658538 } from '../common/1695128658538-AddWorkflowMetadata';
import { ModifyWorkflowHistoryNodesAndConnections1695829275184 } from '../common/1695829275184-ModifyWorkflowHistoryNodesAndConnections';
import { AddGlobalAdminRole1700571993961 } from '../common/1700571993961-AddGlobalAdminRole';
import { DropRoleMapping1705429061930 } from '../common/1705429061930-DropRoleMapping';
import { RemoveFailedExecutionStatus1711018413374 } from '../common/1711018413374-RemoveFailedExecutionStatus';
import { MoveSshKeysToDatabase1711390882123 } from '../common/1711390882123-MoveSshKeysToDatabase';
import { RemoveNodesAccess1712044305787 } from '../common/1712044305787-RemoveNodesAccess';
import { CreateProject1714133768519 } from '../common/1714133768519-CreateProject';
import { MakeExecutionStatusNonNullable1714133768521 } from '../common/1714133768521-MakeExecutionStatusNonNullable';
import { AddConstraintToExecutionMetadata1720101653148 } from '../common/1720101653148-AddConstraintToExecutionMetadata';
import { CreateInvalidAuthTokenTable1723627610222 } from '../common/1723627610222-CreateInvalidAuthTokenTable';
import { RefactorExecutionIndices1723796243146 } from '../common/1723796243146-RefactorExecutionIndices';
import { CreateAnnotationTables1724753530828 } from '../common/1724753530828-CreateExecutionAnnotationTables';
import { AddApiKeysTable1724951148974 } from '../common/1724951148974-AddApiKeysTable';
import { CreateProcessedDataTable1726606152711 } from '../common/1726606152711-CreateProcessedDataTable';
import { SeparateExecutionCreationFromStart1727427440136 } from '../common/1727427440136-SeparateExecutionCreationFromStart';
import { AddMissingPrimaryKeyOnAnnotationTagMapping1728659839644 } from '../common/1728659839644-AddMissingPrimaryKeyOnAnnotationTagMapping';
import { UpdateProcessedDataValueColumnToText1729607673464 } from '../common/1729607673464-UpdateProcessedDataValueColumnToText';
import { AddProjectIcons1729607673469 } from '../common/1729607673469-AddProjectIcons';
import { CreateTestDefinitionTable1730386903556 } from '../common/1730386903556-CreateTestDefinitionTable';
import { AddDescriptionToTestDefinition1731404028106 } from '../common/1731404028106-AddDescriptionToTestDefinition';
import { CreateTestRun1732549866705 } from '../common/1732549866705-CreateTestRunTable';
import { AddMockedNodesColumnToTestDefinition1733133775640 } from '../common/1733133775640-AddMockedNodesColumnToTestDefinition';
import { AddManagedColumnToCredentialsTable1734479635324 } from '../common/1734479635324-AddManagedColumnToCredentialsTable';
import { CreateTestCaseExecutionTable1736947513045 } from '../common/1736947513045-CreateTestCaseExecutionTable';
import { AddErrorColumnsToTestRuns1737715421462 } from '../common/1737715421462-AddErrorColumnsToTestRuns';
import { CreateFolderTable1738709609940 } from '../common/1738709609940-CreateFolderTable';
import { CreateAnalyticsTables1739549398681 } from '../common/1739549398681-CreateAnalyticsTables';
import { RenameAnalyticsToInsights1741167584277 } from '../common/1741167584277-RenameAnalyticsToInsights';
import { AddScopesColumnToApiKeys1742918400000 } from '../common/1742918400000-AddScopesColumnToApiKeys';
import { ClearEvaluation1745322634000 } from '../common/1745322634000-CleanEvaluations';
import { AddWorkflowStatisticsRootCount1745587087521 } from '../common/1745587087521-AddWorkflowStatisticsRootCount';
import { AddWorkflowArchivedColumn1745934666076 } from '../common/1745934666076-AddWorkflowArchivedColumn';
import { DropRoleTable1745934666077 } from '../common/1745934666077-DropRoleTable';
import { AddProjectDescriptionColumn1747824239000 } from '../common/1747824239000-AddProjectDescriptionColumn';
import { AddLastActiveAtColumnToUser1750252139166 } from '../common/1750252139166-AddLastActiveAtColumnToUser';
import { AddScopeTables1750252139166 } from '../common/1750252139166-AddScopeTables';
import { AddRolesTables1750252139167 } from '../common/1750252139167-AddRolesTables';
import { LinkRoleToUserTable1750252139168 } from '../common/1750252139168-LinkRoleToUserTable';
import { RemoveOldRoleColumn1750252139170 } from '../common/1750252139170-RemoveOldRoleColumn';
import { AddInputsOutputsToTestCaseExecution1752669793000 } from '../common/1752669793000-AddInputsOutputsToTestCaseExecution';
import { LinkRoleToProjectRelationTable1753953244168 } from '../common/1753953244168-LinkRoleToProjectRelationTable';
import { CreateDataStoreTables1754475614601 } from '../common/1754475614601-CreateDataStoreTables';
import { ReplaceDataStoreTablesWithDataTables1754475614602 } from '../common/1754475614602-ReplaceDataStoreTablesWithDataTables';
import { AddTimestampsToRoleAndRoleIndexes1756906557570 } from '../common/1756906557570-AddTimestampsToRoleAndRoleIndexes';
import { AddAudienceColumnToApiKeys1758731786132 } from '../common/1758731786132-AddAudienceColumnToApiKey';
import { ChangeValueTypesForInsights1759399811000 } from '../common/1759399811000-ChangeValueTypesForInsights';
import { CreateChatHubTables1760019379982 } from '../common/1760019379982-CreateChatHubTables';
import { CreateChatHubAgentTable1760020000000 } from '../common/1760020000000-CreateChatHubAgentTable';
import { UniqueRoleNames1760020838000 } from '../common/1760020838000-UniqueRoleNames';
import { CreateWorkflowDependencyTable1760314000000 } from '../common/1760314000000-CreateWorkflowDependencyTable';

/**
 * MSSQL Migration List
 * 
 * IMPORTANT: Before running n8n with MSSQL:
 * 1. Manually create the database schema using n8n_schema_idempotent.sql
 * 2. Set DB_TYPE=mssqldb in your environment variables
 * 3. Configure MSSQL connection settings (see below)
 * 
 * Note: The initial migrations (before 1674509946020) are not included here
 * because they are MySQL/Postgres specific. The base schema must be created
 * manually using the provided SQL script.
 */
export const mssqlMigrations: Migration[] = [
	// Note: Initial schema setup is done via manual SQL script
	// These migrations start from 2023 onwards (after base schema is in place)
	CreateLdapEntities1674509946020,
	PurgeInvalidWorkflowConnections1675940580449,
	RemoveResetPasswordColumns1690000000030,
	AddMfaColumns1690000000030,
	CreateWorkflowNameIndex1691088862123,
	CreateWorkflowHistoryTable1692967111175,
	ExecutionSoftDelete1693491613982,
	DisallowOrphanExecutions1693554410387,
	AddWorkflowMetadata1695128658538,
	ModifyWorkflowHistoryNodesAndConnections1695829275184,
	AddGlobalAdminRole1700571993961,
	DropRoleMapping1705429061930,
	RemoveFailedExecutionStatus1711018413374,
	MoveSshKeysToDatabase1711390882123,
	RemoveNodesAccess1712044305787,
	CreateProject1714133768519,
	MakeExecutionStatusNonNullable1714133768521,
	AddConstraintToExecutionMetadata1720101653148,
	CreateInvalidAuthTokenTable1723627610222,
	RefactorExecutionIndices1723796243146,
	CreateAnnotationTables1724753530828,
	AddApiKeysTable1724951148974,
	CreateProcessedDataTable1726606152711,
	SeparateExecutionCreationFromStart1727427440136,
	AddMissingPrimaryKeyOnAnnotationTagMapping1728659839644,
	UpdateProcessedDataValueColumnToText1729607673464,
	AddProjectIcons1729607673469,
	CreateTestDefinitionTable1730386903556,
	AddDescriptionToTestDefinition1731404028106,
	CreateTestRun1732549866705,
	AddMockedNodesColumnToTestDefinition1733133775640,
	AddManagedColumnToCredentialsTable1734479635324,
	CreateTestCaseExecutionTable1736947513045,
	AddErrorColumnsToTestRuns1737715421462,
	CreateFolderTable1738709609940,
	CreateAnalyticsTables1739549398681,
	RenameAnalyticsToInsights1741167584277,
	AddScopesColumnToApiKeys1742918400000,
	AddWorkflowStatisticsRootCount1745587087521,
	AddWorkflowArchivedColumn1745934666076,
	DropRoleTable1745934666077,
	ClearEvaluation1745322634000,
	AddProjectDescriptionColumn1747824239000,
	AddLastActiveAtColumnToUser1750252139166,
	AddScopeTables1750252139166,
	AddRolesTables1750252139167,
	LinkRoleToUserTable1750252139168,
	RemoveOldRoleColumn1750252139170,
	AddInputsOutputsToTestCaseExecution1752669793000,
	LinkRoleToProjectRelationTable1753953244168,
	CreateDataStoreTables1754475614601,
	ReplaceDataStoreTablesWithDataTables1754475614602,
	AddTimestampsToRoleAndRoleIndexes1756906557570,
	AddAudienceColumnToApiKeys1758731786132,
	ChangeValueTypesForInsights1759399811000,
	CreateChatHubTables1760019379982,
	CreateChatHubAgentTable1760020000000,
	UniqueRoleNames1760020838000,
	CreateWorkflowDependencyTable1760314000000,
];

