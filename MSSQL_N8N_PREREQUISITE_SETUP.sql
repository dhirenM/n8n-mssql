-- ============================================================================
-- n8n MSSQL - Complete Prerequisite Setup Script
-- ============================================================================
-- This script inserts required default records for n8n to function properly
-- Run this AFTER creating the schema (n8n_schema_initialization.sql)
-- Run this BEFORE starting n8n for the first time
-- ============================================================================
-- 
-- This script is IDEMPOTENT - safe to run multiple times
-- 
-- Database: Assumes you're using the 'n8n' schema
-- ============================================================================

USE [n8n_database];  -- Replace with your actual database name
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'n8n MSSQL Prerequisite Setup';
PRINT 'Using schema: n8n';
PRINT '========================================';
PRINT '';

-- ============================================================================
-- 1. Verify n8n Schema and Required Tables Exist
-- ============================================================================
PRINT '1. Verifying n8n schema and tables...';

-- Check schema exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'n8n')
BEGIN
    PRINT '   ❌ ERROR: n8n schema not found!';
    PRINT '   Please run n8n_schema_initialization.sql first to create the schema.';
    RAISERROR('n8n schema not found. Run n8n_schema_initialization.sql first.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✓ n8n schema exists';

-- Check required tables
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[role]') AND type in (N'U'))
BEGIN
    PRINT '   ❌ ERROR: n8n.role table not found!';
    PRINT '   Please run n8n_schema_initialization.sql first.';
    RAISERROR('Base schema not found. Run n8n_schema_initialization.sql first.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✓ n8n.role table exists';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[scope]') AND type in (N'U'))
BEGIN
    PRINT '   ❌ ERROR: n8n.scope table not found!';
    RAISERROR('n8n.scope table not found.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✓ n8n.scope table exists';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[user]') AND type in (N'U'))
BEGIN
    PRINT '   ❌ ERROR: n8n.user table not found!';
    RAISERROR('n8n.user table not found.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✓ n8n.user table exists';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[project]') AND type in (N'U'))
BEGIN
    PRINT '   ❌ ERROR: n8n.project table not found!';
    RAISERROR('n8n.project table not found.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✓ n8n.project table exists';

PRINT '';

-- ============================================================================
-- 2. Insert Required Scopes
-- ============================================================================
PRINT '2. Creating required permission scopes...';

-- Core scopes for n8n functionality
DECLARE @scopes TABLE (
    slug NVARCHAR(255),
    displayName NVARCHAR(255),
    description NVARCHAR(MAX)
);

INSERT INTO @scopes (slug, displayName, description) VALUES
    ('workflow:create', 'Create Workflows', 'Permission to create new workflows'),
    ('workflow:read', 'Read Workflows', 'Permission to view workflows'),
    ('workflow:update', 'Update Workflows', 'Permission to modify workflows'),
    ('workflow:delete', 'Delete Workflows', 'Permission to delete workflows'),
    ('workflow:execute', 'Execute Workflows', 'Permission to execute workflows'),
    ('workflow:share', 'Share Workflows', 'Permission to share workflows'),
    ('credential:create', 'Create Credentials', 'Permission to create credentials'),
    ('credential:read', 'Read Credentials', 'Permission to view credentials'),
    ('credential:update', 'Update Credentials', 'Permission to modify credentials'),
    ('credential:delete', 'Delete Credentials', 'Permission to delete credentials'),
    ('credential:share', 'Share Credentials', 'Permission to share credentials'),
    ('user:create', 'Create Users', 'Permission to create new users'),
    ('user:read', 'Read Users', 'Permission to view user information'),
    ('user:update', 'Update Users', 'Permission to modify user information'),
    ('user:delete', 'Delete Users', 'Permission to delete users'),
    ('project:create', 'Create Projects', 'Permission to create projects'),
    ('project:read', 'Read Projects', 'Permission to view projects'),
    ('project:update', 'Update Projects', 'Permission to modify projects'),
    ('project:delete', 'Delete Projects', 'Permission to delete projects'),
    ('tag:create', 'Create Tags', 'Permission to create tags'),
    ('tag:read', 'Read Tags', 'Permission to view tags'),
    ('tag:update', 'Update Tags', 'Permission to modify tags'),
    ('tag:delete', 'Delete Tags', 'Permission to delete tags'),
    ('variable:create', 'Create Variables', 'Permission to create environment variables'),
    ('variable:read', 'Read Variables', 'Permission to view environment variables'),
    ('variable:update', 'Update Variables', 'Permission to modify environment variables'),
    ('variable:delete', 'Delete Variables', 'Permission to delete environment variables'),
    ('sourceControl:pull', 'Pull from Version Control', 'Permission to pull from source control'),
    ('sourceControl:push', 'Push to Version Control', 'Permission to push to source control'),
    ('externalSecretsStore:sync', 'Sync External Secrets', 'Permission to sync external secrets'),
    ('auditLogs:manage', 'Manage Audit Logs', 'Permission to manage audit logs');

-- Insert scopes (idempotent)
DECLARE @scopeSlug NVARCHAR(255);
DECLARE @scopeDisplayName NVARCHAR(255);
DECLARE @scopeDescription NVARCHAR(MAX);

DECLARE scope_cursor CURSOR FOR
SELECT slug, displayName, description FROM @scopes;

OPEN scope_cursor;
FETCH NEXT FROM scope_cursor INTO @scopeSlug, @scopeDisplayName, @scopeDescription;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [n8n].[scope] WHERE slug = @scopeSlug)
    BEGIN
        INSERT INTO [n8n].[scope] (slug, displayName, description)
        VALUES (@scopeSlug, @scopeDisplayName, @scopeDescription);
        PRINT '   ✓ Created scope: ' + @scopeSlug;
    END
    ELSE
        PRINT '   - Scope already exists: ' + @scopeSlug;
    
    FETCH NEXT FROM scope_cursor INTO @scopeSlug, @scopeDisplayName, @scopeDescription;
END

CLOSE scope_cursor;
DEALLOCATE scope_cursor;

PRINT '';

-- ============================================================================
-- 3. Insert Required Global Roles
-- ============================================================================
PRINT '3. Creating required global roles...';

-- Insert global:owner role
IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE slug = 'global:owner')
BEGIN
    INSERT INTO [n8n].[role] (slug, displayName, description, roleType, systemRole, createdAt, updatedAt)
    VALUES ('global:owner', 'Owner', 'Instance owner with full permissions', 'global', 1, GETDATE(), GETDATE());
    PRINT '   ✓ Created role: global:owner';
END
ELSE
    PRINT '   - Role already exists: global:owner';

-- Insert global:admin role
IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE slug = 'global:admin')
BEGIN
    INSERT INTO [n8n].[role] (slug, displayName, description, roleType, systemRole, createdAt, updatedAt)
    VALUES ('global:admin', 'Admin', 'Administrator with elevated permissions', 'global', 1, GETDATE(), GETDATE());
    PRINT '   ✓ Created role: global:admin';
END
ELSE
    PRINT '   - Role already exists: global:admin';

-- Insert global:member role
IF NOT EXISTS (SELECT 1 FROM [n8n].[role] WHERE slug = 'global:member')
BEGIN
    INSERT INTO [n8n].[role] (slug, displayName, description, roleType, systemRole, createdAt, updatedAt)
    VALUES ('global:member', 'Member', 'Regular member with standard permissions', 'global', 1, GETDATE(), GETDATE());
    PRINT '   ✓ Created role: global:member';
END
ELSE
    PRINT '   - Role already exists: global:member';

PRINT '';

-- ============================================================================
-- 4. Map Scopes to Roles
-- ============================================================================
PRINT '4. Mapping scopes to roles...';

-- Owner gets ALL scopes
DECLARE @allScopes TABLE (scopeSlug NVARCHAR(255));
INSERT INTO @allScopes SELECT slug FROM [n8n].[scope];

DECLARE @currentScope NVARCHAR(255);
DECLARE owner_scope_cursor CURSOR FOR
SELECT scopeSlug FROM @allScopes;

OPEN owner_scope_cursor;
FETCH NEXT FROM owner_scope_cursor INTO @currentScope;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [n8n].[role_scope] WHERE roleSlug = 'global:owner' AND scopeSlug = @currentScope)
    BEGIN
        INSERT INTO [n8n].[role_scope] (roleSlug, scopeSlug)
        VALUES ('global:owner', @currentScope);
    END
    FETCH NEXT FROM owner_scope_cursor INTO @currentScope;
END

CLOSE owner_scope_cursor;
DEALLOCATE owner_scope_cursor;

PRINT '   ✓ Mapped all scopes to global:owner';

-- Admin gets most scopes (excluding user management)
DELETE FROM @allScopes;
INSERT INTO @allScopes 
SELECT slug FROM [n8n].[scope] 
WHERE slug NOT IN ('user:create', 'user:delete');

DECLARE admin_scope_cursor CURSOR FOR
SELECT scopeSlug FROM @allScopes;

OPEN admin_scope_cursor;
FETCH NEXT FROM admin_scope_cursor INTO @currentScope;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [n8n].[role_scope] WHERE roleSlug = 'global:admin' AND scopeSlug = @currentScope)
    BEGIN
        INSERT INTO [n8n].[role_scope] (roleSlug, scopeSlug)
        VALUES ('global:admin', @currentScope);
    END
    FETCH NEXT FROM admin_scope_cursor INTO @currentScope;
