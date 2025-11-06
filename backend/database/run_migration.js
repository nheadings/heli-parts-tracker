const pool = require('../config/database');
const fs = require('fs');
const path = require('path');

async function runMigration() {
  const migrationPath = path.join(__dirname, 'migrations', 'add_life_limited_to_parts.sql');
  const sql = fs.readFileSync(migrationPath, 'utf8');

  try {
    await pool.query(sql);
    console.log('Migration completed successfully');
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
