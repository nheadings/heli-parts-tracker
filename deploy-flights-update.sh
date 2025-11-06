#!/bin/bash

# Deployment script for Flight Page update
# Run this from the project root directory

set -e  # Exit on error

echo "🚁 Deploying Flight Page Update..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
BACKEND_SERVER="192.168.68.6"
BACKEND_USER="heli-parts-backend"
BACKEND_PATH="backend"
DB_NAME="heli_parts_tracker"

echo -e "${BLUE}Step 1: Copying new backend files to server...${NC}"

# Copy new route files
echo "Copying flights.js..."
scp backend/routes/flights.js ${BACKEND_USER}@${BACKEND_SERVER}:${BACKEND_PATH}/routes/

echo "Copying squawks.js..."
scp backend/routes/squawks.js ${BACKEND_USER}@${BACKEND_SERVER}:${BACKEND_PATH}/routes/

echo "Copying updated server.js..."
scp backend/server.js ${BACKEND_USER}@${BACKEND_SERVER}:${BACKEND_PATH}/

echo "Copying migration files..."
scp backend/database/flights-squawks-migration.sql ${BACKEND_USER}@${BACKEND_SERVER}:${BACKEND_PATH}/database/
scp backend/run-flights-migration.sh ${BACKEND_USER}@${BACKEND_SERVER}:${BACKEND_PATH}/

echo -e "${GREEN}✓ Files copied${NC}"
echo ""

echo -e "${BLUE}Step 2: Running database migration...${NC}"

ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend
chmod +x run-flights-migration.sh
./run-flights-migration.sh
ENDSSH

echo -e "${GREEN}✓ Migration complete${NC}"
echo ""

echo -e "${BLUE}Step 3: Restarting backend server...${NC}"

ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend
# Kill existing node process
pkill -f "node.*server.js" || true
# Start server in background
nohup npm start > server.log 2>&1 &
sleep 2
# Check if server started
if pgrep -f "node.*server.js" > /dev/null; then
    echo "Server started successfully"
else
    echo "Server failed to start - check logs"
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

# Test new endpoints
if curl -s http://${BACKEND_SERVER}:3000/ | grep -q "flights"; then
    echo -e "${GREEN}✓ Flights endpoint registered${NC}"
else
    echo -e "${RED}✗ Flights endpoint not found${NC}"
fi

if curl -s http://${BACKEND_SERVER}:3000/ | grep -q "squawks"; then
    echo -e "${GREEN}✓ Squawks endpoint registered${NC}"
else
    echo -e "${RED}✗ Squawks endpoint not found${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Backend deployment complete! ✅${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo "1. Build iOS app: cd ios-appnew/HeliPartsTracker && open HeliPartsTracker.xcodeproj"
echo "2. In Xcode: Product > Build (⌘B)"
echo "3. Run on device/simulator (⌘R)"
echo ""
echo "Backend API: http://${BACKEND_SERVER}:3000"
echo "API Docs: http://${BACKEND_SERVER}:3000/"
