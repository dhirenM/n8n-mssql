-- ============================================================================
-- n8n MSSQL - Complete Prerequisite Setup Script
-- ============================================================================
-- This script prepares the MSSQL database for n8n
-- Run this ONCE before starting n8n for the first time
-- ============================================================================

USE dmnen_test;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

PRINT '========================================';
PRINT 'n8n MSSQL Prerequisite Setup';
PRINT '========================================';
PRINT '';

-- ============================================================================
-- 1. Verify Required Tables Exist
-- ============================================================================
PRINT '1. Checking required tables...';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[role]') AND type in (N'U'))
BEGIN
    PRINT '   ❌ ERROR: role table not found!';
    PRINT '   Please run n8n_schema_idempotent.sql first to create the base schema.';
    RAISERROR('Base schema not found. Run n8n_schema_idempotent.sql first.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✅ role table exists';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[user]') AND type in (N'U'))
BEGIN
    PRINT '   ❌ ERROR: user table not found!';
    PRINT '   Please run n8n_schema_idempotent.sql first to create the base schema.';
    RAISERROR('Base schema not found. Run n8n_schema_idempotent.sql first.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✅ user table exists';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project]') AND type in (N'U'))
BEGIN
    PRINT '   ❌ ERROR: project table not found!';
    PRINT '   Please run n8n_schema_idempotent.sql first to create the base schema.';
    RAISERROR('Base schema not found. Run n8n_schema_idempotent.sql first.', 16, 1);
    RETURN;
END
ELSE
    PRINT '   ✅ project table exists';

PRINT '';

-- ============================================================================
-- 2. Ensure Global Roles Exist
-- ============================================================================
PRINT '2. Checking/Creating global roles...';

-- Insert global:owner role
IF NOT EXISTS (SELECT 1 FROM dbo.[role] WHERE slug = 'global:owner')
BEGIN
    INSERT INTO dbo.[role] (slug, displayName, description, roleType, systemRole, createdAt, updatedAt)
    VALUES ('global:owner', 'Owner', 'Owner', 'global', 1, GETDATE(), GETDATE());
    PRINT '   ✅ Created role: global:owner';
END
ELSE
    PRINT '   ✓ Role already exists: global:owner';

-- Insert global:admin role
IF NOT EXISTS (SELECT 1 FROM dbo.[role] WHERE slug = 'global:admin')
BEGIN
    INSERT INTO dbo.[role] (slug, displayName, description, roleType, systemRole, createdAt, updatedAt)
    VALUES ('global:admin', 'Admin', 'Admin', 'global', 1, GETDATE(), GETDATE());
    PRINT '   ✅ Created role: global:admin';
END
ELSE
    PRINT '   ✓ Role already exists: global:admin';

-- Insert global:member role
IF NOT EXISTS (SELECT 1 FROM dbo.[role] WHERE slug = 'global:member')
BEGIN
    INSERT INTO dbo.[role] (slug, displayName, description, roleType, systemRole, createdAt, updatedAt)
    VALUES ('global:member', 'Member', 'Member', 'global', 1, GETDATE(), GETDATE());
    PRINT '   ✅ Created role: global:member';
END
ELSE
    PRINT '   ✓ Role already exists: global:member';

PRINT '';

-- ============================================================================
-- 3. Create Shell Owner User (if not exists)
-- ============================================================================
PRINT '3. Creating shell owner user...';

DECLARE @ownerUserId UNIQUEIDENTIFIER;
DECLARE @existingOwnerId UNIQUEIDENTIFIER;

-- Check if shell owner already exists
SELECT @existingOwnerId = id 
FROM dbo.[user] u
WHERE u.roleSlug = 'global:owner';

IF @existingOwnerId IS NOT NULL
BEGIN
    PRINT '   ✓ Shell owner user already exists: ' + CAST(@existingOwnerId AS VARCHAR(36));
    SET @ownerUserId = @existingOwnerId;
END
ELSE
BEGIN
    SET @ownerUserId = NEWID();
    
    INSERT INTO dbo.[user] (
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
        'global:owner',                  -- roleSlug
        GETDATE(),                       -- createdAt
        GETDATE()                        -- updatedAt
    );
    
    PRINT '   ✅ Shell owner user created: ' + CAST(@ownerUserId AS VARCHAR(36));
END

PRINT '';

-- ============================================================================
-- 4. Create Personal Project for Owner (if not exists)
-- ============================================================================
PRINT '4. Creating owner''s personal project...';

DECLARE @projectId VARCHAR(36);
DECLARE @existingProjectId VARCHAR(36);

-- Check if owner already has a personal project
SELECT TOP 1 @existingProjectId = pr.projectId
FROM dbo.project_relation pr
INNER JOIN dbo.project p ON pr.projectId = p.id
WHERE pr.userId = @ownerUserId 
  AND p.type = 'personal'
  AND pr.role = 'project:personalOwner';

IF @existingProjectId IS NOT NULL
BEGIN
    PRINT '   ✓ Personal project already exists: ' + @existingProjectId;
END
ELSE
BEGIN
    -- Generate nano ID for project (21 characters)
    SET @projectId = REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', '');
    SET @projectId = SUBSTRING(@projectId, 1, 21);
    
    INSERT INTO dbo.project (id, name, type, createdAt, updatedAt)
    VALUES (@projectId, 'Owner''s Personal Project', 'personal', GETDATE(), GETDATE());
    
    PRINT '   ✅ Personal project created: ' + @projectId;
    
    -- Link owner to project
    INSERT INTO dbo.project_relation (projectId, userId, role, createdAt, updatedAt)
    VALUES (@projectId, @ownerUserId, 'project:personalOwner', GETDATE(), GETDATE());
    
    PRINT '   ✅ Owner linked to project';
END

PRINT '';

-- ============================================================================
-- 5. Create Required Settings
-- ============================================================================
PRINT '5. Creating required settings...';

-- userManagement.isInstanceOwnerSetUp
IF NOT EXISTS (SELECT 1 FROM dbo.settings WHERE [key] = 'userManagement.isInstanceOwnerSetUp')
BEGIN
    INSERT INTO dbo.settings ([key], value, loadOnStartup)
    VALUES ('userManagement.isInstanceOwnerSetUp', 'false', 1);
    PRINT '   ✅ Created setting: userManagement.isInstanceOwnerSetUp = false';
END
ELSE
BEGIN
    UPDATE dbo.settings 
    SET value = 'false'
    WHERE [key] = 'userManagement.isInstanceOwnerSetUp';
    PRINT '   ✓ Updated setting: userManagement.isInstanceOwnerSetUp = false';
END

-- userManagement.skipInstanceOwnerSetup
IF NOT EXISTS (SELECT 1 FROM dbo.settings WHERE [key] = 'userManagement.skipInstanceOwnerSetup')
BEGIN
    INSERT INTO dbo.settings ([key], value, loadOnStartup)
    VALUES ('userManagement.skipInstanceOwnerSetup', 'false', 1);
    PRINT '   ✅ Created setting: userManagement.skipInstanceOwnerSetup = false';
END

-- ui.banners.dismissed (if not exists)
IF NOT EXISTS (SELECT 1 FROM dbo.settings WHERE [key] = 'ui.banners.dismissed')
BEGIN
    INSERT INTO dbo.settings ([key], value, loadOnStartup)
    VALUES ('ui.banners.dismissed', '["V1"]', 1);
    PRINT '   ✅ Created setting: ui.banners.dismissed';
END

PRINT '';

-- ============================================================================
-- 6. Verify Setup Complete
-- ============================================================================
PRINT '6. Verification...';

DECLARE @userCount INT;
DECLARE @roleCount INT;
DECLARE @projectCount INT;

SELECT @userCount = COUNT(*) FROM dbo.[user] WHERE roleSlug = 'global:owner';
SELECT @roleCount = COUNT(*) FROM dbo.[role] WHERE slug IN ('global:owner', 'global:admin', 'global:member');
SELECT @projectCount = COUNT(*) FROM dbo.project p
INNER JOIN dbo.project_relation pr ON p.id = pr.projectId
WHERE pr.userId = @ownerUserId AND p.type = 'personal';

PRINT '   ✓ Shell owner users: ' + CAST(@userCount AS VARCHAR);
PRINT '   ✓ Global roles: ' + CAST(@roleCount AS VARCHAR) + ' (expected: 3)';
PRINT '   ✓ Owner personal projects: ' + CAST(@projectCount AS VARCHAR);

IF @userCount >= 1 AND @roleCount >= 3 AND @projectCount >= 1
BEGIN
    PRINT '';
    PRINT '========================================';
    PRINT '✅ SETUP COMPLETE!';
    PRINT '========================================';
    PRINT '';
    PRINT 'n8n is ready for initialization!';
    PRINT '';
    PRINT 'Next steps:';
    PRINT '  1. Start n8n: .\START_N8N_MSSQL.ps1';
    PRINT '  2. Open browser: http://localhost:5678';
    PRINT '  3. Complete owner setup form';
    PRINT '';
    PRINT 'Shell owner user ID: ' + CAST(@ownerUserId AS VARCHAR(36));
    PRINT '========================================';
END
ELSE
BEGIN
    PRINT '';
    PRINT '⚠️  WARNING: Setup may be incomplete!';
    PRINT 'Please verify the counts above.';
END

PRINT '';
GO

