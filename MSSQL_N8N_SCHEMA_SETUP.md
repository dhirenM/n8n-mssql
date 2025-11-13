# n8n MSSQL Schema Setup Guide

This document describes the MSSQL initialization schema for n8n using the `n8n` schema instead of `dbo`.

## What's New

✅ **Created n8n Schema**: All tables now use the `n8n` schema instead of `dbo`
✅ **Schema Creation Script**: Automatic schema creation before table creation
✅ **Migration Files**: SQL script for initial setup
✅ **Updated Documentation**: Comprehensive README for migrations

## Files Created/Modified

### New Files

1. **`packages/@n8n/db/src/migrations/mssqldb/n8n_schema_initialization.sql`**
   - Complete SQL script to create `n8n` schema and all 46 tables
   - Idempotent - can be run multiple times safely
   - Uses `n8n` schema for all objects
   - Includes schema creation at the beginning

2. **`packages/@n8n/db/src/migrations/mssqldb/README.md`**
   - Comprehensive documentation
   - Setup instructions
   - Troubleshooting guide
   - Schema structure reference

3. **`MSSQL_N8N_PREREQUISITE_SETUP.sql`**
   - Inserts required default records (roles, scopes, users, projects)
   - Idempotent script

### Modified Files

4. **`packages/@n8n/db/src/migrations/mssqldb/index.ts`**
   - Updated documentation comments
   - Common migrations run after manual schema creation

## Schema Comparison

### Old Schema (dbo)
```sql
CREATE TABLE [dbo].[migrations] (...)
CREATE TABLE [dbo].[settings] (...)
CREATE TABLE [dbo].[user] (...)
```

### New Schema (n8n)
```sql
-- Create schema first
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'n8n')
BEGIN
    CREATE SCHEMA [n8n];
END

CREATE TABLE [n8n].[migrations] (...)
CREATE TABLE [n8n].[settings] (...)
CREATE TABLE [n8n].[user] (...)
```

## Setup Options

⚠️ **IMPORTANT:** The initial schema MUST be created manually using the SQL script.

### Manual SQL Script (Required)

Run the SQL script manually before starting n8n:

**Using SQL Server Management Studio:**
1. Open `packages/@n8n/db/src/migrations/mssqldb/n8n_schema_initialization.sql`
2. Connect to your database
3. Execute the script

**Using sqlcmd:**
```bash
sqlcmd -S localhost -d n8n -U your_user -P your_password \
  -i packages/@n8n/db/src/migrations/mssqldb/n8n_schema_initialization.sql
```

**Using PowerShell:**
```powershell
Invoke-Sqlcmd -ServerInstance "localhost" -Database "n8n" `
  -Username "your_user" -Password "your_password" `
  -InputFile "packages/@n8n/db/src/migrations/mssqldb/n8n_schema_initialization.sql"
```

**After running the script:**
```bash
# Set environment variables
export DB_TYPE=mssqldb
export DB_MSSQL_HOST=localhost
export DB_MSSQL_PORT=1433
export DB_MSSQL_DATABASE=n8n
export DB_MSSQL_USER=your_user
export DB_MSSQL_PASSWORD=your_password
export DB_TABLE_PREFIX=n8n_

# Start n8n - subsequent migrations will run automatically
pnpm start
```

## Tables Created (46 Total)

The schema includes all tables required for n8n functionality:

### Core (2 tables)
- migrations, settings

### User Management (8 tables)
- role, scope, role_scope, user, auth_identity, auth_provider_sync_history, user_api_keys, invalid_auth_token

### Projects (2 tables)
- project, project_relation

### Credentials (2 tables)
- credentials_entity, shared_credentials

### Workflows (9 tables)
- folder, tag_entity, folder_tag, workflow_entity, workflows_tags, shared_workflow, workflow_statistics, workflow_history, workflow_dependency

### Webhooks (1 table)
- webhook_entity

### Executions (6 tables)
- execution_entity, execution_data, execution_metadata, execution_annotations, annotation_tag_entity, execution_annotation_tags

### Testing (2 tables)
- test_run, test_case_execution

### Data Management (3 tables)
- variables, processed_data, event_destinations

### Data Tables (2 tables)
- data_table, data_table_column

### Analytics/Insights (3 tables)
- insights_metadata, insights_raw, insights_by_period

### Chat Hub (3 tables)
- chat_hub_agents, chat_hub_sessions, chat_hub_messages

## Migration Timeline

The migrations are run in this order:

1. **Manual SQL Script** - Creates base schema and tables (REQUIRED - run manually first)
2. **Common Migrations** - All shared migrations from 2023 onwards (run automatically by n8n)

## Verification

After running the migration, verify the schema was created correctly:

```sql
-- Check if schema exists
SELECT * FROM sys.schemas WHERE name = 'n8n';

-- List all tables in n8n schema
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'n8n'
ORDER BY TABLE_NAME;

-- Count tables (should be 46)
SELECT COUNT(*) as TableCount
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'n8n';

-- Check migrations
SELECT * FROM n8n.migrations ORDER BY timestamp;
```

## Benefits of n8n Schema

1. **Separation of Concerns**: n8n tables are isolated from other application tables
2. **Security**: Easier to grant permissions at schema level
3. **Organization**: Clear distinction between n8n and other database objects
4. **Best Practice**: Follows SQL Server conventions for multi-tenant applications
5. **Migration Safety**: Reduces risk of conflicts with existing tables

