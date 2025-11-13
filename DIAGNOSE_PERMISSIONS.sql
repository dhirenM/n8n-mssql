-- ==================================================
-- n8n Permission System Diagnostic Script
-- ==================================================
-- Run this to check what's set up and what's missing
-- ==================================================

USE [YourVoyagerDatabaseName]; -- CHANGE THIS TO YOUR TENANT DATABASE NAME
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'n8n Permission System Diagnostic';
PRINT '========================================';
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- ==================================================
-- 1. CHECK REQUIRED TABLES EXIST
-- ==================================================
PRINT '1. Checking if required tables exist...';
PRINT '';

DECLARE @tablesExist TABLE (tableName NVARCHAR(255), tableExists BIT);

INSERT INTO @tablesExist VALUES 
    ('n8n.role', CASE WHEN OBJECT_ID('n8n.role', 'U') IS NOT NULL THEN 1 ELSE 0 END),
    ('n8n.scope', CASE WHEN OBJECT_ID('n8n.scope', 'U') IS NOT NULL THEN 1 ELSE 0 END),
    ('n8n.role_scope', CASE WHEN OBJECT_ID('n8n.role_scope', 'U') IS NOT NULL THEN 1 ELSE 0 END),
    ('n8n.user', CASE WHEN OBJECT_ID('n8n.user', 'U') IS NOT NULL THEN 1 ELSE 0 END),
    ('n8n.project', CASE WHEN OBJECT_ID('n8n.project', 'U') IS NOT NULL THEN 1 ELSE 0 END),
    ('n8n.project_relation', CASE WHEN OBJECT_ID('n8n.project_relation', 'U') IS NOT NULL THEN 1 ELSE 0 END);

DECLARE @tableName NVARCHAR(255), @tableExists BIT, @allTablesExist BIT = 1;
DECLARE table_cursor CURSOR FOR SELECT tableName, tableExists FROM @tablesExist;
OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @tableName, @tableExists;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @tableExists = 1
        PRINT '   ✓ ' + @tableName + ' exists';
    ELSE
    BEGIN
        PRINT '   ✗ ' + @tableName + ' MISSING!';
        SET @allTablesExist = 0;
    END
    FETCH NEXT FROM table_cursor INTO @tableName, @tableExists;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;

PRINT '';

IF @allTablesExist = 0
BEGIN
    PRINT '   ⚠️  PROBLEM: Some required tables are missing!';
    PRINT '   ACTION: Run n8n_schema_initialization.sql to create missing tables';
    PRINT '';
END

-- ==================================================
-- 2. CHECK ROLES
-- ==================================================
PRINT '2. Checking roles...';
PRINT '';

IF OBJECT_ID('n8n.role', 'U') IS NOT NULL
BEGIN
    DECLARE @roleCount INT;
    SELECT @roleCount = COUNT(*) FROM n8n.[role];
    
    IF @roleCount = 0
    BEGIN
        PRINT '   ✗ NO ROLES FOUND!';
        PRINT '   ACTION: Run MISSING_SCHEMA_FIX.sql to create default roles';
    END
    ELSE
    BEGIN
        PRINT '   ✓ Found ' + CAST(@roleCount AS NVARCHAR(10)) + ' role(s)';
        PRINT '';
        PRINT '   Key roles:';
        
        -- Check for essential roles
        IF EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = 'global:owner')
            PRINT '   ✓ global:owner';
        ELSE
            PRINT '   ✗ global:owner MISSING';
            
        IF EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = 'global:admin')
            PRINT '   ✓ global:admin';
        ELSE
            PRINT '   ✗ global:admin MISSING';
            
        IF EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = 'global:member')
            PRINT '   ✓ global:member';
        ELSE
            PRINT '   ✗ global:member MISSING';
            
        IF EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = 'project:admin')
            PRINT '   ✓ project:admin';
        ELSE
            PRINT '   ✗ project:admin MISSING';
            
        IF EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = 'project:editor')
            PRINT '   ✓ project:editor';
        ELSE
            PRINT '   ✗ project:editor MISSING';
    END
END
ELSE
    PRINT '   ✗ role table does not exist!';

PRINT '';

-- ==================================================
-- 3. CHECK SCOPES
-- ==================================================
PRINT '3. Checking scopes...';
PRINT '';

