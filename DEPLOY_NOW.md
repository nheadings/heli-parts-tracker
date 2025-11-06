# 🚀 Deploy Backend NOW

## ✅ iPhone App Already Installed!

Your app is installed on **Norman's iPhone 17 Pro Max** and ready to use!

---

## Deploy Backend - Choose One Option:

**SSH Credentials:**
- Host: `192.168.68.6`
- Username: `heli-parts-backend`
- Password: `Mornan540`

---

### Option A: Automatic Script (if you have SSH access)

```bash
cd /Users/normanheadings/heli-parts-tracker
chmod +x deploy-backend-now.sh
./deploy-backend-now.sh
```

Enter password: `Mornan540` when prompted.

---

### Option B: Manual Step-by-Step (Recommended)

#### Step 1: Copy Files to Server

Open Terminal and run these commands one by one (password: `Mornan540`):

```bash
cd /Users/normanheadings/heli-parts-tracker

# Copy route files
scp backend/routes/flights.js heli-parts-backend@192.168.68.6:backend/routes/
scp backend/routes/squawks.js heli-parts-backend@192.168.68.6:backend/routes/

# Copy updated server.js
scp backend/server.js heli-parts-backend@192.168.68.6:backend/
```

#### Step 2: SSH to Server

```bash
ssh heli-parts-backend@192.168.68.6  # password: Mornan540
```

#### Step 3: Restart Server (on server)

```bash
# Stop current server
pkill -f "node.*server.js"

# Start server
npm start
```

Server should start and show:
```
🚁 Helicopter Parts Tracker API
📡 Server running on http://localhost:3000
```

#### Step 4: Verify (on server)

```bash
curl http://localhost:3000/health
```

Should return:
```json
{"status":"ok","timestamp":"..."}
```

---

### Option C: Copy-Paste All Commands

If you want to do it all at once (password: `Mornan540`):

```bash
cd /Users/normanheadings/heli-parts-tracker && \
scp backend/routes/flights.js heli-parts-backend@192.168.68.6:backend/routes/ && \
scp backend/routes/squawks.js heli-parts-backend@192.168.68.6:backend/routes/ && \
scp backend/server.js heli-parts-backend@192.168.68.6:backend/ && \
echo "✅ Files copied! Now SSH to server..." && \
ssh heli-parts-backend@192.168.68.6 "cd backend && pkill -f 'node.*server.js' ; nohup npm start > server.log 2>&1 &"
```

---

## 🧪 Test the App

Once backend is deployed:

1. **Open HeliPartsTracker** on your iPhone
2. **Login**:
   - Username: `admin`
   - Password: `admin123`
3. **Tap Flights tab** (4th tab, ✈️ icon)
4. **Test Features**:
   - Select different aircraft
   - Check maintenance indicators
   - Tap "Scan Hobbs" (use camera!)
   - Tap "Add Squawk"
   - Create a test squawk with photo
   - Tap squawk to view details
   - Mark it as fixed

---

## ⚠️ Troubleshooting

### "Permission denied" when copying files

Use password: `Mornan540` when prompted.

Or set up SSH key for easier access:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t rsa

# Copy to server
ssh-copy-id heli-parts-backend@192.168.68.6  # password: Mornan540
```

### Can't find app on iPhone

1. Look for "HeliPartsTracker" on your home screen
2. If not visible, swipe down and search "heli"
3. The app icon should appear

### Backend won't start

Check logs on server:

```bash
ssh heli-parts-backend@192.168.68.6
cd backend
tail -f server.log
```

### App shows "Cannot connect to server"

1. Check backend is running: `curl http://192.168.68.6:3000/health`
2. Check iPhone is on same network as server
3. Check firewall allows port 3000

---

## 📊 Deployment Status

| Component | Status |
|-----------|--------|
| iOS App Build | ✅ Complete |
| iOS App Installed | ✅ On iPhone 17 Pro Max |
| Backend Files | ✅ Ready |
| Backend Running | ⏳ Pending (restart server) |

---

## 🎯 Quick Summary

**What's Done:**
- ✅ iOS app built successfully
- ✅ App installed on your iPhone 17 Pro Max
- ✅ Backend code ready to deploy

**What's Next:**
- 📤 Copy files to server (3 commands above)
- 🚀 Restart backend server
- ✅ Start using the app!

---

**SSH Password:** `Mornan540`

**Ready to go?** Run the commands above and you're all set! 🚁✨
