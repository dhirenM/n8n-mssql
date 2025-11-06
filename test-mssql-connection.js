/**
 * MSSQL Connection Test Script
 * 
 * This script tests if n8n can connect to your SQL Server database
 * Run this BEFORE starting n8n to verify your configuration
 */

const sql = require('mssql');

// Configuration from environment variables or hardcoded values
const config = {
    server: process.env.DB_MSSQLDB_HOST || 'localhost',
    port: parseInt(process.env.DB_MSSQLDB_PORT) || 1433,
    database: process.env.DB_MSSQLDB_DATABASE || 'n8n_db',
    user: process.env.DB_MSSQLDB_USER || 'n8n_user',
    password: process.env.DB_MSSQLDB_PASSWORD || 'YourPassword123!',
    options: {
        encrypt: (process.env.DB_MSSQLDB_ENCRYPT || 'true') === 'true',
        trustServerCertificate: (process.env.DB_MSSQLDB_TRUST_SERVER_CERTIFICATE || 'true') === 'true',
        enableArithAbort: true,
        connectTimeout: parseInt(process.env.DB_MSSQLDB_CONNECTION_TIMEOUT) || 20000
    }
};

async function testConnection() {
    console.log('========================================');
    console.log('Testing MSSQL Connection for n8n');
    console.log('========================================\n');
    
    console.log('Configuration:');
    console.log('  Server:', config.server);
    console.log('  Port:', config.port);
    console.log('  Database:', config.database);
    console.log('  User:', config.user);
    console.log('  Encrypt:', config.options.encrypt);
    console.log('  Trust Certificate:', config.options.trustServerCertificate);
    console.log('  Timeout:', config.options.connectTimeout, 'ms');
    console.log('');

    let pool;
    
    try {
        console.log('⏳ Connecting to SQL Server...');
        pool = await sql.connect(config);
        console.log('✅ Connected to MSSQL successfully!\n');
        
        // Test 1: Get SQL Server version
        console.log('Test 1: Checking SQL Server version...');
        const versionResult = await pool.request().query('SELECT @@VERSION AS version');
        console.log('✅ Version:', versionResult.recordset[0].version.split('\n')[0]);
        console.log('');
        
        // Test 2: Check database
        console.log('Test 2: Checking database...');
        const dbResult = await pool.request().query('SELECT DB_NAME() AS current_db');
        console.log('✅ Current Database:', dbResult.recordset[0].current_db);
        console.log('');
        
        // Test 3: Count tables
        console.log('Test 3: Counting tables in database...');
        const tableResult = await pool.request().query(`
            SELECT COUNT(*) AS table_count 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_TYPE = 'BASE TABLE'
        `);
        const tableCount = tableResult.recordset[0].table_count;
        console.log('✅ Tables found:', tableCount);
        
        if (tableCount === 0) {
            console.log('⚠️  WARNING: No tables found!');
            console.log('   You need to run: n8n_schema_idempotent.sql');
        } else if (tableCount < 46) {
            console.log('⚠️  WARNING: Expected 46 tables, found', tableCount);
            console.log('   Some tables may be missing. Run: n8n_schema_idempotent.sql');
        } else {
            console.log('✅ Schema looks complete!');
        }
        console.log('');
        
        // Test 4: Check critical tables exist
        console.log('Test 4: Checking critical tables...');
        const criticalTables = [
            'user', 
            'workflow_entity', 
            'execution_entity', 
            'credentials_entity',
            'project',
            'role',
            'settings'
        ];
        
        for (const tableName of criticalTables) {
            const checkResult = await pool.request().query(`
                SELECT COUNT(*) AS exists_flag
                FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_NAME = '${tableName}'
            `);
            const exists = checkResult.recordset[0].exists_flag > 0;
            console.log(exists ? '✅' : '❌', tableName, exists ? '(exists)' : '(MISSING!)');
        }
        console.log('');
        
        // Test 5: Test write permission
        console.log('Test 5: Testing write permissions...');
        try {
            await pool.request().query(`
                IF NOT EXISTS (SELECT * FROM settings WHERE [key] = 'test_key')
                    INSERT INTO settings ([key], [value], [loadOnStartup]) VALUES ('test_key', 'test_value', 0)
                ELSE
                    UPDATE settings SET [value] = 'test_value' WHERE [key] = 'test_key'
            `);
            await pool.request().query(`DELETE FROM settings WHERE [key] = 'test_key'`);
            console.log('✅ Write permissions OK');
        } catch (writeError) {
            console.log('❌ Write permissions ERROR:', writeError.message);
        }
        console.log('');
        
        console.log('========================================');
        console.log('✅ All tests passed!');
        console.log('========================================');
        console.log('');
        console.log('Next steps:');
        console.log('1. Set environment variables in .env file');
        console.log('2. Run: pnpm build');
        console.log('3. Run: cd packages/cli && pnpm start');
        console.log('');
        
    } catch (err) {
        console.log('');
        console.log('========================================');
        console.log('❌ Connection FAILED!');
        console.log('========================================');
        console.log('');
        console.log('Error:', err.message);
        console.log('');
        
        if (err.code === 'ESOCKET') {
            console.log('Troubleshooting:');
            console.log('- Check if SQL Server is running');
            console.log('- Verify the hostname/IP is correct');
            console.log('- Check if port 1433 is accessible');
            console.log('- Check firewall settings');
        } else if (err.code === 'ELOGIN') {
            console.log('Troubleshooting:');
            console.log('- Verify username and password');
            console.log('- Check if SQL Server Authentication is enabled');
            console.log('- Verify user has permissions to the database');
        } else if (err.message.includes('certificate')) {
            console.log('Troubleshooting:');
            console.log('- Try setting: DB_MSSQLDB_TRUST_SERVER_CERTIFICATE=true');
            console.log('- Or install proper SSL certificate on SQL Server');
        } else if (err.message.includes('database')) {
            console.log('Troubleshooting:');
            console.log('- Create database: CREATE DATABASE n8n_db;');
            console.log('- Verify database name is correct');
        }
        console.log('');
        process.exit(1);
    } finally {
        if (pool) {
            await pool.close();
        }
    }
}

// Check if mssql package is installed
try {
    require.resolve('mssql');
} catch (e) {
    console.log('❌ ERROR: mssql package not installed!');
    console.log('');
    console.log('Install it with:');
    console.log('  cd C:\\Git\\n8n');
    console.log('  pnpm add mssql --workspace-root');
    console.log('');
    process.exit(1);
}

testConnection();


