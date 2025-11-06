// Script to view n8n database structure
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const os = require('os');

const dbPath = path.join(os.homedir(), '.n8n', 'database.sqlite');

const db = new sqlite3.Database(dbPath, sqlite3.OPEN_READONLY, (err) => {
  if (err) {
    console.error('❌ Error:', err.message);
    return;
  }
  
  console.log('📂 Database:', dbPath);
  console.log('');
  
  // Get all tables
  db.all("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name", [], (err, tables) => {
    if (err) {
      console.error('❌ Error:', err.message);
      return;
    }
    
    console.log('📊 DATABASE TABLES:');
    console.log('═'.repeat(80));
    
    let completed = 0;
    tables.forEach((table, index) => {
      const tableName = table.name;
      
      // Count rows in each table
      db.get(`SELECT COUNT(*) as count FROM "${tableName}"`, [], (err, result) => {
        if (!err) {
          console.log(`${(index + 1).toString().padStart(2)}. ${tableName.padEnd(35)} → ${result.count} rows`);
        }
        
        completed++;
        if (completed === tables.length) {
          console.log('═'.repeat(80));
          console.log(`\nTotal tables: ${tables.length}`);
          db.close();
        }
      });
    });
  });
});


