-- Debug: Check what's ACTUALLY in the database right now
SELECT 
    id,
    name,
    type,
    LEN(data) as encrypted_length,
    createdAt,
    updatedAt,
    -- Check if the encrypted data starts correctly (should be base64 starting with U2FsdGVk which is "Salted__")
    LEFT(data, 20) as encrypted_start,
    RIGHT(data, 20) as encrypted_end
FROM credentials_entity 
WHERE type = 'httpBearerAuth'
ORDER BY updatedAt DESC;

-- Show ALL credentials to see if there are multiple