IF OBJECT_ID('n8n.scope', 'U') IS NOT NULL
BEGIN
    DECLARE @scopeCount INT;
    SELECT @scopeCount = COUNT(*) FROM n8n.[scope];
    
    IF @scopeCount = 0
    BEGIN
        PRINT '   ✗ NO SCOPES FOUND!';
        PRINT '   ACTION: Run MISSING_SCHEMA_FIX.sql to create default scopes';
    END
    ELSE
    BEGIN
        PRINT '   ✓ Found ' + CAST(@scopeCount AS NVARCHAR(10)) + ' scope(s)';
        PRINT '';
        PRINT '   Critical scopes:';
        
        -- Check for workflow:create scope
        IF EXISTS (SELECT 1 FROM n8n.[scope] WHERE slug = 'workflow:create')
            PRINT '   ✓ workflow:create';
        ELSE
            PRINT '   ✗ workflow:create MISSING!';
            
        IF EXISTS (SELECT 1 FROM n8n.[scope] WHERE slug = 'workflow:read')
            PRINT '   ✓ workflow:read';
        ELSE
            PRINT '   ✗ workflow:read MISSING!';
            
        IF EXISTS (SELECT 1 FROM n8n.[scope] WHERE slug = 'workflow:update')
            PRINT '   ✓ workflow:update';
        ELSE
            PRINT '   ✗ workflow:update MISSING!';
    END
END
ELSE
    PRINT '   ✗ scope table does not exist!';

PRINT '';

-- ==================================================
-- 4. CHECK ROLE-SCOPE MAPPINGS
-- ==================================================
PRINT '4. Checking role-scope mappings...';
PRINT '';

IF OBJECT_ID('n8n.role_scope', 'U') IS NOT NULL
BEGIN
    DECLARE @mappingCount INT;
    SELECT @mappingCount = COUNT(*) FROM n8n.[role_scope];
    
    IF @mappingCount = 0
    BEGIN
        PRINT '   ✗ NO ROLE-SCOPE MAPPINGS FOUND!';
        PRINT '   ACTION: Run MISSING_SCHEMA_FIX.sql to create role-scope mappings';
    END
    ELSE
    BEGIN
        PRINT '   ✓ Found ' + CAST(@mappingCount AS NVARCHAR(10)) + ' role-scope mapping(s)';
        PRINT '';
        PRINT '   Critical mappings for workflow:create:';
        
        -- Check which roles have workflow:create scope
        IF EXISTS (SELECT 1 FROM n8n.[role_scope] WHERE roleSlug = 'global:admin' AND scopeSlug = 'workflow:create')
            PRINT '   ✓ global:admin → workflow:create';
        ELSE
            PRINT '   ✗ global:admin → workflow:create MISSING!';
            
        IF EXISTS (SELECT 1 FROM n8n.[role_scope] WHERE roleSlug = 'global:member' AND scopeSlug = 'workflow:create')
            PRINT '   ✓ global:member → workflow:create';
        ELSE
            PRINT '   ✗ global:member → workflow:create MISSING';
            
        IF EXISTS (SELECT 1 FROM n8n.[role_scope] WHERE roleSlug = 'project:admin' AND scopeSlug = 'workflow:create')
            PRINT '   ✓ project:admin → workflow:create';
        ELSE
            PRINT '   ✗ project:admin → workflow:create MISSING!';
            
        IF EXISTS (SELECT 1 FROM n8n.[role_scope] WHERE roleSlug = 'project:editor' AND scopeSlug = 'workflow:create')
            PRINT '   ✓ project:editor → workflow:create';
        ELSE
            PRINT '   ✗ project:editor → workflow:create MISSING!';
    END
END
ELSE
    PRINT '   ✗ role_scope table does not exist!';

PRINT '';

-- ==================================================
-- 5. CHECK PROJECTS
-- ==================================================
PRINT '5. Checking projects...';
PRINT '';

