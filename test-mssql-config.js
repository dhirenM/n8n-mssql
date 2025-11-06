/**
 * Test MSSQL Configuration Generation
 * This shows exactly what configuration n8n is generating for MSSQL
 */

// Set environment variables
process.env.DB_TYPE = 'mssqldb';
process.env.DB_MSSQLDB_HOST = '10.242.218.73';
process.env.DB_MSSQLDB_PORT = '1433';
process.env.DB_MSSQLDB_DATABASE = 'dmnen_test';
process.env.DB_MSSQLDB_USER = 'qa';
process.env.DB_MSSQLDB_PASSWORD = 'bestqateam';
process.env.DB_MSSQLDB_SCHEMA = 'dbo';
process.env.DB_MSSQLDB_ENCRYPT = 'false';
process.env.DB_MSSQLDB_TRUST_SERVER_CERTIFICATE = 'true';

console.log('\n========================================');
console.log('Testing n8n MSSQL Configuration');
console.log('========================================\n');

try {
    // Load n8n's database configuration
    const { Container } = require('@n8n/di');
    const { GlobalConfig } = require('@n8n/config');
    const { DbConnectionOptions } = require('@n8n/db');
    
    // Get configuration
    const globalConfig = Container.get(GlobalConfig);
    const dbConfig = globalConfig.database;
    
    console.log('1. Database Type:', dbConfig.type);
    console.log('2. MSSQL Config:');
    console.log('   Host:', dbConfig.mssqldb.host);
    console.log('   Port:', dbConfig.mssqldb.port);
    console.log('   Database:', dbConfig.mssqldb.database);
    console.log('   User:', dbConfig.mssqldb.user);
    console.log('   Schema:', dbConfig.mssqldb.schema);
    console.log('   Encrypt:', dbConfig.mssqldb.encrypt);
    console.log('   Trust Cert:', dbConfig.mssqldb.trustServerCertificate);
    console.log('');
    
    // Get connection options
    const connectionOptions = Container.get(DbConnectionOptions);
    const options = connectionOptions.getOptions();
    
    console.log('3. Generated TypeORM Options:');
    console.log('   type:', options.type);
    console.log('   server:', options.server);
    console.log('   host:', options.host);
    console.log('   port:', options.port);
    console.log('   database:', options.database);
    console.log('   username:', options.username);
    console.log('   password:', '********');
    console.log('   schema:', options.schema);
    console.log('   encrypt:', options.options?.encrypt);
    console.log('   trustServerCertificate:', options.options?.trustServerCertificate);
    console.log('');
    
    // Check if server property is set correctly
    if (!options.server) {
        console.log('❌ ERROR: server property is NOT set!');
        console.log('   This will cause: "config.server property is required"\n');
        process.exit(1);
    } else if (typeof options.server !== 'string') {
        console.log('❌ ERROR: server property is not a string!');
        console.log('   Type:', typeof options.server);
        console.log('   Value:', options.server, '\n');
        process.exit(1);
    } else {
        console.log('✅ server property is set correctly:', options.server, '\n');
    }
    
    console.log('========================================');
    console.log('✅ Configuration looks good!');
    console.log('========================================\n');
    console.log('Ready to start n8n with MSSQL\n');
    
} catch (err) {
    console.log('❌ Error loading configuration:', err.message);
    console.log('\nStack:', err.stack);
    process.exit(1);
}

