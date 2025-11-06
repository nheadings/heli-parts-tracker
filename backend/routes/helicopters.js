const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// Get all helicopters
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM helicopters ORDER BY tail_number'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Get helicopters error:', error);
    res.status(500).json({ error: 'Failed to fetch helicopters' });
  }
});

// Get single helicopter
router.get('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('SELECT * FROM helicopters WHERE id = $1', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Helicopter not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get helicopter error:', error);
    res.status(500).json({ error: 'Failed to fetch helicopter' });
  }
});

// Get all parts installed on a helicopter
router.get('/:id/parts', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      `SELECT
        pi.id as installation_id,
        pi.quantity_installed,
        pi.installation_date,
        pi.serial_number,
        pi.hours_at_installation,
        pi.status as installation_status,
        pi.notes as installation_notes,
        p.*,
        u.username as installed_by_username,
        u.full_name as installed_by_name
       FROM part_installations pi
       JOIN parts p ON pi.part_id = p.id
       LEFT JOIN users u ON pi.installed_by = u.id
       WHERE pi.helicopter_id = $1 AND pi.status = 'active'
       ORDER BY pi.installation_date DESC`,
      [id]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get helicopter parts error:', error);
    res.status(500).json({ error: 'Failed to fetch helicopter parts' });
  }
});

// Get installation history for a helicopter
router.get('/:id/history', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      `SELECT
        pi.*,
        p.part_number,
        p.description,
        u1.username as installed_by_username,
        u2.username as removed_by_username
       FROM part_installations pi
       JOIN parts p ON pi.part_id = p.id
       LEFT JOIN users u1 ON pi.installed_by = u1.id
       LEFT JOIN users u2 ON pi.removed_by = u2.id
       WHERE pi.helicopter_id = $1
       ORDER BY pi.installation_date DESC`,
      [id]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get helicopter history error:', error);
    res.status(500).json({ error: 'Failed to fetch helicopter history' });
  }
});

// Create helicopter
router.post('/', async (req, res) => {
  const { tail_number, model, manufacturer, year, status, notes } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO helicopters (tail_number, model, manufacturer, year, status, notes)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [tail_number, model, manufacturer, year, status || 'active', notes]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create helicopter error:', error);
    if (error.code === '23505') {
      return res.status(400).json({ error: 'Tail number already exists' });
    }
    res.status(500).json({ error: 'Failed to create helicopter' });
  }
});

// Update helicopter
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { tail_number, model, manufacturer, year, status, notes } = req.body;

  try {
    const result = await pool.query(
      `UPDATE helicopters SET
       tail_number = COALESCE($1, tail_number),
       model = COALESCE($2, model),
       manufacturer = COALESCE($3, manufacturer),
       year = COALESCE($4, year),
       status = COALESCE($5, status),
       notes = COALESCE($6, notes)
       WHERE id = $7
       RETURNING *`,
      [tail_number, model, manufacturer, year, status, notes, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Helicopter not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update helicopter error:', error);
    res.status(500).json({ error: 'Failed to update helicopter' });
  }
});

// Delete helicopter
router.delete('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('DELETE FROM helicopters WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Helicopter not found' });
    }

    res.json({ message: 'Helicopter deleted successfully', helicopter: result.rows[0] });
  } catch (error) {
    console.error('Delete helicopter error:', error);
    res.status(500).json({ error: 'Failed to delete helicopter' });
  }
});

module.exports = router;