IF OBJECT_ID('n8n.project', 'U') IS NOT NULL
BEGIN
    DECLARE @projectCount INT;
    SELECT @projectCount = COUNT(*) FROM n8n.[project];
    
    IF @projectCount = 0
    BEGIN
        PRINT '   ✗ NO PROJECTS FOUND!';
        PRINT '   ACTION: Run ELEVATE_MODE_PREREQUISITES.sql to create default "n8nnet" project';
    END
    ELSE
    BEGIN
        PRINT '   ✓ Found ' + CAST(@projectCount AS NVARCHAR(10)) + ' project(s)';
        PRINT '';
        
        -- Check for the default n8nnet project
        DECLARE @defaultProjectName NVARCHAR(255) = 'n8nnet';
        IF EXISTS (SELECT 1 FROM n8n.[project] WHERE name = @defaultProjectName AND type = 'team')
        BEGIN
            PRINT '   ✓ Default team project "' + @defaultProjectName + '" exists';
            
            -- Get project details
            DECLARE @projectId UNIQUEIDENTIFIER;
            SELECT @projectId = id FROM n8n.[project] WHERE name = @defaultProjectName AND type = 'team';
            PRINT '   • Project ID: ' + CAST(@projectId AS NVARCHAR(50));
        END
        ELSE
        BEGIN
            PRINT '   ✗ Default team project "' + @defaultProjectName + '" MISSING!';
            PRINT '   ACTION: Run ELEVATE_MODE_PREREQUISITES.sql to create it';
        END
        
        PRINT '';
        PRINT '   All projects:';
        
        -- List all projects
        DECLARE @pName NVARCHAR(255), @pType NVARCHAR(50);
        DECLARE @pId NVARCHAR(50); -- Changed from UNIQUEIDENTIFIER to NVARCHAR to avoid conversion issues
        DECLARE project_cursor CURSOR FOR 
            SELECT CAST(id AS NVARCHAR(50)), name, type FROM n8n.[project] ORDER BY type, name;
        
        OPEN project_cursor;
        FETCH NEXT FROM project_cursor INTO @pId, @pName, @pType;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT '   • [' + @pType + '] ' + @pName + ' (' + CAST(@pId AS NVARCHAR(50)) + ')';
            FETCH NEXT FROM project_cursor INTO @pId, @pName, @pType;
        END
        
        CLOSE project_cursor;
        DEALLOCATE project_cursor;
    END
END
ELSE
    PRINT '   ✗ project table does not exist!';

PRINT '';

-- ==================================================
-- 6. CHECK USERS AND PROJECT RELATIONS
-- ==================================================
PRINT '6. Checking users and project memberships...';
PRINT '';

IF OBJECT_ID('n8n.user', 'U') IS NOT NULL AND OBJECT_ID('n8n.project_relation', 'U') IS NOT NULL
BEGIN
    DECLARE @userCount INT;
    SELECT @userCount = COUNT(*) FROM n8n.[user];
    
    IF @userCount = 0
    BEGIN
        PRINT '   • No users found (will be created on first JWT login)';
    END
    ELSE
    BEGIN
        PRINT '   ✓ Found ' + CAST(@userCount AS NVARCHAR(10)) + ' user(s)';
        PRINT '';
        PRINT '   User details:';
        
        -- Show user details with their projects
        DECLARE @userId UNIQUEIDENTIFIER, @userEmail NVARCHAR(255), @userRole NVARCHAR(255);
        DECLARE user_cursor CURSOR FOR 
            SELECT id, email, roleSlug FROM n8n.[user] ORDER BY email;
        
        OPEN user_cursor;
        FETCH NEXT FROM user_cursor INTO @userId, @userEmail, @userRole;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT '';
            PRINT '   User: ' + @userEmail;
            PRINT '   • ID: ' + CAST(@userId AS NVARCHAR(50));
            PRINT '   • Global Role: ' + ISNULL(@userRole, 'NULL');
            
            -- Check project relations for this user
            DECLARE @projectRelCount INT;
            SELECT @projectRelCount = COUNT(*) 
            FROM n8n.[project_relation] 
            WHERE userId = @userId;
            
            IF @projectRelCount = 0
            BEGIN
                PRINT '   • ✗ NOT A MEMBER OF ANY PROJECTS!';
                PRINT '   • This user cannot create workflows!';
            END
            ELSE
            BEGIN
                PRINT '   • Project memberships (' + CAST(@projectRelCount AS NVARCHAR(10)) + '):';
                
                -- List projects for this user
                DECLARE @projName NVARCHAR(255), @projRole NVARCHAR(255);
                DECLARE user_project_cursor CURSOR FOR
                    SELECT p.name, pr.role
                    FROM n8n.[project_relation] pr
                    JOIN n8n.[project] p ON pr.projectId = p.id
                    WHERE pr.userId = @userId;
                
                OPEN user_project_cursor;
                FETCH NEXT FROM user_project_cursor INTO @projName, @projRole;
                
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    PRINT '     - ' + @projName + ' (role: ' + @projRole + ')';
                    FETCH NEXT FROM user_project_cursor INTO @projName, @projRole;
                END
                
                CLOSE user_project_cursor;
                DEALLOCATE user_project_cursor;
            END
            
            FETCH NEXT FROM user_cursor INTO @userId, @userEmail, @userRole;
        END
        
        CLOSE user_cursor;
        DEALLOCATE user_cursor;
    END