END

CLOSE admin_scope_cursor;
DEALLOCATE admin_scope_cursor;

PRINT '   ✓ Mapped scopes to global:admin';

-- Member gets basic scopes
DELETE FROM @allScopes;
INSERT INTO @allScopes VALUES 
    ('workflow:create'),
    ('workflow:read'),
    ('workflow:update'),
    ('workflow:execute'),
    ('credential:create'),
    ('credential:read'),
    ('credential:update'),
    ('tag:create'),
    ('tag:read'),
    ('variable:read'),
    ('project:read');

DECLARE member_scope_cursor CURSOR FOR
SELECT scopeSlug FROM @allScopes;

OPEN member_scope_cursor;
FETCH NEXT FROM member_scope_cursor INTO @currentScope;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [n8n].[role_scope] WHERE roleSlug = 'global:member' AND scopeSlug = @currentScope)
    BEGIN
        INSERT INTO [n8n].[role_scope] (roleSlug, scopeSlug)
        VALUES ('global:member', @currentScope);
    END
    FETCH NEXT FROM member_scope_cursor INTO @currentScope;
END

CLOSE member_scope_cursor;
DEALLOCATE member_scope_cursor;

PRINT '   ✓ Mapped scopes to global:member';
PRINT '';

-- ============================================================================
-- 5. Create Shell Owner User
-- ============================================================================
PRINT '5. Creating shell owner user...';

