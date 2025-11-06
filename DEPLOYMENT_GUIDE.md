# Flight Page Deployment Guide

## Quick Start

You have two options for deployment:

1. **Option A**: Deploy to production server (192.168.68.6)
2. **Option B**: Test locally first

---

## Option A: Deploy to Production Server (192.168.68.6)

### Prerequisites
- SSH access to `heli-parts-backend@192.168.68.6`
- PostgreSQL database access on the server

### Step 1: Copy Files to Server

From your local machine:

```bash
cd /Users/normanheadings/heli-parts-tracker

# Copy new route files
scp backend/routes/flights.js heli-parts-backend@192.168.68.6:backend/routes/
scp backend/routes/squawks.js heli-parts-backend@192.168.68.6:backend/routes/

# Copy updated server.js
scp backend/server.js heli-parts-backend@192.168.68.6:backend/

# Copy migration files
scp backend/database/flights-squawks-migration.sql heli-parts-backend@192.168.68.6:backend/database/
scp backend/run-flights-migration.sh heli-parts-backend@192.168.68.6:backend/
```

### Step 2: SSH into Server and Run Migration

```bash
ssh heli-parts-backend@192.168.68.6

# Navigate to backend directory
cd backend

# Make migration script executable
chmod +x run-flights-migration.sh

# Run the migration
./run-flights-migration.sh
```

Expected output:
```
Running Flights and Squawks Migration...
Database: heli_parts_tracker
Migration file: database/flights-squawks-migration.sql

CREATE TABLE
CREATE TABLE
CREATE INDEX
...
✅ Migration completed successfully!
```

### Step 3: Restart Backend Server

Still on the server:

```bash
# Stop the current server (if running)
pkill -f "node.*server.js"

# Start the server
npm start
```

Or if using PM2:
```bash
pm2 restart heli-parts-backend
```

### Step 4: Verify Deployment

Test the health endpoint:
```bash
curl http://192.168.68.6:3000/health
```

Should return:
```json
{"status":"ok","timestamp":"2025-11-06T..."}
```

Test new endpoints are registered:
```bash
curl http://192.168.68.6:3000/
```

Should include in the response:
```json
{
  "endpoints": {
    ...
    "flights": "/api/flights",
    "squawks": "/api/squawks"
  }
}
```

---

## Option B: Test Locally First

### Step 1: Setup Local Database (if not already done)

```bash
# Create database
createdb heli_parts_tracker

# Run main schema
cd /Users/normanheadings/heli-parts-tracker/backend
psql heli_parts_tracker < database/schema.sql

# Run logbook migration
psql heli_parts_tracker < database/logbook-migration.sql

# Run flights/squawks migration
psql heli_parts_tracker < database/flights-squawks-migration.sql
```

### Step 2: Configure Environment

Create `.env` file in backend directory:

```bash
cd /Users/normanheadings/heli-parts-tracker/backend
cat > .env << EOF
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=heli_parts_tracker
DB_USER=your_username
DB_PASSWORD=your_password
JWT_SECRET=your_secret_key_here
EOF
```

### Step 3: Start Local Backend

```bash
cd /Users/normanheadings/heli-parts-tracker/backend
npm start
```

Expected output:
```
🚁 Helicopter Parts Tracker API
📡 Server running on http://localhost:3000
🏥 Health check: http://localhost:3000/health
```

### Step 4: Update iOS App for Local Testing

Edit `ios-appnew/HeliPartsTracker/HeliPartsTracker/Services/APIService.swift`:

Change line 6:
```swift
private let baseURL = "http://localhost:3000/api"
```

Or use your Mac's IP address for testing on a device:
```swift
private let baseURL = "http://YOUR_MAC_IP:3000/api"
```

---

## iOS App Build & Deploy

### Step 1: Open Project in Xcode

```bash
cd /Users/normanheadings/heli-parts-tracker/ios-appnew/HeliPartsTracker
open HeliPartsTracker.xcodeproj
```

### Step 2: Build the App

In Xcode:

1. **Select your target device/simulator** from the dropdown (top-left)
2. **Select a development team** (if prompted):
   - Xcode → Preferences → Accounts → Add your Apple ID
   - Select your team in project settings
3. **Build the app**: `Product → Build` (⌘B)

Fix any build errors if they appear.

### Step 3: Add New Files to Xcode (if needed)

If the new Swift files aren't in the project:

1. Right-click on the `Views` folder in Xcode
2. Select `Add Files to "HeliPartsTracker"...`
3. Navigate to and select:
   - `FlightView.swift`
   - `HobbsScannerView.swift`
   - `AddSquawkView.swift`
   - `SquawkDetailView.swift`
4. Right-click on `Models` folder and add:
   - `FlightModels.swift`
