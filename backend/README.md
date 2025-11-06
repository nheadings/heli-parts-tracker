# Helicopter Parts Tracker - Backend API

Node.js/Express backend API for managing helicopter parts inventory and tracking installations.

## Features

- JWT-based authentication with user roles
- Parts inventory management with QR code support
- Helicopter fleet management
- Part installation tracking
- Customizable low inventory alerts
- Real-time search functionality
- Comprehensive transaction logging
- **Logbook system** with helicopter hours tracking, maintenance logs, fluid logs, and life-limited parts
- **Maintenance schedules** and AD compliance tracking
- Comprehensive dashboard with upcoming maintenance and alerts

## Prerequisites

- Node.js (v14 or higher)
- PostgreSQL (v12 or higher)
- npm or yarn

## Installation

1. Install dependencies:
```bash
cd backend
npm install
```

2. Set up PostgreSQL database:
```bash
# Create database
createdb heli_parts_tracker

# Run schema
psql heli_parts_tracker < database/schema.sql
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your database credentials and JWT secret
```

4. Start the server:
```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

The API will be available at `http://localhost:3000`

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| DB_HOST | PostgreSQL host | localhost |
| DB_PORT | PostgreSQL port | 5432 |
| DB_NAME | Database name | heli_parts_tracker |
| DB_USER | Database user | postgres |
| DB_PASSWORD | Database password | your_password |
| JWT_SECRET | Secret key for JWT tokens | random_secret_string |
| PORT | API server port | 3000 |

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login and get JWT token
- `GET /api/auth/verify` - Verify token

### Parts
- `GET /api/parts` - Get all parts
- `GET /api/parts/search?query=XXX` - Search parts by number or description
- `GET /api/parts/:id` - Get part by ID
- `GET /api/parts/qr/:qr_code` - Get part by QR code
- `POST /api/parts` - Create new part
- `PUT /api/parts/:id` - Update part
- `DELETE /api/parts/:id` - Delete part
- `GET /api/parts/alerts/low-stock` - Get parts with low stock

### Helicopters
- `GET /api/helicopters` - Get all helicopters
- `GET /api/helicopters/:id` - Get helicopter by ID
- `GET /api/helicopters/:id/parts` - Get all parts installed on helicopter
- `GET /api/helicopters/:id/history` - Get installation history
- `POST /api/helicopters` - Create new helicopter
- `PUT /api/helicopters/:id` - Update helicopter
- `DELETE /api/helicopters/:id` - Delete helicopter

### Installations
- `GET /api/installations` - Get all installations
- `GET /api/installations/:id` - Get installation by ID
- `POST /api/installations` - Install part on helicopter
- `POST /api/installations/:id/remove` - Remove part from helicopter

### Alerts
- `GET /api/alerts` - Get all alerts
- `GET /api/alerts/active` - Get active alerts (triggered)
- `POST /api/alerts` - Create new alert
- `PUT /api/alerts/:id` - Update alert
- `DELETE /api/alerts/:id` - Delete alert

### Logbook
- `GET /api/logbook/helicopters/:id/dashboard` - Get comprehensive logbook dashboard
- `GET /api/logbook/helicopters/:id/hours` - Get helicopter hours history
- `POST /api/logbook/helicopters/:id/hours` - Update helicopter hours
- `PUT /api/logbook/hours/:id` - Update hours entry
- `GET /api/logbook/helicopters/:id/maintenance` - Get maintenance logs
- `POST /api/logbook/helicopters/:id/maintenance` - Create maintenance log
- `PUT /api/logbook/maintenance/:id` - Update maintenance log
- `DELETE /api/logbook/maintenance/:id` - Delete maintenance log
- `GET /api/logbook/helicopters/:id/fluids` - Get fluid logs
- `POST /api/logbook/helicopters/:id/fluids` - Create fluid log
- `PUT /api/logbook/fluids/:id` - Update fluid log
- `GET /api/logbook/helicopters/:id/life-limited-parts` - Get life-limited parts
- `POST /api/logbook/life-limited-parts` - Create life-limited part
- `PUT /api/logbook/life-limited-parts/:id` - Update life-limited part
- `POST /api/logbook/life-limited-parts/:id/remove` - Remove life-limited part
- `GET /api/logbook/helicopters/:id/schedules` - Get maintenance schedules
- `POST /api/logbook/maintenance-schedules` - Create maintenance schedule
- `PUT /api/logbook/maintenance-schedules/:id` - Update maintenance schedule
- `DELETE /api/logbook/maintenance-schedules/:id` - Delete maintenance schedule

## Database Schema

The database includes the following tables:
- `users` - User accounts with authentication
- `helicopters` - Fleet helicopters
- `parts` - Parts inventory
- `part_installations` - Installation records
- `inventory_alerts` - Custom alert configurations
- `inventory_transactions` - Audit log of all inventory changes

## Authentication

All endpoints except `/api/auth/register` and `/api/auth/login` require authentication.

Include the JWT token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

## Sample Data

The schema includes 9 sample helicopters with tail numbers N100H through N108H.

To create a test user:
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "email": "admin@example.com",
    "password": "password123",
    "full_name": "Admin User",
    "role": "admin"
  }'
```

## Development

The server uses nodemon for auto-reload during development:
```bash
npm run dev
```

## Production Deployment

1. Set up PostgreSQL on your server
2. Copy files to server
3. Configure `.env` with production values
4. Install dependencies: `npm install --production`
5. Run database schema: `psql heli_parts_tracker < database/schema.sql`
6. Start server: `npm start`

Consider using PM2 for process management:
```bash
npm install -g pm2
pm2 start server.js --name heli-tracker-api
pm2 save
pm2 startup
```

## Security Notes

- Change JWT_SECRET to a strong random string in production
- Use HTTPS in production
- Configure PostgreSQL to require SSL connections
- Implement rate limiting for production
- Keep dependencies updated

## License

Proprietary - All rights reserved
