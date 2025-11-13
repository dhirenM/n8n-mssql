-- ==================================================
-- Debug User Permissions
-- ==================================================
-- Use this to troubleshoot "User is missing a scope" errors
-- Shows exactly what permissions a user has
-- ==================================================

USE [CMQA6]; -- Your database
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'User Permission Debug';
PRINT '========================================';
PRINT '';

-- Change this to the JWT user's email
DECLARE @userEmail NVARCHAR(255) = 'your-jwt-user@example.com'; -- CHANGE THIS!

-- ==================================================
-- 1. FIND THE USER
-- ==================================================
PRINT '1. Looking up user...';
PRINT '';

DECLARE @userId NVARCHAR(36);
DECLARE @userRoleSlug NVARCHAR(255);

SELECT 
    @userId = id,
    @userRoleSlug = roleSlug
FROM [n8n].[user] 
WHERE email = @userEmail;

IF @userId IS NULL
BEGIN
    PRINT '   ❌ User not found: ' + @userEmail;
    PRINT '';
    PRINT 'Available users:';
    SELECT TOP 10 email, roleSlug FROM [n8n].[user];
    RETURN;
END
ELSE
BEGIN
    PRINT '   ✓ Found user:';
    PRINT '     Email: ' + @userEmail;
    PRINT '     User ID: ' + @userId;
    PRINT '     Global Role: ' + ISNULL(@userRoleSlug, 'NULL');
END

PRINT '';

-- ==================================================
-- 2. CHECK USER'S GLOBAL ROLE SCOPES
-- ==================================================
PRINT '2. Global role scopes (from user.roleSlug):';
PRINT '';

SELECT 
    r.slug AS role,
    r.displayName,
    r.roleType,
    r.systemRole,
    COUNT(rs.scopeSlug) AS scopeCount
FROM [n8n].[role] r
LEFT JOIN [n8n].[role_scope] rs ON r.slug = rs.roleSlug
WHERE r.slug = @userRoleSlug
GROUP BY r.slug, r.displayName, r.roleType, r.systemRole;

PRINT '';
PRINT 'Global scopes available to user:';

SELECT 
    rs.scopeSlug,
    s.displayName
FROM [n8n].[role_scope] rs
INNER JOIN [n8n].[scope] s ON rs.scopeSlug = s.slug
WHERE rs.roleSlug = @userRoleSlug
ORDER BY rs.scopeSlug;

PRINT '';

-- ==================================================
-- 3. CHECK USER'S PROJECT MEMBERSHIPS
-- ==================================================
PRINT '3. Project memberships:';
PRINT '';

SELECT 
    pr.projectId,
    p.name AS projectName,
    p.type AS projectType,
    pr.role AS projectRole,
    COUNT(rs.scopeSlug) AS projectScopeCount
FROM [n8n].[project_relation] pr
INNER JOIN [n8n].[project] p ON pr.projectId = p.id
INNER JOIN [n8n].[role] r ON pr.role = r.slug
LEFT JOIN [n8n].[role_scope] rs ON r.slug = rs.roleSlug
WHERE pr.userId = @userId
GROUP BY pr.projectId, p.name, p.type, pr.role;

PRINT '';

-- ==================================================
-- 4. CHECK PROJECT ROLE SCOPES
-- ==================================================
PRINT '4. Project-level scopes available to user:';
PRINT '';

SELECT 
    pr.role AS projectRole,
    p.name AS projectName,
    rs.scopeSlug,
    s.displayName AS scopeDisplayName
FROM [n8n].[project_relation] pr
INNER JOIN [n8n].[project] p ON pr.projectId = p.id
INNER JOIN [n8n].[role_scope] rs ON pr.role = rs.roleSlug
INNER JOIN [n8n].[scope] s ON rs.scopeSlug = s.slug
WHERE pr.userId = @userId
ORDER BY p.name, rs.scopeSlug;

PRINT '';

-- ==================================================
-- 5. ALL SCOPES COMBINED
-- ==================================================
PRINT '5. ALL scopes user has (global + project combined):';
PRINT '';

-- Global scopes
SELECT DISTINCT
    'GLOBAL' AS source,
    rs.scopeSlug,
    s.displayName
FROM [n8n].[role_scope] rs
INNER JOIN [n8n].[scope] s ON rs.scopeSlug = s.slug
WHERE rs.roleSlug = @userRoleSlug

UNION

