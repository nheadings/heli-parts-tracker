# Helicopter Parts Tracker

Comprehensive helicopter maintenance tracking system with native iOS app and Node.js backend.

## Project Overview

**Stack**: Native iOS (SwiftUI) + Node.js/Express + PostgreSQL

Complete system for tracking helicopter parts inventory, maintenance logs, and flight hours with a comprehensive logbook system.

## Project Structure

```
heli-parts-tracker/
├── backend/                  # Node.js/Express API server
│   ├── routes/              # API endpoints
│   ├── database/            # PostgreSQL schema and migrations
│   └── README.md            # Backend documentation
├── ios-appnew/              # ✅ CURRENT iOS app (SwiftUI)
│   └── HeliPartsTracker/
│       ├── Models/
│       ├── Views/
│       ├── ViewModels/
│       ├── Services/
│       └── README.md        # iOS app documentation
└── ios-app/                 # ⚠️ DEPRECATED - Legacy prototype
```

## Features

### Parts Management
- Real-time inventory tracking
- QR code scanning and generation
- Low stock alerts
- Part installation tracking
- Vendor management with reorder links

### Logbook System
- Helicopter hours tracking with full history
- Maintenance logs (oil changes, inspections, repairs, AD compliance, service)
- Fluid tracking (engine oil, transmission oil, hydraulic fluid, fuel)
- Life-limited parts monitoring
- Maintenance schedules
- **Editable entries with confirmation warnings**

### Fleet Management
- 9 pre-configured helicopters
- Comprehensive dashboard per helicopter
- Part installation history
- Upcoming maintenance tracking

## Quick Start

### 1. Backend Setup

```bash
cd backend
npm install
createdb heli_parts_tracker
psql heli_parts_tracker < database/schema.sql
cp .env.example .env
# Edit .env with your database credentials
npm start
```

Backend will run on `http://localhost:3000`

See `backend/README.md` for detailed setup instructions.

### 2. iOS App Setup

```bash
cd ios-appnew/HeliPartsTracker
open HeliPartsTracker.xcodeproj
```

1. Select your development team in Xcode
2. Build and run (⌘R)

See `ios-appnew/HeliPartsTracker/README.md` for detailed build instructions.

## Default Credentials

- **Username**: `admin`
- **Password**: `admin123`

## System Architecture

```
┌─────────────────┐
│   iOS App       │
│   (SwiftUI)     │
└────────┬────────┘
         │ REST API
         │ (HTTP)
┌────────▼────────┐
│  Node.js/Express│
│   Backend API   │
└────────┬────────┘
         │ SQL
         │
┌────────▼────────┐
│   PostgreSQL    │
│   Database      │
└─────────────────┘
```

## API Endpoints

### Core Resources
- `/api/auth/*` - Authentication
- `/api/parts/*` - Parts inventory
- `/api/helicopters/*` - Fleet management
- `/api/installations/*` - Part installations
- `/api/logbook/*` - Logbook system

See `backend/README.md` for complete API documentation.

## Database Schema

Main tables:
- `users` - User authentication
- `parts` - Parts inventory
- `helicopters` - Fleet helicopters
- `part_installations` - Installation records
- `helicopter_hours` - Hours tracking
- `maintenance_logs` - Maintenance records
- `fluid_logs` - Fluid addition records
- `life_limited_parts` - Life-limited parts tracking
- `maintenance_schedules` - Scheduled maintenance
- `inventory_transactions` - Audit trail

## Development Server (Backend)

Backend is deployed on `192.168.68.6`:

```bash
ssh heli-parts-backend@192.168.68.6
cd backend
npm start
```

Health check:
```bash
curl http://192.168.68.6:3000/health
```

## Backup

Backup created: `heli-parts-tracker-backup-20251106-061537.tar.gz`

To create new backup:
```bash
cd /Users/normanheadings
tar -czf heli-parts-tracker-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  --exclude='node_modules' \
  --exclude='.git' \
  --exclude='DerivedData' \
  --exclude='build' \
  heli-parts-tracker/
```

## Recent Updates

**November 2025**
- Added comprehensive logbook system with editable entries
- Implemented fluid tracking and maintenance logs
- Added life-limited parts monitoring
- Implemented maintenance schedules
- Added warning dialogs for editing historical logbook data
- Made logbook entries clickable and editable throughout the app

## Technology Stack

- **iOS**: SwiftUI, iOS 26.0+, native camera APIs
- **Backend**: Node.js 14+, Express 4.x
- **Database**: PostgreSQL 12+
- **Authentication**: JWT with bcrypt
- **Development**: Xcode 16.0+, nodemon

## Notes

- Native iOS app (no cross-platform frameworks)
- No third-party dependencies on iOS side
- All data synced via REST API
- Local development uses HTTP (configure HTTPS for production)

## License

Proprietary - All rights reserved
