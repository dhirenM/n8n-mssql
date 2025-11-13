-- ==================================================
-- n8n Elevate Mode - Database Prerequisites Script
-- ==================================================
-- Run this script ONCE per tenant database (Voyager)
-- This sets up the minimum required data for n8n with JWT auth
-- ==================================================

USE [YourVoyagerDatabaseName]; -- CHANGE THIS TO YOUR TENANT DATABASE NAME
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'n8n Elevate Mode - Prerequisites Setup';
PRINT '========================================';
PRINT '';

-- ==================================================
-- IMPORTANT NOTE ABOUT ROLES:
-- ==================================================
-- Roles and scopes are AUTO-CREATED by n8n at startup!
-- You do NOT need to manually insert roles.
-- n8n will automatically create all system roles when it starts:
--   - global:owner, global:admin, global:member
--   - project:admin, project:editor, project:viewer
--   - workflow:owner, credential:owner, etc.
--
-- This script ONLY creates the default "n8nnet" project.
-- ==================================================

PRINT '1. Checking roles (should be auto-created by n8n)...';

-- Verify roles exist (should be created by n8n on first startup)
DECLARE @roleCount INT;
SELECT @roleCount = COUNT(*) FROM n8n.[role];

IF @roleCount = 0
BEGIN
    PRINT '   ⚠️  WARNING: No roles found!';
    PRINT '   Make sure to START n8n FIRST to let it create system roles.';
    PRINT '   Then run this script to create the default project.';
    PRINT '';
END
ELSE
BEGIN
    PRINT '   ✓ Found ' + CAST(@roleCount AS NVARCHAR(10)) + ' role(s) - created by n8n';
    
    -- Show which key roles exist
    IF EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = 'global:member')
        PRINT '   ✓ global:member exists';
    IF EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = 'project:editor')
        PRINT '   ✓ project:editor exists';
END

PRINT '';

-- ==================================================
-- 2. DEFAULT PROJECT - Create "n8nnet" team project
-- ==================================================
PRINT '2. Setting up default project...';

DECLARE @defaultProjectId UNIQUEIDENTIFIER;
DECLARE @defaultProjectName NVARCHAR(255) = 'n8nnet';

-- Check if project exists
SELECT @defaultProjectId = id 
FROM n8n.project 
WHERE name = @defaultProjectName AND type = 'team';

IF @defaultProjectId IS NULL
BEGIN
    SET @defaultProjectId = NEWID();
    
    INSERT INTO n8n.project (id, name, type, icon, description, createdAt, updatedAt)
    VALUES (
        @defaultProjectId,
        @defaultProjectName,
        'team',  -- Team project (shared by all JWT users)
        NULL,
        'Default project for Elevate mode JWT-authenticated users',
        GETDATE(),
        GETDATE()
    );
    
    PRINT '   ✓ Created default project: ' + @defaultProjectName;
    PRINT '   • Project ID: ' + CAST(@defaultProjectId AS NVARCHAR(50));
END
ELSE
BEGIN
    PRINT '   • Project already exists: ' + @defaultProjectName;
    PRINT '   • Project ID: ' + CAST(@defaultProjectId AS NVARCHAR(50));
END

PRINT '';

-- ==================================================
-- 3. VERIFICATION - Check all prerequisites
-- ==================================================
PRINT '3. Verifying prerequisites...';

DECLARE @verifyRoleCount INT;
DECLARE @verifyProjectCount INT;

SELECT @verifyRoleCount = COUNT(*) FROM n8n.[role];
SELECT @verifyProjectCount = COUNT(*) FROM n8n.project WHERE name = @defaultProjectName;

IF @verifyProjectCount = 1
BEGIN
    PRINT '   ✓ Prerequisites verified successfully!';
    PRINT '   • Roles in database: ' + CAST(@verifyRoleCount AS NVARCHAR(10)) + ' (auto-created by n8n)';
    PRINT '   • Default project exists: Yes';
    
    IF @verifyRoleCount = 0
    BEGIN
        PRINT '';
        PRINT '   ⚠️  WARNING: No roles found yet.';
        PRINT '   Start n8n to auto-create system roles before JWT users login.';
    END
END
ELSE
BEGIN
    PRINT '   ✗ Verification failed!';
    PRINT '   • Default project found: ' + CAST(@verifyProjectCount AS NVARCHAR(10)) + ' (expected: 1)';
    PRINT '   Please check the error messages above.';
END

PRINT '';

-- ==================================================
-- 4. SUMMARY - Display configuration info
-- ==================================================
PRINT '========================================';
PRINT 'Setup Summary';
PRINT '========================================';
PRINT 'Database: ' + DB_NAME();
PRINT 'Default Project: ' + @defaultProjectName;
PRINT 'Default Project ID: ' + CAST(@defaultProjectId AS NVARCHAR(50));
PRINT '';
PRINT 'Deployment Order:';
PRINT '1. START n8n FIRST to auto-create roles & scopes';
PRINT '2. Run this script to create "n8nnet" default project';
PRINT '3. Configure JWT settings (DOTNET_AUDIENCE_SECRET, etc.)';
PRINT '4. Restart n8n with JWT enabled';
PRINT '5. JWT users will auto-register and join "n8nnet" project';
PRINT '';
PRINT 'Note: Roles (global:member, project:editor, etc.) are';
PRINT 'automatically created by n8n at startup. You do NOT need';
PRINT 'to manually insert roles.';
PRINT '========================================';

GO

