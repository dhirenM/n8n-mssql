-- ==================================================
-- n8n Test Data Cleanup Script
-- ==================================================
-- Safely deletes test data while respecting FK constraints
-- Use this to reset your database for testing JWT authentication
-- ==================================================
-- CAUTION: This will delete data! Use only in TEST/DEV environments
-- ==================================================

USE [YourVoyagerDatabaseName]; -- CHANGE THIS TO YOUR TENANT DATABASE NAME
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'n8n Test Data Cleanup';
PRINT '========================================';
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- ==================================================
-- SAFETY CHECK
-- ==================================================
DECLARE @isProduction BIT = 0; -- Change to 1 if this is production to prevent accidental cleanup

IF @isProduction = 1
BEGIN
    PRINT '⚠️  ERROR: Production database detected!';
    PRINT 'This cleanup script is for TEST/DEV environments only.';
    PRINT 'Set @isProduction = 0 in the script if you are sure.';
    RETURN;
END

-- ==================================================
-- OPTION SELECTION
-- ==================================================
-- Set which cleanup option you want:
--   0 = TRUNCATE USERS ONLY (fastest - deletes only user table and its children)
--   1 = Delete ALL USER DATA (keeps prerequisite: roles, scopes, "n8nnet" project)
--   2 = Delete only USERS and their relations (keeps workflows/credentials)
--   3 = Delete specific user by email
--   4 = Delete all JWT-created users (keeps manually created ones)
--   5 = NUCLEAR OPTION - Delete EVERYTHING including prerequisites (requires re-running setup scripts)

DECLARE @cleanupOption INT = 0; -- CHANGE THIS TO YOUR DESIRED OPTION
DECLARE @specificUserEmail NVARCHAR(255) = 'test@example.com'; -- For option 3

-- ==================================================
-- WHAT GETS PRESERVED BY DEFAULT (Options 1-4)
-- ==================================================
-- ✅ ALWAYS PRESERVED:
--    - role table (global:admin, global:member, project:admin, etc.)
--    - scope table (workflow:read, workflow:create, etc.)
--    - role_scope table (role-to-scope mappings)
--    - "n8nnet" default project
--
-- ❌ DELETED:
--    - Users, executions, workflows, credentials, variables
--    - User-created projects
--    - All runtime data
--
-- NOTE: Option 5 deletes EVERYTHING (requires re-running setup scripts)
-- ==================================================

PRINT 'Cleanup Option: ' + CAST(@cleanupOption AS NVARCHAR(10));
PRINT '';

-- ==================================================
-- BEFORE COUNTS
-- ==================================================
PRINT 'Records BEFORE cleanup:';
PRINT '  Users: ' + CAST((SELECT COUNT(*) FROM n8n.[user]) AS NVARCHAR(10));
PRINT '  Projects: ' + CAST((SELECT COUNT(*) FROM n8n.project) AS NVARCHAR(10));
PRINT '  Project Relations: ' + CAST((SELECT COUNT(*) FROM n8n.project_relation) AS NVARCHAR(10));
PRINT '  Workflows: ' + CAST((SELECT COUNT(*) FROM n8n.workflow_entity) AS NVARCHAR(10));
PRINT '  Credentials: ' + CAST((SELECT COUNT(*) FROM n8n.credentials_entity) AS NVARCHAR(10));
PRINT '  Executions: ' + CAST((SELECT COUNT(*) FROM n8n.execution_entity) AS NVARCHAR(10));
PRINT '';

-- ==================================================
-- CLEANUP LOGIC
-- ==================================================

IF @cleanupOption = 0
BEGIN
    PRINT 'OPTION 0: TRUNCATE USERS ONLY (fastest)...';
    PRINT '';
    PRINT 'NOTE: Deletes only users and their direct children (project_relation, auth_identity)';
    PRINT 'Keeps: Workflows, credentials, executions, projects, roles, scopes';
    PRINT '';
    
    -- Delete child tables first (due to FK constraints)
    
    PRINT '1. Deleting project relations...';
    DELETE FROM [n8n].[project_relation];
    DECLARE @prCount INT = @@ROWCOUNT;
    PRINT '   ✓ Deleted ' + CAST(@prCount AS NVARCHAR(10)) + ' project relation(s)';
    
    PRINT '2. Deleting auth identities...';
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_identity]'))
    BEGIN
        DELETE FROM [n8n].[auth_identity];
        DECLARE @aiCount INT = @@ROWCOUNT;
        PRINT '   ✓ Deleted ' + CAST(@aiCount AS NVARCHAR(10)) + ' auth identity/identities';
    END
    ELSE
        PRINT '   • auth_identity table does not exist';
    
    PRINT '3. Deleting all users...';
    DELETE FROM [n8n].[user];
    DECLARE @userCount INT = @@ROWCOUNT;
    PRINT '   ✓ Deleted ' + CAST(@userCount AS NVARCHAR(10)) + ' user(s)';
    
    PRINT '';
    PRINT '✅ User table cleanup completed!';
    PRINT '✅ Prerequisite data intact (roles, scopes, projects, workflows, credentials)';
