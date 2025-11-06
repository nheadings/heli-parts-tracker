#!/bin/bash

# Backend deployment script
# This will deploy the flight page backend to 192.168.68.6

set -e

BACKEND_SERVER="192.168.68.6"
BACKEND_USER="heli-parts-backend"

echo "🚁 Deploying Flight Page Backend..."
echo ""

echo "Step 1: Copying files to server..."

# Copy route files
echo "  → flights.js"
scp backend/routes/flights.js ${BACKEND_USER}@${BACKEND_SERVER}:backend/routes/

echo "  → squawks.js"
scp backend/routes/squawks.js ${BACKEND_USER}@${BACKEND_SERVER}:backend/routes/

echo "  → server.js"
scp backend/server.js ${BACKEND_USER}@${BACKEND_SERVER}:backend/

echo "  → migration files"
scp backend/database/flights-squawks-migration.sql ${BACKEND_USER}@${BACKEND_SERVER}:backend/database/
scp backend/run-flights-migration.sh ${BACKEND_USER}@${BACKEND_SERVER}:backend/

echo ""
echo "Step 2: Running migration..."

ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend
chmod +x run-flights-migration.sh
./run-flights-migration.sh
ENDSSH

echo ""
echo "Step 3: Restarting server..."

ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend
pkill -f "node.*server.js" || true
nohup npm start > server.log 2>&1 &
sleep 3
if pgrep -f "node.*server.js" > /dev/null; then
    echo "✅ Server started successfully"
else
    echo "❌ Server failed to start"
    exit 1
fi
ENDSSH

echo ""
echo "✅ Backend deployment complete!"
echo ""
echo "Testing endpoints..."
sleep 2

if curl -s http://${BACKEND_SERVER}:3000/health | grep -q "ok"; then
    echo "✅ Health check passed"
else
    echo "⚠️  Health check failed"
fi

echo ""
echo "Backend API: http://${BACKEND_SERVER}:3000"
echo "App is ready to use on your iPhone!"
