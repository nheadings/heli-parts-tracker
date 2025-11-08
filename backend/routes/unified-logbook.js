const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;

// All routes require authentication
router.use(authenticateToken);

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const uploadDir = path.join(__dirname, '..', 'uploads', 'logbook');
    try {
      await fs.mkdir(uploadDir, { recursive: true });
      cb(null, uploadDir);
    } catch (error) {
      cb(error);
    }
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + '-' + file.originalname);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// ============================================================
// LOGBOOK CATEGORIES ENDPOINTS
// ============================================================

// Get all categories
router.get('/categories', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM logbook_categories
       WHERE is_active = true
       ORDER BY display_order ASC, name ASC`
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get categories error:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// Create category
router.post('/categories', async (req, res) => {
  const { name, icon, color, display_order } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO logbook_categories (name, icon, color, display_order)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [name, icon, color || '#007AFF', display_order || 0]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Create category error:', error);
    res.status(500).json({ error: 'Failed to create category' });
  }
});

// Update category
router.put('/categories/:id', async (req, res) => {
  const { id } = req.params;
  const {
    name,
    icon,
    color,
    display_order,
    is_active,
    display_in_flight_view,
    interval_hours,
    threshold_warning
  } = req.body;

  try {
    console.log('Updating category', id, 'with:', { name, icon, color, display_order, is_active, display_in_flight_view, interval_hours, threshold_warning });

    const result = await pool.query(
      `UPDATE logbook_categories
       SET name = $1, icon = $2, color = $3, display_order = $4, is_active = $5,
           display_in_flight_view = $6, interval_hours = $7, threshold_warning = $8
       WHERE id = $9
       RETURNING *`,
      [name, icon, color, display_order, is_active, display_in_flight_view || false,
       interval_hours, threshold_warning, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Category not found' });
    }

    console.log('Category updated successfully:', result.rows[0]);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update category error:', error);
    console.error('Error details:', error.message);
    res.status(500).json({ error: 'Failed to update category', details: error.message });
  }
});

// Get helicopters assigned to category banner
router.get('/categories/:categoryId/helicopters', async (req, res) => {
  const { categoryId } = req.params;

  try {
    const result = await pool.query(
      `SELECT h.id, h.tail_number
       FROM helicopter_category_banners hcb
       JOIN helicopters h ON hcb.helicopter_id = h.id
       WHERE hcb.category_id = $1 AND hcb.is_enabled = true
       ORDER BY h.tail_number`,
      [categoryId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get category helicopters error:', error);
    res.status(500).json({ error: 'Failed to fetch category helicopters' });
  }
});

// Update helicopter assignments for category banner
router.put('/categories/:categoryId/helicopters', async (req, res) => {
  const { categoryId } = req.params;
  const { helicopter_ids } = req.body;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Delete all existing assignments
    await client.query(
      'DELETE FROM helicopter_category_banners WHERE category_id = $1',
      [categoryId]
    );

    // Insert new assignments if any
    if (helicopter_ids && helicopter_ids.length > 0) {
      const values = helicopter_ids.map((heliId, index) =>
        `($1, $${index + 2}, true)`
      ).join(', ');

      await client.query(
        `INSERT INTO helicopter_category_banners (category_id, helicopter_id, is_enabled)
         VALUES ${values}`,
        [categoryId, ...helicopter_ids]
      );
    }

    await client.query('COMMIT');
    res.json({ message: 'Category helicopter assignments updated successfully' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Update category helicopters error:', error);
    res.status(500).json({ error: 'Failed to update category helicopters' });
  } finally {
    client.release();
  }
});

// Delete category
router.delete('/categories/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM logbook_categories WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Category not found' });
    }

    res.json({ message: 'Category deleted successfully' });
  } catch (error) {
    console.error('Delete category error:', error);
    res.status(500).json({ error: 'Failed to delete category' });
  }
});

// ============================================================
// LOGBOOK ENTRIES ENDPOINTS
// ============================================================

// Get entries with filtering
router.get('/entries', async (req, res) => {
  const {
    helicopter_id,
    category_ids,
    start_date,
    end_date,
    search,
    limit = 100,
    offset = 0
  } = req.query;

  try {
    let query = `
      SELECT
        e.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        h.tail_number,
        u.username as performed_by_username,
        u.full_name as performed_by_name,
        uf.username as fixed_by_username,
        uf.full_name as fixed_by_name,
        (SELECT COUNT(*)::INTEGER FROM logbook_attachments WHERE entry_id = e.id) as attachment_count
      FROM logbook_entries e
      JOIN logbook_categories c ON e.category_id = c.id
      JOIN helicopters h ON e.helicopter_id = h.id
      LEFT JOIN users u ON e.performed_by = u.id
      LEFT JOIN users uf ON e.fixed_by = uf.id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    // Filter by helicopter
    if (helicopter_id && helicopter_id !== 'all') {
      params.push(helicopter_id);
      query += ` AND e.helicopter_id = $${paramCount++}`;
    }

    // Filter by categories (comma-separated IDs)
    if (category_ids && category_ids !== 'all') {
      const categoryArray = category_ids.split(',').map(id => parseInt(id));
      params.push(categoryArray);
      query += ` AND e.category_id = ANY($${paramCount++})`;
    }

    // Filter by date range
    if (start_date) {
      params.push(start_date);
      query += ` AND e.event_date >= $${paramCount++}`;
    }
    if (end_date) {
      params.push(end_date);
      query += ` AND e.event_date <= $${paramCount++}`;
    }

    // Search across text fields
    if (search) {
      params.push(`%${search}%`);
      query += ` AND (
        e.description ILIKE $${paramCount} OR
        e.notes ILIKE $${paramCount} OR
        c.name ILIKE $${paramCount} OR
        h.tail_number ILIKE $${paramCount} OR
        u.username ILIKE $${paramCount} OR
        u.full_name ILIKE $${paramCount}
      )`;
      paramCount++;
    }

    query += ` ORDER BY e.event_date DESC, e.id DESC`;

    // Add pagination
    params.push(limit, offset);
    query += ` LIMIT $${paramCount++} OFFSET $${paramCount++}`;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get entries error:', error);
    res.status(500).json({ error: 'Failed to fetch entries' });
  }
});

