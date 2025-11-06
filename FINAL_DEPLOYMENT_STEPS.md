# 🚁 Final Deployment Steps

## ✅ What's Already Done

### iOS App - **INSTALLED ON YOUR IPHONE** ✅
- ✅ Built successfully
- ✅ Installed on Norman's iPhone 17 Pro Max
- ✅ Ready to launch!

### Backend - **READY TO DEPLOY** (Needs your SSH password)
- ✅ All files prepared
- ✅ Migration ready
- ✅ Server is online (ping successful: 192.168.68.6)
- ⏳ Just needs SSH authentication to deploy

---

## 🚀 Deploy Backend NOW - Three Options

### Option 1: One-Command Deploy (Easiest)

```bash
cd /Users/normanheadings/heli-parts-tracker/deployment-package
./DEPLOY.sh
```

**Enter your SSH password when prompted**

The script will automatically:
1. Copy all files to server
2. Run database migration
3. Restart backend
4. Verify deployment

---

### Option 2: Manual Commands (Copy-Paste)

Open Terminal and run these one by one:

```bash
# Navigate to deployment package
cd /Users/normanheadings/heli-parts-tracker/deployment-package

# Copy files (enter password for each)
scp flights.js heli-parts-backend@192.168.68.6:backend/routes/
scp squawks.js heli-parts-backend@192.168.68.6:backend/routes/
scp server.js heli-parts-backend@192.168.68.6:backend/
scp flights-squawks-migration.sql heli-parts-backend@192.168.68.6:backend/database/
scp run-flights-migration.sh heli-parts-backend@192.168.68.6:backend/

# SSH to server
ssh heli-parts-backend@192.168.68.6

# On server, run these:
cd backend
chmod +x run-flights-migration.sh
./run-flights-migration.sh
pkill -f "node.*server.js"
npm start
```

---

### Option 3: Use FileZilla/Cyberduck (GUI)

If you prefer a graphical interface:

1. **Open FileZilla or Cyberduck**
2. **Connect to server**:
   - Host: `192.168.68.6`
   - Username: `heli-parts-backend`
   - Password: [your password]
   - Port: `22`

3. **Upload files**:
   - `flights.js` → `backend/routes/`
   - `squawks.js` → `backend/routes/`
   - `server.js` → `backend/`
   - `flights-squawks-migration.sql` → `backend/database/`
   - `run-flights-migration.sh` → `backend/`

4. **SSH to server** and run:
   ```bash
   cd backend
   chmod +x run-flights-migration.sh
   ./run-flights-migration.sh
   pkill -f "node.*server.js"
   npm start
   ```

---

## 📦 Deployment Package Location

All files are ready in:
```
/Users/normanheadings/heli-parts-tracker/deployment-package/
```

Files included:
- ✅ `flights.js` (5.5 KB)
- ✅ `squawks.js` (7.2 KB)
- ✅ `server.js` (2.3 KB)
- ✅ `flights-squawks-migration.sql` (3.3 KB)
- ✅ `run-flights-migration.sh` (502 bytes)
- ✅ `DEPLOY.sh` (automated deployment script)
- ✅ `README.md` (detailed instructions)

Also created compressed archive:
```
/Users/normanheadings/heli-parts-tracker/backend-deployment.tar.gz
```

---

## ✅ Verification Steps

After deployment, verify everything works:

### 1. Check Backend Health

```bash
curl http://192.168.68.6:3000/health
```

Should return:
```json
{"status":"ok","timestamp":"2025-11-06T..."}
```

### 2. Check New Endpoints

```bash
curl http://192.168.68.6:3000/
```

Should include:
```json
{
  "endpoints": {
    ...
    "flights": "/api/flights",
    "squawks": "/api/squawks"
  }
}
```

### 3. Test on iPhone

1. Open **HeliPartsTracker** app
2. Login: `admin` / `admin123`
3. Tap **Flights** tab (✈️ icon)
4. Should see:
   - Aircraft dropdown
   - Maintenance indicators
   - "Scan Hobbs" button
   - "Add Squawk" button

---

## 🎯 What the Migration Does

The migration creates two new tables:

### `flights` Table
Stores flight records with:
- Hobbs start/end readings
- Flight time (auto-calculated)
- Pilot information
- Departure/arrival times
- Photo of Hobbs meter
- OCR confidence score

