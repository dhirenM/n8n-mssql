// Simple script to view n8n users from SQLite database
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const os = require('os');

const dbPath = path.join(os.homedir(), '.n8n', 'database.sqlite');

console.log('📂 Database location:', dbPath);
console.log('');

const db = new sqlite3.Database(dbPath, sqlite3.OPEN_READONLY, (err) => {
  if (err) {
    console.error('❌ Error opening database:', err.message);
    return;
  }
  
  console.log('✅ Connected to database successfully!\n');
  
  // Query users
  db.all('SELECT id, email, firstName, lastName, disabled, mfaEnabled, createdAt, updatedAt FROM user', [], (err, rows) => {
    if (err) {
      console.error('❌ Error querying users:', err.message);
      return;
    }
    
    console.log('👥 USERS IN DATABASE:');
    console.log('═'.repeat(80));
    
    if (rows.length === 0) {
      console.log('No users found. You may need to complete the n8n setup first.');
    } else {
      rows.forEach((row, index) => {
        console.log(`\n${index + 1}. User ID: ${row.id}`);
        console.log(`   Email: ${row.email || 'N/A'}`);
        console.log(`   Name: ${row.firstName || 'N/A'} ${row.lastName || 'N/A'}`);
        console.log(`   Status: ${row.disabled ? '❌ Disabled' : '✅ Active'}`);
        console.log(`   MFA: ${row.mfaEnabled ? '🔐 Enabled' : 'Disabled'}`);
        console.log(`   Created: ${row.createdAt}`);
        console.log(`   Updated: ${row.updatedAt}`);
      });
    }
    
    console.log('\n' + '═'.repeat(80));
    console.log(`Total users: ${rows.length}`);
    
    // Close the database connection
    db.close((err) => {
      if (err) {
        console.error('Error closing database:', err.message);
      }
    });
  });
});


