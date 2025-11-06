# Xcode Setup Steps for Flight Page

**Xcode is now open!** Follow these steps to add the new files and build the app.

## Step 1: Add New Swift Files to Project

### Add View Files

1. In Xcode's left sidebar (Project Navigator), locate the **Views** folder
2. Right-click on **Views** folder → **Add Files to "HeliPartsTracker"...**
3. Navigate to: `HeliPartsTracker/HeliPartsTracker/Views/`
4. Select these files (hold ⌘ to select multiple):
   - ✅ `FlightView.swift`
   - ✅ `HobbsScannerView.swift`
   - ✅ `AddSquawkView.swift`
   - ✅ `SquawkDetailView.swift`

5. **Important**: In the dialog:
   - ☑️ Check "Copy items if needed"
   - ☑️ Make sure "HeliPartsTracker" target is selected
   - Click **Add**

### Add Model File

1. In Xcode's left sidebar, locate the **Models** folder
2. Right-click on **Models** folder → **Add Files to "HeliPartsTracker"...**
3. Navigate to: `HeliPartsTracker/HeliPartsTracker/Models/`
4. Select:
   - ✅ `FlightModels.swift`

5. In the dialog:
   - ☑️ Check "Copy items if needed"
   - ☑️ Make sure "HeliPartsTracker" target is selected
   - Click **Add**

## Step 2: Verify Files Are Added

In the left sidebar, you should now see:

```
HeliPartsTracker/
├── Models/
│   ├── ...
│   └── FlightModels.swift        ← NEW
├── Views/
│   ├── ...
│   ├── FlightView.swift           ← NEW
│   ├── HobbsScannerView.swift     ← NEW
│   ├── AddSquawkView.swift        ← NEW
│   └── SquawkDetailView.swift     ← NEW
└── ...
```

## Step 3: Build the App

1. Select a target device/simulator from the dropdown (top-left)
   - For testing: Choose any iPhone simulator (e.g., "iPhone 15 Pro")
   - For deployment: Connect your iPhone and select it

2. Press **⌘B** (or Product → Build)

3. Wait for the build to complete
   - Check the progress bar at the top
   - Any errors will appear in the Issues Navigator (left sidebar, ⚠️ icon)

## Step 4: Fix Common Build Errors

### If you see: "Cannot find 'FlightView' in scope"

This means MainTabView.swift can't find FlightView.

**Solution**:
- Build again (⌘B) - sometimes files need to be indexed first
- Clean build folder: Product → Clean Build Folder (⇧⌘K), then build again

### If you see: "No such module 'PhotosUI'"

This is for the ImagePicker in AddSquawkView.

**Solution**: This is already imported at the top of AddSquawkView.swift. If error persists:
- Select project in navigator → Target: HeliPartsTracker → General
- Check Deployment Target is iOS 14.0 or higher

### If you see: Missing files or "File not found"

**Solution**:
- Make sure you selected "Copy items if needed" when adding files
- Try removing the file from project (right-click → Delete → Remove Reference)
- Add it again with "Copy items if needed" checked

## Step 5: Run the App

Once build succeeds:

1. Press **⌘R** (or Product → Run)
2. Wait for app to launch in simulator/device
3. App should open to login screen

## Step 6: Test the Flight Page

1. **Login**:
   - Username: `admin`
   - Password: `admin123`

2. **Navigate to Flights tab** (4th tab, airplane icon)

3. **You should see**:
   - Aircraft dropdown selector at top
   - Oil Change and Fuel Line AD indicators
   - "Scan Hobbs" button
   - "Add Squawk" button
   - Empty squawks list (or sample squawks if any exist)

4. **Test basic functionality**:
   - Try selecting different aircraft from dropdown
   - Tap "Add Squawk" to create a test squawk
   - Tap on a squawk to view details

## Troubleshooting

### App crashes when opening Flights tab

**Check**:
1. Backend server is running at 192.168.68.6:3000
2. In Xcode console (View → Debug Area → Show Debug Area), look for error messages
3. Common issue: Backend API not accessible
   - **Solution**: Make sure backend server is running
   - Or test with local backend (see DEPLOYMENT_GUIDE.md)

### Can't find new files in Xcode

**Solution**:
- Close Xcode
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Reopen project
- Add files again

### Simulator doesn't have camera

**Expected**: Hobbs scanning won't work in simulator
- Tap "Scan Hobbs" → Manual entry is available
- For camera testing, use a real device

## Quick Reference

| Action | Keyboard Shortcut |
|--------|-------------------|
| Build | ⌘B |
| Run | ⌘R |
| Clean Build Folder | ⇧⌘K |
| Show/Hide Debug Area | ⇧⌘Y |
| Show Navigator | ⌘1 |
| Show Issue Navigator | ⌘5 |

---

## Next: Backend Deployment

After iOS app builds successfully, deploy the backend:

See **DEPLOYMENT_GUIDE.md** for backend deployment instructions.

Quick version:
```bash
# SSH to server
ssh heli-parts-backend@192.168.68.6

# Copy files (from local machine)
scp backend/routes/flights.js heli-parts-backend@192.168.68.6:backend/routes/
scp backend/routes/squawks.js heli-parts-backend@192.168.68.6:backend/routes/
scp backend/server.js heli-parts-backend@192.168.68.6:backend/
scp backend/database/flights-squawks-migration.sql heli-parts-backend@192.168.68.6:backend/database/
scp backend/run-flights-migration.sh heli-parts-backend@192.168.68.6:backend/

# On server, run migration
cd backend
chmod +x run-flights-migration.sh
./run-flights-migration.sh

# Restart server
npm start
```

---

**Status**: Xcode is open and ready! Follow steps above to complete build.
