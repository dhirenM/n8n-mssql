-- ============================================================================
-- Fix Credentials Data Column Type for SQL Server
-- ============================================================================
-- This script converts the credentials_entity.data column from ntext to nvarchar(max)
-- to fix truncation issues with large credential data (like long JWT tokens)
--
-- Run this script if you're experiencing credential data truncation
-- ============================================================================

-- Check current column type
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'n8n'
  AND TABLE_NAME = 'credentials_entity'
  AND COLUMN_NAME = 'data';

-- Convert ntext to nvarchar(max) if needed
-- Replace 'n8n' with your actual schema name if different
ALTER TABLE [n8n].[credentials_entity] 
ALTER COLUMN [data] nvarchar(max) NOT NULL;

-- Verify the change
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'n8n'
  AND TABLE_NAME = 'credentials_entity'
  AND COLUMN_NAME = 'data';

-- After running this script:
-- 1. Restart n8n
-- 2. Re-save your credentials with the full JWT token
-- 3. The data should no longer be truncated

