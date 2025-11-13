-- ==================================================
-- Fix Existing JWT Users - Add Personal Projects
-- ==================================================
-- This script creates personal projects for JWT users
-- who were created before the personal project fix
-- ==================================================

USE [CMQA6];  -- Your database
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'Fix Existing JWT Users';
PRINT '========================================';
PRINT '';

-- Get project:admin role
DECLARE @ownerRoleSlug NVARCHAR(255) = 'project:admin';
DECLARE @ownerRole NVARCHAR(255);

SELECT @ownerRole = slug FROM [n8n].[role] WHERE slug = @ownerRoleSlug;

IF @ownerRole IS NULL
BEGIN
    PRINT '❌ Project admin role not found!';
    RETURN;
END

-- Find JWT users without personal projects
PRINT 'Finding JWT users without personal projects...';
PRINT '';

DECLARE @userId NVARCHAR(36);
DECLARE @email NVARCHAR(255);
DECLARE @firstName NVARCHAR(100);
DECLARE @lastName NVARCHAR(100);
DECLARE @personalProjectId NVARCHAR(36);
DECLARE @usersFixed INT = 0;

DECLARE user_cursor CURSOR FOR
    SELECT u.id, u.email, u.firstName, u.lastName
    FROM [n8n].[user] u
    WHERE u.password IS NULL  -- JWT users have no password
    AND NOT EXISTS (
        SELECT 1 
        FROM [n8n].project_relation pr
        INNER JOIN [n8n].project p ON pr.projectId = p.id
        WHERE pr.userId = u.id 
        AND p.type = 'personal'
    );

OPEN user_cursor;
FETCH NEXT FROM user_cursor INTO @userId, @email, @firstName, @lastName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Fixing user: ' + @email;
    
    -- Generate UUID for personal project
    SET @personalProjectId = NEWID();
    
    -- Create personal project
    INSERT INTO [n8n].project (id, name, type, icon, description, createdAt, updatedAt)
    VALUES (
        @personalProjectId,
        @firstName + '''s Project',
        'personal',
        NULL,
        'Personal project for JWT-authenticated user',
        GETDATE(),
        GETDATE()
    );
    
    PRINT '  ✓ Created personal project: ' + @firstName + '''s Project';
    
    -- Link user to their personal project
    INSERT INTO [n8n].project_relation (userId, projectId, role, createdAt, updatedAt)
    VALUES (
        @userId,
        @personalProjectId,
        @ownerRoleSlug,
        GETDATE(),
        GETDATE()
    );
    
    PRINT '  ✓ Linked user to personal project';
    PRINT '';
    
    SET @usersFixed = @usersFixed + 1;
    
    FETCH NEXT FROM user_cursor INTO @userId, @email, @firstName, @lastName;
END

CLOSE user_cursor;
DEALLOCATE user_cursor;

PRINT '========================================';
PRINT 'Summary';
PRINT '========================================';
PRINT 'Users fixed: ' + CAST(@usersFixed AS NVARCHAR(10));
PRINT '';

IF @usersFixed > 0
BEGIN
    PRINT '✅ All JWT users now have personal projects!';
    PRINT 'Restart n8n and refresh browser.';
END
ELSE
    PRINT 'No users needed fixing.';

PRINT '';
GO

