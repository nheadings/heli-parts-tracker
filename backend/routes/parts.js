const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// All routes require authentication
router.use(authenticateToken);

// Search parts (with real-time filtering)
router.get('/search', async (req, res) => {
  const { query, category, low_stock } = req.query;

  try {
    let sql = 'SELECT * FROM parts WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    if (query) {
      sql += ` AND (LOWER(part_number) LIKE LOWER($${paramIndex}) OR LOWER(description) LIKE LOWER($${paramIndex}))`;
      params.push(`%${query}%`);
      paramIndex++;
    }

    if (category) {
      sql += ` AND category = $${paramIndex}`;
      params.push(category);
      paramIndex++;
    }

    if (low_stock === 'true') {
      sql += ' AND quantity_in_stock <= minimum_quantity';
    }

    sql += ' ORDER BY part_number';

    const result = await pool.query(sql, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Failed to search parts' });
  }
});

// Get parts with low stock (must come before /:id route)
router.get('/alerts/low-stock', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM parts WHERE quantity_in_stock <= minimum_quantity ORDER BY quantity_in_stock'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Get low stock parts error:', error);
    res.status(500).json({ error: 'Failed to fetch low stock parts' });
  }
});

// Get part by QR code (must come before /:id route)
router.get('/qr/:qr_code', async (req, res) => {
  const { qr_code } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM parts WHERE qr_code = $1',
      [qr_code]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Part not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get part by QR error:', error);
    res.status(500).json({ error: 'Failed to fetch part' });
  }
});

// Get all parts
router.get('/', async (req, res) => {
  try {
    console.log('Fetching all parts...');
    const result = await pool.query(
      'SELECT * FROM parts ORDER BY part_number'
    );
    console.log(`Returning ${result.rows.length} parts`);
    console.log('First part:', JSON.stringify(result.rows[0]));
    res.json(result.rows);
  } catch (error) {
    console.error('Get parts error:', error);
    res.status(500).json({ error: 'Failed to fetch parts' });
  }
});

// Get single part by ID (must come after specific routes)
router.get('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('SELECT * FROM parts WHERE id = $1', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Part not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get part error:', error);
    res.status(500).json({ error: 'Failed to fetch part' });
  }
});

// Create new part
router.post('/', async (req, res) => {
  const {
    part_number,
    alternate_part_number,
    description,
    manufacturer,
    category,
    quantity_in_stock,
    minimum_quantity,
    unit_price,
    reorder_url,
    qr_code,
    location,
    notes,
    is_life_limited
  } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO parts (part_number, alternate_part_number, description, manufacturer, category, quantity_in_stock,
       minimum_quantity, unit_price, reorder_url, qr_code, location, notes, is_life_limited)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING *`,
      [part_number, alternate_part_number, description, manufacturer, category, quantity_in_stock || 0,
       minimum_quantity || 0, unit_price, reorder_url, qr_code, location, notes, is_life_limited || false]
    );

    // Log transaction
    await pool.query(
      `INSERT INTO inventory_transactions (part_id, transaction_type, quantity_change,
       quantity_after, performed_by, notes)
       VALUES ($1, 'add', $2, $2, $3, 'Initial stock')`,
      [result.rows[0].id, quantity_in_stock || 0, req.user.id]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create part error:', error);
    if (error.code === '23505') { // Unique constraint violation
      return res.status(400).json({ error: 'Part number already exists' });
    }
    res.status(500).json({ error: 'Failed to create part' });
  }
});

// Update part
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const {
    part_number,
    alternate_part_number,
    description,
    manufacturer,
    category,
    quantity_in_stock,
    minimum_quantity,
    unit_price,
    reorder_url,
    location,
    notes,
    is_life_limited
  } = req.body;

  try {
    // Get current quantity for transaction log
    const currentPart = await pool.query('SELECT quantity_in_stock FROM parts WHERE id = $1', [id]);

    if (currentPart.rows.length === 0) {
      return res.status(404).json({ error: 'Part not found' });
    }

    const result = await pool.query(
      `UPDATE parts SET
       part_number = COALESCE($1, part_number),
       alternate_part_number = COALESCE($2, alternate_part_number),
       description = COALESCE($3, description),
       manufacturer = COALESCE($4, manufacturer),
       category = COALESCE($5, category),
       quantity_in_stock = COALESCE($6, quantity_in_stock),
       minimum_quantity = COALESCE($7, minimum_quantity),
       unit_price = COALESCE($8, unit_price),
       reorder_url = COALESCE($9, reorder_url),
       location = COALESCE($10, location),
       notes = COALESCE($11, notes),
       is_life_limited = COALESCE($12, is_life_limited)
       WHERE id = $13
       RETURNING *`,
      [part_number, alternate_part_number, description, manufacturer, category, quantity_in_stock,
       minimum_quantity, unit_price, reorder_url, location, notes, is_life_limited, id]
    );

    // Log quantity change if it changed
    if (quantity_in_stock !== undefined && quantity_in_stock !== currentPart.rows[0].quantity_in_stock) {
      const quantityChange = quantity_in_stock - currentPart.rows[0].quantity_in_stock;
      await pool.query(
        `INSERT INTO inventory_transactions (part_id, transaction_type, quantity_change,
         quantity_after, performed_by, notes)
         VALUES ($1, 'adjust', $2, $3, $4, 'Manual adjustment')`,
        [id, quantityChange, quantity_in_stock, req.user.id]
      );
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update part error:', error);
    res.status(500).json({ error: 'Failed to update part' });
  }
});

// Delete part
router.delete('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('DELETE FROM parts WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Part not found' });
    }

    res.json({ message: 'Part deleted successfully', part: result.rows[0] });
  } catch (error) {
    console.error('Delete part error:', error);
    res.status(500).json({ error: 'Failed to delete part' });
  }
});

// Get transactions for a part
router.get('/:id/transactions', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      `SELECT it.id,
              it.part_id,
              it.transaction_type,
              it.quantity_change,
              it.quantity_after,
              it.reference_type,
              it.reference_id,
              it.performed_by,
              it.notes,
              it.created_at as transaction_date,
              u.username as performed_by_username,
              CASE
                WHEN it.reference_type = 'installation' THEN h.id
                ELSE NULL
              END as helicopter_id,
              CASE
                WHEN it.reference_type = 'installation' THEN h.tail_number
                ELSE NULL
              END as helicopter_tail_number
       FROM inventory_transactions it
       LEFT JOIN users u ON it.performed_by = u.id
       LEFT JOIN part_installations pi ON it.reference_type = 'installation' AND it.reference_id = pi.id
       LEFT JOIN helicopters h ON pi.helicopter_id = h.id
       WHERE it.part_id = $1
       ORDER BY it.created_at DESC`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Get part transactions error:', error);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

module.exports = router;
