#!/bin/bash

# Maintenance System Update Deployment Script
# Run this from the project root directory

set -e  # Exit on error

echo "🚁 Deploying Maintenance System Update..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKEND_SERVER="192.168.68.6"
BACKEND_USER="heli-parts-backend"
BACKEND_PATH="backend"

# Prompt for password
echo -e "${YELLOW}Enter password for ${BACKEND_USER}@${BACKEND_SERVER}:${NC}"
read -s SSH_PASSWORD
echo ""

echo -e "${BLUE}Step 1: Copying backend files to server...${NC}"

# Copy migration file
echo "  → maintenance migration SQL"
sshpass -p "$SSH_PASSWORD" scp backend/database/migrations/002_add_maintenance_template_customization.sql ${BACKEND_USER}@${BACKEND_SERVER}:${BACKEND_PATH}/database/migrations/

# Copy updated route file
echo "  → logbook.js"
sshpass -p "$SSH_PASSWORD" scp backend/routes/logbook.js ${BACKEND_USER}@${BACKEND_SERVER}:${BACKEND_PATH}/routes/

echo -e "${GREEN}✓ Files copied${NC}"
echo ""

echo -e "${BLUE}Step 2: Running database migration...${NC}"

sshpass -p "$SSH_PASSWORD" ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "Loading DATABASE_URL from .env file..."
    export $(grep DATABASE_URL .env | xargs)
fi

# Run migration
echo "Running migration..."
psql $DATABASE_URL -f database/migrations/002_add_maintenance_template_customization.sql

echo "✅ Migration complete"
ENDSSH

echo -e "${GREEN}✓ Migration complete${NC}"
echo ""

echo -e "${BLUE}Step 3: Restarting backend server...${NC}"

sshpass -p "$SSH_PASSWORD" ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend

# Kill existing node process
pkill -f "node.*server.js" || true
sleep 1

# Start server in background
nohup npm start > server.log 2>&1 &
sleep 3

# Check if server started
if pgrep -f "node.*server.js" > /dev/null; then
    echo "✅ Server started successfully"
else
    echo "❌ Server failed to start - check logs"
    exit 1
fi
ENDSSH

echo -e "${GREEN}✓ Backend server restarted${NC}"
echo ""

echo -e "${BLUE}Step 4: Verifying deployment...${NC}"

# Wait a moment for server to fully start
sleep 3

# Test health endpoint
if curl -s http://${BACKEND_SERVER}:3000/health | grep -q "ok"; then
    echo -e "${GREEN}✓ Backend health check passed${NC}"
else
    echo -e "${RED}✗ Backend health check failed${NC}"
    exit 1
fi

# Test new endpoint
if curl -s http://${BACKEND_SERVER}:3000/logbook/maintenance-schedules/templates | grep -q "Oil Change"; then
    echo -e "${GREEN}✓ Maintenance templates endpoint working${NC}"
else
    echo -e "${RED}⚠  Maintenance templates endpoint may need attention${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Backend deployment complete! ✅${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo "1. Open Xcode: cd ios-appnew/HeliPartsTracker && open HeliPartsTracker.xcodeproj"
echo "2. Build and run: ⌘B then ⌘R"
echo "3. Test: Go to Settings > Maintenance Templates"
echo ""
echo "Backend API: http://${BACKEND_SERVER}:3000"
echo "Templates API: http://${BACKEND_SERVER}:3000/logbook/maintenance-schedules/templates"
