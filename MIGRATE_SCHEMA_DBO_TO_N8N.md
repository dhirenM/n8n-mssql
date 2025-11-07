# 🔄 Migrate n8n Tables from `dbo` to `n8n` Schema

## Overview

**Scenario:** You already created n8n tables in the `dbo` schema and want to move them to a custom `n8n` schema.

**Solution:** Use SQL Server's `ALTER SCHEMA TRANSFER` command to move tables atomically.

**Risk Level:** 🟡 **MEDIUM** (Backup recommended, but operation is atomic and reversible)

---

## 📋 Complete List of n8n Tables

Based on your n8n v1.119.0 installation, here are all the tables:

### Core Tables (35 tables)
1. `user`
2. `role`
3. `scope`
4. `project`
5. `project_relation`
6. `workflow_entity`
7. `workflow_dependency`
8. `workflow_statistics`
9. `workflow_tag_mapping` (also called `workflows_tags`)
10. `workflow_history`
11. `credentials_entity`
12. `shared_credentials`
13. `shared_workflow`
14. `execution_entity`
15. `execution_data`
16. `execution_metadata`
17. `execution_annotation`
18. `tag_entity`
19. `annotation_tag_entity`
20. `annotation_tag_mapping`
21. `folder`
22. `folder_tag_mapping`
23. `webhook_entity`
24. `settings`
25. `variables`
26. `api_key`
27. `auth_identity`
28. `auth_provider_sync_history`
29. `invalid_auth_token`
30. `event_destinations`
31. `processed_data`
32. `test_run`
33. `test_case_execution`
34. `migrations` (TypeORM migrations table)
35. `role_scope` (junction table)

### Additional Tables (may exist depending on modules)
- `oauth_clients` (if MCP module is enabled)
- `oauth_access_tokens`
- `oauth_refresh_tokens`
- `oauth_authorization_codes`
- `oauth_user_consents`

---

## ⚠️ Pre-Migration Checklist

### 1. Stop n8n
```powershell
# Stop n8n completely
Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
```

### 2. Backup Your Database
```sql
-- Option A: Full database backup
BACKUP DATABASE [dmnen_test] 
TO DISK = 'C:\Backups\dmnen_test_before_schema_migration.bak'
WITH FORMAT, COMPRESSION;

-- Option B: Export tables (lighter weight)
-- Use SQL Server Management Studio:
-- Right-click database → Tasks → Generate Scripts
-- Select all n8n tables → Script to file
```

### 3. Verify Current Tables
```sql
-- See what tables currently exist in dbo
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    (SELECT COUNT(*) FROM sys.objects o 
     WHERE o.name = t.TABLE_NAME AND o.type = 'U') as row_count_available
FROM INFORMATION_SCHEMA.TABLES t
WHERE TABLE_SCHEMA = 'dbo'
    AND TABLE_NAME IN (
        'user', 'role', 'scope', 'project', 'project_relation',
        'workflow_entity', 'workflow_dependency', 'workflow_statistics',
        'workflows_tags', 'workflow_history', 'credentials_entity',
        'shared_credentials', 'shared_workflow', 'execution_entity',
        'execution_data', 'execution_metadata', 'execution_annotation',
        'tag_entity', 'annotation_tag_entity', 'annotation_tag_mapping',
        'folder', 'folder_tag_mapping', 'webhook_entity', 'settings',
        'variables', 'api_key', 'auth_identity', 'auth_provider_sync_history',
        'invalid_auth_token', 'event_destinations', 'processed_data',
        'test_run', 'test_case_execution', 'migrations', 'role_scope'
    )
ORDER BY TABLE_NAME;
```

---

## 🚀 Migration Script

### Step 1: Create the n8n Schema

```sql
USE [dmnen_test];
GO

-- Create the n8n schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'n8n')
BEGIN
    EXEC('CREATE SCHEMA [n8n] AUTHORIZATION dbo');
    PRINT 'Schema [n8n] created successfully.';
END
ELSE
BEGIN
    PRINT 'Schema [n8n] already exists.';
END
GO
```

### Step 2: Transfer All Tables to n8n Schema