DECLARE @ownerUserId NVARCHAR(36);
DECLARE @existingOwnerId NVARCHAR(36);

-- Check if shell owner already exists
SELECT TOP 1 @existingOwnerId = id 
FROM [n8n].[user] u
WHERE u.roleSlug = 'global:owner';

IF @existingOwnerId IS NOT NULL
BEGIN
    PRINT '   - Shell owner user already exists: ' + @existingOwnerId;
    SET @ownerUserId = @existingOwnerId;
END
ELSE
BEGIN
    SET @ownerUserId = LOWER(CAST(NEWID() AS NVARCHAR(36)));
    
    INSERT INTO [n8n].[user] (
        id,
        email,
        firstName,
        lastName,
        password,
        personalizationAnswers,
        settings,
        disabled,
        mfaEnabled,
        mfaSecret,
        mfaRecoveryCodes,
        lastActiveAt,
        roleSlug,
        createdAt,
        updatedAt
    )
    VALUES (
        @ownerUserId,                    -- id (UUID)
        NULL,                            -- email (will be set during setup)
        NULL,                            -- firstName (will be set during setup)
        NULL,                            -- lastName (will be set during setup)
        NULL,                            -- password (will be set during setup)
        NULL,                            -- personalizationAnswers
        NULL,                            -- settings
        0,                               -- disabled (false)
        0,                               -- mfaEnabled (false)
        NULL,                            -- mfaSecret
        NULL,                            -- mfaRecoveryCodes
        NULL,                            -- lastActiveAt
        'global:owner',                  -- roleSlug
        GETDATE(),                       -- createdAt
        GETDATE()                        -- updatedAt
    );
    
    PRINT '   ✓ Shell owner user created: ' + @ownerUserId;
