-- ============================================================
-- Complete Migration: Move n8n Tables from dbo to n8n Schema
-- ============================================================
-- Database: dmnen_test
-- Purpose: Fix user permissions + Move all tables to n8n schema
-- ============================================================

USE [dmnen_test];
GO

PRINT '============================================================';
PRINT 'Complete n8n Schema Migration';
PRINT 'Started: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
PRINT '============================================================';
PRINT '';

-- ============================================================
-- STEP 1: Find existing user for login 'qa'
-- ============================================================

PRINT '🔍 Step 1: Finding existing database user for login [qa]...';

DECLARE @existingUser NVARCHAR(128);

SELECT @existingUser = dp.name
FROM sys.database_principals dp
INNER JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE sp.name = 'qa';

IF @existingUser IS NOT NULL
BEGIN
    PRINT '   ✅ Found: Login [qa] is mapped to user [' + @existingUser + ']';
    PRINT '   We will use this existing user for permissions.';
END
ELSE
BEGIN
    PRINT '   ⚠️  No user found for login [qa]';
    PRINT '   Creating new user...';
    
    CREATE USER [qa] FOR LOGIN [qa];
    SET @existingUser = 'qa';
    PRINT '   ✅ Created user [qa]';
END
PRINT '';
GO

-- ============================================================
-- STEP 2: Create n8n schema
-- ============================================================

PRINT '📦 Step 2: Creating n8n schema...';

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'n8n')
BEGIN
    EXEC('CREATE SCHEMA [n8n] AUTHORIZATION dbo');
    PRINT '   ✅ Schema [n8n] created.';
END
ELSE
BEGIN
    PRINT '   ✅ Schema [n8n] already exists.';
END
PRINT '';
GO

-- ============================================================
-- STEP 3: Transfer tables from dbo to n8n
-- ============================================================

PRINT '📋 Step 3: Transferring n8n tables from dbo to n8n schema...';
PRINT '';

DECLARE @tableName NVARCHAR(128);
DECLARE @sql NVARCHAR(MAX);
DECLARE @transferCount INT = 0;
DECLARE @skipCount INT = 0;
DECLARE @notFoundCount INT = 0;

-- List of n8n tables (not YOUR custom tables)
DECLARE @n8nTables TABLE (TableName NVARCHAR(128));

INSERT INTO @n8nTables (TableName) VALUES
    -- Core tables
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
    ('execution_annotation_tags'),
    ('execution_annotations'),
    ('tag_entity'),
    ('annotation_tag_entity'),
    ('annotation_tag_mapping'),
    ('folder'),
    ('folder_tag'),
    ('folder_tag_mapping'),
    ('webhook_entity'),
    ('settings'),
    ('variables'),
    ('api_key'),
    ('user_api_keys'),
    ('auth_identity'),
    ('auth_provider_sync_history'),
    ('invalid_auth_token'),
    ('event_destinations'),
    ('processed_data'),
    ('test_run'),
    ('test_case_execution'),
    ('migrations'),
    ('installed_packages'),
    ('installed_nodes'),
    -- Chat/Hub tables
    ('chat_hub_agents'),
    ('chat_hub_messages'),
    ('chat_hub_sessions'),
    -- Data tables
    ('data_table'),
    ('data_table_column'),
    -- Insights tables
    ('insights_by_period'),
    ('insights_metadata'),
    ('insights_raw');

-- NOTE: We're NOT moving 'user' table yet - check if it's yours or n8n's

-- Transfer each table
DECLARE table_cursor CURSOR FOR 
SELECT TableName FROM @n8nTables ORDER BY TableName;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @tableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Check if table exists in dbo
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
               WHERE TABLE_SCHEMA = 'dbo' 
               AND TABLE_NAME = @tableName)
    BEGIN
        -- Check if already in n8n schema
        IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
                   WHERE TABLE_SCHEMA = 'n8n' 
                   AND TABLE_NAME = @tableName)
        BEGIN
            PRINT '   ⚠️  SKIP: [n8n].[' + @tableName + '] already exists';
            SET @skipCount = @skipCount + 1;
        END
        ELSE
        BEGIN
            BEGIN TRY
                SET @sql = 'ALTER SCHEMA [n8n] TRANSFER [dbo].[' + @tableName + '];';
                EXEC sp_executesql @sql;
                PRINT '   ✅ ' + REPLICATE(' ', 30 - LEN(@tableName)) + 'dbo.' + @tableName + ' → n8n.' + @tableName;
                SET @transferCount = @transferCount + 1;
            END TRY
            BEGIN CATCH
                PRINT '   ❌ ERROR: ' + @tableName + ' - ' + ERROR_MESSAGE();
            END CATCH
        END
    END
    ELSE
    BEGIN
        -- Table doesn't exist in dbo (that's OK)
        SET @notFoundCount = @notFoundCount + 1;
    END
    
    FETCH NEXT FROM table_cursor INTO @tableName;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;