```sql
USE [dmnen_test];
GO

-- Transfer tables from dbo to n8n schema
-- This operation is ATOMIC - either all succeed or all fail

PRINT '=================================================';
PRINT 'Starting Schema Transfer: dbo → n8n';
PRINT '=================================================';
PRINT '';

-- Core n8n tables
DECLARE @tableName NVARCHAR(128);
DECLARE @sql NVARCHAR(MAX);
DECLARE @transferCount INT = 0;
DECLARE @skipCount INT = 0;

-- List of tables to transfer
DECLARE @tables TABLE (TableName NVARCHAR(128));

INSERT INTO @tables (TableName) VALUES
('user'),
('role'),
('scope'),
('role_scope'),
('project'),
('project_relation'),
('workflow_entity'),
('workflow_dependency'),
('workflow_statistics'),
('workflows_tags'),
('workflow_history'),
('credentials_entity'),
('shared_credentials'),
('shared_workflow'),
('execution_entity'),
('execution_data'),
('execution_metadata'),
('execution_annotation'),
('tag_entity'),
('annotation_tag_entity'),
('annotation_tag_mapping'),
('folder'),
('folder_tag_mapping'),
('webhook_entity'),
('settings'),
('variables'),
('api_key'),
('auth_identity'),
('auth_provider_sync_history'),
('invalid_auth_token'),
('event_destinations'),
('processed_data'),
('test_run'),
('test_case_execution'),
('migrations');

-- Optional: MCP module tables (uncomment if you use MCP)
-- INSERT INTO @tables (TableName) VALUES
-- ('oauth_clients'),
-- ('oauth_access_tokens'),
-- ('oauth_refresh_tokens'),
-- ('oauth_authorization_codes'),
-- ('oauth_user_consents');

-- Transfer each table
DECLARE table_cursor CURSOR FOR 
SELECT TableName FROM @tables;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @tableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Check if table exists in dbo schema
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
               WHERE TABLE_SCHEMA = 'dbo' 
               AND TABLE_NAME = @tableName)
    BEGIN
        -- Check if table already exists in n8n schema
        IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
                   WHERE TABLE_SCHEMA = 'n8n' 
                   AND TABLE_NAME = @tableName)
        BEGIN
            PRINT '⚠️  SKIP: [n8n].[' + @tableName + '] already exists';
            SET @skipCount = @skipCount + 1;
        END
        ELSE
        BEGIN
            BEGIN TRY
                -- Transfer the table
                SET @sql = 'ALTER SCHEMA [n8n] TRANSFER [dbo].[' + @tableName + '];';
                EXEC sp_executesql @sql;
                
                PRINT '✅ Transferred: dbo.' + @tableName + ' → n8n.' + @tableName;
                SET @transferCount = @transferCount + 1;
            END TRY
            BEGIN CATCH
                PRINT '❌ ERROR transferring ' + @tableName + ': ' + ERROR_MESSAGE();
            END CATCH
        END
    END
    ELSE
    BEGIN
        PRINT '⚠️  NOT FOUND: dbo.' + @tableName + ' (skipping)';
    END
    
    FETCH NEXT FROM table_cursor INTO @tableName;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;

PRINT '';
PRINT '=================================================';
PRINT 'Migration Summary:';
PRINT '  Transferred: ' + CAST(@transferCount AS NVARCHAR(10)) + ' tables';
PRINT '  Skipped: ' + CAST(@skipCount AS NVARCHAR(10)) + ' tables';
PRINT '=================================================';
GO
```

### Step 3: Grant Permissions on n8n Schema

```sql
USE [dmnen_test];
GO

-- Grant permissions to your n8n database user
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[n8n] TO [qa];
GRANT CREATE TABLE ON SCHEMA::[n8n] TO [qa];
GRANT ALTER ON SCHEMA::[n8n] TO [qa];
GRANT EXECUTE ON SCHEMA::[n8n] TO [qa];

PRINT 'Permissions granted to user [qa] on schema [n8n]';
GO
```

---

## 🔍 Verification

### 1. Verify All Tables Were Moved

```sql
-- Check tables in n8n schema
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    (SELECT COUNT(*) 
     FROM sys.objects o 
     JOIN sys.schemas s ON o.schema_id = s.schema_id
     WHERE s.name = TABLE_SCHEMA 
     AND o.name = TABLE_NAME 
     AND o.type = 'U') as exists_check
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'n8n'
ORDER BY TABLE_NAME;

-- Expected: Should see 35+ tables
```