END

PRINT '';

-- ============================================================================
-- 6. Create Personal Project for Owner
-- ============================================================================
PRINT '6. Creating owner''s personal project...';

DECLARE @projectId NVARCHAR(36);
DECLARE @existingProjectId NVARCHAR(36);

-- Check if owner already has a personal project
SELECT TOP 1 @existingProjectId = pr.projectId
FROM [n8n].project_relation pr
INNER JOIN [n8n].project p ON pr.projectId = p.id
WHERE pr.userId = @ownerUserId 
  AND p.type = 'personal'
  AND pr.role = 'project:personalOwner';

IF @existingProjectId IS NOT NULL
BEGIN
    PRINT '   - Personal project already exists: ' + @existingProjectId;
END
ELSE
BEGIN
    -- Generate nano ID for project (21 characters)
    SET @projectId = REPLACE(LOWER(CAST(NEWID() AS NVARCHAR(36))), '-', '');
    SET @projectId = SUBSTRING(@projectId, 1, 21);
    
    INSERT INTO [n8n].project (id, name, type, icon, description, createdAt, updatedAt)
    VALUES (@projectId, 'My project', 'personal', NULL, NULL, GETDATE(), GETDATE());
    
    PRINT '   ✓ Personal project created: ' + @projectId;
    
    -- Link owner to project
    INSERT INTO [n8n].project_relation (projectId, userId, role, createdAt, updatedAt)
    VALUES (@projectId, @ownerUserId, 'project:personalOwner', GETDATE(), GETDATE());
    
    PRINT '   ✓ Owner linked to personal project';
END

PRINT '';

-- ============================================================================
-- 7. Create Required System Settings
-- ============================================================================
PRINT '7. Creating required system settings...';

-- userManagement.isInstanceOwnerSetUp (MUST be false for initial setup)
IF NOT EXISTS (SELECT 1 FROM [n8n].settings WHERE [key] = 'userManagement.isInstanceOwnerSetUp')
BEGIN
    INSERT INTO [n8n].settings ([key], value, loadOnStartup)
    VALUES ('userManagement.isInstanceOwnerSetUp', 'false', 1);
    PRINT '   ✓ Created setting: userManagement.isInstanceOwnerSetUp = false';
END
ELSE
BEGIN
    -- Force it to false to allow setup
    UPDATE [n8n].settings 
    SET value = 'false', loadOnStartup = 1
    WHERE [key] = 'userManagement.isInstanceOwnerSetUp';
    PRINT '   ✓ Updated setting: userManagement.isInstanceOwnerSetUp = false';
END

-- userManagement.skipInstanceOwnerSetup (should be false)
IF NOT EXISTS (SELECT 1 FROM [n8n].settings WHERE [key] = 'userManagement.skipInstanceOwnerSetup')
BEGIN
    INSERT INTO [n8n].settings ([key], value, loadOnStartup)
    VALUES ('userManagement.skipInstanceOwnerSetup', 'false', 1);
    PRINT '   ✓ Created setting: userManagement.skipInstanceOwnerSetup = false';
END

-- ui.banners.dismissed
IF NOT EXISTS (SELECT 1 FROM [n8n].settings WHERE [key] = 'ui.banners.dismissed')
BEGIN
    INSERT INTO [n8n].settings ([key], value, loadOnStartup)
    VALUES ('ui.banners.dismissed', '["V1"]', 1);
    PRINT '   ✓ Created setting: ui.banners.dismissed';
END

-- Community nodes installation (enable)
IF NOT EXISTS (SELECT 1 FROM [n8n].settings WHERE [key] = 'nodes.communityPackages.enabled')
BEGIN
    INSERT INTO [n8n].settings ([key], value, loadOnStartup)
    VALUES ('nodes.communityPackages.enabled', 'true', 1);
    PRINT '   ✓ Created setting: nodes.communityPackages.enabled = true';
END

-- Telemetry (you may want to disable this)
IF NOT EXISTS (SELECT 1 FROM [n8n].settings WHERE [key] = 'diagnostics.enabled')
BEGIN
    INSERT INTO [n8n].settings ([key], value, loadOnStartup)
    VALUES ('diagnostics.enabled', 'false', 1);
    PRINT '   ✓ Created setting: diagnostics.enabled = false';