PRINT '';
PRINT '   Transfer Summary:';
PRINT '   ✅ Transferred: ' + CAST(@transferCount AS VARCHAR(10)) + ' tables';
PRINT '   ⚠️  Skipped: ' + CAST(@skipCount AS VARCHAR(10)) + ' tables';
PRINT '   ℹ️  Not in dbo: ' + CAST(@notFoundCount AS VARCHAR(10)) + ' tables';
PRINT '';
GO

-- ============================================================
-- STEP 4: Handle 'user' table separately
-- ============================================================

PRINT '👤 Step 4: Checking [user] table...';

-- Check if dbo.user has n8n data or is a custom table
DECLARE @userTableRowCount INT = 0;
DECLARE @hasN8nColumns BIT = 0;

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'user')
BEGIN
    -- Check if it has n8n-specific columns
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'user' 
               AND COLUMN_NAME IN ('personalizationAnswers', 'mfaEnabled', 'roleSlug'))
    BEGIN
        SET @hasN8nColumns = 1;
        SELECT @userTableRowCount = COUNT(*) FROM [dbo].[user];
        
        IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'n8n' AND TABLE_NAME = 'user')
        BEGIN
            PRINT '   ⚠️  SKIP: n8n.user already exists';
        END
        ELSE
        BEGIN
            PRINT '   ✅ This is n8n''s user table (' + CAST(@userTableRowCount AS VARCHAR(10)) + ' rows)';
            PRINT '   Moving to n8n schema...';
            
            ALTER SCHEMA [n8n] TRANSFER [dbo].[user];
            PRINT '   ✅ dbo.user → n8n.user';
        END
    END
    ELSE
    BEGIN
        PRINT '   ℹ️  dbo.user exists but does NOT have n8n columns.';
        PRINT '   This is likely YOUR custom user table - NOT moving it.';
        PRINT '   Your dbo.user table will remain in dbo schema.';
    END
END
ELSE
BEGIN
    PRINT '   ℹ️  No user table in dbo schema.';
END
PRINT '';
GO

-- ============================================================
-- STEP 5: Grant permissions
-- ============================================================

PRINT '🔐 Step 5: Granting permissions...';

-- Find the user again (in case it wasn't in scope)
DECLARE @userName NVARCHAR(128);

SELECT @userName = dp.name
FROM sys.database_principals dp
INNER JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE sp.name = 'qa';

IF @userName IS NOT NULL
BEGIN
    DECLARE @grantSQL NVARCHAR(MAX);
    
    -- Grant schema-level permissions
    SET @grantSQL = 'GRANT SELECT, INSERT, UPDATE, DELETE, ALTER, EXECUTE ON SCHEMA::[n8n] TO [' + @userName + ']';
    EXEC sp_executesql @grantSQL;
    
    PRINT '   ✅ Granted permissions to [' + @userName + '] on schema [n8n]';
END
PRINT '';
GO

-- ============================================================
-- STEP 6: Verification
-- ============================================================

PRINT '🔍 Step 6: Verification...';
PRINT '';

-- Count tables in each schema
PRINT '   Tables in n8n schema:';
SELECT '      - ' + TABLE_NAME as TableName
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'n8n'
ORDER BY TABLE_NAME;

PRINT '';
PRINT '   Tables still in dbo schema:';
SELECT '      - ' + TABLE_NAME as TableName
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME;

PRINT '';
PRINT '============================================================';
PRINT '✅ MIGRATION COMPLETED!';
PRINT '============================================================';
PRINT '';
PRINT 'Next Steps:';
PRINT '   1. Stop n8n if running';
PRINT '   2. Restart n8n with: .\START_N8N_MSSQL.ps1';
PRINT '   3. Verify queries use n8n schema in logs:';
PRINT '      Should see: FROM "n8n"."workflow_entity"';
PRINT '      NOT: FROM "dbo"."workflow_entity"';
PRINT '';
PRINT 'Completed: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
PRINT '============================================================';
GO

