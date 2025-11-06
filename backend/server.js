const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Import routes
const authRoutes = require('./routes/auth');
const partsRoutes = require('./routes/parts');
const helicoptersRoutes = require('./routes/helicopters');
const installationsRoutes = require('./routes/installations');
const alertsRoutes = require('./routes/alerts');
const logbookRoutes = require('./routes/logbook');
const flightsRoutes = require('./routes/flights');
const squawksRoutes = require('./routes/squawks');

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/parts', partsRoutes);
app.use('/api/helicopters', helicoptersRoutes);
app.use('/api/installations', installationsRoutes);
app.use('/api/alerts', alertsRoutes);
app.use('/api/logbook', logbookRoutes);
app.use('/api/flights', flightsRoutes);
app.use('/api/squawks', squawksRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Helicopter Parts Tracker API',
    version: '1.0.0',
    endpoints: {
      auth: '/api/auth',
      parts: '/api/parts',
      helicopters: '/api/helicopters',
      installations: '/api/installations',
      alerts: '/api/alerts',
      logbook: '/api/logbook',
      flights: '/api/flights',
      squawks: '/api/squawks'
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🚁 Helicopter Parts Tracker API`);
  console.log(`📡 Server running on http://localhost:${PORT}`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health\n`);
});

module.exports = app;