-- Project scopes
SELECT DISTINCT
    'PROJECT: ' + p.name AS source,
    rs.scopeSlug,
    s.displayName
FROM [n8n].[project_relation] pr
INNER JOIN [n8n].[project] p ON pr.projectId = p.id
INNER JOIN [n8n].[role_scope] rs ON pr.role = rs.roleSlug
INNER JOIN [n8n].[scope] s ON rs.scopeSlug = s.slug
WHERE pr.userId = @userId

ORDER BY scopeSlug;

PRINT '';

-- ==================================================
-- 6. CHECK SPECIFIC SCOPES FOR TAGS ENDPOINT
-- ==================================================
PRINT '6. Checking scopes needed for /rest/tags endpoint...';
PRINT '';

-- Tags typically require tag:read or tag:list scope
DECLARE @hasTagRead BIT = 0;
DECLARE @hasTagList BIT = 0;

-- Check global role
IF EXISTS (
    SELECT 1 FROM [n8n].[role_scope] 
    WHERE roleSlug = @userRoleSlug 
    AND scopeSlug LIKE 'tag:%'
)
    SET @hasTagRead = 1;

-- Check project roles
IF EXISTS (
    SELECT 1 FROM [n8n].[project_relation] pr
    INNER JOIN [n8n].[role_scope] rs ON pr.role = rs.roleSlug
    WHERE pr.userId = @userId AND rs.scopeSlug LIKE 'tag:%'
)
    SET @hasTagRead = 1;

PRINT '   Has tag-related scope: ' + CASE WHEN @hasTagRead = 1 THEN 'YES ✓' ELSE 'NO ✗' END;

-- Show what tag scopes exist
PRINT '';
PRINT 'Available tag scopes in system:';
SELECT slug, displayName FROM [n8n].[scope] WHERE slug LIKE 'tag:%';

PRINT '';

-- ==================================================
-- 7. SUMMARY & DIAGNOSIS
-- ==================================================
PRINT '========================================';
PRINT 'Diagnosis';
PRINT '========================================';
PRINT '';

DECLARE @totalScopes INT;
SELECT @totalScopes = COUNT(DISTINCT scopeSlug)
FROM (
    SELECT scopeSlug FROM [n8n].[role_scope] WHERE roleSlug = @userRoleSlug
    UNION
    SELECT rs.scopeSlug 
    FROM [n8n].[project_relation] pr
    INNER JOIN [n8n].[role_scope] rs ON pr.role = rs.roleSlug
    WHERE pr.userId = @userId
) AS combined;

PRINT 'User: ' + @userEmail;
PRINT 'Global Role: ' + ISNULL(@userRoleSlug, 'NULL');
PRINT 'Total Scopes Available: ' + CAST(@totalScopes AS NVARCHAR(10));
PRINT '';

IF @totalScopes = 0
BEGIN
    PRINT '❌ PROBLEM FOUND: User has ZERO scopes!';
    PRINT '';
    PRINT 'Possible causes:';
    PRINT '  1. Role "' + @userRoleSlug + '" has no scopes in role_scope table';
    PRINT '  2. User is not linked to any project';
    PRINT '  3. MISSING_SCHEMA_FIX.sql was not run (role_scope table empty)';
    PRINT '';
    PRINT 'Solution:';
    PRINT '  Run MISSING_SCHEMA_FIX.sql to create role-scope mappings';
END
ELSE IF @hasTagRead = 0
BEGIN
    PRINT '⚠️  PROBLEM FOUND: User has ' + CAST(@totalScopes AS NVARCHAR(10)) + ' scopes, but NONE for tags!';
    PRINT '';
    PRINT 'User needs one of these scopes for /rest/tags:';
    PRINT '  - tag:read';
    PRINT '  - tag:list';
    PRINT '';
    PRINT 'Solution:';
    PRINT '  1. Check if tag scopes exist in scope table';
    PRINT '  2. Link tag scopes to user''s role in role_scope table';
    PRINT '  3. Or assign user global:admin role (has all scopes)';
END
ELSE
BEGIN
    PRINT '✓ User has ' + CAST(@totalScopes AS NVARCHAR(10)) + ' scopes';
    PRINT '✓ User has tag-related scopes';
    PRINT '';
    PRINT 'The 403 error might be caused by:';
    PRINT '  1. Cached permissions (restart n8n)';
    PRINT '  2. Different scope name than expected';
    PRINT '  3. Check n8n logs for which scope is required';
END

PRINT '';
PRINT '========================================';

GO