END

-- Instance ID
IF NOT EXISTS (SELECT 1 FROM [n8n].settings WHERE [key] = 'instanceId')
BEGIN
    DECLARE @instanceId NVARCHAR(36) = LOWER(CAST(NEWID() AS NVARCHAR(36)));
    INSERT INTO [n8n].settings ([key], value, loadOnStartup)
    VALUES ('instanceId', @instanceId, 1);
    PRINT '   ✓ Created setting: instanceId = ' + @instanceId;
END

PRINT '';

-- ============================================================================
-- 8. Verification and Summary
-- ============================================================================
PRINT '8. Verification...';

DECLARE @userCount INT;
DECLARE @roleCount INT;
DECLARE @scopeCount INT;
DECLARE @projectCount INT;
DECLARE @settingsCount INT;

SELECT @userCount = COUNT(*) FROM [n8n].[user] WHERE roleSlug = 'global:owner';
SELECT @roleCount = COUNT(*) FROM [n8n].[role] WHERE slug IN ('global:owner', 'global:admin', 'global:member');
SELECT @scopeCount = COUNT(*) FROM [n8n].[scope];
SELECT @projectCount = COUNT(*) FROM [n8n].project p
    INNER JOIN [n8n].project_relation pr ON p.id = pr.projectId
    WHERE pr.userId = @ownerUserId AND p.type = 'personal';
SELECT @settingsCount = COUNT(*) FROM [n8n].settings 
    WHERE [key] IN ('userManagement.isInstanceOwnerSetUp', 'instanceId');

PRINT '';
PRINT '   Database Objects Created:';
PRINT '   -------------------------';
PRINT '   ✓ Shell owner users: ' + CAST(@userCount AS VARCHAR) + ' (expected: 1)';
PRINT '   ✓ Global roles: ' + CAST(@roleCount AS VARCHAR) + ' (expected: 3)';
PRINT '   ✓ Permission scopes: ' + CAST(@scopeCount AS VARCHAR) + ' (expected: 31+)';
PRINT '   ✓ Owner personal projects: ' + CAST(@projectCount AS VARCHAR) + ' (expected: 1)';
PRINT '   ✓ System settings: ' + CAST(@settingsCount AS VARCHAR) + ' (expected: 2+)';

IF @userCount >= 1 AND @roleCount >= 3 AND @projectCount >= 1 AND @settingsCount >= 2
BEGIN
    PRINT '';
    PRINT '========================================';
    PRINT '✅ PREREQUISITE SETUP COMPLETE!';
    PRINT '========================================';
    PRINT '';
    PRINT 'Database Schema: n8n';
    PRINT 'Shell Owner User ID: ' + @ownerUserId;
    PRINT '';
    PRINT 'Default Records Created:';
    PRINT '  • 3 Global Roles (owner, admin, member)';
    PRINT '  • 31+ Permission Scopes';
    PRINT '  • 1 Shell Owner User (placeholder)';
    PRINT '  • 1 Personal Project';
    PRINT '  • System Settings';
    PRINT '';
    PRINT 'Next Steps:';
    PRINT '  1. Start n8n using: .\START_N8N_MSSQL.ps1';
    PRINT '  2. Open browser: http://localhost:5678';
    PRINT '  3. Complete the owner setup form';
    PRINT '  4. The shell user will be updated with your credentials';
    PRINT '';
    PRINT 'IMPORTANT:';
    PRINT '  • userManagement.isInstanceOwnerSetUp = false';
    PRINT '  • This allows n8n to show the setup wizard';
    PRINT '  • After setup, this will be set to true automatically';
    PRINT '';
    PRINT '========================================';
END
ELSE
BEGIN
    PRINT '';
    PRINT '⚠️  WARNING: Setup may be incomplete!';
    PRINT 'Please verify the counts above.';
    PRINT '';
    PRINT 'Expected values:';
    PRINT '  • Users: 1+';
    PRINT '  • Roles: 3';
    PRINT '  • Projects: 1+';
    PRINT '  • Settings: 2+';
END

PRINT '';
SET NOCOUNT OFF;
GO