END

ELSE IF @cleanupOption = 1
BEGIN
    PRINT 'OPTION 1: Deleting ALL USER DATA (keeps prerequisite data)...';
    PRINT '';
    PRINT 'NOTE: This keeps roles, scopes, role_scope, and "n8nnet" project';
    PRINT '';
    
    -- Delete in reverse order of dependencies
    
    PRINT '1. Deleting executions...';
    DELETE FROM [n8n].[execution_metadata];
    DELETE FROM [n8n].[execution_data];
    DELETE FROM [n8n].[execution_entity];
    PRINT '   ✓ Executions deleted';
    
    PRINT '2. Deleting workflow-related data...';
    DELETE FROM [n8n].[workflow_statistics];
    DELETE FROM [n8n].[workflow_tag_mapping];
    DELETE FROM [n8n].[shared_workflow];
    DELETE FROM [n8n].[workflow_entity];
    PRINT '   ✓ Workflows deleted';
    
    PRINT '3. Deleting credentials...';
    DELETE FROM [n8n].[shared_credentials];
    DELETE FROM [n8n].[credentials_entity];
    PRINT '   ✓ Credentials deleted';
    
    PRINT '4. Deleting variables...';
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[variables]'))
        DELETE FROM [n8n].[variables];
    PRINT '   ✓ Variables deleted';
    
    PRINT '5. Deleting project relations...';
    DELETE FROM [n8n].[project_relation];
    PRINT '   ✓ Project relations deleted';
    
    PRINT '6. Deleting user-created projects (keeping "n8nnet")...';
    DECLARE @defaultProjectName NVARCHAR(255) = COALESCE(N'n8nnet', 'n8nnet');
    DELETE FROM [n8n].[project] WHERE name != @defaultProjectName;
    PRINT '   ✓ User projects deleted (kept "n8nnet")';
    
    PRINT '7. Deleting auth identities...';
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_identity]'))
        DELETE FROM [n8n].[auth_identity];
    PRINT '   ✓ Auth identities deleted';
    
    PRINT '8. Deleting users...';
    DELETE FROM [n8n].[user];
    PRINT '   ✓ Users deleted';
    
    PRINT '';
    PRINT '✅ Full user data cleanup completed!';
    PRINT '✅ Prerequisite data preserved (roles, scopes, "n8nnet" project)';
END

ELSE IF @cleanupOption = 2
BEGIN
    PRINT 'OPTION 2: Deleting only USERS and relations (keeps workflows/credentials)...';
    PRINT '';
    
    PRINT '1. Deleting project relations...';
    DELETE FROM [n8n].[project_relation];
    PRINT '   ✓ Project relations deleted';
    
    PRINT '2. Deleting auth identities...';
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_identity]'))
        DELETE FROM [n8n].[auth_identity];
    PRINT '   ✓ Auth identities deleted';
    
    PRINT '3. Deleting users...';
    DELETE FROM [n8n].[user];
    PRINT '   ✓ Users deleted';
    
    PRINT '';
    PRINT '✅ User cleanup completed! (Workflows/credentials preserved)';
END

ELSE IF @cleanupOption = 3
BEGIN
    PRINT 'OPTION 3: Deleting specific user: ' + @specificUserEmail;
    PRINT '';
    
    DECLARE @userId NVARCHAR(36);
    SELECT @userId = id FROM [n8n].[user] WHERE email = @specificUserEmail;
    
    IF @userId IS NULL
    BEGIN
        PRINT '   ⚠️  User not found: ' + @specificUserEmail;
    END
    ELSE
    BEGIN
        PRINT '   Found user ID: ' + @userId;
        
        PRINT '1. Deleting project relations for user...';
        DELETE FROM [n8n].[project_relation] WHERE userId = @userId;
        PRINT '   ✓ Project relations deleted';
        
        PRINT '2. Deleting auth identities for user...';
        IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_identity]'))
            DELETE FROM [n8n].[auth_identity] WHERE userId = @userId;
        PRINT '   ✓ Auth identities deleted';
        
        PRINT '3. Deleting user...';
        DELETE FROM [n8n].[user] WHERE id = @userId;
        PRINT '   ✓ User deleted';
        
        PRINT '';
        PRINT '✅ User deleted: ' + @specificUserEmail;
    END
END

