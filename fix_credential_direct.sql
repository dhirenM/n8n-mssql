-- Direct database fix for the credential
-- This bypasses the unredact logic and forces the new encrypted data

-- Step 1: First, let's encrypt the FULL token using n8n's encryption
-- You'll need to do this through n8n's API or by creating a NEW credential
-- with the full token, then copying that encrypted value

-- Step 2: Or, delete the old credential and create a new one with the full token

-- RECOMMENDED APPROACH:
-- 1. In n8n UI, CREATE A NEW CREDENTIAL (don't edit the old one)
-- 2. Paste the FULL JWT token
-- 3. Save with a NEW name like "Bearer Auth account - FIXED"
-- 4. Update your workflows to use the new credential
-- 5. Delete the old broken credential

-- This ensures you start fresh with no old bad data being restored!

