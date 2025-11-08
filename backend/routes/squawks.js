const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// All routes require authentication
router.use(authenticateToken);

// ============================================================
// SQUAWKS ENDPOINTS
// ============================================================

// Get all squawks for a helicopter
router.get('/helicopters/:helicopterId/squawks', async (req, res) => {
  const { helicopterId } = req.params;
  const { status, severity } = req.query;

  try {
    let query = `
      SELECT s.*,
             u1.username as reported_by_username,
             u1.full_name as reported_by_name,
             u2.username as fixed_by_username,
             u2.full_name as fixed_by_name,
             h.tail_number
      FROM squawks s
      LEFT JOIN users u1 ON s.reported_by = u1.id
      LEFT JOIN users u2 ON s.fixed_by = u2.id
      LEFT JOIN helicopters h ON s.helicopter_id = h.id
      WHERE s.helicopter_id = $1
    `;
    const params = [helicopterId];

    if (status) {
      query += ' AND s.status = $' + (params.length + 1);
      params.push(status);
    }

    if (severity) {
      query += ' AND s.severity = $' + (params.length + 1);
      params.push(severity);
    }

    // Order by status (active first) then by reported date (newest first)
    query += `
      ORDER BY
        CASE s.status
          WHEN 'active' THEN 1
          WHEN 'deferred' THEN 2
          WHEN 'fixed' THEN 3
        END,
        s.reported_at DESC
    `;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get squawks error:', error);
    // Return empty array instead of error to prevent Flight View crash
    res.json([]);
  }
});

// Get single squawk
router.get('/squawks/:squawkId', async (req, res) => {
  const { squawkId } = req.params;

  try {
    const result = await pool.query(
      `SELECT s.*,
              u1.username as reported_by_username,
              u1.full_name as reported_by_name,
              u2.username as fixed_by_username,
              u2.full_name as fixed_by_name,
              h.tail_number
       FROM squawks s
       LEFT JOIN users u1 ON s.reported_by = u1.id
       LEFT JOIN users u2 ON s.fixed_by = u2.id
       LEFT JOIN helicopters h ON s.helicopter_id = h.id
       WHERE s.id = $1`,
      [squawkId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Squawk not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get squawk error:', error);
    res.status(500).json({ error: 'Failed to fetch squawk' });
  }
});

// Add new squawk
router.post('/helicopters/:helicopterId/squawks', async (req, res) => {
  const { helicopterId } = req.params;
  const { severity = 'routine', title, description, photos } = req.body;
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `INSERT INTO squawks
       (helicopter_id, severity, title, description, reported_by, photos)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [helicopterId, severity, title, description, userId, JSON.stringify(photos)]
    );

    // Fetch the complete squawk record with user info
    const completeResult = await pool.query(
      `SELECT s.*,
              u.username as reported_by_username,
              u.full_name as reported_by_name,
              h.tail_number
       FROM squawks s
       LEFT JOIN users u ON s.reported_by = u.id
       LEFT JOIN helicopters h ON s.helicopter_id = h.id
       WHERE s.id = $1`,
      [result.rows[0].id]
    );

    res.json(completeResult.rows[0]);
  } catch (error) {
    console.error('Add squawk error:', error);
    res.status(500).json({ error: 'Failed to add squawk' });
  }
});

// Update squawk
router.put('/squawks/:squawkId', async (req, res) => {
  const { squawkId } = req.params;
  const { severity, title, description, photos } = req.body;

  try {
    const result = await pool.query(
      `UPDATE squawks
       SET severity = $1, title = $2, description = $3, photos = $4
       WHERE id = $5
       RETURNING *`,
      [severity, title, description, JSON.stringify(photos), squawkId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Squawk not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update squawk error:', error);
    res.status(500).json({ error: 'Failed to update squawk' });
  }
});

// Mark squawk as fixed
router.put('/squawks/:squawkId/fix', async (req, res) => {
  const { squawkId } = req.params;
  const { fix_notes } = req.body;
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `UPDATE squawks
       SET status = 'fixed', fixed_by = $1, fixed_at = CURRENT_TIMESTAMP, fix_notes = $2
       WHERE id = $3
       RETURNING *`,
      [userId, fix_notes, squawkId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Squawk not found' });
    }

    // Fetch the complete squawk record with user info
    const completeResult = await pool.query(
      `SELECT s.*,
              u1.username as reported_by_username,
              u1.full_name as reported_by_name,
              u2.username as fixed_by_username,
              u2.full_name as fixed_by_name,
              h.tail_number
       FROM squawks s
       LEFT JOIN users u1 ON s.reported_by = u1.id
       LEFT JOIN users u2 ON s.fixed_by = u2.id
       LEFT JOIN helicopters h ON s.helicopter_id = h.id
       WHERE s.id = $1`,
      [squawkId]
    );

    res.json(completeResult.rows[0]);
  } catch (error) {
    console.error('Fix squawk error:', error);
    res.status(500).json({ error: 'Failed to fix squawk' });
  }
});

// Change squawk status (active, fixed, deferred)
router.put('/squawks/:squawkId/status', async (req, res) => {
  const { squawkId } = req.params;
  const { status } = req.body;

  // Validate status
  if (!['active', 'fixed', 'deferred'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status. Must be: active, fixed, or deferred' });
  }

  try {
    const result = await pool.query(
      `UPDATE squawks
       SET status = $1
       WHERE id = $2
       RETURNING *`,
      [status, squawkId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Squawk not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update squawk status error:', error);
    res.status(500).json({ error: 'Failed to update squawk status' });
  }
});

// Delete squawk
router.delete('/squawks/:squawkId', async (req, res) => {
  const { squawkId } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM squawks WHERE id = $1 RETURNING id',
      [squawkId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Squawk not found' });
    }

    res.json({ message: 'Squawk deleted successfully' });
  } catch (error) {
    console.error('Delete squawk error:', error);
    res.status(500).json({ error: 'Failed to delete squawk' });
  }
});

module.exports = router;