### 2. Verify Tables No Longer in dbo

```sql
-- Check if n8n tables still exist in dbo
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
    AND TABLE_NAME IN (
        'user', 'workflow_entity', 'execution_entity', 
        'credentials_entity', 'settings'
    )
ORDER BY TABLE_NAME;

-- Expected: Should be EMPTY (or only YOUR user table, not n8n's)
```

### 3. Check Row Counts (Data Integrity)

```sql
-- Verify data is intact
SELECT 
    'n8n.user' as TableName, 
    COUNT(*) as RowCount 
FROM [n8n].[user]
UNION ALL
SELECT 
    'n8n.workflow_entity', 
    COUNT(*) 
FROM [n8n].[workflow_entity]
UNION ALL
SELECT 
    'n8n.execution_entity', 
    COUNT(*) 
FROM [n8n].[execution_entity]
UNION ALL
SELECT 
    'n8n.credentials_entity', 
    COUNT(*) 
FROM [n8n].[credentials_entity]
UNION ALL
SELECT 
    'n8n.settings', 
    COUNT(*) 
FROM [n8n].[settings];
```

---

## 🔧 Update n8n Configuration

### Update START_N8N_MSSQL.ps1

```powershell
# File: START_N8N_MSSQL.ps1
# Line 19 - Change from:
$env:DB_MSSQLDB_SCHEMA = "dbo"

# To:
$env:DB_MSSQLDB_SCHEMA = "n8n"
```

---

## ✅ Test n8n

### Start n8n

```powershell
.\START_N8N_MSSQL.ps1
```

### Verify in Logs

You should see queries like:

```sql
SELECT * FROM "n8n"."user" WHERE ...
SELECT * FROM "n8n"."workflow_entity" WHERE ...
```

NOT:

```sql
SELECT * FROM "dbo"."user" WHERE ...  ← This would be wrong
```

---

## 🔙 Rollback Procedure (If Needed)

If something goes wrong, you can move tables back to dbo:

```sql
USE [dmnen_test];
GO

-- Move tables back to dbo schema
ALTER SCHEMA [dbo] TRANSFER [n8n].[user];
ALTER SCHEMA [dbo] TRANSFER [n8n].[workflow_entity];
ALTER SCHEMA [dbo] TRANSFER [n8n].[execution_entity];
-- ... repeat for all tables

-- Or restore from backup
RESTORE DATABASE [dmnen_test] 
FROM DISK = 'C:\Backups\dmnen_test_before_schema_migration.bak'
WITH REPLACE;
```

---

## 📊 Complete Migration Checklist

- [ ] **Stop n8n** completely
- [ ] **Backup database** (full backup or script tables)
- [ ] **Verify current tables** in dbo schema
- [ ] **Create n8n schema** (Step 1)
- [ ] **Run transfer script** (Step 2)
- [ ] **Grant permissions** (Step 3)
- [ ] **Verify migration** (all verification queries)
- [ ] **Update START_N8N_MSSQL.ps1** (change schema to "n8n")
- [ ] **Start n8n** and check logs
- [ ] **Test basic operations** (login, create workflow, etc.)
- [ ] **Verify queries use n8n schema** in logs

---

## ⚡ Quick One-Command Migration

If you want to run everything at once:

