# Helicopter Parts Tracker - Deployment Guide

## Quick Reference

### iPhone Details
- **Device**: Norman's iPhone 17 Pro Max
- **ID**: `00008150-00023CC436B8401C`
- **OS**: iOS 26.0.1

### Server Details
- **IP**: 192.168.68.6
- **Port**: 3000
- **SSH User**: heli-parts-backend
- **SSH Password**: Mornan540
- **DB User**: heliapp
- **DB Password**: HeliSecure2024!
- **Database**: heli_parts_tracker

---

## Deploy Backend

```bash
# Copy files
sshpass -p 'Mornan540' scp backend/routes/*.js heli-parts-backend@192.168.68.6:~/backend/routes/
sshpass -p 'Mornan540' scp backend/server.js heli-parts-backend@192.168.68.6:~/backend/

# Restart server (safe, prevents crashes)
sshpass -p 'Mornan540' ssh heli-parts-backend@192.168.68.6 "~/backend/restart-server.sh"

# Check status
curl -s http://192.168.68.6:3000/health
```

## Deploy iOS App

```bash
# Build for iPhone 17
xcodebuild -scheme HeliPartsTracker \
  -destination 'platform=iOS,id=00008150-00023CC436B8401C' \
  -configuration Debug build

# Install to device
xcrun devicectl device install app \
  --device 00008150-00023CC436B8401C \
  /Users/normanheadings/Library/Developer/Xcode/DerivedData/HeliPartsTracker-foloyfcvaeocjhesygrxjhoaqjbw/Build/Products/Debug-iphoneos/HeliPartsTracker.app
```

## Run Database Migration

```bash
# Copy migration file
sshpass -p 'Mornan540' scp backend/database/migrations/XXX_name.sql heli-parts-backend@192.168.68.6:~/backend/database/migrations/

# Run migration
sshpass -p 'Mornan540' ssh heli-parts-backend@192.168.68.6 "cd ~/backend && node run-migration.js XXX_name.sql"
```

## Backup Before Changes

```bash
# Local backup
tar -czf /Users/normanheadings/heli-parts-tracker/backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /Users/normanheadings/heli-parts-tracker ios-appnew backend

# Server backup (code + database)
sshpass -p 'Mornan540' ssh heli-parts-backend@192.168.68.6 \
  "tar -czf ~/backup-$(date +%Y%m%d-%H%M%S).tar.gz -C ~/ backend/ && \
   echo 'Mornan540' | sudo -S -u postgres pg_dump heli_parts_tracker > ~/db-backup-$(date +%Y%m%d-%H%M%S).sql"
```

---

## Current System Status

### Unified Logbook System ✅
- **One table**: `logbook_entries` - all events (flights, maintenance, squawks, fluids)
- **Categories drive everything**: No more separate templates
- **Dynamic forms**: Form adapts to category (squawk→severity/status, fluid→type/quantity)
- **Deleted tables**: squawks, fluid_logs, maintenance_logs, maintenance_completions, maintenance_schedules

### Features Working
- ✅ Maintenance banners in Flight View (category-based)
- ✅ Banner hours update when logging flights
- ✅ Click banner → Opens logbook entry form (pre-filled)
- ✅ Unified logbook with filters, search, photos/documents
- ✅ Settings → Logbook Categories → Configure banners
- ✅ Aircraft assignment per banner
- ✅ Server restart script prevents crashes

### Known Issues
- ⚠️ Banners show full interval hours until first completion is logged (not "N/A")
- ⚠️ Must complete each maintenance once to start tracking properly

---

## Git Repository
- **Remote**: github.com-heli-parts-tracker:nheadings/heli-parts-tracker.git
- **Branch**: main
- **Latest Commit**: f6520a5 (Complete unified logbook system)

## Project Structure

```
/Users/normanheadings/heli-parts-tracker/
├── ios-appnew/HeliPartsTracker/        # iOS app
│   └── HeliPartsTracker/
│       ├── Models/                      # Data models
│       ├── Views/                       # UI views
│       ├── Services/                    # API client
│       └── ViewModels/                  # State management
│
└── backend/                             # Node.js backend
    ├── routes/                          # API endpoints
    ├── database/migrations/             # SQL migrations
    ├── config/database.js               # DB connection
    ├── server.js                        # Main server
    └── restart-server.sh                # Safe restart script
```

---

## Troubleshooting

**Server won't start**: Check if port 3000 is in use
```bash
sshpass -p 'Mornan540' ssh heli-parts-backend@192.168.68.6 "lsof -ti:3000 | xargs kill -9"
```

**Database permissions error**: Grant ownership
```bash
sshpass -p 'Mornan540' ssh heli-parts-backend@192.168.68.6 \
  "echo 'Mornan540' | sudo -S -u postgres psql heli_parts_tracker -c 'ALTER TABLE tablename OWNER TO heliapp;'"
```

**Check server logs**:
```bash
sshpass -p 'Mornan540' ssh heli-parts-backend@192.168.68.6 "tail -50 ~/backend/server.log"
```

---

## Next Steps / TODOs

1. **Squawk Integration**: Update squawk queries to use logbook_entries
2. **Fluid Integration**: Update fluid queries to use logbook_entries
3. **Initial Completion Data**: Optionally populate first completions for existing banners
4. **Settings**: Remove "Maintenance Templates" nav item (obsolete)
5. **Testing**: Verify dynamic form fields work (severity, fluid type, etc.)

---

*Last Updated: 2025-11-07*
*Session Tokens Used: 733K/1M*
