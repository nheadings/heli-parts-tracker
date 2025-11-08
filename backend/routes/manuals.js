const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// All routes require authentication
router.use(authenticateToken);

// Get all manual URLs
router.get('/urls', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT manual_type, url, description, updated_at
       FROM manual_urls
       ORDER BY manual_type`
    );

    // Convert to object format for easy lookup
    const urls = {};
    result.rows.forEach(row => {
      urls[row.manual_type] = {
        url: row.url,
        description: row.description,
        updated_at: row.updated_at
      };
    });

    res.json(urls);
  } catch (error) {
    console.error('Get manual URLs error:', error);
    res.status(500).json({ error: 'Failed to fetch manual URLs' });
  }
});

// Update a manual URL (admin only)
router.put('/urls/:manualType', async (req, res) => {
  const { manualType } = req.params;
  const { url, description } = req.body;
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `INSERT INTO manual_urls (manual_type, url, description, updated_by)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (manual_type) DO UPDATE SET
         url = EXCLUDED.url,
         description = EXCLUDED.description,
         updated_by = EXCLUDED.updated_by
       RETURNING *`,
      [manualType, url, description, userId]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update manual URL error:', error);
    res.status(500).json({ error: 'Failed to update manual URL' });
  }
});

module.exports = router;
