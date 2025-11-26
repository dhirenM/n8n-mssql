-- SQL Script to verify and fix the credential

-- 1. First, check the current encrypted data length
SELECT 
    id,
    name,
    type,
    LEN(data) as encrypted_data_length,
    LEFT(data, 100) as encrypted_preview,
    updatedAt
FROM credentials_entity 
WHERE type = 'httpBearerAuth'
ORDER BY updatedAt DESC;

-- The encrypted_data_length should be around 1880+ characters for a full JWT
-- If it's much smaller, the data is truncated

-- 2. After you re-save the credential in n8n UI, run this again to compare:
-- The updatedAt should change and encrypted_data_length should increase

