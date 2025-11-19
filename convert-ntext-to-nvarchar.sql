-- ============================================================================
-- Convert ntext columns to nvarchar(max) for SQL Server
-- ============================================================================
-- This script converts all ntext columns to nvarchar(max) to fix
-- "Validation failed for parameter" errors when saving large JSON data
-- ============================================================================

USE n8nnet;
GO

PRINT 'Starting conversion of ntext columns to nvarchar(max)...';
PRINT '';

-- workflow_entity table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_entity') AND name = 'nodes' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_entity.nodes from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_entity] ALTER COLUMN [nodes] NVARCHAR(MAX);
    PRINT '✓ Converted workflow_entity.nodes';
END
ELSE
    PRINT '- workflow_entity.nodes already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_entity') AND name = 'connections' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_entity.connections from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_entity] ALTER COLUMN [connections] NVARCHAR(MAX);
    PRINT '✓ Converted workflow_entity.connections';
END
ELSE
    PRINT '- workflow_entity.connections already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_entity') AND name = 'settings' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_entity.settings from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_entity] ALTER COLUMN [settings] NVARCHAR(MAX);
    PRINT '✓ Converted workflow_entity.settings';
END
ELSE
    PRINT '- workflow_entity.settings already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_entity') AND name = 'staticData' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_entity.staticData from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_entity] ALTER COLUMN [staticData] NVARCHAR(MAX);
    PRINT '✓ Converted workflow_entity.staticData';
END
ELSE
    PRINT '- workflow_entity.staticData already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_entity') AND name = 'meta' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_entity.meta from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_entity] ALTER COLUMN [meta] NVARCHAR(MAX);
    PRINT '✓ Converted workflow_entity.meta';
END
ELSE
    PRINT '- workflow_entity.meta already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_entity') AND name = 'pinData' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_entity.pinData from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_entity] ALTER COLUMN [pinData] NVARCHAR(MAX);
    PRINT '✓ Converted workflow_entity.pinData';
END
ELSE
    PRINT '- workflow_entity.pinData already nvarchar(max) or does not exist';

-- workflow_history table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_history') AND name = 'nodes' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_history.nodes from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_history] ALTER COLUMN [nodes] NVARCHAR(MAX) NOT NULL;
    PRINT '✓ Converted workflow_history.nodes';
END
ELSE
    PRINT '- workflow_history.nodes already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.workflow_history') AND name = 'connections' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting workflow_history.connections from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[workflow_history] ALTER COLUMN [connections] NVARCHAR(MAX) NOT NULL;
    PRINT '✓ Converted workflow_history.connections';
END
ELSE
    PRINT '- workflow_history.connections already nvarchar(max) or does not exist';

-- execution_data table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.execution_data') AND name = 'workflowData' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting execution_data.workflowData from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[execution_data] ALTER COLUMN [workflowData] NVARCHAR(MAX) NOT NULL;
    PRINT '✓ Converted execution_data.workflowData';
END
ELSE
    PRINT '- execution_data.workflowData already nvarchar(max) or does not exist';

-- user table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.user') AND name = 'personalizationAnswers' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting user.personalizationAnswers from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[user] ALTER COLUMN [personalizationAnswers] NVARCHAR(MAX);
    PRINT '✓ Converted user.personalizationAnswers';
END
ELSE
    PRINT '- user.personalizationAnswers already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.user') AND name = 'settings' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting user.settings from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[user] ALTER COLUMN [settings] NVARCHAR(MAX);
    PRINT '✓ Converted user.settings';
END
ELSE
    PRINT '- user.settings already nvarchar(max) or does not exist';

-- user_api_keys table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.user_api_keys') AND name = 'scopes' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting user_api_keys.scopes from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[user_api_keys] ALTER COLUMN [scopes] NVARCHAR(MAX);
    PRINT '✓ Converted user_api_keys.scopes';
END
ELSE
    PRINT '- user_api_keys.scopes already nvarchar(max) or does not exist';

-- event_destinations table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.event_destinations') AND name = 'destination' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting event_destinations.destination from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[event_destinations] ALTER COLUMN [destination] NVARCHAR(MAX) NOT NULL;
    PRINT '✓ Converted event_destinations.destination';
END
ELSE
    PRINT '- event_destinations.destination already nvarchar(max) or does not exist';

-- processed_data table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.processed_data') AND name = 'value' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting processed_data.value from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[processed_data] ALTER COLUMN [value] NVARCHAR(MAX) NOT NULL;
    PRINT '✓ Converted processed_data.value';
END
ELSE
    PRINT '- processed_data.value already nvarchar(max) or does not exist';

-- test_run table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.test_run') AND name = 'metrics' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting test_run.metrics from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[test_run] ALTER COLUMN [metrics] NVARCHAR(MAX);
    PRINT '✓ Converted test_run.metrics';
END
ELSE
    PRINT '- test_run.metrics already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.test_run') AND name = 'errorDetails' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting test_run.errorDetails from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[test_run] ALTER COLUMN [errorDetails] NVARCHAR(MAX);
    PRINT '✓ Converted test_run.errorDetails';
END
ELSE
    PRINT '- test_run.errorDetails already nvarchar(max) or does not exist';

-- test_case_execution table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.test_case_execution') AND name = 'errorDetails' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting test_case_execution.errorDetails from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[test_case_execution] ALTER COLUMN [errorDetails] NVARCHAR(MAX);
    PRINT '✓ Converted test_case_execution.errorDetails';
END
ELSE
    PRINT '- test_case_execution.errorDetails already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.test_case_execution') AND name = 'metrics' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting test_case_execution.metrics from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[test_case_execution] ALTER COLUMN [metrics] NVARCHAR(MAX);
    PRINT '✓ Converted test_case_execution.metrics';
END
ELSE
    PRINT '- test_case_execution.metrics already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.test_case_execution') AND name = 'inputs' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting test_case_execution.inputs from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[test_case_execution] ALTER COLUMN [inputs] NVARCHAR(MAX);
    PRINT '✓ Converted test_case_execution.inputs';
END
ELSE
    PRINT '- test_case_execution.inputs already nvarchar(max) or does not exist';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('n8n.test_case_execution') AND name = 'outputs' AND system_type_id = (SELECT system_type_id FROM sys.types WHERE name = 'ntext'))
BEGIN
    PRINT 'Converting test_case_execution.outputs from ntext to nvarchar(max)...';
    ALTER TABLE [n8n].[test_case_execution] ALTER COLUMN [outputs] NVARCHAR(MAX);
    PRINT '✓ Converted test_case_execution.outputs';
END
ELSE
    PRINT '- test_case_execution.outputs already nvarchar(max) or does not exist';

PRINT '';
PRINT '========================================';
PRINT 'Conversion Complete!';
PRINT '========================================';
PRINT '';
PRINT 'All ntext columns have been converted to nvarchar(max).';
PRINT 'You can now save workflows with large JSON data without errors.';
PRINT '';

GO

