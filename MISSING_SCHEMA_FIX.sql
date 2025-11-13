-- ==================================================
-- n8n Missing Schema Fix
-- ==================================================
-- This script adds missing foreign key constraints and
-- default role data that should exist in the database
-- but are not in n8n_schema_initialization.sql
-- ==================================================
-- Run this AFTER running n8n_schema_initialization.sql
-- ==================================================
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'n8n Missing Schema Fix';
PRINT '========================================';
PRINT '';

-- ==================================================
-- 1. CHECK FOR ORPHANED DATA IN project_relation
-- ==================================================
PRINT '1. Checking for orphaned role references...';
PRINT '';

-- Find project_relation records with invalid role values
IF EXISTS (
    SELECT 1 
    FROM [n8n].[project_relation] pr
    WHERE NOT EXISTS (
        SELECT 1 FROM [n8n].[role] r WHERE r.[slug] = pr.[role]
    )
)
BEGIN
    PRINT '   ⚠️  Found project_relation records with invalid role values';
    
    -- Show which invalid roles exist
    DECLARE @invalidRoles TABLE (role NVARCHAR(255), recordCount INT);
    INSERT INTO @invalidRoles
    SELECT pr.[role], COUNT(*) as recordCount
    FROM [n8n].[project_relation] pr
    WHERE NOT EXISTS (
        SELECT 1 FROM [n8n].[role] r WHERE r.[slug] = pr.[role]
    )
    GROUP BY pr.[role];
    
    -- Display invalid roles
    DECLARE @invalidRole NVARCHAR(255), @count INT;
    DECLARE invalid_cursor CURSOR FOR SELECT role, recordCount FROM @invalidRoles;
    OPEN invalid_cursor;
    FETCH NEXT FROM invalid_cursor INTO @invalidRole, @count;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '   • Invalid role "' + @invalidRole + '" found in ' + CAST(@count AS NVARCHAR(10)) + ' record(s)';
        FETCH NEXT FROM invalid_cursor INTO @invalidRole, @count;
    END
    
    CLOSE invalid_cursor;
    DEALLOCATE invalid_cursor;
    
    PRINT '';
    PRINT '   These will be fixed before adding FK constraint...';
END
ELSE
    PRINT '   ✓ No orphaned role references found';

PRINT '';
GO

-- ==================================================
-- 2. INSERT DEFAULT SYSTEM ROLES
-- ==================================================
PRINT '2. Inserting default system roles...';
PRINT '';

-- Global roles
IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = 'global:owner')
BEGIN
    INSERT INTO [n8n].[role] ([slug], [displayName], [description], [roleType], [systemRole])
    VALUES ('global:owner', 'Owner', 'Global owner role', 'global', 1);
    PRINT '   ✓ Inserted role: global:owner';
END
ELSE
    PRINT '   • Role already exists: global:owner';

IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = 'global:admin')
BEGIN
    INSERT INTO [n8n].[role] ([slug], [displayName], [description], [roleType], [systemRole])
    VALUES ('global:admin', 'Admin', 'Global admin role', 'global', 1);
    PRINT '   ✓ Inserted role: global:admin';
END
ELSE
    PRINT '   • Role already exists: global:admin';

IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = 'global:member')
BEGIN
    INSERT INTO [n8n].[role] ([slug], [displayName], [description], [roleType], [systemRole])
    VALUES ('global:member', 'Member', 'Global member role', 'global', 1);
    PRINT '   ✓ Inserted role: global:member';
END
ELSE
    PRINT '   • Role already exists: global:member';

-- Project roles
IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = 'project:admin')
BEGIN
    INSERT INTO [n8n].[role] ([slug], [displayName], [description], [roleType], [systemRole])
    VALUES ('project:admin', 'Project Admin', 'Project admin role', 'project', 1);
    PRINT '   ✓ Inserted role: project:admin';
END
ELSE
    PRINT '   • Role already exists: project:admin';

IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = 'project:editor')
BEGIN
    INSERT INTO [n8n].[role] ([slug], [displayName], [description], [roleType], [systemRole])
    VALUES ('project:editor', 'Project Editor', 'Project editor role', 'project', 1);
    PRINT '   ✓ Inserted role: project:editor';
