# Backend Deployment Package

## 📦 Contents

This package contains everything needed to deploy the Flight Page backend:

- `flights.js` - Flights API routes
- `squawks.js` - Squawks API routes
- `server.js` - Updated main server file
- `flights-squawks-migration.sql` - Database migration
- `run-flights-migration.sh` - Migration runner script
- `DEPLOY.sh` - One-command deployment script

---

## 🚀 Quick Deploy (Recommended)

### One Command:

```bash
cd deployment-package
./DEPLOY.sh
```

Enter your server password when prompted. The script will:
1. ✅ Copy all files to server
2. ✅ Run database migration
3. ✅ Restart backend server
4. ✅ Verify deployment

---

## 📋 Manual Deploy (If script doesn't work)

### Step 1: Copy Files

```bash
# Copy route files
scp flights.js heli-parts-backend@192.168.68.6:backend/routes/
scp squawks.js heli-parts-backend@192.168.68.6:backend/routes/

# Copy server file
scp server.js heli-parts-backend@192.168.68.6:backend/

# Copy migration files
scp flights-squawks-migration.sql heli-parts-backend@192.168.68.6:backend/database/
scp run-flights-migration.sh heli-parts-backend@192.168.68.6:backend/
```

### Step 2: SSH to Server

```bash
ssh heli-parts-backend@192.168.68.6
```

### Step 3: Run Migration (on server)

```bash
cd backend
chmod +x run-flights-migration.sh
./run-flights-migration.sh
```

Expected output:
```
Running Flights and Squawks Migration...
CREATE TABLE
CREATE TABLE
...
✅ Migration completed successfully!
```

### Step 4: Restart Server (on server)

```bash
cd backend
pkill -f "node.*server.js"
npm start
```

Server should show:
```
🚁 Helicopter Parts Tracker API
📡 Server running on http://localhost:3000
```

### Step 5: Verify

```bash
curl http://localhost:3000/health
```

Should return:
```json
{"status":"ok","timestamp":"..."}
```

---

## 🧪 Test After Deployment

### From Command Line:

```bash
# Health check
curl http://192.168.68.6:3000/health

# Check endpoints are registered
curl http://192.168.68.6:3000/ | grep -E "(flights|squawks)"
```

### From iPhone App:

1. Open **HeliPartsTracker** on iPhone
2. Login: `admin` / `admin123`
3. Tap **Flights** tab (✈️)
4. Test features:
   - Select aircraft
   - Scan Hobbs meter
   - Add squawk
   - Mark squawk as fixed

---

## ⚠️ Troubleshooting

### SSH Connection Failed

**Issue**: `Permission denied (publickey,password)`

**Solutions**:
1. Check you have the correct password
2. Set up SSH key:
   ```bash
   ssh-keygen -t rsa
   ssh-copy-id heli-parts-backend@192.168.68.6
   ```
3. Use manual deployment method above

### Migration Already Run

**Issue**: `relation "flights" already exists`

**Solution**: Tables already exist - skip to restart server step

### Server Won't Start

**Issue**: Server fails to start

**Check**:
```bash
ssh heli-parts-backend@192.168.68.6
cd backend
tail -f server.log
```

Common issues:
- Port 3000 in use
- Database connection failed
- Missing dependencies

**Fix**:
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9

# Check database
psql heli_parts_tracker -c "\dt"

# Reinstall dependencies
npm install
```

### Health Check Fails

**Issue**: `curl` returns error or no response

**Check**:
1. Server is running: `pgrep -f "node.*server.js"`
2. Port is open: `telnet 192.168.68.6 3000`
3. Firewall allows port 3000

---

## 📊 What Gets Deployed

### Database Tables
- `flights` - Flight records with Hobbs data
- `squawks` - Maintenance discrepancies

### API Endpoints
- `/api/flights/*` - Flight operations
- `/api/squawks/*` - Squawk management

### File Locations on Server
```
backend/
├── routes/
│   ├── flights.js      ← NEW
│   └── squawks.js      ← NEW
├── database/
│   └── flights-squawks-migration.sql ← NEW
├── server.js           ← UPDATED
└── run-flights-migration.sh ← NEW
```

---

## ✅ Success Indicators

After successful deployment:

1. **Health check returns OK**:
   ```bash
   curl http://192.168.68.6:3000/health
   # {"status":"ok",...}
   ```

2. **Endpoints registered**:
   ```bash
   curl http://192.168.68.6:3000/
   # Shows "flights" and "squawks" in endpoints list
   ```

3. **Database tables exist**:
   ```bash
   psql heli_parts_tracker -c "\dt flights"
   # Table "public.flights" exists
   ```

4. **App connects**:
   - Open app on iPhone
   - Navigate to Flights tab
   - No connection errors

---

## 🎯 Quick Reference

| Action | Command |
|--------|---------|
| Deploy everything | `./DEPLOY.sh` |
| Check server status | `ssh heli-parts-backend@192.168.68.6 "pgrep -f node"` |
| View server logs | `ssh heli-parts-backend@192.168.68.6 "tail -f backend/server.log"` |
| Restart server | `ssh heli-parts-backend@192.168.68.6 "cd backend && pkill -f node && npm start"` |
| Test health | `curl http://192.168.68.6:3000/health` |

---

**Ready to deploy?** Run `./DEPLOY.sh` or follow manual steps above!
