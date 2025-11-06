const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// Get all alerts
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        ia.*,
        p.part_number,
        p.description,
        p.quantity_in_stock,
        p.minimum_quantity,
        u.username as created_by_username
       FROM inventory_alerts ia
       JOIN parts p ON ia.part_id = p.id
       LEFT JOIN users u ON ia.created_by = u.id
       WHERE ia.is_active = true
       ORDER BY ia.created_at DESC`
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get alerts error:', error);
    res.status(500).json({ error: 'Failed to fetch alerts' });
  }
});

// Get active alerts (parts below threshold)
router.get('/active', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        ia.*,
        p.part_number,
        p.description,
        p.quantity_in_stock,
        p.minimum_quantity,
        u.username as created_by_username
       FROM inventory_alerts ia
       JOIN parts p ON ia.part_id = p.id
       LEFT JOIN users u ON ia.created_by = u.id
       WHERE ia.is_active = true
       AND p.quantity_in_stock <= ia.threshold_quantity
       ORDER BY p.quantity_in_stock ASC`
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get active alerts error:', error);
    res.status(500).json({ error: 'Failed to fetch active alerts' });
  }
});

// Create alert
router.post('/', async (req, res) => {
  const {
    part_id,
    alert_type,
    threshold_quantity,
    email_notification
  } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO inventory_alerts
       (part_id, alert_type, threshold_quantity, email_notification, created_by)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [part_id, alert_type || 'low_stock', threshold_quantity,
       email_notification !== false, req.user.id]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create alert error:', error);
    res.status(500).json({ error: 'Failed to create alert' });
  }
});

// Update alert
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const {
    threshold_quantity,
    is_active,
    email_notification
  } = req.body;

  try {
    const result = await pool.query(
      `UPDATE inventory_alerts SET
       threshold_quantity = COALESCE($1, threshold_quantity),
       is_active = COALESCE($2, is_active),
       email_notification = COALESCE($3, email_notification)
       WHERE id = $4
       RETURNING *`,
      [threshold_quantity, is_active, email_notification, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Alert not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update alert error:', error);
    res.status(500).json({ error: 'Failed to update alert' });
  }
});

// Delete alert
router.delete('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM inventory_alerts WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Alert not found' });
    }

    res.json({ message: 'Alert deleted successfully' });
  } catch (error) {
    console.error('Delete alert error:', error);
    res.status(500).json({ error: 'Failed to delete alert' });
  }
});

module.exports = router;