END
ELSE
    PRINT '   • Role already exists: project:editor';

IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = 'project:viewer')
BEGIN
    INSERT INTO [n8n].[role] ([slug], [displayName], [description], [roleType], [systemRole])
    VALUES ('project:viewer', 'Project Viewer', 'Project viewer role', 'project', 1);
    PRINT '   ✓ Inserted role: project:viewer';
END
ELSE
    PRINT '   • Role already exists: project:viewer';

PRINT '';

-- ==================================================
-- 3. FIX ORPHANED ROLE REFERENCES
-- ==================================================
PRINT '3. Fixing orphaned role references in project_relation...';
PRINT '';

-- Update invalid role values to valid ones
-- Map common old roles to new roles
UPDATE [n8n].[project_relation]
SET [role] = 'project:admin'
WHERE [role] IN ('owner', 'admin', 'project:owner')
  AND NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = [n8n].[project_relation].[role]);

UPDATE [n8n].[project_relation]
SET [role] = 'project:editor'
WHERE [role] IN ('editor', 'member')
  AND NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = [n8n].[project_relation].[role]);

UPDATE [n8n].[project_relation]
SET [role] = 'project:viewer'
WHERE [role] IN ('viewer', 'guest')
  AND NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = [n8n].[project_relation].[role]);

-- For any remaining invalid roles, default to project:viewer (least privilege)
UPDATE [n8n].[project_relation]
SET [role] = 'project:viewer'
WHERE NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = [n8n].[project_relation].[role]);

-- Check if any orphaned records remain
DECLARE @remainingOrphans INT;
SELECT @remainingOrphans = COUNT(*)
FROM [n8n].[project_relation] pr
WHERE NOT EXISTS (SELECT 1 FROM [n8n].[role] r WHERE r.[slug] = pr.[role]);

IF @remainingOrphans = 0
    PRINT '   ✓ All project_relation records now have valid role references';
ELSE
    PRINT '   ⚠️  WARNING: ' + CAST(@remainingOrphans AS NVARCHAR(10)) + ' orphaned records still exist';

PRINT '';
GO

-- ==================================================
-- 4. ADD MISSING FOREIGN KEY CONSTRAINTS
-- ==================================================
PRINT '4. Adding missing foreign key constraints...';
PRINT '';

-- FK: project_relation.role -> role.slug
IF NOT EXISTS (
    SELECT 1 
    FROM sys.foreign_keys 
    WHERE name = 'FK_project_relation_role' 
    AND parent_object_id = OBJECT_ID('n8n.project_relation')
)
BEGIN
    PRINT '   Adding FK: project_relation.role -> role.slug';
    
    ALTER TABLE [n8n].[project_relation]
    ADD CONSTRAINT [FK_project_relation_role]
    FOREIGN KEY ([role])
    REFERENCES [n8n].[role]([slug]);
    
    PRINT '   ✓ FK created: FK_project_relation_role';
END
ELSE
    PRINT '   • FK already exists: FK_project_relation_role';
GO

PRINT '';

-- ==================================================
-- 5. INSERT DEFAULT SCOPES (Sample - n8n auto-creates more)
-- ==================================================
PRINT '5. Inserting core permission scopes...';
PRINT '';

-- Core scopes (comprehensive list for basic n8n functionality)
DECLARE @coreScopes TABLE (slug NVARCHAR(255), displayName NVARCHAR(255), description NVARCHAR(MAX));

