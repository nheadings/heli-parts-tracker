const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// All routes require authentication
router.use(authenticateToken);

// ============================================================
// HELICOPTER HOURS ENDPOINTS
// ============================================================

// Get helicopter current hours and history
router.get('/helicopters/:helicopterId/hours', async (req, res) => {
  const { helicopterId } = req.params;
  const { limit = 50 } = req.query;

  try {
    // Get current hours from helicopter table
    const heliResult = await pool.query(
      'SELECT current_hours FROM helicopters WHERE id = $1',
      [helicopterId]
    );

    if (heliResult.rows.length === 0) {
      return res.status(404).json({ error: 'Helicopter not found' });
    }

    // Get hours history
    const historyResult = await pool.query(
      `SELECT hh.*, u.username as recorded_by_username
       FROM helicopter_hours hh
       LEFT JOIN users u ON hh.recorded_by = u.id
       WHERE hh.helicopter_id = $1
       ORDER BY hh.recorded_at DESC
       LIMIT $2`,
      [helicopterId, limit]
    );

    res.json({
      current_hours: heliResult.rows[0].current_hours,
      history: historyResult.rows
    });
  } catch (error) {
    console.error('Get hours error:', error);
    res.status(500).json({ error: 'Failed to fetch hours' });
  }
});

// Update helicopter hours
router.post('/helicopters/:helicopterId/hours', async (req, res) => {
  const { helicopterId } = req.params;
  const { hours, photo_url, ocr_confidence, entry_method = 'manual', notes } = req.body;
  const userId = req.user.id;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Update helicopter current_hours
    await client.query(
      'UPDATE helicopters SET current_hours = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [hours, helicopterId]
    );

    // Insert hours record
    const result = await client.query(
      `INSERT INTO helicopter_hours
       (helicopter_id, hours, recorded_by, photo_url, ocr_confidence, entry_method, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id`,
      [helicopterId, hours, userId, photo_url, ocr_confidence, entry_method, notes]
    );

    // Fetch the complete record with username
    const hoursRecord = await client.query(
      `SELECT hh.*, u.username as recorded_by_username
       FROM helicopter_hours hh
       LEFT JOIN users u ON hh.recorded_by = u.id
       WHERE hh.id = $1`,
      [result.rows[0].id]
    );

    await client.query('COMMIT');
    res.json(hoursRecord.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Update hours error:', error);
    res.status(500).json({ error: 'Failed to update hours' });
  } finally {
    client.release();
  }
});