// Get single entry with attachments
router.get('/entries/:id', async (req, res) => {
  const { id } = req.params;

  try {
    // Get entry details
    const entryResult = await pool.query(
      `SELECT
        e.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        h.tail_number,
        u.username as performed_by_username,
        u.full_name as performed_by_name,
        uf.username as fixed_by_username,
        uf.full_name as fixed_by_name
      FROM logbook_entries e
      JOIN logbook_categories c ON e.category_id = c.id
      JOIN helicopters h ON e.helicopter_id = h.id
      LEFT JOIN users u ON e.performed_by = u.id
      LEFT JOIN users uf ON e.fixed_by = uf.id
      WHERE e.id = $1`,
      [id]
    );

    if (entryResult.rows.length === 0) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    // Get attachments
    const attachmentsResult = await pool.query(
      `SELECT a.*, u.username as uploaded_by_username
       FROM logbook_attachments a
       LEFT JOIN users u ON a.uploaded_by = u.id
       WHERE a.entry_id = $1
       ORDER BY a.uploaded_at DESC`,
      [id]
    );

    const entry = entryResult.rows[0];
    entry.attachments = attachmentsResult.rows;

    res.json(entry);
  } catch (error) {
    console.error('Get entry error:', error);
    res.status(500).json({ error: 'Failed to fetch entry' });
  }
});