INSERT INTO @coreScopes VALUES
    -- Project scopes
    ('project:create', 'Create Projects', 'Can create new projects'),
    ('project:read', 'Read Projects', 'Can view projects'),
    ('project:update', 'Update Projects', 'Can modify projects'),
    ('project:delete', 'Delete Projects', 'Can delete projects'),
    ('project:list', 'List Projects', 'Can list projects'),
    
    -- Workflow scopes
    ('workflow:create', 'Create Workflows', 'Can create new workflows'),
    ('workflow:read', 'Read Workflows', 'Can view workflows'),
    ('workflow:update', 'Update Workflows', 'Can modify workflows'),
    ('workflow:delete', 'Delete Workflows', 'Can delete workflows'),
    ('workflow:execute', 'Execute Workflows', 'Can execute workflows'),
    ('workflow:list', 'List Workflows', 'Can list workflows'),
    ('workflow:share', 'Share Workflows', 'Can share workflows'),
    ('workflow:move', 'Move Workflows', 'Can move workflows between projects'),
    
    -- Credential scopes
    ('credential:create', 'Create Credentials', 'Can create new credentials'),
    ('credential:read', 'Read Credentials', 'Can view credentials'),
    ('credential:update', 'Update Credentials', 'Can modify credentials'),
    ('credential:delete', 'Delete Credentials', 'Can delete credentials'),
    ('credential:list', 'List Credentials', 'Can list credentials'),
    ('credential:share', 'Share Credentials', 'Can share credentials'),
    ('credential:move', 'Move Credentials', 'Can move credentials between projects'),
    
    -- Tag scopes (THIS IS WHAT WAS MISSING!)
    ('tag:create', 'Create Tags', 'Can create new tags'),
    ('tag:read', 'Read Tags', 'Can view tags'),
    ('tag:update', 'Update Tags', 'Can modify tags'),
    ('tag:delete', 'Delete Tags', 'Can delete tags'),
    ('tag:list', 'List Tags', 'Can list tags'),
    
    -- Execution scopes
    ('execution:read', 'Read Executions', 'Can view execution history'),
    ('execution:list', 'List Executions', 'Can list executions'),
    
    -- User scopes
    ('user:list', 'List Users', 'Can list users'),
    ('user:create', 'Create Users', 'Can create users'),
    
    -- Variable scopes
    ('variable:create', 'Create Variables', 'Can create variables'),
    ('variable:read', 'Read Variables', 'Can read variables'),
    ('variable:update', 'Update Variables', 'Can update variables'),
    ('variable:delete', 'Delete Variables', 'Can delete variables'),
    ('variable:list', 'List Variables', 'Can list variables'),
    
    -- Data table scopes
    ('dataTable:create', 'Create Data Tables', 'Can create data tables'),
    ('dataTable:read', 'Read Data Tables', 'Can read data tables'),
    ('dataTable:update', 'Update Data Tables', 'Can update data tables'),
    ('dataTable:delete', 'Delete Data Tables', 'Can delete data tables'),
    ('dataTable:list', 'List Data Tables', 'Can list data tables');

DECLARE @slug NVARCHAR(255), @displayName NVARCHAR(255), @description NVARCHAR(MAX);
DECLARE @scopeCount INT = 0;

DECLARE scope_cursor CURSOR FOR SELECT slug, displayName, description FROM @coreScopes;
OPEN scope_cursor;
FETCH NEXT FROM scope_cursor INTO @slug, @displayName, @description;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [n8n].[scope] WHERE [slug] = @slug)
    BEGIN
        INSERT INTO [n8n].[scope] ([slug], [displayName], [description])
        VALUES (@slug, @displayName, @description);
        SET @scopeCount = @scopeCount + 1;
    END
    FETCH NEXT FROM scope_cursor INTO @slug, @displayName, @description;
END

CLOSE scope_cursor;
DEALLOCATE scope_cursor;

IF @scopeCount > 0
    PRINT '   ✓ Inserted ' + CAST(@scopeCount AS NVARCHAR(10)) + ' new scope(s)';
ELSE
    PRINT '   • All core scopes already exist';

PRINT '';
PRINT '   NOTE: n8n may auto-create additional scopes at startup.';
PRINT '   We added ~39 essential scopes (project, workflow, credential, tag, execution, etc.)';

PRINT '';

-- ==================================================
-- 6. LINK ROLES TO SCOPES (Sample mappings)
-- ==================================================
PRINT '6. Linking roles to scopes...';
PRINT '';

-- Link global:member to basic scopes
DECLARE @roleScopeMappings TABLE (roleSlug NVARCHAR(255), scopeSlug NVARCHAR(255));

