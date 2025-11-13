-- ==================================================
-- Add User to n8nnet Project - Quick Fix
-- ==================================================
-- Use this to manually add a user to the n8nnet project
-- if they're not auto-added by JWT middleware
-- ==================================================

USE [YourVoyagerDatabaseName]; -- CHANGE THIS TO YOUR TENANT DATABASE NAME
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'Add User to n8nnet Project';
PRINT '========================================';
PRINT 'Database: ' + DB_NAME();
PRINT '';

-- ==================================================
-- 1. FIND THE USER
-- ==================================================
PRINT '1. Looking for user...';
PRINT '';

-- Find the first user (or specify an email)
DECLARE @userEmail NVARCHAR(255);
DECLARE @userId UNIQUEIDENTIFIER;

-- OPTION A: Use the first user in the database
SELECT TOP 1 @userId = id, @userEmail = email 
FROM n8n.[user] 
ORDER BY createdAt DESC;

-- OPTION B: Uncomment and specify a specific user email
-- SET @userEmail = 'your.email@example.com';
-- SELECT @userId = id FROM n8n.[user] WHERE email = @userEmail;

IF @userId IS NULL
BEGIN
    PRINT '   ✗ ERROR: No user found!';
    PRINT '   Make sure you have logged in at least once via JWT';
    PRINT '';
    RETURN;
END

PRINT '   ✓ Found user: ' + @userEmail;
PRINT '   • User ID: ' + CAST(@userId AS NVARCHAR(50));
PRINT '';

-- ==================================================
-- 2. FIND THE n8nnet PROJECT
-- ==================================================
PRINT '2. Looking for n8nnet project...';
PRINT '';

DECLARE @projectId UNIQUEIDENTIFIER;
DECLARE @projectName NVARCHAR(255) = 'n8nnet';

SELECT @projectId = id 
FROM n8n.[project] 
WHERE name = @projectName AND type = 'team';

IF @projectId IS NULL
BEGIN
    PRINT '   ✗ ERROR: n8nnet project not found!';
    PRINT '   Run ELEVATE_MODE_PREREQUISITES.sql first';
    PRINT '';
    RETURN;
END

PRINT '   ✓ Found project: ' + @projectName;
PRINT '   • Project ID: ' + CAST(@projectId AS NVARCHAR(50));
PRINT '';

-- ==================================================
-- 3. CHECK IF USER IS ALREADY A MEMBER
-- ==================================================
PRINT '3. Checking current membership...';
PRINT '';

IF EXISTS (
    SELECT 1 
    FROM n8n.[project_relation] 
    WHERE userId = @userId 
    AND projectId = @projectId
)
BEGIN
    DECLARE @currentRole NVARCHAR(255);
    SELECT @currentRole = role 
    FROM n8n.[project_relation] 
    WHERE userId = @userId 
    AND projectId = @projectId;
    
    PRINT '   • User is already a member of ' + @projectName;
    PRINT '   • Current role: ' + @currentRole;
    PRINT '';
    
    -- Check if they have the right role
    IF @currentRole = 'project:admin'
    BEGIN
        PRINT '   ✓ User has project:admin role (full access)';
        PRINT '   ✓ User should be able to create workflows';
    END
    ELSE IF @currentRole = 'project:editor'
    BEGIN
        PRINT '   ✓ User has project:editor role (can create workflows)';
    END
    ELSE
    BEGIN
        PRINT '   ⚠️  User has role: ' + @currentRole;
        PRINT '   This role might not have workflow:create permission';
        PRINT '';
        PRINT '   Do you want to upgrade to project:admin? (y/n)';
        PRINT '   If yes, run this update:';
        PRINT '';
        PRINT '   UPDATE n8n.[project_relation]';
        PRINT '   SET role = ''project:admin''';
        PRINT '   WHERE userId = ''' + CAST(@userId AS NVARCHAR(50)) + '''';
        PRINT '   AND projectId = ''' + CAST(@projectId AS NVARCHAR(50)) + ''';';
    END
END
ELSE
BEGIN
    PRINT '   ✗ User is NOT a member of ' + @projectName;
    PRINT '';
    
    -- ==================================================
    -- 4. ADD USER TO PROJECT
    -- ==================================================
    PRINT '4. Adding user to project...';
    PRINT '';
    
    -- Get the project:admin role
    DECLARE @projectRole NVARCHAR(255) = 'project:admin';
    
    -- Verify the role exists
    IF NOT EXISTS (SELECT 1 FROM n8n.[role] WHERE slug = @projectRole)
    BEGIN
        PRINT '   ✗ ERROR: Role ' + @projectRole + ' not found!';
        PRINT '   Run MISSING_SCHEMA_FIX.sql first';
        PRINT '';
        RETURN;
    END
    
    -- Create the project relation
    INSERT INTO n8n.[project_relation] (userId, projectId, role)
    VALUES (@userId, @projectId, @projectRole);
    
    PRINT '   ✓ Successfully added user to project!';
    PRINT '   • User: ' + @userEmail;
    PRINT '   • Project: ' + @projectName;
    PRINT '   • Role: ' + @projectRole;
END

PRINT '';

-- ==================================================
-- 5. VERIFY THE RESULT
-- ==================================================
PRINT '5. Verifying result...';
PRINT '';

-- Show all projects for this user
PRINT '   User: ' + @userEmail;
PRINT '   Project memberships:';
PRINT '';

DECLARE @verifyProjName NVARCHAR(255), @verifyRole NVARCHAR(255);
DECLARE verify_cursor CURSOR FOR
    SELECT p.name, pr.role
    FROM n8n.[project_relation] pr
    JOIN n8n.[project] p ON pr.projectId = p.id
    WHERE pr.userId = @userId;

OPEN verify_cursor;
FETCH NEXT FROM verify_cursor INTO @verifyProjName, @verifyRole;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '   • ' + @verifyProjName + ' (role: ' + @verifyRole + ')';
    FETCH NEXT FROM verify_cursor INTO @verifyProjName, @verifyRole;
END

CLOSE verify_cursor;
DEALLOCATE verify_cursor;

PRINT '';

-- ==================================================
-- 6. FINAL INSTRUCTIONS
-- ==================================================
PRINT '========================================';
PRINT 'Next Steps';
PRINT '========================================';
PRINT '';
PRINT '1. Clear browser cache and cookies';
PRINT '2. Restart n8n (if running)';
PRINT '3. Log in again with your JWT token';
PRINT '4. Navigate to the workflows page';
PRINT '5. The "Create Workflow" button should now be enabled';
PRINT '';
PRINT 'If still disabled, check browser console for errors';
PRINT '========================================';

GO