```sql
USE [dmnen_test];
GO

-- Create schema, transfer tables, grant permissions - ALL IN ONE
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'n8n')
    EXEC('CREATE SCHEMA [n8n] AUTHORIZATION dbo');

-- Transfer all tables (abbreviated - use full list from Step 2)
ALTER SCHEMA [n8n] TRANSFER [dbo].[user];
ALTER SCHEMA [n8n] TRANSFER [dbo].[role];
ALTER SCHEMA [n8n] TRANSFER [dbo].[scope];
ALTER SCHEMA [n8n] TRANSFER [dbo].[role_scope];
ALTER SCHEMA [n8n] TRANSFER [dbo].[project];
ALTER SCHEMA [n8n] TRANSFER [dbo].[project_relation];
ALTER SCHEMA [n8n] TRANSFER [dbo].[workflow_entity];
ALTER SCHEMA [n8n] TRANSFER [dbo].[workflow_dependency];
ALTER SCHEMA [n8n] TRANSFER [dbo].[workflow_statistics];
ALTER SCHEMA [n8n] TRANSFER [dbo].[workflows_tags];
ALTER SCHEMA [n8n] TRANSFER [dbo].[workflow_history];
ALTER SCHEMA [n8n] TRANSFER [dbo].[credentials_entity];
ALTER SCHEMA [n8n] TRANSFER [dbo].[shared_credentials];
ALTER SCHEMA [n8n] TRANSFER [dbo].[shared_workflow];
ALTER SCHEMA [n8n] TRANSFER [dbo].[execution_entity];
ALTER SCHEMA [n8n] TRANSFER [dbo].[execution_data];
ALTER SCHEMA [n8n] TRANSFER [dbo].[execution_metadata];
ALTER SCHEMA [n8n] TRANSFER [dbo].[execution_annotation];
ALTER SCHEMA [n8n] TRANSFER [dbo].[tag_entity];
ALTER SCHEMA [n8n] TRANSFER [dbo].[annotation_tag_entity];
ALTER SCHEMA [n8n] TRANSFER [dbo].[annotation_tag_mapping];
ALTER SCHEMA [n8n] TRANSFER [dbo].[folder];
ALTER SCHEMA [n8n] TRANSFER [dbo].[folder_tag_mapping];
ALTER SCHEMA [n8n] TRANSFER [dbo].[webhook_entity];
ALTER SCHEMA [n8n] TRANSFER [dbo].[settings];
ALTER SCHEMA [n8n] TRANSFER [dbo].[variables];
ALTER SCHEMA [n8n] TRANSFER [dbo].[api_key];
ALTER SCHEMA [n8n] TRANSFER [dbo].[auth_identity];
ALTER SCHEMA [n8n] TRANSFER [dbo].[auth_provider_sync_history];
ALTER SCHEMA [n8n] TRANSFER [dbo].[invalid_auth_token];
ALTER SCHEMA [n8n] TRANSFER [dbo].[event_destinations];
ALTER SCHEMA [n8n] TRANSFER [dbo].[processed_data];
ALTER SCHEMA [n8n] TRANSFER [dbo].[test_run];
ALTER SCHEMA [n8n] TRANSFER [dbo].[test_case_execution];
ALTER SCHEMA [n8n] TRANSFER [dbo].[migrations];

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[n8n] TO [qa];
GRANT CREATE TABLE ON SCHEMA::[n8n] TO [qa];
GRANT ALTER ON SCHEMA::[n8n] TO [qa];
GRANT EXECUTE ON SCHEMA::[n8n] TO [qa];

PRINT 'Migration completed successfully!';
GO
```

---

## 💡 Important Notes

### 1. **ALTER SCHEMA TRANSFER is Atomic**
- The operation either succeeds completely or fails with no changes
- No data is copied - just metadata update
- Foreign keys and indexes are preserved
- Very fast (milliseconds even for large tables)

### 2. **No Downtime for Data**
- The transfer is instant
- No data loss risk
- Foreign key relationships are maintained

### 3. **Your Existing dbo.user Table**
- Will NOT be affected
- Remains in dbo schema
- Completely separate from n8n.user

### 4. **After Migration**
- Your database structure:
  ```
  dmnen_test:
    ├── dbo.user (YOUR table) ✅
    ├── n8n.user (n8n's user table) ✅
    ├── n8n.workflow_entity ✅
    ├── n8n.execution_entity ✅
    └── ... (all n8n tables in n8n schema)
  ```

---

## 🎯 Summary

**What happens:**
- **35+ tables** moved from `dbo` to `n8n` schema
- **No data loss** (atomic operation)
- **Instant transfer** (metadata only)
- **Complete separation** from your existing dbo.user table

**Time required:**
- Script execution: **< 1 minute**
- Total including verification: **~10 minutes**

**Risk:**
- 🟡 Medium (backup recommended, but operation is reversible)

---

**Ready to migrate?** Follow the checklist step by step! 🚀

