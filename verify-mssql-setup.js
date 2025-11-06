/**
 * Verify MSSQL Setup for n8n
 * This script checks if everything is ready for n8n to use MSSQL
 */

const sql = require('mssql');

const config = {
    server: process.env.DB_MSSQLDB_HOST || '10.242.218.73',
    port: parseInt(process.env.DB_MSSQLDB_PORT) || 1433,
    database: process.env.DB_MSSQLDB_DATABASE || 'dmnen_test',
    user: process.env.DB_MSSQLDB_USER || 'qa',
    password: process.env.DB_MSSQLDB_PASSWORD || 'bestqateam',
    options: {
        encrypt: (process.env.DB_MSSQLDB_ENCRYPT || 'false') === 'true',
        trustServerCertificate: (process.env.DB_MSSQLDB_TRUST_SERVER_CERTIFICATE || 'true') === 'true',
        enableArithAbort: true
    }
};

async function verify() {
    console.log('\n========================================');
    console.log('n8n MSSQL Setup Verification');
    console.log('========================================\n');
    
    console.log('1. Checking mssql package...');
    try {
        require('mssql');
        console.log('   ✅ mssql package installed\n');
    } catch (e) {
        console.log('   ❌ mssql package NOT installed');
        console.log('   Run: cd C:\\Git\\n8n && pnpm add mssql --workspace-root\n');
        process.exit(1);
    }
    
    console.log('2. Testing SQL Server connection...');
    console.log('   Server:', config.server);
    console.log('   Database:', config.database);
    console.log('   User:', config.user);
    
    let pool;
    try {
        pool = await sql.connect(config);
        console.log('   ✅ Connected successfully\n');
    } catch (err) {
        console.log('   ❌ Connection FAILED');
        console.log('   Error:', err.message);
        console.log('\n   Check:');
        console.log('   - SQL Server is running');
        console.log('   - Hostname/IP is correct');
        console.log('   - Credentials are correct');
        console.log('   - Firewall allows connection\n');
        process.exit(1);
    }
    
    console.log('3. Checking if database exists...');
    try {
        const dbCheck = await pool.request().query(`
            SELECT name FROM sys.databases WHERE name = '${config.database}'
        `);
        if (dbCheck.recordset.length > 0) {
            console.log('   ✅ Database exists\n');
        } else {
            console.log('   ❌ Database does NOT exist');
            console.log('   Create it with: CREATE DATABASE ' + config.database + ';\n');
            await pool.close();
            process.exit(1);
        }
    } catch (err) {
        console.log('   ❌ Error checking database:', err.message, '\n');
        await pool.close();
        process.exit(1);
    }
    
    console.log('4. Checking if schema is created...');
    try {
        const tableCount = await pool.request().query(`
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_TYPE = 'BASE TABLE'
        `);
        const count = tableCount.recordset[0].count;
        console.log('   Tables found:', count);
        
        if (count === 0) {
            console.log('   ❌ NO TABLES! Schema not created!');
            console.log('\n   ACTION REQUIRED:');
            console.log('   Run this script in SQL Server Management Studio:');
            console.log('   C:\\Users\\dhirenm\\Documents\\SQL Server Management Studio\\n8n_schema_idempotent.sql\n');
            await pool.close();
            process.exit(1);
        } else if (count < 46) {
            console.log('   ⚠️  WARNING: Expected 46 tables, found', count);
            console.log('   Schema might be incomplete. Run: n8n_schema_idempotent.sql\n');
        } else {
            console.log('   ✅ Schema looks complete (46 tables)\n');
        }
    } catch (err) {
        console.log('   ❌ Error checking tables:', err.message, '\n');
        await pool.close();
        process.exit(1);
    }
    
    console.log('5. Checking critical tables...');
    const criticalTables = ['user', 'workflow_entity', 'execution_entity', 'credentials_entity', 'settings'];
    let allExist = true;
    
    for (const table of criticalTables) {
        const result = await pool.request().query(`
            SELECT COUNT(*) as count
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_NAME = '${table}'
        `);
        const exists = result.recordset[0].count > 0;
        console.log('   ', exists ? '✅' : '❌', table);
        if (!exists) allExist = false;
    }
    
    if (!allExist) {
        console.log('\n   ❌ Missing critical tables!');
        console.log('   Run: n8n_schema_idempotent.sql\n');
        await pool.close();
        process.exit(1);
    }
    
    console.log('\n========================================');
    console.log('✅ ALL CHECKS PASSED!');
    console.log('========================================\n');
    console.log('Your MSSQL setup is ready for n8n!\n');
    console.log('To start n8n:');
    console.log('  cd C:\\Git\\n8n\\packages\\cli');
    console.log('  pnpm dev\n');
    
    await pool.close();
}

verify().catch(err => {
    console.error('\n❌ Verification failed:', err.message);
    process.exit(1);
});

