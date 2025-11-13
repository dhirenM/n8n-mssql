# MSSQL Migrations for n8n

This directory contains MSSQL-specific migrations for n8n. **MSSQL support is EXPERIMENTAL and not officially supported by n8n.**

## Schema Information

All tables are created in the `n8n` schema instead of the default `dbo` schema. This allows for better organization and security.

## Initial Setup

⚠️ **IMPORTANT:** The initial n8n database schema for MSSQL MUST be created manually using the SQL script.

### Manual SQL Script (Required)

You must run the SQL script before starting n8n for the first time:

1. Execute `n8n_schema_initialization.sql` using SQL Server Management Studio or `sqlcmd`:
   ```bash
   sqlcmd -S localhost -d n8n -U your_user -P your_password -i n8n_schema_initialization.sql
   ```

2. This script is idempotent and can be safely run multiple times

3. After running the script, set your environment variables:
   ```bash
   DB_TYPE=mssqldb
   DB_MSSQL_HOST=localhost
   DB_MSSQL_PORT=1433
   DB_MSSQL_DATABASE=n8n
   DB_MSSQL_USER=your_user
   DB_MSSQL_PASSWORD=your_password
   DB_TABLE_PREFIX=n8n_
   ```

4. Start n8n - subsequent migrations will run automatically

## Migration Files

- **n8n_schema_initialization.sql**: SQL script for initial schema creation (MUST be run manually first)
- **index.ts**: Migration list exported to n8n (includes common migrations after initial setup)

## Schema Structure

The migration creates 46 tables organized into the following categories:

### Core System Tables
- `migrations` - Migration tracking
- `settings` - Application settings

### User Management
- `role` - User roles
- `scope` - Permission scopes
- `role_scope` - Role-scope mappings
- `user` - User accounts
- `auth_identity` - External authentication providers
- `auth_provider_sync_history` - Auth sync history
- `user_api_keys` - API keys for users
- `invalid_auth_token` - Invalidated tokens

### Project Management
- `project` - Projects
- `project_relation` - User-project relationships

### Credentials
- `credentials_entity` - Stored credentials
- `shared_credentials` - Project-credential sharing

### Workflows
- `folder` - Workflow folders
- `tag_entity` - Tags for organization
- `folder_tag` - Folder-tag mappings
- `workflow_entity` - Workflows
- `workflows_tags` - Workflow-tag mappings
- `shared_workflow` - Project-workflow sharing
- `workflow_statistics` - Workflow statistics
- `workflow_history` - Workflow version history
- `workflow_dependency` - Workflow dependencies

### Webhooks
- `webhook_entity` - Webhook registrations

### Executions
- `execution_entity` - Workflow executions
- `execution_data` - Execution data
- `execution_metadata` - Execution metadata
- `execution_annotations` - Execution annotations
- `annotation_tag_entity` - Annotation tags
- `execution_annotation_tags` - Annotation-tag mappings

### Testing
- `test_run` - Test runs
- `test_case_execution` - Test case executions

### Data Management
- `variables` - Environment variables
- `processed_data` - Processed data cache
- `event_destinations` - Event destinations

### Data Tables
- `data_table` - Data table definitions
- `data_table_column` - Data table columns

### Analytics/Insights
- `insights_metadata` - Insights metadata
- `insights_raw` - Raw insights data
- `insights_by_period` - Aggregated insights

### Chat Hub
- `chat_hub_agents` - AI agents
- `chat_hub_sessions` - Chat sessions
- `chat_hub_messages` - Chat messages

## Important Notes

1. **Schema Name**: All tables use the `n8n` schema by default. You can customize this via the `DB_TABLE_PREFIX` environment variable.

2. **Idempotency**: Both the TypeScript migration and SQL script are idempotent - they can be run multiple times safely.

3. **Common Migrations**: After the initial schema is created, subsequent migrations are imported from the `../common` folder and are shared with MySQL.

4. **Production Warning**: MSSQL is NOT officially supported by n8n. For production use, please use PostgreSQL, MySQL, MariaDB, or SQLite.

## Troubleshooting

### Schema Not Found
If you get errors about the schema not existing, ensure that:
- The `n8n` schema is created (check with `SELECT * FROM sys.schemas WHERE name = 'n8n'`)
- Your user has permissions to create schemas and tables
- The `DB_TABLE_PREFIX` is set correctly

### Permission Errors
Ensure your database user has the following permissions:
```sql
-- Grant schema creation permission
GRANT CREATE SCHEMA TO [your_user];

-- Grant permissions on the n8n schema
GRANT CREATE TABLE TO [your_user];
GRANT ALTER ON SCHEMA::n8n TO [your_user];
GRANT CONTROL ON SCHEMA::n8n TO [your_user];
```

### Migration Already Run
If you've manually run the SQL script, the TypeScript migration will detect existing tables and skip creation. This is normal behavior.

## Maintenance

To view existing migrations in the database:
```sql
SELECT * FROM n8n.migrations ORDER BY timestamp;
```

To reset the database (⚠️ WARNING: This will delete all data!):
```sql
USE [n8n];
GO

-- Drop all tables in the n8n schema
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql += 'DROP TABLE IF EXISTS [n8n].[' + name + ']; '
FROM sys.tables
WHERE schema_id = SCHEMA_ID('n8n');

EXEC sp_executesql @sql;

-- Drop the schema
DROP SCHEMA IF EXISTS [n8n];
GO
```