INSERT INTO @roleScopeMappings VALUES
    -- global:admin permissions (FULL ACCESS - all scopes)
    ('global:admin', 'project:create'),
    ('global:admin', 'project:read'),
    ('global:admin', 'project:update'),
    ('global:admin', 'project:delete'),
    ('global:admin', 'project:list'),
    ('global:admin', 'workflow:create'),
    ('global:admin', 'workflow:read'),
    ('global:admin', 'workflow:update'),
    ('global:admin', 'workflow:delete'),
    ('global:admin', 'workflow:execute'),
    ('global:admin', 'workflow:list'),
    ('global:admin', 'workflow:share'),
    ('global:admin', 'workflow:move'),
    ('global:admin', 'credential:create'),
    ('global:admin', 'credential:read'),
    ('global:admin', 'credential:update'),
    ('global:admin', 'credential:delete'),
    ('global:admin', 'credential:list'),
    ('global:admin', 'credential:share'),
    ('global:admin', 'credential:move'),
    ('global:admin', 'tag:create'),
    ('global:admin', 'tag:read'),
    ('global:admin', 'tag:update'),
    ('global:admin', 'tag:delete'),
    ('global:admin', 'tag:list'),
    ('global:admin', 'execution:read'),
    ('global:admin', 'execution:list'),
    ('global:admin', 'user:list'),
    ('global:admin', 'user:create'),
    ('global:admin', 'variable:create'),
    ('global:admin', 'variable:read'),
    ('global:admin', 'variable:update'),
    ('global:admin', 'variable:delete'),
    ('global:admin', 'variable:list'),
    ('global:admin', 'dataTable:create'),
    ('global:admin', 'dataTable:read'),
    ('global:admin', 'dataTable:update'),
    ('global:admin', 'dataTable:delete'),
    ('global:admin', 'dataTable:list'),
    
    -- global:member basic permissions
    ('global:member', 'workflow:read'),
    ('global:member', 'workflow:list'),
    ('global:member', 'workflow:create'),
    ('global:member', 'workflow:update'),
    ('global:member', 'workflow:execute'),
    ('global:member', 'credential:read'),
    ('global:member', 'credential:list'),
    ('global:member', 'credential:create'),
    ('global:member', 'tag:list'),
    ('global:member', 'tag:read'),
    ('global:member', 'execution:read'),
    ('global:member', 'execution:list'),
    
    -- project:admin permissions (full project access)
    ('project:admin', 'project:read'),
    ('project:admin', 'project:update'),
    ('project:admin', 'project:delete'),
    ('project:admin', 'workflow:read'),
    ('project:admin', 'workflow:list'),
    ('project:admin', 'workflow:create'),
    ('project:admin', 'workflow:update'),
    ('project:admin', 'workflow:delete'),
    ('project:admin', 'workflow:execute'),
    ('project:admin', 'workflow:share'),
    ('project:admin', 'workflow:move'),
    ('project:admin', 'credential:read'),
    ('project:admin', 'credential:list'),
    ('project:admin', 'credential:create'),
    ('project:admin', 'credential:update'),
    ('project:admin', 'credential:delete'),
    ('project:admin', 'credential:share'),
    ('project:admin', 'credential:move'),
    ('project:admin', 'tag:create'),
    ('project:admin', 'tag:read'),
    ('project:admin', 'tag:update'),
    ('project:admin', 'tag:delete'),
    ('project:admin', 'tag:list'),
    ('project:admin', 'execution:read'),
    ('project:admin', 'execution:list'),
    
    -- project:editor permissions
    ('project:editor', 'workflow:read'),
    ('project:editor', 'workflow:list'),
    ('project:editor', 'workflow:create'),
    ('project:editor', 'workflow:update'),
    ('project:editor', 'workflow:execute'),
    ('project:editor', 'credential:read'),
    ('project:editor', 'credential:list'),
    ('project:editor', 'credential:create'),
    ('project:editor', 'credential:update'),
    ('project:editor', 'tag:list'),
    ('project:editor', 'tag:read'),
    ('project:editor', 'execution:read'),
    ('project:editor', 'execution:list');

