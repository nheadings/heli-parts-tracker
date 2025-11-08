const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');
const fs = require('fs').promises;
const path = require('path');

// All routes require authentication and admin role
router.use(authenticateToken);
router.use((req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
});

// Run migration
router.post('/run-migration', async (req, res) => {
  const { migrationFile } = req.body;

  if (!migrationFile) {
    return res.status(400).json({ error: 'Migration file name required' });
  }

  try {
    console.log(`Running migration: ${migrationFile}`);

    const sqlPath = path.join(__dirname, '..', 'database', 'migrations', migrationFile);
    const sql = await fs.readFile(sqlPath, 'utf8');

    await pool.query(sql);

    console.log(`✅ Migration completed: ${migrationFile}`);
    res.json({ message: 'Migration completed successfully', file: migrationFile });
  } catch (error) {
    console.error(`❌ Migration failed: ${error.message}`);
    console.error(error);
    res.status(500).json({ error: 'Migration failed', details: error.message });
  }
});

module.exports = router;
