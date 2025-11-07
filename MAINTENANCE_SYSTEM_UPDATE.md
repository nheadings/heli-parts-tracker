# Maintenance System Update - Implementation Guide

## Overview
This update transforms the maintenance tracking system from hardcoded intervals to a fully customizable, template-based system that allows:
- Up to 5 maintenance items displayed on the flight page
- Customizable intervals (e.g., change from 100 hrs to 50 hrs easily)
- Color customization for each maintenance type
- Global management through the Settings page
- Display in both Flight View and Helicopter Detail screens

## What's Included

### 1. Database Changes
**File:** `backend/database/migrations/002_add_maintenance_template_customization.sql`

New fields added to `maintenance_schedules` table:
- `color` (VARCHAR(7)) - Hex color code (e.g., #FF9500)
- `display_order` (INTEGER) - Order for display on flight page
- `display_in_flight_view` (BOOLEAN) - Show/hide from flight page
- `threshold_warning` (INTEGER) - Hours before due to show warning color

Default templates included:
1. **Oil Change** - 100 hrs, Orange (#FF9500), Position 1
2. **Fuel Line Inspection** - 100 hrs, Red (#FF3B30), Position 2
3. **AVBlend** - 50 hrs, Blue (#007AFF), Position 3

### 2. Backend API Updates
**File:** `backend/routes/logbook.js`

New/Updated Endpoints:
- `GET /logbook/maintenance-schedules/flight-view` - Get templates for flight page
- `POST /logbook/maintenance-schedules` - Create template (updated with new fields)
- `PUT /logbook/maintenance-schedules/:id` - Update template (updated with new fields)
- `DELETE /logbook/maintenance-schedules/:id` - Delete template
- `GET /logbook/helicopters/:helicopterId/dashboard` - Updated to include flight_view_maintenance

### 3. iOS Models
**Files Updated:**
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Models/LogbookModels.swift`

New Models:
- `FlightViewMaintenance` - Simplified model for flight page display
- Updated `MaintenanceSchedule` with new fields
- Updated `LogbookDashboard` to include `flightViewMaintenance` array

### 4. Settings Page
**New Files:**
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/MaintenanceTemplatesView.swift`
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/EditMaintenanceTemplateView.swift`
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Extensions/ColorExtensions.swift`

Features:
- List all maintenance templates
- Add/Edit/Delete templates
- Color picker with 8 preset colors
- Configure display order (1-5)
- Set warning thresholds
- Toggle flight view visibility

### 5. Flight Page Updates
**File:** `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/FlightView.swift`

Changes:
- Dynamic maintenance cards (1-5 items)
- Auto-scaling spacing based on item count
- Color-coded status using template colors
- Opacity changes based on urgency level

Color Logic:
- **Overdue** (≤0 hrs): Red (override)
- **Warning** (≤threshold): Full template color
- **Approaching** (≤threshold×2): 70% opacity
- **OK** (>threshold×2): 50% opacity

### 6. Helicopter Detail View
**File:** `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/HelicopterDetailView.swift`

New Features:
- Compact maintenance status banner at top
- Small colored circles for each item
- Shows hours remaining
- Automatically loads with helicopter data

## Deployment Steps

### Backend Deployment

1. **Run Database Migration:**
   ```bash
   # SSH into your server
   ssh heli-parts-backend@192.168.68.6

   # Navigate to backend directory
   cd backend

   # Run migration
   psql $DATABASE_URL -f database/migrations/002_add_maintenance_template_customization.sql
   ```

2. **Deploy Updated Backend:**
   ```bash
   # From your local machine
   scp backend/routes/logbook.js heli-parts-backend@192.168.68.6:backend/routes/

   # Restart backend server
   ssh heli-parts-backend@192.168.68.6 'cd backend && pkill -f "node.*server.js" && nohup npm start > server.log 2>&1 &'
   ```

3. **Verify Backend:**
   ```bash
   curl http://192.168.68.6:3000/logbook/maintenance-schedules/flight-view
   ```
   Should return 3 default templates.

### iOS App Deployment

1. **Open Xcode:**
   ```bash
   cd ios-appnew/HeliPartsTracker
   open HeliPartsTracker.xcodeproj
   ```

2. **Build & Run:**
   - Select your device/simulator
   - Press ⌘B to build
   - Press ⌘R to run

3. **Verify Installation:**
   - Open Settings > Maintenance Templates
   - Should see 3 default templates
   - Try editing one to change the interval

## Usage Guide

### Managing Maintenance Templates

1. **View Templates:**
   - Navigate to Settings
   - Tap "Maintenance Templates"
   - See "Flight View Templates" section (max 5)
   - See "Other Templates" section (unlimited)

2. **Add New Template:**
   - Tap "+" in top-right
   - Enter title (e.g., "100-Hour Inspection")
   - Set interval hours (e.g., 100)
   - Select category
   - Choose color from palette
   - Toggle "Show in Flight View"
   - Set display order (1-5)
   - Set warning threshold (e.g., 10 hours)
   - Tap "Save"

3. **Edit Template:**
   - Tap on any template in the list
   - Modify fields
   - Tap "Save"

4. **Delete Template:**
   - Tap on template
   - Scroll to bottom
   - Tap "Delete Template"
   - Confirm deletion

5. **Reorder Flight View Items:**
   - Edit each template
   - Change "Display Order" (1-5)
   - Items with order 1 appear first, 5 appears last

### Flight Page Display

The flight page now shows:
- **Dynamic Layout:** Automatically adjusts spacing for 1-5 items
- **Color Coded:**
  - Red = Overdue
  - Full color = Due soon
  - Faded = Approaching
  - Very faded = Plenty of time
- **Live Updates:** Refreshes when helicopter selected

### Helicopter Detail Display

- Compact maintenance banner at top
- Small colored circles for quick status
- Hours remaining shown below each item
- Perfect for at-a-glance status check

## Customization Examples

### Example 1: Change Oil Change Interval from 100 to 50 hours
1. Settings > Maintenance Templates
2. Tap "Oil Change"
3. Change "Hours" from 100 to 50
4. Tap "Save"
5. Return to Flight View - see updated interval

### Example 2: Add New Maintenance Item "Rotor Inspection"
1. Settings > Maintenance Templates > "+"
2. Title: "Rotor Inspection"
3. Hours: 25
4. Category: Inspection
5. Color: Purple
6. Toggle "Show in Flight View": ON
7. Display Order: 4
8. Warning Threshold: 5
9. Tap "Save"

### Example 3: Hide an Item from Flight View
1. Settings > Maintenance Templates
2. Tap the template you want to hide
3. Toggle "Show in Flight View": OFF
4. Tap "Save"
5. Item removed from Flight View (still tracked in logbook)

## Color Palette

Default colors included:
- 🔴 Red (#FF3B30) - Urgent items
- 🟠 Orange (#FF9500) - Regular maintenance
- 🟡 Yellow (#FFCC00) - Caution items
- 🟢 Green (#34C759) - Normal items
- 🔵 Blue (#007AFF) - Additives/fluids
- 🟣 Purple (#5856D6) - Inspections
- 🩷 Pink (#FF2D55) - Special items
- 💙 Light Blue (#5AC8FA) - Secondary items

## Technical Details

### Smart Color System
The app uses a sophisticated color system:
1. Templates have a base color
2. System applies opacity based on urgency
3. Always overrides to red when overdue
4. Provides immediate visual feedback

### Spacing Algorithm
```swift
1-2 items: 16pt spacing
3 items:   12pt spacing
4 items:   8pt spacing
5 items:   6pt spacing
```

### Database Structure
```sql
maintenance_schedules
├── id (primary key)
├── title (e.g., "Oil Change")
├── interval_hours (e.g., 100)
├── color (e.g., "#FF9500")
├── display_order (1-5)
├── display_in_flight_view (boolean)
├── threshold_warning (hours)
└── ... (other existing fields)
```

## Troubleshooting

### Templates Not Showing in Flight View
- Check that `display_in_flight_view` is ON
- Verify `display_order` is set (1-5)
- Ensure helicopter has current hours set
- Try refreshing the flight view (pull down)

### Colors Not Displaying Correctly
- Verify color is in hex format (#RRGGBB)
- Check that ColorExtensions.swift is included in build
- Restart the app

### Migration Failed
- Check database connection
- Verify you're running on correct database
- Check for existing column conflicts
- Review migration logs

## Future Enhancements

Possible additions:
- Calendar-based maintenance (not just hours)
- Push notifications when maintenance due
- Maintenance history per template
- Export maintenance schedules
- Import templates from other aircraft

## Support

For issues or questions:
1. Check this documentation
2. Review code comments
3. Check git commit history
4. Create GitHub issue

## Files Modified

### Backend
- `backend/routes/logbook.js` - API endpoints
- `backend/database/migrations/002_add_maintenance_template_customization.sql` - Database schema

### iOS
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Models/LogbookModels.swift` - Data models
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/FlightView.swift` - Dynamic display
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/HelicopterDetailView.swift` - Banner display
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/SettingsView.swift` - Settings menu
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/MaintenanceTemplatesView.swift` - Template list (NEW)
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Views/EditMaintenanceTemplateView.swift` - Template editor (NEW)
- `ios-appnew/HeliPartsTracker/HeliPartsTracker/Extensions/ColorExtensions.swift` - Color utilities (NEW)

---

**Version:** 1.0.0
**Date:** November 7, 2025
**Generated with:** Claude Code
