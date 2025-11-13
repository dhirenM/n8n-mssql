-- ============================================================
-- Debug: Check Elevate DB for Default Subdomain
-- ============================================================

USE elevate_multitenant_mssql_dev;
GO

-- Check if 'pmgroup' company exists
SELECT 
    domain,
    db_server,
    db_name,
    db_user,
    inactive,
    issql
FROM company 
WHERE domain = 'pmgroup';
GO

-- If no results, check all companies:
SELECT TOP 10
    domain,
    db_server,
    db_name,
    inactive
FROM company
ORDER BY domain;
GO

-- Check what the default subdomain should be:
SELECT 
    domain,
    db_server,
    db_name
FROM company
WHERE inactive = 0
ORDER BY domain;
GO

