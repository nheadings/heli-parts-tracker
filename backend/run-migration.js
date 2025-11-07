const pool = require('./config/database');
const fs = require('fs').promises;
const path = require('path');

async function runMigration(migrationFile) {
  try {
    console.log(`Running migration: ${migrationFile}`);

    const sqlPath = path.join(__dirname, 'database', 'migrations', migrationFile);
    const sql = await fs.readFile(sqlPath, 'utf8');

    await pool.query(sql);

    console.log(`✅ Migration completed: ${migrationFile}`);
    process.exit(0);
  } catch (error) {
    console.error(`❌ Migration failed: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

const migrationFile = process.argv[2];
if (!migrationFile) {
  console.error('Usage: node run-migration.js <migration-file>');
  process.exit(1);
}

runMigration(migrationFile);