### `squawks` Table
Stores maintenance squawks with:
- Severity level (routine/caution/urgent)
- Title and description
- Reporter and timestamp
- Status (active/fixed/deferred)
- Photos (multiple)
- Fix information and notes

Both tables integrate with existing `helicopters` and `users` tables.

---

## ⚠️ Troubleshooting

### Can't SSH to Server

**Try**:
```bash
# Test SSH connection
ssh heli-parts-backend@192.168.68.6 "echo Connected"
```

**If fails**:
- Check you have the correct password
- Make sure you're on the same network as server
- Verify username is `heli-parts-backend`

### Migration Says "Table Already Exists"

**This is OK!** It means the tables were already created. Skip to restart step:
```bash
ssh heli-parts-backend@192.168.68.6
cd backend
pkill -f "node.*server.js"
npm start
```

### Server Won't Start

**Check logs**:
```bash
ssh heli-parts-backend@192.168.68.6
cd backend
tail -f server.log
```

**Common fixes**:
```bash
# Kill any existing node processes
pkill -9 node

# Check database connection
psql heli_parts_tracker -c "SELECT 1"

# Reinstall dependencies if needed
npm install

# Start server
npm start
```

### App Shows "Cannot Connect"

1. **Verify backend is running**:
   ```bash
   curl http://192.168.68.6:3000/health
   ```

2. **Check iPhone is on same network**:
   - WiFi settings → Check connected to same network as server

3. **Verify API URL in app**:
   - Should be: `http://192.168.68.6:3000/api`
   - This is already set in `APIService.swift`

---

## 📱 Using the App

Once backend is deployed:

### Features to Test:

1. **Aircraft Selection**
   - Tap dropdown at top
   - Select any of 9 helicopters

2. **Maintenance Tracking**
   - View oil change countdown (hours remaining)
   - View fuel line AD countdown (hours remaining)
   - Colors change: Green → Yellow → Orange → Red

3. **Hobbs Scanning**
   - Tap "Scan Hobbs" button
   - Use camera to photograph Hobbs meter
   - Or enter manually
   - Saves and updates helicopter hours

4. **Squawk Reporting**
   - Tap "Add Squawk" button
   - Choose severity: Routine/Caution/Urgent
   - Add title and description
   - Take photos with camera
   - Save squawk

5. **Squawk Management**
   - Tap on any squawk to view details
   - Tap "Mark as Fixed" button
   - Confirm in popup
   - Squawk moves to Fixed section

### Color Coding:

**Maintenance Indicators**:
- 🟢 Green: Plenty of time remaining
- 🟡 Yellow: Getting close
- 🟠 Orange: Very close to due
- 🔴 Red: Overdue or critical

**Squawk Severity**:
- ⚪ White/Gray: Routine (normal maintenance)
- 🟠 Amber: Caution (needs attention)
- 🔴 Red: Urgent (safety critical)

---

## 📊 Deployment Status

| Task | Status | Action Required |
|------|--------|-----------------|
| iOS App Build | ✅ Complete | None - already done |
| iOS App Install | ✅ Complete | None - on your iPhone |
| Backend Files | ✅ Ready | In `deployment-package/` |
| Server Online | ✅ Confirmed | Responding to ping |
| SSH Access | ⏳ Needs Auth | Enter your password |
| Deploy Backend | ⏳ **Waiting** | **Run DEPLOY.sh or manual steps** |
| Migration | ⏳ Pending | Will run automatically |
| Server Restart | ⏳ Pending | Will run automatically |

---

## 🎉 You're Almost There!

**Just one step left**: Run the deployment!

Choose your method:
- **Easiest**: Run `./DEPLOY.sh` in deployment-package folder
- **Manual**: Copy-paste commands from Option 2
- **GUI**: Use FileZilla as described in Option 3

Once deployed (takes ~2 minutes), your pilots can start using the app immediately!

---

## 📞 Quick Support

**Issue**: Forgot server password
- Check your server admin credentials or password manager

**Issue**: Script fails partway through
- Run manual commands one by one to see where it fails
- Check error message and see troubleshooting section

**Issue**: Everything works but app won't connect
- Restart the app completely
- Check server is accessible: `curl http://192.168.68.6:3000/health`
- Verify iPhone on same WiFi network

---

**Ready?** Open Terminal and run:

```bash
cd /Users/normanheadings/heli-parts-tracker/deployment-package
./DEPLOY.sh
```

Then open the app on your iPhone and start flying! 🚁✨
