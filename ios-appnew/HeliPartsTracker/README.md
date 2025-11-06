# HeliPartsTracker - Native iOS App

**Current active iOS application built with SwiftUI and Xcode.**

## Overview

Native iOS app for managing helicopter parts inventory, maintenance logs, and logbook tracking. Built with SwiftUI for iOS 26.0+.

## Features

### Parts Management
- Real-time parts inventory with search
- QR code scanning and generation
- Low stock alerts and notifications
- Part installation tracking on helicopters
- Vendor reorder links

### Logbook System
- Helicopter hours tracking with history
- Maintenance log entries (oil changes, inspections, repairs, AD compliance)
- Fluid addition tracking (engine oil, transmission oil, hydraulic fluid, fuel)
- Life-limited parts monitoring with remaining hours
- Maintenance schedule tracking
- **Editable logbook entries with warnings** - Click any logbook entry to edit with confirmation dialogs

### Fleet Management
- 9 pre-loaded helicopters
- Install/remove parts tracking
- View all installed parts per helicopter
- Comprehensive logbook dashboard per helicopter

## Project Structure

```
HeliPartsTracker/
├── HeliPartsTrackerApp.swift
├── Models/
│   ├── User.swift
│   ├── Part.swift
│   ├── Helicopter.swift
│   └── LogbookModels.swift (helicopter hours, maintenance logs, fluid logs, life-limited parts)
├── Services/
│   └── APIService.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── PartsViewModel.swift
│   └── HelicoptersViewModel.swift
└── Views/
    ├── LoginView.swift
    ├── MainTabView.swift
    ├── PartsListView.swift
    ├── PartDetailView.swift
    ├── AddPartView.swift
    ├── HelicoptersListView.swift
    ├── HelicopterDetailView.swift
    ├── InstallPartView.swift
    ├── LogbookView.swift
    ├── LogbookDashboardView.swift
    ├── AddMaintenanceLogView.swift
    ├── AddFluidLogView.swift
    ├── QRScannerView.swift
    ├── AlertsView.swift
    └── SettingsView.swift
```

## Build and Run

### Prerequisites
- macOS with Xcode 16.0 or later
- iOS 26.0+ device or simulator
- Backend server running (see backend/README.md)

### Steps

1. **Open Project**
   ```bash
   cd /Users/normanheadings/heli-parts-tracker/ios-appnew/HeliPartsTracker
   open HeliPartsTracker.xcodeproj
   ```

2. **Configure Signing**
   - Select your development team in Xcode
   - Project settings → Signing & Capabilities

3. **Build and Run**
   - Select your target device/simulator
   - Click Run (⌘R) or build (⌘B)

### Installation
```bash
# Build and install on connected device
xcodebuild -project HeliPartsTracker.xcodeproj \
  -scheme HeliPartsTracker \
  -configuration Debug \
  -destination 'id=YOUR_DEVICE_ID' \
  -allowProvisioningUpdates \
  clean build

xcrun devicectl device install app \
  --device YOUR_DEVICE_ID \
  /path/to/HeliPartsTracker.app
```

## Backend Configuration

The app connects to the backend API at `http://192.168.68.6:3000/api`.

To change the backend URL, edit `HeliPartsTracker/Services/APIService.swift`:
```swift
private let baseURL = "http://YOUR_SERVER_IP:3000/api"
```

## Login Credentials

Default admin account:
- **Username**: `admin`
- **Password**: `admin123`

## Recent Updates

- **Nov 2025**: Added comprehensive logbook system with editable entries
- **Nov 2025**: Implemented fluid tracking and life-limited parts monitoring
- **Nov 2025**: Added maintenance schedule tracking and warnings for editing historical data

## Notes

- Native iOS app using SwiftUI (no cross-platform frameworks)
- All HTTP connections allowed via Info.plist for local development
- QR scanner uses native iOS camera APIs
- No third-party dependencies required
- All data synced with PostgreSQL backend via REST API

## Backend Server

Ensure the backend is running:
```bash
ssh heli-parts-backend@192.168.68.6
cd backend
npm start
```

Check server health:
```bash
curl http://192.168.68.6:3000/health
```
