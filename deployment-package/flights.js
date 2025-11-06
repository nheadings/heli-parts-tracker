const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// All routes require authentication
router.use(authenticateToken);

// ============================================================
// FLIGHTS ENDPOINTS
// ============================================================

// Get all flights for a helicopter
router.get('/helicopters/:helicopterId/flights', async (req, res) => {
  const { helicopterId } = req.params;
  const { limit = 50 } = req.query;

  try {
    const result = await pool.query(
      `SELECT f.*,
              u.username as pilot_username,
              u.full_name as pilot_name,
              h.tail_number
       FROM flights f
       LEFT JOIN users u ON f.pilot_id = u.id
       LEFT JOIN helicopters h ON f.helicopter_id = h.id
       WHERE f.helicopter_id = $1
       ORDER BY f.departure_time DESC
       LIMIT $2`,
      [helicopterId, limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get flights error:', error);
    res.status(500).json({ error: 'Failed to fetch flights' });
  }
});

// Get single flight
router.get('/flights/:flightId', async (req, res) => {
  const { flightId } = req.params;

  try {
    const result = await pool.query(
      `SELECT f.*,
              u.username as pilot_username,
              u.full_name as pilot_name,
              h.tail_number
       FROM flights f
       LEFT JOIN users u ON f.pilot_id = u.id
       LEFT JOIN helicopters h ON f.helicopter_id = h.id
       WHERE f.id = $1`,
      [flightId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Flight not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get flight error:', error);
    res.status(500).json({ error: 'Failed to fetch flight' });
  }
});

// Add new flight
router.post('/helicopters/:helicopterId/flights', async (req, res) => {
  const { helicopterId } = req.params;
  const {
    hobbs_start,
    hobbs_end,
    departure_time,
    arrival_time,
    hobbs_photo_url,
    ocr_confidence,
    notes
  } = req.body;
  const pilotId = req.user.id;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Insert flight record
    const flightResult = await client.query(
      `INSERT INTO flights
       (helicopter_id, pilot_id, hobbs_start, hobbs_end, departure_time, arrival_time,
        hobbs_photo_url, ocr_confidence, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [helicopterId, pilotId, hobbs_start, hobbs_end, departure_time, arrival_time,
       hobbs_photo_url, ocr_confidence, notes]
    );

    // Update helicopter current hours if hobbs_end is provided
    if (hobbs_end) {
      await client.query(
        `UPDATE helicopters
         SET current_hours = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [hobbs_end, helicopterId]
      );

      // Also add to helicopter_hours table for history
      await client.query(
        `INSERT INTO helicopter_hours
         (helicopter_id, hours, recorded_by, photo_url, ocr_confidence, entry_method, notes)
         VALUES ($1, $2, $3, $4, $5, 'flight', $6)`,
        [helicopterId, hobbs_end, pilotId, hobbs_photo_url, ocr_confidence, notes]
      );
    }

    await client.query('COMMIT');

    // Fetch the complete flight record
    const completeResult = await pool.query(
      `SELECT f.*,
              u.username as pilot_username,
              u.full_name as pilot_name,
              h.tail_number
       FROM flights f
       LEFT JOIN users u ON f.pilot_id = u.id
       LEFT JOIN helicopters h ON f.helicopter_id = h.id
       WHERE f.id = $1`,
      [flightResult.rows[0].id]
    );

    res.json(completeResult.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Add flight error:', error);
    res.status(500).json({ error: 'Failed to add flight' });
  } finally {
    client.release();
  }
});

// Update flight
router.put('/flights/:flightId', async (req, res) => {
  const { flightId } = req.params;
  const {
    hobbs_start,
    hobbs_end,
    departure_time,
    arrival_time,
    hobbs_photo_url,
    ocr_confidence,
    notes
  } = req.body;

  try {
    const result = await pool.query(
      `UPDATE flights
       SET hobbs_start = $1, hobbs_end = $2, departure_time = $3, arrival_time = $4,
           hobbs_photo_url = $5, ocr_confidence = $6, notes = $7
       WHERE id = $8
       RETURNING *`,
      [hobbs_start, hobbs_end, departure_time, arrival_time,
       hobbs_photo_url, ocr_confidence, notes, flightId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Flight not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update flight error:', error);
    res.status(500).json({ error: 'Failed to update flight' });
  }
});

// Delete flight
router.delete('/flights/:flightId', async (req, res) => {
  const { flightId } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM flights WHERE id = $1 RETURNING id',
      [flightId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Flight not found' });
    }

    res.json({ message: 'Flight deleted successfully' });
  } catch (error) {
    console.error('Delete flight error:', error);
    res.status(500).json({ error: 'Failed to delete flight' });
  }
});

module.exports = router;