// Update hours entry
router.put('/hours/:hoursId', async (req, res) => {
  const { hoursId } = req.params;
  const { hours, photo_url, ocr_confidence, entry_method, notes } = req.body;

  try {
    const result = await pool.query(
      `UPDATE helicopter_hours
       SET hours = $1, photo_url = $2, ocr_confidence = $3, entry_method = $4, notes = $5
       WHERE id = $6
       RETURNING *`,
      [hours, photo_url, ocr_confidence, entry_method, notes, hoursId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Hours entry not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update hours entry error:', error);
    res.status(500).json({ error: 'Failed to update hours entry' });
  }
});

// ============================================================
// MAINTENANCE LOGS ENDPOINTS
// ============================================================

// Get maintenance logs for a helicopter
router.get('/helicopters/:helicopterId/maintenance', async (req, res) => {
  const { helicopterId } = req.params;
  const { log_type, limit = 100 } = req.query;

  try {
    let query = `
      SELECT ml.*, u.username as performed_by_username, u.full_name as performed_by_full_name
      FROM maintenance_logs ml
      LEFT JOIN users u ON ml.performed_by = u.id
      WHERE ml.helicopter_id = $1
    `;
    const params = [helicopterId];

    if (log_type) {
      query += ' AND ml.log_type = $2';
      params.push(log_type);
    }

    query += ' ORDER BY ml.date_performed DESC LIMIT $' + (params.length + 1);
    params.push(limit);

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get maintenance logs error:', error);
    res.status(500).json({ error: 'Failed to fetch maintenance logs' });
  }
});

// Add maintenance log
router.post('/helicopters/:helicopterId/maintenance', async (req, res) => {
  const { helicopterId } = req.params;
  const {
    log_type,
    hours_at_service,
    date_performed,
    description,
    cost,
    next_due_hours,
    next_due_date,
    attachments,
    status = 'completed'
  } = req.body;
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `INSERT INTO maintenance_logs
       (helicopter_id, log_type, hours_at_service, date_performed, performed_by,
        description, cost, next_due_hours, next_due_date, attachments, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [helicopterId, log_type, hours_at_service, date_performed, userId, description,
       cost, next_due_hours, next_due_date, JSON.stringify(attachments), status]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Add maintenance log error:', error);
    res.status(500).json({ error: 'Failed to add maintenance log' });
  }
});

// Get single maintenance log
router.get('/maintenance/:logId', async (req, res) => {
  const { logId } = req.params;

  try {
    const result = await pool.query(
      `SELECT ml.*, u.username as performed_by_username, u.full_name as performed_by_full_name
       FROM maintenance_logs ml
       LEFT JOIN users u ON ml.performed_by = u.id
       WHERE ml.id = $1`,
      [logId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Maintenance log not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get maintenance log error:', error);
    res.status(500).json({ error: 'Failed to fetch maintenance log' });
  }
});

// Update maintenance log
router.put('/maintenance/:logId', async (req, res) => {
  const { logId } = req.params;
  const {
    log_type,
    hours_at_service,
    date_performed,
    description,
    cost,
    next_due_hours,
    next_due_date,
    attachments,
    status
  } = req.body;
  console.log('PUT /maintenance/' + logId + ' - Body:', req.body);

  try {
    const result = await pool.query(
      `UPDATE maintenance_logs
       SET log_type = $1, hours_at_service = $2, date_performed = $3, description = $4,
           cost = $5, next_due_hours = $6, next_due_date = $7, attachments = $8, status = $9
       WHERE id = $10
       RETURNING *`,
      [log_type, hours_at_service, date_performed, description, cost,
       next_due_hours, next_due_date, JSON.stringify(attachments), status, logId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Maintenance log not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update maintenance log error:', error);
    res.status(500).json({ error: 'Failed to update maintenance log' });
  }
});

// Delete maintenance log
router.delete('/maintenance/:logId', async (req, res) => {
  const { logId } = req.params;
  console.log('DELETE /maintenance/' + logId);

  try {
    const result = await pool.query(
      'DELETE FROM maintenance_logs WHERE id = $1 RETURNING id',
      [logId]
    );

    console.log('Delete maintenance result rows:', result.rows.length);

    if (result.rows.length === 0) {
      console.log('Maintenance log not found:', logId);
      return res.status(404).json({ error: 'Maintenance log not found' });
    }

    console.log('Maintenance log deleted successfully:', result.rows[0].id);
    res.json({ message: 'Maintenance log deleted successfully' });
  } catch (error) {
    console.error('Delete maintenance log error:', error);
    res.status(500).json({ error: 'Failed to delete maintenance log' });
  }
});

// ============================================================
// FLUID LOGS ENDPOINTS
// ============================================================

// Get fluid logs for a helicopter
router.get('/helicopters/:helicopterId/fluids', async (req, res) => {
  const { helicopterId } = req.params;
  const { fluid_type, limit = 100 } = req.query;

  try {
    let query = `
      SELECT fl.*, u.username as added_by_username, u.full_name as added_by_full_name
      FROM fluid_logs fl
      LEFT JOIN users u ON fl.added_by = u.id
      WHERE fl.helicopter_id = $1
    `;
    const params = [helicopterId];

    if (fluid_type) {
      query += ' AND fl.fluid_type = $2';
      params.push(fluid_type);
    }

    query += ' ORDER BY fl.date_added DESC LIMIT $' + (params.length + 1);
    params.push(limit);

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get fluid logs error:', error);
    res.status(500).json({ error: 'Failed to fetch fluid logs' });
  }
});

// Add fluid log
router.post('/helicopters/:helicopterId/fluids', async (req, res) => {
  const { helicopterId } = req.params;
  const { fluid_type, quantity, unit = 'quarts', hours, date_added, notes } = req.body;
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `INSERT INTO fluid_logs
       (helicopter_id, fluid_type, quantity, unit, hours, date_added, added_by, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [helicopterId, fluid_type, quantity, unit, hours, date_added, userId, notes]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Add fluid log error:', error);
    res.status(500).json({ error: 'Failed to add fluid log' });
  }
});

// Update fluid log
router.put('/fluids/:fluidId', async (req, res) => {
  const { fluidId } = req.params;
  const { fluid_type, quantity, unit, hours, date_added, notes } = req.body;
  console.log('PUT /fluids/' + fluidId + ' - Body:', req.body);

  try {
    const result = await pool.query(
      `UPDATE fluid_logs
       SET fluid_type = $1, quantity = $2, unit = $3, hours = $4, date_added = $5, notes = $6
       WHERE id = $7
       RETURNING *`,
      [fluid_type, quantity, unit, hours, date_added, notes, fluidId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Fluid log not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update fluid log error:', error);
    res.status(500).json({ error: 'Failed to update fluid log' });
  }
});

// Delete a fluid log
router.delete('/fluids/:fluidId', async (req, res) => {
  const { fluidId } = req.params;
  console.log('DELETE /fluids/' + fluidId);

  try {
    const result = await pool.query(
      'DELETE FROM fluid_logs WHERE id = $1 RETURNING id',
      [fluidId]
    );

    console.log('Delete result rows:', result.rows.length);

    if (result.rows.length === 0) {
      console.log('Fluid log not found:', fluidId);
      return res.status(404).json({ error: 'Fluid log not found' });
    }

    console.log('Fluid log deleted successfully:', result.rows[0].id);
    res.json({ message: 'Fluid log deleted successfully', id: result.rows[0].id });
  } catch (error) {
    console.error('Delete fluid log error:', error);
    res.status(500).json({ error: 'Failed to delete fluid log' });
  }
});

// ============================================================
// LIFE-LIMITED PARTS ENDPOINTS
// ============================================================

// Get life-limited parts for a helicopter
router.get('/helicopters/:helicopterId/life-limited-parts', async (req, res) => {
  const { helicopterId } = req.params;

  try {
    // Get current helicopter hours
    const heliResult = await pool.query(
      'SELECT current_hours FROM helicopters WHERE id = $1',
      [helicopterId]
    );

    if (heliResult.rows.length === 0) {
      return res.status(404).json({ error: 'Helicopter not found' });
    }

    const currentHours = heliResult.rows[0].current_hours;

    // Get life-limited parts with remaining life calculations
    const result = await pool.query(
      `SELECT llp.*,
              p.part_number, p.description,
              CASE
                WHEN llp.hour_limit IS NOT NULL
                THEN llp.hour_limit - ($1 - llp.installed_hours)
                ELSE NULL
              END as hours_remaining,
              CASE
                WHEN llp.calendar_limit_months IS NOT NULL
                THEN (llp.calendar_limit_months * 30) - (CURRENT_DATE - llp.installed_date)
                ELSE NULL
              END as days_remaining,
              CASE
                WHEN llp.hour_limit IS NOT NULL AND llp.calendar_limit_months IS NOT NULL
                THEN LEAST(
                  ((llp.hour_limit - ($1 - llp.installed_hours)) / llp.hour_limit) * 100,
                  (((llp.calendar_limit_months * 30) - (CURRENT_DATE - llp.installed_date))::DECIMAL / (llp.calendar_limit_months * 30)) * 100
                )
                WHEN llp.hour_limit IS NOT NULL
                THEN ((llp.hour_limit - ($1 - llp.installed_hours)) / llp.hour_limit) * 100
                WHEN llp.calendar_limit_months IS NOT NULL
                THEN (((llp.calendar_limit_months * 30) - (CURRENT_DATE - llp.installed_date))::DECIMAL / (llp.calendar_limit_months * 30)) * 100
                ELSE 100
              END as percent_remaining
       FROM life_limited_parts llp
       JOIN parts p ON llp.part_id = p.id
       WHERE llp.helicopter_id = $2 AND llp.status = 'active'
       ORDER BY percent_remaining ASC`,
      [currentHours, helicopterId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get life-limited parts error:', error);
    res.status(500).json({ error: 'Failed to fetch life-limited parts' });
  }
});

// Add life-limited part
router.post('/life-limited-parts', async (req, res) => {
  const {
    part_id,
    installation_id,
    helicopter_id,
    part_serial_number,
    hour_limit,
    calendar_limit_months,
    installed_hours,
    installed_date,
    alert_threshold_percent = 80,
    notes
  } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO life_limited_parts
       (part_id, installation_id, helicopter_id, part_serial_number, hour_limit, calendar_limit_months,
        installed_hours, installed_date, alert_threshold_percent, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [part_id, installation_id, helicopter_id, part_serial_number, hour_limit, calendar_limit_months,
       installed_hours, installed_date, alert_threshold_percent, notes]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Add life-limited part error:', error);
    res.status(500).json({ error: 'Failed to add life-limited part' });
  }
});

// Update life-limited part status
router.put('/life-limited-parts/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  try {
    const result = await pool.query(
      'UPDATE life_limited_parts SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Life-limited part not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update life-limited part status error:', error);
    res.status(500).json({ error: 'Failed to update status' });
  }
});

// ============================================================
// MAINTENANCE SCHEDULES ENDPOINTS
// ============================================================

// Get maintenance schedule templates
router.get('/maintenance-schedules/templates', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM maintenance_schedules
       WHERE is_template = true AND is_active = true
       ORDER BY category, title`
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get templates error:', error);
    res.status(500).json({ error: 'Failed to fetch templates' });
  }
});

// Get maintenance schedules for a helicopter
router.get('/helicopters/:helicopterId/schedules', async (req, res) => {
  const { helicopterId } = req.params;

  try {
    const result = await pool.query(
      `SELECT * FROM maintenance_schedules
       WHERE helicopter_id = $1 AND is_active = true
       ORDER BY category, title`,
      [helicopterId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get schedules error:', error);
    res.status(500).json({ error: 'Failed to fetch schedules' });
  }
});

// Create maintenance schedule
router.post('/maintenance-schedules', async (req, res) => {
  const {
    title,
    description,
    interval_hours,
    interval_days,
    is_template = false,
    helicopter_id,
    category
  } = req.body;
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `INSERT INTO maintenance_schedules
       (title, description, interval_hours, interval_days, is_template, helicopter_id, category, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [title, description, interval_hours, interval_days, is_template, helicopter_id, category, userId]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Create schedule error:', error);
    res.status(500).json({ error: 'Failed to create schedule' });
  }
});

// Update maintenance schedule
router.put('/maintenance-schedules/:id', async (req, res) => {
  const { id } = req.params;
  const {
    title,
    description,
    interval_hours,
    interval_days,
    category,
    is_active,
    color,
    display_order,
    display_in_flight_view,
    threshold_warning
  } = req.body;

  try {
    const result = await pool.query(
      `UPDATE maintenance_schedules
       SET title = $1, description = $2, interval_hours = $3, interval_days = $4,
           category = $5, is_active = $6, color = $7, display_order = $8,
           display_in_flight_view = $9, threshold_warning = $10
       WHERE id = $11
       RETURNING *`,
      [title, description, interval_hours, interval_days, category, is_active,
       color, display_order, display_in_flight_view, threshold_warning, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Schedule not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update schedule error:', error);
    res.status(500).json({ error: 'Failed to update schedule' });
  }
});

// Get helicopters assigned to a maintenance template
router.get('/maintenance-schedules/:templateId/helicopters', async (req, res) => {
  const { templateId } = req.params;

  try {
    const result = await pool.query(
      `SELECT h.id, h.tail_number
       FROM helicopter_maintenance_templates hmt
       JOIN helicopters h ON hmt.helicopter_id = h.id
       WHERE hmt.template_id = $1 AND hmt.is_enabled = true
       ORDER BY h.tail_number`,
      [templateId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get template helicopters error:', error);
    res.status(500).json({ error: 'Failed to fetch template helicopters' });
  }
});

// Update helicopter assignments for a maintenance template
router.put('/maintenance-schedules/:templateId/helicopters', async (req, res) => {
  const { templateId } = req.params;
  const { helicopter_ids } = req.body;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Delete all existing assignments for this template
    await client.query(
      'DELETE FROM helicopter_maintenance_templates WHERE template_id = $1',
      [templateId]
    );

    // If helicopter_ids array is not empty, insert new assignments
    if (helicopter_ids && helicopter_ids.length > 0) {
      const values = helicopter_ids.map((helicopterId, index) =>
        `($1, $${index + 2}, true)`
      ).join(', ');

      await client.query(
        `INSERT INTO helicopter_maintenance_templates (template_id, helicopter_id, is_enabled)
         VALUES ${values}`,
        [templateId, ...helicopter_ids]
      );
    }

    await client.query('COMMIT');
    res.json({ message: 'Template helicopter assignments updated successfully' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Update template helicopters error:', error);
    res.status(500).json({ error: 'Failed to update template helicopters' });
  } finally {
    client.release();
  }
});

// ============================================================
// MAINTENANCE COMPLETIONS ENDPOINTS
// ============================================================

// Create maintenance completion
router.post('/maintenance-completions', async (req, res) => {
  const {
    helicopter_id,
    template_id,
    hours_at_completion,
    notes,
    completed_by
  } = req.body;
  const userId = completed_by || req.user.id;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Get template details
    const templateResult = await client.query(
      'SELECT title, interval_hours, category FROM maintenance_schedules WHERE id = $1',
      [template_id]
    );

    if (templateResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Template not found' });
    }

    const template = templateResult.rows[0];

    // Insert maintenance completion
    const completionResult = await client.query(
      `INSERT INTO maintenance_completions
       (helicopter_id, template_id, hours_at_completion, notes, completed_by)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [helicopter_id, template_id, hours_at_completion, notes, userId]
    );

    // Create corresponding maintenance log entry
    const logType = template.category || 'maintenance';
    const nextDueHours = hours_at_completion + (template.interval_hours || 0);
    const description = `${template.title} completed at ${hours_at_completion} hours`;

    await client.query(
      `INSERT INTO maintenance_logs
       (helicopter_id, log_type, hours_at_service, date_performed, performed_by,
        description, cost, next_due_hours, next_due_date, attachments, status)
       VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4, $5, NULL, $6, NULL, NULL, 'completed')`,
      [helicopter_id, logType, hours_at_completion, userId, description, nextDueHours]
    );

    await client.query('COMMIT');
    res.json(completionResult.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Create maintenance completion error:', error);
    res.status(500).json({ error: 'Failed to create maintenance completion' });
  } finally {
    client.release();
  }
});

// Get maintenance completions for a helicopter
router.get('/helicopters/:helicopterId/maintenance-completions', async (req, res) => {
  const { helicopterId } = req.params;
  const { limit = 50, offset = 0 } = req.query;

  try {
    const result = await pool.query(
      `SELECT mc.*,
              ms.title as maintenance_title,
              ms.category as maintenance_category,
              ms.color as maintenance_color,
              u.username as completed_by_username,
              u.full_name as completed_by_name
       FROM maintenance_completions mc
       LEFT JOIN maintenance_schedules ms ON mc.template_id = ms.id
       LEFT JOIN users u ON mc.completed_by = u.id
       WHERE mc.helicopter_id = $1
       ORDER BY mc.completed_at DESC
       LIMIT $2 OFFSET $3`,
      [helicopterId, limit, offset]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get maintenance completions error:', error);
    res.status(500).json({ error: 'Failed to fetch maintenance completions' });
  }
});

// ============================================================
// DASHBOARD ENDPOINTS
// ============================================================

// Get helicopter dashboard (summary of upcoming maintenance)
router.get('/helicopters/:helicopterId/dashboard', async (req, res) => {
  const { helicopterId } = req.params;

  try {
    // Get helicopter info with current hours
    const heliResult = await pool.query(
      'SELECT * FROM helicopters WHERE id = $1',
      [helicopterId]
    );

    if (heliResult.rows.length === 0) {
      return res.status(404).json({ error: 'Helicopter not found' });
    }

    const helicopter = heliResult.rows[0];
    const currentHours = parseFloat(helicopter.current_hours) || 0;

    // Get next oil change
    const oilChangeResult = await pool.query(
      `SELECT ml.*, u.username as performed_by_username
       FROM maintenance_logs ml
       LEFT JOIN users u ON ml.performed_by = u.id
       WHERE ml.helicopter_id = $1 AND ml.log_type = 'oil_change' AND ml.next_due_hours IS NOT NULL
       ORDER BY ml.date_performed DESC
       LIMIT 1`,
      [helicopterId]
    );

    // Get upcoming scheduled maintenance with hours/days remaining
    const schedulesResult = await pool.query(
      `SELECT ms.id, ms.title, ms.category,
              COALESCE(msh.next_due_hours, ms.interval_hours) as next_due_hours,
              COALESCE(msh.next_due_date::TEXT,
                CASE WHEN ms.interval_days IS NOT NULL
                  THEN (CURRENT_DATE + (ms.interval_days || ' days')::interval)::DATE::TEXT
                  ELSE NULL
                END) as next_due_date,
              CASE
                WHEN COALESCE(msh.next_due_hours, ms.interval_hours) IS NOT NULL
                THEN COALESCE(msh.next_due_hours, ms.interval_hours) - $1
                ELSE NULL
              END as hours_remaining,
              CASE
                WHEN COALESCE(msh.next_due_date::TEXT,
                  CASE WHEN ms.interval_days IS NOT NULL
                    THEN (CURRENT_DATE + (ms.interval_days || ' days')::interval)::DATE::TEXT
                    ELSE NULL
                  END) IS NOT NULL
                THEN (COALESCE(msh.next_due_date::TEXT,
                  CASE WHEN ms.interval_days IS NOT NULL
                    THEN (CURRENT_DATE + (ms.interval_days || ' days')::interval)::DATE::TEXT
                    ELSE NULL
                  END)::DATE - CURRENT_DATE)::INTEGER
                ELSE NULL
              END as days_remaining
       FROM maintenance_schedules ms
       LEFT JOIN LATERAL (
         SELECT * FROM maintenance_schedule_history
         WHERE schedule_id = ms.id
         ORDER BY completed_date DESC
         LIMIT 1
       ) msh ON true
       WHERE ms.helicopter_id = $2 AND ms.is_active = true
       ORDER BY COALESCE(msh.next_due_hours, ms.interval_hours) ASC,
                COALESCE(msh.next_due_date,
                  CASE WHEN ms.interval_days IS NOT NULL
                    THEN (CURRENT_DATE + (ms.interval_days || ' days')::interval)::DATE
                    ELSE CURRENT_DATE
                  END) ASC
       LIMIT 10`,
      [currentHours, helicopterId]
    );

    // Get life-limited parts with full details
    const lifePartsResult = await pool.query(
      `SELECT llp.*,
              p.part_number,
              p.description as part_description,
              CASE
                WHEN llp.hour_limit IS NOT NULL
                THEN llp.hour_limit - ($1 - llp.installed_hours)
                ELSE NULL
              END as hours_remaining,
              CASE
                WHEN llp.calendar_limit_months IS NOT NULL
                THEN EXTRACT(DAY FROM ((llp.installed_date + (llp.calendar_limit_months || ' months')::interval) - CURRENT_DATE))::INTEGER
                ELSE NULL
              END as days_remaining,
              CASE
                WHEN llp.hour_limit IS NOT NULL AND llp.calendar_limit_months IS NOT NULL
                THEN LEAST(
                  ((llp.hour_limit - ($1 - llp.installed_hours)) / llp.hour_limit) * 100,
                  (EXTRACT(DAY FROM ((llp.installed_date + (llp.calendar_limit_months || ' months')::interval) - CURRENT_DATE))::DECIMAL / (llp.calendar_limit_months * 30)) * 100
                )
                WHEN llp.hour_limit IS NOT NULL
                THEN ((llp.hour_limit - ($1 - llp.installed_hours)) / llp.hour_limit) * 100
                WHEN llp.calendar_limit_months IS NOT NULL
                THEN (EXTRACT(DAY FROM ((llp.installed_date + (llp.calendar_limit_months || ' months')::interval) - CURRENT_DATE))::DECIMAL / (llp.calendar_limit_months * 30)) * 100
                ELSE 100
              END as percent_remaining
       FROM life_limited_parts llp
       LEFT JOIN parts p ON llp.part_id = p.id
       WHERE llp.helicopter_id = $2 AND llp.status = 'active'
       ORDER BY percent_remaining ASC`,
      [currentHours, helicopterId]
    );

    // Get recent fluid logs
    const fluidLogsResult = await pool.query(
      `SELECT fl.*, u.username as added_by_username
       FROM fluid_logs fl
       LEFT JOIN users u ON fl.added_by = u.id
       WHERE fl.helicopter_id = $1
       ORDER BY fl.date_added DESC
       LIMIT 10`,
      [helicopterId]
    );

    // Get recent part installations
    const installationsResult = await pool.query(
      `SELECT pi.*,
              p.part_number,
              p.description,
              u.username as installed_by_username
       FROM part_installations pi
       LEFT JOIN parts p ON pi.part_id = p.id
       LEFT JOIN users u ON pi.installed_by = u.id
       WHERE pi.helicopter_id = $1 AND pi.status = 'active'
       ORDER BY pi.installation_date DESC
       LIMIT 10`,
      [helicopterId]
    );

    // Get flight view maintenance status (for display in flight page banners)
    const flightViewMaintenanceResult = await pool.query(
      `SELECT ms.id, ms.title, ms.interval_hours, ms.color, ms.display_order, ms.threshold_warning,
              mc.hours_at_completion as last_completed_hours,
              mc.hours_at_completion + ms.interval_hours as next_due_hours,
              CASE
                WHEN mc.hours_at_completion IS NOT NULL
                THEN (mc.hours_at_completion + ms.interval_hours) - $1
                ELSE ms.interval_hours
              END as hours_remaining
       FROM maintenance_schedules ms
       LEFT JOIN LATERAL (
         SELECT hours_at_completion
         FROM maintenance_completions
         WHERE template_id = ms.id
         AND helicopter_id = $2
         ORDER BY completed_at DESC
         LIMIT 1
       ) mc ON true
       LEFT JOIN helicopter_maintenance_templates hmt
         ON hmt.template_id = ms.id AND hmt.helicopter_id = $2 AND hmt.is_enabled = true
       WHERE ms.is_template = true
         AND ms.is_active = true
         AND ms.display_in_flight_view = true
         AND (
           hmt.id IS NOT NULL
           OR NOT EXISTS (
             SELECT 1 FROM helicopter_maintenance_templates
             WHERE template_id = ms.id
           )
         )
       ORDER BY ms.display_order ASC
       LIMIT 5`,
      [currentHours, helicopterId]
    );

    res.json({
      helicopter,
      oil_change: oilChangeResult.rows[0] || null,
      hours_until_oil_change: oilChangeResult.rows[0] ?
        parseFloat(oilChangeResult.rows[0].next_due_hours) - currentHours : null,
      upcoming_maintenance: schedulesResult.rows,
      life_limited_parts: lifePartsResult.rows,
      recent_fluids: fluidLogsResult.rows,
      recent_installations: installationsResult.rows,
      flight_view_maintenance: flightViewMaintenanceResult.rows
    });
  } catch (error) {
    console.error('Get dashboard error:', error);
    res.status(500).json({ error: 'Failed to fetch dashboard' });
  }
});

module.exports = router;