// Create entry
router.post('/entries', async (req, res) => {
  const {
    helicopter_id,
    category_id,
    event_date,
    hours_at_event,
    description,
    notes,
    cost,
    next_due_hours,
    next_due_date,
    severity,
    status,
    fluid_type,
    quantity,
    unit,
    fixed_by,
    fixed_at,
    fix_notes
  } = req.body;
  const userId = req.user.id;

  try {
    const insertResult = await pool.query(
      `INSERT INTO logbook_entries
       (helicopter_id, category_id, event_date, hours_at_event, description, notes,
        performed_by, cost, next_due_hours, next_due_date, severity, status, fluid_type,
        quantity, unit, fixed_by, fixed_at, fix_notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
       RETURNING id`,
      [helicopter_id, category_id, event_date || new Date(), hours_at_event, description,
       notes, userId, cost, next_due_hours, next_due_date, severity, status || 'completed',
       fluid_type, quantity, unit, fixed_by, fixed_at, fix_notes]
    );

    // Fetch the complete entry with joined fields
    const entryId = insertResult.rows[0].id;
    const result = await pool.query(
      `SELECT
        e.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        h.tail_number,
        u.username as performed_by_username,
        u.full_name as performed_by_name,
        (SELECT COUNT(*)::INTEGER FROM logbook_attachments WHERE entry_id = e.id) as attachment_count
      FROM logbook_entries e
      JOIN logbook_categories c ON e.category_id = c.id
      JOIN helicopters h ON e.helicopter_id = h.id
      LEFT JOIN users u ON e.performed_by = u.id
      WHERE e.id = $1`,
      [entryId]
    );

    const entry = result.rows[0];
    console.log('Created entry response:', JSON.stringify(entry, null, 2));
    res.json(entry);
  } catch (error) {
    console.error('Create entry error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ error: 'Failed to create entry', details: error.message });
  }
});

// Update entry
router.put('/entries/:id', async (req, res) => {
  const { id } = req.params;
  const {
    category_id,
    event_date,
    hours_at_event,
    description,
    notes,
    cost,
    next_due_hours,
    next_due_date,
    severity,
    status,
    fluid_type,
    quantity,
    unit,
    fixed_by,
    fixed_at,
    fix_notes
  } = req.body;

  try {
    const updateResult = await pool.query(
      `UPDATE logbook_entries
       SET category_id = $1, event_date = $2, hours_at_event = $3, description = $4,
           notes = $5, cost = $6, next_due_hours = $7, next_due_date = $8,
           severity = $9, status = $10, fluid_type = $11, quantity = $12, unit = $13,
           fixed_by = $14, fixed_at = $15, fix_notes = $16
       WHERE id = $17
       RETURNING id`,
      [category_id, event_date, hours_at_event, description, notes, cost,
       next_due_hours, next_due_date, severity, status, fluid_type, quantity, unit,
       fixed_by, fixed_at, fix_notes, id]
    );

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    // Fetch the complete entry with joined fields
    const result = await pool.query(
      `SELECT
        e.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        h.tail_number,
        u.username as performed_by_username,
        u.full_name as performed_by_name,
        uf.username as fixed_by_username,
        uf.full_name as fixed_by_name,
        (SELECT COUNT(*)::INTEGER FROM logbook_attachments WHERE entry_id = e.id) as attachment_count
      FROM logbook_entries e
      JOIN logbook_categories c ON e.category_id = c.id
      JOIN helicopters h ON e.helicopter_id = h.id
      LEFT JOIN users u ON e.performed_by = u.id
      LEFT JOIN users uf ON e.fixed_by = uf.id
      WHERE e.id = $1`,
      [id]
    );

    const entry = result.rows[0];
    console.log('Updated entry response:', JSON.stringify(entry, null, 2));
    res.json(entry);
  } catch (error) {
    console.error('Update entry error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ error: 'Failed to update entry', details: error.message });
  }
});

// Delete entry
router.delete('/entries/:id', async (req, res) => {
  const { id } = req.params;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Get and delete attachments
    const attachments = await client.query(
      'SELECT file_path FROM logbook_attachments WHERE entry_id = $1',
      [id]
    );

    // Delete files from filesystem
    for (const attachment of attachments.rows) {
      try {
        // Convert URL path to filesystem path
        const absolutePath = path.join(__dirname, '..', attachment.file_path);
        await fs.unlink(absolutePath);
      } catch (err) {
        console.error('Failed to delete file:', err);
      }
    }

    // Delete attachments from database
    await client.query('DELETE FROM logbook_attachments WHERE entry_id = $1', [id]);

    // Delete entry
    const result = await client.query(
      'DELETE FROM logbook_entries WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Entry not found' });
    }

    await client.query('COMMIT');
    res.json({ message: 'Entry deleted successfully' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Delete entry error:', error);
    res.status(500).json({ error: 'Failed to delete entry' });
  } finally {
    client.release();
  }
});

// ============================================================
// LOGBOOK ATTACHMENTS ENDPOINTS
// ============================================================

// Upload attachment
router.post('/entries/:entryId/attachments', upload.single('file'), async (req, res) => {
  const { entryId } = req.params;
  const userId = req.user.id;

  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  try {
    // Store URL path instead of filesystem path (like squawks do)
    const fileUrl = `/uploads/logbook/${req.file.filename}`;

    const result = await pool.query(
      `INSERT INTO logbook_attachments
       (entry_id, file_name, file_path, file_type, file_size, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [entryId, req.file.originalname, fileUrl, req.file.mimetype, req.file.size, userId]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Upload attachment error:', error);
    // Clean up uploaded file on error
    try {
      await fs.unlink(req.file.path);
    } catch (unlinkError) {
      console.error('Failed to delete file after error:', unlinkError);
    }
    res.status(500).json({ error: 'Failed to upload attachment' });
  }
});

// Delete attachment
router.delete('/attachments/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM logbook_attachments WHERE id = $1 RETURNING file_path',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Attachment not found' });
    }

    // Convert URL path to filesystem path and delete file
    const filePath = result.rows[0].file_path;
    // filePath is like "/uploads/logbook/123-file.jpg", convert to absolute path
    const absolutePath = path.join(__dirname, '..', filePath);

    try {
      await fs.unlink(absolutePath);
    } catch (err) {
      console.error('Failed to delete file:', err);
    }

    res.json({ message: 'Attachment deleted successfully' });
  } catch (error) {
    console.error('Delete attachment error:', error);
    res.status(500).json({ error: 'Failed to delete attachment' });
  }
});

// Download/serve attachment
router.get('/attachments/:id/download', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'SELECT file_path, file_name, file_type FROM logbook_attachments WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Attachment not found' });
    }

    const { file_path, file_name, file_type } = result.rows[0];

    res.setHeader('Content-Type', file_type);
    res.setHeader('Content-Disposition', `attachment; filename="${file_name}"`);
    res.sendFile(file_path);
  } catch (error) {
    console.error('Download attachment error:', error);
    res.status(500).json({ error: 'Failed to download attachment' });
  }
});

module.exports = router;
