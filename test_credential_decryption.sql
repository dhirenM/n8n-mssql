-- Test decryption of the newly saved credential
-- Replace 'C9AFq8hanc7SsRox' with your credential ID if different

SELECT 
    id,
    name,
    LEN(data) as encrypted_length,
    -- Show first and last part of encrypted data to verify it's complete
    LEFT(data, 50) as encrypted_start,
    RIGHT(data, 50) as encrypted_end,
    updatedAt
FROM credentials_entity 
WHERE id = 'C9AFq8hanc7SsRox';

-- The encrypted data should be around 1880 chars
-- Now test if decryption returns the FULL token without "..."