DECLARE @roleSlug NVARCHAR(255), @scopeSlug NVARCHAR(255);
DECLARE @mappingCount INT = 0;

DECLARE mapping_cursor CURSOR FOR SELECT roleSlug, scopeSlug FROM @roleScopeMappings;
OPEN mapping_cursor;
FETCH NEXT FROM mapping_cursor INTO @roleSlug, @scopeSlug;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Only insert if both role and scope exist
    IF EXISTS (SELECT 1 FROM [n8n].[role] WHERE [slug] = @roleSlug)
        AND EXISTS (SELECT 1 FROM [n8n].[scope] WHERE [slug] = @scopeSlug)
        AND NOT EXISTS (SELECT 1 FROM [n8n].[role_scope] WHERE [roleSlug] = @roleSlug AND [scopeSlug] = @scopeSlug)
    BEGIN
        INSERT INTO [n8n].[role_scope] ([roleSlug], [scopeSlug])
        VALUES (@roleSlug, @scopeSlug);
        SET @mappingCount = @mappingCount + 1;
    END
    FETCH NEXT FROM mapping_cursor INTO @roleSlug, @scopeSlug;
END

CLOSE mapping_cursor;
DEALLOCATE mapping_cursor;

IF @mappingCount > 0
    PRINT '   ✓ Created ' + CAST(@mappingCount AS NVARCHAR(10)) + ' role-scope mapping(s)';
ELSE
    PRINT '   • All role-scope mappings already exist';

PRINT '';
PRINT '   NOTE: These are basic role-scope mappings.';
PRINT '   n8n may auto-create additional mappings at startup.';

PRINT '';

-- ==================================================
-- 7. VERIFICATION
-- ==================================================
PRINT '7. Verifying schema...';
PRINT '';

DECLARE @roleCount INT, @fkExists BIT;

SELECT @roleCount = COUNT(*) FROM [n8n].[role];
SELECT @scopeCount = COUNT(*) FROM [n8n].[scope];
SELECT @mappingCount = COUNT(*) FROM [n8n].[role_scope];
SELECT @fkExists = CASE WHEN EXISTS (
    SELECT 1 FROM sys.foreign_keys 
    WHERE name = 'FK_project_relation_role' 
    AND parent_object_id = OBJECT_ID('n8n.project_relation')
) THEN 1 ELSE 0 END;

PRINT '   Roles: ' + CAST(@roleCount AS NVARCHAR(10));
PRINT '   Scopes: ' + CAST(@scopeCount AS NVARCHAR(10));
PRINT '   Role-Scope Mappings: ' + CAST(@mappingCount AS NVARCHAR(10));
PRINT '   FK (project_relation.role): ' + CASE WHEN @fkExists = 1 THEN 'EXISTS' ELSE 'MISSING' END;

IF @roleCount >= 6 AND @fkExists = 1
BEGIN
    PRINT '';
    PRINT '   ✓ Schema verification PASSED';
END
ELSE
BEGIN
    PRINT '';
    PRINT '   ⚠️  WARNING: Some elements may be missing';
    IF @roleCount < 6
        PRINT '   - Expected at least 6 roles, found ' + CAST(@roleCount AS NVARCHAR(10));
    IF @fkExists = 0
        PRINT '   - Missing FK: project_relation.role -> role.slug';
END

PRINT '';

-- ==================================================
-- 8. SUMMARY
-- ==================================================
PRINT '========================================';
PRINT 'Summary';
PRINT '========================================';
PRINT 'Database: ' + DB_NAME();
PRINT '';
PRINT 'What was fixed:';
PRINT '✓ Orphaned role references in project_relation';
PRINT '✓ Default system roles (global, project)';
PRINT '✓ Missing FK: project_relation.role -> role.slug';
PRINT '✓ Core permission scopes';
PRINT '✓ Basic role-scope mappings';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Run ELEVATE_MODE_PREREQUISITES.sql to create "n8nnet" project';
PRINT '2. Start n8n - it will auto-create any additional scopes';
PRINT '3. JWT users can now authenticate and auto-register';
PRINT '========================================';

GO