ELSE IF @cleanupOption = 4
BEGIN
    PRINT 'OPTION 4: Deleting JWT-created users (password IS NULL)...';
    PRINT '';
    
    -- JWT users have NULL password since they auth via JWT
    DECLARE @jwtUserIds TABLE (id NVARCHAR(36), email NVARCHAR(254));
    INSERT INTO @jwtUserIds
    SELECT id, email FROM [n8n].[user] WHERE password IS NULL;
    
    DECLARE @jwtUserCount INT;
    SELECT @jwtUserCount = COUNT(*) FROM @jwtUserIds;
    
    IF @jwtUserCount = 0
    BEGIN
        PRINT '   No JWT users found (all users have passwords)';
    END
    ELSE
    BEGIN
        PRINT '   Found ' + CAST(@jwtUserCount AS NVARCHAR(10)) + ' JWT user(s) to delete:';
        
        -- Show which users will be deleted
        DECLARE @email NVARCHAR(254);
        DECLARE email_cursor CURSOR FOR SELECT email FROM @jwtUserIds;
        OPEN email_cursor;
        FETCH NEXT FROM email_cursor INTO @email;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT '   - ' + @email;
            FETCH NEXT FROM email_cursor INTO @email;
        END
        CLOSE email_cursor;
        DEALLOCATE email_cursor;
        
        PRINT '';
        PRINT '1. Deleting project relations for JWT users...';
        DELETE FROM [n8n].[project_relation] 
        WHERE userId IN (SELECT id FROM @jwtUserIds);
        PRINT '   ✓ Project relations deleted';
        
        PRINT '2. Deleting auth identities for JWT users...';
        IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_identity]'))
            DELETE FROM [n8n].[auth_identity] 
            WHERE userId IN (SELECT id FROM @jwtUserIds);
        PRINT '   ✓ Auth identities deleted';
        
        PRINT '3. Deleting JWT users...';
        DELETE FROM [n8n].[user] WHERE password IS NULL;
        PRINT '   ✓ JWT users deleted';
        
        PRINT '';
        PRINT '✅ JWT users cleanup completed!';
    END
END

ELSE IF @cleanupOption = 5
BEGIN
    PRINT '⚠️  OPTION 5: NUCLEAR CLEANUP - Deleting EVERYTHING including prerequisites!';
    PRINT '';
    PRINT 'WARNING: This will delete roles, scopes, and "n8nnet" project!';
    PRINT 'You will need to re-run MISSING_SCHEMA_FIX.sql and ELEVATE_MODE_PREREQUISITES.sql';
    PRINT '';
    
    -- Delete in reverse order of dependencies
    
    PRINT '1. Deleting all data tables...';
    DELETE FROM [n8n].[execution_metadata];
    DELETE FROM [n8n].[execution_data];
    DELETE FROM [n8n].[execution_entity];
    DELETE FROM [n8n].[workflow_statistics];
    DELETE FROM [n8n].[workflow_tag_mapping];
    DELETE FROM [n8n].[shared_workflow];
    DELETE FROM [n8n].[workflow_entity];
    DELETE FROM [n8n].[shared_credentials];
    DELETE FROM [n8n].[credentials_entity];
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[variables]'))
        DELETE FROM [n8n].[variables];
    PRINT '   ✓ All data deleted';
    
    PRINT '2. Deleting project relations and users...';
    DELETE FROM [n8n].[project_relation];
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_identity]'))
        DELETE FROM [n8n].[auth_identity];
    DELETE FROM [n8n].[user];
    PRINT '   ✓ Users deleted';
    
    PRINT '3. Deleting ALL projects (including "n8nnet")...';
    DELETE FROM [n8n].[project];
    PRINT '   ✓ ALL projects deleted';
    
    PRINT '4. Deleting role-scope mappings...';
    DELETE FROM [n8n].[role_scope];
    PRINT '   ✓ Role-scope mappings deleted';
    
    PRINT '5. Deleting scopes...';
    DELETE FROM [n8n].[scope];
    PRINT '   ✓ Scopes deleted';
    
    PRINT '6. Deleting roles...';
    DELETE FROM [n8n].[role];
    PRINT '   ✓ Roles deleted';
    
    PRINT '';
    PRINT '✅ NUCLEAR cleanup completed!';
    PRINT '⚠️  You MUST re-run these scripts:';
    PRINT '   1. MISSING_SCHEMA_FIX.sql (creates roles & scopes)';
    PRINT '   2. ELEVATE_MODE_PREREQUISITES.sql (creates "n8nnet" project)';
END

ELSE
BEGIN
    PRINT '⚠️  Invalid cleanup option: ' + CAST(@cleanupOption AS NVARCHAR(10));
    PRINT 'Please set @cleanupOption to 1, 2, 3, 4, or 5';
END

PRINT '';

-- ==================================================
-- AFTER COUNTS
-- ==================================================
PRINT 'Records AFTER cleanup:';
PRINT '  Users: ' + CAST((SELECT COUNT(*) FROM n8n.[user]) AS NVARCHAR(10));
PRINT '  Projects: ' + CAST((SELECT COUNT(*) FROM n8n.project) AS NVARCHAR(10));
PRINT '  Project Relations: ' + CAST((SELECT COUNT(*) FROM n8n.project_relation) AS NVARCHAR(10));
PRINT '  Workflows: ' + CAST((SELECT COUNT(*) FROM n8n.workflow_entity) AS NVARCHAR(10));
PRINT '  Credentials: ' + CAST((SELECT COUNT(*) FROM n8n.credentials_entity) AS NVARCHAR(10));
PRINT '  Executions: ' + CAST((SELECT COUNT(*) FROM n8n.execution_entity) AS NVARCHAR(10));
PRINT '';

PRINT '========================================';
PRINT 'Cleanup Complete';
PRINT '========================================';

GO