5. Ensure "Copy items if needed" is checked
6. Ensure "HeliPartsTracker" target is selected

### Step 4: Run the App

1. **Run on simulator**: `Product → Run` (⌘R)
2. **Or run on device**:
   - Connect your iOS device
   - Select it from the device dropdown
   - Trust the device if prompted
   - Run (⌘R)

### Step 5: Test the Flight Page

1. Login with credentials: `admin` / `admin123`
2. Tap the **Flights** tab (airplane icon)
3. Test features:
   - ✅ Select different aircraft from dropdown
   - ✅ Check oil change/fuel line AD indicators
   - ✅ Tap "Scan Hobbs" button
   - ✅ Tap "Add Squawk" button
   - ✅ Create a test squawk
   - ✅ Tap on squawk to view details
   - ✅ Mark squawk as fixed

---

## Troubleshooting

### Backend Issues

**Problem**: Migration fails with "psql: command not found"
```bash
# Solution: Run migration manually
psql heli_parts_tracker < backend/database/flights-squawks-migration.sql
```

**Problem**: Server fails to start
```bash
# Check logs
tail -f backend/server.log  # or wherever your logs are

# Common issues:
# - Port 3000 already in use: kill the process or use different port
# - Database connection fails: check .env file credentials
```

**Problem**: "Cannot find module './routes/flights'"
```bash
# Verify files were copied correctly
ls -la backend/routes/flights.js
ls -la backend/routes/squawks.js
```

### iOS Build Issues

**Problem**: "No such module 'FlightModels'"
- Make sure `FlightModels.swift` is added to the Xcode project
- Check it's in the correct target membership

**Problem**: "Use of undeclared type 'Squawk'"
- Build the project (⌘B) to ensure all files are compiled
- Check import statements

**Problem**: App crashes on Flights tab
- Check backend is running and accessible
- Verify API base URL is correct in `APIService.swift`
- Check Xcode console for error messages

### Database Issues

**Problem**: Tables already exist
```sql
-- Drop and recreate if needed (CAUTION: will lose data)
DROP TABLE IF EXISTS squawks CASCADE;
DROP TABLE IF EXISTS flights CASCADE;

-- Then re-run migration
\i backend/database/flights-squawks-migration.sql
```

---

## Verification Checklist

### Backend
- [ ] Migration script ran successfully
- [ ] Server starts without errors
- [ ] Health check returns OK: `curl http://192.168.68.6:3000/health`
- [ ] Flights endpoint exists: `curl http://192.168.68.6:3000/ | grep flights`
- [ ] Squawks endpoint exists: `curl http://192.168.68.6:3000/ | grep squawks`

### iOS App
- [ ] App builds without errors
- [ ] Flights tab appears in navigation
- [ ] Aircraft dropdown shows helicopters
- [ ] Maintenance indicators display
- [ ] Can open Hobbs scanner
- [ ] Can add squawk
- [ ] Squawks display correctly
- [ ] Can mark squawk as fixed
- [ ] Color coding works (white/amber/red)

---

## Quick Commands Reference

### Backend Server Management
```bash
# Start server
cd backend && npm start

# Start with PM2 (if installed)
pm2 start backend/server.js --name heli-parts-backend

# View logs
pm2 logs heli-parts-backend

# Restart server
pm2 restart heli-parts-backend

# Stop server
pm2 stop heli-parts-backend
```

### Database Operations
```bash
# Connect to database
psql heli_parts_tracker

# Run migration
psql heli_parts_tracker < backend/database/flights-squawks-migration.sql

# Check tables were created
psql heli_parts_tracker -c "\dt"

# View squawks
psql heli_parts_tracker -c "SELECT * FROM squawks;"

# View flights
psql heli_parts_tracker -c "SELECT * FROM flights;"
```

### Testing API Endpoints
```bash
# Replace 192.168.68.6 with localhost if testing locally

# Health check
curl http://192.168.68.6:3000/health

# List all endpoints
curl http://192.168.68.6:3000/

# Get squawks for helicopter ID 1 (requires auth token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://192.168.68.6:3000/api/squawks/helicopters/1/squawks

# Get flights for helicopter ID 1 (requires auth token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://192.168.68.6:3000/api/flights/helicopters/1/flights
```

---

## Next Steps After Deployment

1. **Create sample squawks** for testing
2. **Add maintenance schedules** for oil change and fuel line AD tracking
3. **Test Hobbs scanning** with actual device camera
4. **Train pilots** on using the new features

---

## Need Help?

Check these files for more information:
- `FLIGHT_PAGE_IMPLEMENTATION.md` - Feature details and API documentation
- `backend/README.md` - Backend setup instructions
- `ios-appnew/HeliPartsTracker/README.md` - iOS app documentation
