/**
 * Check n8n Database Configuration
 * This script checks what database n8n is configured to use
 */

const fs = require('fs');
const path = require('path');

console.log('========================================');
console.log('n8n Database Configuration Check');
console.log('========================================\n');

// Check 1: Environment Variable
console.log('1. Checking DB_TYPE environment variable:');
const dbTypeEnv = process.env.DB_TYPE;
if (dbTypeEnv) {
    console.log(`   ✅ DB_TYPE = "${dbTypeEnv}"`);
} else {
    console.log('   ❌ DB_TYPE is not set in environment');
}
console.log('');

// Check 2: .env file
console.log('2. Checking .env file:');
const envPath = path.join(__dirname, 'packages', 'cli', '.env');
console.log(`   Location: ${envPath}`);

if (fs.existsSync(envPath)) {
    console.log('   ✅ .env file exists');
    
    const envContent = fs.readFileSync(envPath, 'utf-8');
    const lines = envContent.split('\n');
    
    // Find DB_TYPE line
    const dbTypeLine = lines.find(line => line.trim().startsWith('DB_TYPE=') && !line.trim().startsWith('#'));
    
    if (dbTypeLine) {
        const value = dbTypeLine.split('=')[1].trim();
        console.log(`   ✅ DB_TYPE in .env = "${value}"`);
        
        if (value === 'mssqldb') {
            console.log('   ✅ Correctly set to mssqldb');
        } else {
            console.log(`   ⚠️  Set to "${value}" instead of "mssqldb"`);
        }
    } else {
        console.log('   ❌ DB_TYPE not found in .env file');
    }
    
    // Check for MSSQL connection settings
    console.log('\n3. Checking MSSQL connection settings in .env:');
    const mssqlVars = [
        'DB_MSSQLDB_HOST',
        'DB_MSSQLDB_DATABASE',
        'DB_MSSQLDB_USER',
        'DB_MSSQLDB_PASSWORD'
    ];
    
    mssqlVars.forEach(varName => {
        const line = lines.find(l => l.trim().startsWith(`${varName}=`) && !l.trim().startsWith('#'));
        if (line) {
            const value = line.split('=')[1].trim();
            if (varName === 'DB_MSSQLDB_PASSWORD') {
                console.log(`   ✅ ${varName} = ${'*'.repeat(value.length)} (hidden)`);
            } else {
                console.log(`   ✅ ${varName} = "${value}"`);
            }
        } else {
            console.log(`   ❌ ${varName} not set`);
        }
    });
    
} else {
    console.log('   ❌ .env file NOT found');
    console.log(`   Expected location: ${envPath}`);
}
console.log('');

// Check 3: MSSQL package
console.log('4. Checking mssql package:');
try {
    require('mssql');
    console.log('   ✅ mssql package is installed');
} catch (e) {
    console.log('   ❌ mssql package NOT installed');
    console.log('   Run: pnpm add mssql --workspace-root');
}
console.log('');

// Check 4: Database file (if SQLite is being used)
console.log('5. Checking for SQLite database file:');
const sqlitePath = path.join(__dirname, '.n8n', 'database.sqlite');
if (fs.existsSync(sqlitePath)) {
    console.log(`   ⚠️  SQLite database exists at: ${sqlitePath}`);
    console.log('   This means n8n has been run with SQLite before');
    console.log('   Make sure to restart n8n to use MSSQL');
} else {
    console.log('   ✅ No SQLite database found');
}
console.log('');

// Summary
console.log('========================================');
console.log('Summary:');
console.log('========================================');

if (dbTypeEnv === 'mssqldb') {
    console.log('✅ Environment variable correctly set to mssqldb');
} else if (dbTypeLine && dbTypeLine.includes('mssqldb')) {
    console.log('⚠️  .env file has mssqldb, but environment variable not loaded');
    console.log('   Solution: Restart your terminal or explicitly set:');
    console.log('   $env:DB_TYPE = "mssqldb"');
} else {
    console.log('❌ Database not configured for MSSQL');
}

console.log('');
console.log('To ensure MSSQL is used:');
console.log('1. Make sure .env file is at: packages/cli/.env');
console.log('2. Verify DB_TYPE=mssqldb in .env file');
console.log('3. Restart n8n: cd packages/cli && pnpm start');
console.log('');


