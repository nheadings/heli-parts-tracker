const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// Install part on helicopter
router.post('/', async (req, res) => {
  const {
    part_id,
    helicopter_id,
    quantity_installed,
    serial_number,
    hours_at_installation,
    notes
  } = req.body;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Check if part has enough stock
    const partResult = await client.query(
      'SELECT quantity_in_stock FROM parts WHERE id = $1',
      [part_id]
    );

    if (partResult.rows.length === 0) {
      throw new Error('Part not found');
    }

    const currentStock = partResult.rows[0].quantity_in_stock;
    const installQty = quantity_installed || 1;

    if (currentStock < installQty) {
      throw new Error('Insufficient stock');
    }

    // Create installation record
    const installResult = await client.query(
      `INSERT INTO part_installations
       (part_id, helicopter_id, quantity_installed, installed_by, serial_number,
        hours_at_installation, notes, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')
       RETURNING *`,
      [part_id, helicopter_id, installQty, req.user.id, serial_number,
       hours_at_installation, notes]
    );

    // Update part quantity
    const newStock = currentStock - installQty;
    await client.query(
      'UPDATE parts SET quantity_in_stock = $1 WHERE id = $2',
      [newStock, part_id]
    );

    // Log inventory transaction
    await client.query(
      `INSERT INTO inventory_transactions
       (part_id, transaction_type, quantity_change, quantity_after,
        reference_type, reference_id, performed_by, notes)
       VALUES ($1, 'install', $2, $3, 'installation', $4, $5, $6)`,
      [part_id, -installQty, newStock, installResult.rows[0].id, req.user.id,
       `Installed on helicopter`]
    );

    await client.query('COMMIT');

    // Fetch complete installation info
    const result = await pool.query(
      `SELECT
        pi.*,
        p.part_number,
        p.description,
        h.tail_number,
        u.username as installed_by_username
       FROM part_installations pi
       JOIN parts p ON pi.part_id = p.id
       JOIN helicopters h ON pi.helicopter_id = h.id
       LEFT JOIN users u ON pi.installed_by = u.id
       WHERE pi.id = $1`,
      [installResult.rows[0].id]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Install part error:', error);
    res.status(500).json({ error: error.message || 'Failed to install part' });
  } finally {
    client.release();
  }
});

// Remove part from helicopter
router.post('/:id/remove', async (req, res) => {
  const { id } = req.params;
  const { notes, return_to_stock } = req.body;
  console.log('POST /installations/' + id + '/remove - Body:', req.body);

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Get installation details
    const installResult = await client.query(
      'SELECT * FROM part_installations WHERE id = $1',
      [id]
    );

    console.log('Installation found:', installResult.rows.length);

    if (installResult.rows.length === 0) {
      throw new Error('Installation not found');
    }

    const installation = installResult.rows[0];
    console.log('Current installation status:', installation.status);

    // Update installation status
    const updateResult = await client.query(
      `UPDATE part_installations
       SET status = 'removed', removed_date = CURRENT_TIMESTAMP,
           removed_by = $1, notes = COALESCE($2, notes)
       WHERE id = $3
       RETURNING *`,
      [req.user.id, notes, id]
    );
    console.log('Installation status updated to:', updateResult.rows[0].status);

    // If returning to stock, update inventory
    if (return_to_stock) {
      const partResult = await client.query(
        'SELECT quantity_in_stock FROM parts WHERE id = $1',
        [installation.part_id]
      );

      const newStock = partResult.rows[0].quantity_in_stock + installation.quantity_installed;

      await client.query(
        'UPDATE parts SET quantity_in_stock = $1 WHERE id = $2',
        [newStock, installation.part_id]
      );

      // Log transaction
      await client.query(
        `INSERT INTO inventory_transactions
         (part_id, transaction_type, quantity_change, quantity_after,
          reference_type, reference_id, performed_by, notes)
         VALUES ($1, 'return', $2, $3, 'installation', $4, $5, $6)`,
        [installation.part_id, installation.quantity_installed, newStock,
         id, req.user.id, 'Removed from helicopter and returned to stock']
      );
    }

    await client.query('COMMIT');
    res.json({ message: 'Part removed successfully' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Remove part error:', error);
    res.status(500).json({ error: error.message || 'Failed to remove part' });
  } finally {
    client.release();
  }
});

// Update part installation
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { serial_number, hours_at_installation, notes } = req.body;

  try {
    const result = await pool.query(
      `UPDATE part_installations
       SET serial_number = $1, hours_at_installation = $2, notes = $3
       WHERE id = $4
       RETURNING *`,
      [serial_number, hours_at_installation, notes, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Installation not found' });
    }

    // Fetch complete installation info
    const fullResult = await pool.query(
      `SELECT
        pi.*,
        p.part_number,
        p.description,
        h.tail_number,
        u1.username as installed_by_username,
        u2.username as removed_by_username
       FROM part_installations pi
       JOIN parts p ON pi.part_id = p.id
       JOIN helicopters h ON pi.helicopter_id = h.id
       LEFT JOIN users u1 ON pi.installed_by = u1.id
       LEFT JOIN users u2 ON pi.removed_by = u2.id
       WHERE pi.id = $1`,
      [id]
    );

    res.json(fullResult.rows[0]);
  } catch (error) {
    console.error('Update installation error:', error);
    res.status(500).json({ error: 'Failed to update installation' });
  }
});

// Get all installations
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        pi.*,
        p.part_number,
        p.description,
        h.tail_number,
        u1.username as installed_by_username,
        u2.username as removed_by_username
       FROM part_installations pi
       JOIN parts p ON pi.part_id = p.id
       JOIN helicopters h ON pi.helicopter_id = h.id
       LEFT JOIN users u1 ON pi.installed_by = u1.id
       LEFT JOIN users u2 ON pi.removed_by = u2.id
       ORDER BY pi.installation_date DESC`
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get installations error:', error);
    res.status(500).json({ error: 'Failed to fetch installations' });
  }
});

// Get installation by ID
router.get('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      `SELECT
        pi.*,
        p.part_number,
        p.description,
        h.tail_number,
        u1.username as installed_by_username,
        u2.username as removed_by_username
       FROM part_installations pi
       JOIN parts p ON pi.part_id = p.id
       JOIN helicopters h ON pi.helicopter_id = h.id
       LEFT JOIN users u1 ON pi.installed_by = u1.id
       LEFT JOIN users u2 ON pi.removed_by = u2.id
       WHERE pi.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Installation not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get installation error:', error);
    res.status(500).json({ error: 'Failed to fetch installation' });
  }
});

module.exports = router;