END
ELSE
BEGIN
    IF OBJECT_ID('n8n.user', 'U') IS NULL
        PRINT '   ✗ user table does not exist!';
    IF OBJECT_ID('n8n.project_relation', 'U') IS NULL
        PRINT '   ✗ project_relation table does not exist!';
END

PRINT '';

-- ==================================================
-- 7. SUMMARY & RECOMMENDATIONS
-- ==================================================
PRINT '========================================';
PRINT 'Summary & Recommendations';
PRINT '========================================';
PRINT '';

-- Determine what needs to be done
DECLARE @needsSchemaInit BIT = 0;
DECLARE @needsMissingSchemaFix BIT = 0;
DECLARE @needsElevatePrereqs BIT = 0;

-- Check if schema initialization is needed
IF OBJECT_ID('n8n.role', 'U') IS NULL 
   OR OBJECT_ID('n8n.scope', 'U') IS NULL 
   OR OBJECT_ID('n8n.role_scope', 'U') IS NULL
    SET @needsSchemaInit = 1;

-- Check if missing schema fix is needed
IF OBJECT_ID('n8n.scope', 'U') IS NOT NULL
BEGIN
    DECLARE @roleCheckCount INT, @scopeCheckCount INT, @mappingCheckCount INT;
    SELECT @roleCheckCount = COUNT(*) FROM n8n.[role] WHERE slug IN ('global:admin', 'project:admin', 'project:editor');
    SELECT @scopeCheckCount = COUNT(*) FROM n8n.[scope] WHERE slug = 'workflow:create';
    SELECT @mappingCheckCount = COUNT(*) FROM n8n.[role_scope] WHERE scopeSlug = 'workflow:create';
    
    IF @roleCheckCount < 3 OR @scopeCheckCount = 0 OR @mappingCheckCount = 0
        SET @needsMissingSchemaFix = 1;
END

-- Check if elevate prerequisites are needed
IF OBJECT_ID('n8n.project', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM n8n.[project] WHERE name = 'n8nnet' AND type = 'team')
        SET @needsElevatePrereqs = 1;
END

-- Display recommendations
IF @needsSchemaInit = 1
BEGIN
    PRINT '❌ STEP 1: Initialize Database Schema';
    PRINT '   Run: packages\@n8n\db\src\migrations\mssqldb\n8n_schema_initialization.sql';
    PRINT '';
END
ELSE
    PRINT '✓ Database schema initialized';

IF @needsMissingSchemaFix = 1
BEGIN
    PRINT '❌ STEP 2: Add Roles, Scopes, and Mappings';
    PRINT '   Run: MISSING_SCHEMA_FIX.sql';
    PRINT '';
END
ELSE
    PRINT '✓ Roles, scopes, and mappings configured';

IF @needsElevatePrereqs = 1
BEGIN
    PRINT '❌ STEP 3: Create Default "n8nnet" Project';
    PRINT '   Run: ELEVATE_MODE_PREREQUISITES.sql';
    PRINT '';
END
ELSE
    PRINT '✓ Default project exists';

IF @needsSchemaInit = 0 AND @needsMissingSchemaFix = 0 AND @needsElevatePrereqs = 0
BEGIN
    PRINT '';
    PRINT '✓ All prerequisites are in place!';
    PRINT '';
    PRINT 'If "Create Workflow" is still disabled:';
    PRINT '1. Restart n8n';
    PRINT '2. Clear browser cache and cookies';
    PRINT '3. Re-login with your JWT token';
    PRINT '4. Check browser console for errors';
END

PRINT '';
PRINT '========================================';

GO

