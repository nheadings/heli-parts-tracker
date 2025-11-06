#!/bin/bash

# One-Command Backend Deployment Script
# This script will deploy all files and restart the server

BACKEND_SERVER="192.168.68.6"
BACKEND_USER="heli-parts-backend"

echo "🚁 Deploying HeliPartsTracker Flight Page Backend..."
echo ""
echo "Server: ${BACKEND_USER}@${BACKEND_SERVER}"
echo ""

# Check if we can connect
echo "Testing connection..."
if ! ssh -o ConnectTimeout=5 ${BACKEND_USER}@${BACKEND_SERVER} "echo 'Connected'" 2>/dev/null; then
    echo "❌ Cannot connect to server. Please check:"
    echo "   1. Server is online: ping ${BACKEND_SERVER}"
    echo "   2. SSH credentials are correct"
    echo "   3. You have SSH access"
    echo ""
    echo "To deploy manually:"
    echo "   1. Copy these files to server: flights.js, squawks.js, server.js, flights-squawks-migration.sql, run-flights-migration.sh"
    echo "   2. Place route files in: backend/routes/"
    echo "   3. Place server.js in: backend/"
    echo "   4. Place migration files in: backend/database/"
    echo "   5. Run: cd backend && chmod +x run-flights-migration.sh && ./run-flights-migration.sh"
    echo "   6. Restart: pkill -f 'node.*server.js' && npm start"
    exit 1
fi

echo "✅ Connection successful!"
echo ""

# Copy files
echo "📤 Copying files to server..."

scp flights.js ${BACKEND_USER}@${BACKEND_SERVER}:backend/routes/ && echo "  ✓ flights.js"
scp squawks.js ${BACKEND_USER}@${BACKEND_SERVER}:backend/routes/ && echo "  ✓ squawks.js"
scp server.js ${BACKEND_USER}@${BACKEND_SERVER}:backend/ && echo "  ✓ server.js"
scp flights-squawks-migration.sql ${BACKEND_USER}@${BACKEND_SERVER}:backend/database/ && echo "  ✓ migration.sql"
scp run-flights-migration.sh ${BACKEND_USER}@${BACKEND_SERVER}:backend/ && echo "  ✓ migration script"

echo ""
echo "🗄️  Running database migration..."

ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend
chmod +x run-flights-migration.sh
./run-flights-migration.sh
ENDSSH

if [ $? -eq 0 ]; then
    echo "✅ Migration completed!"
else
    echo "⚠️  Migration may have failed - check server logs"
fi

echo ""
echo "🔄 Restarting backend server..."

ssh ${BACKEND_USER}@${BACKEND_SERVER} << 'ENDSSH'
cd backend
echo "Stopping old server..."
pkill -f "node.*server.js" || echo "No server running"
sleep 2
echo "Starting new server..."
nohup npm start > server.log 2>&1 &
sleep 3
if pgrep -f "node.*server.js" > /dev/null; then
    echo "✅ Server started successfully!"
    exit 0
else
    echo "❌ Server failed to start - check logs with: tail -f backend/server.log"
    exit 1
fi
ENDSSH

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Deployment Complete!"
    echo ""
    echo "Testing endpoints..."
    sleep 2

    if curl -s http://${BACKEND_SERVER}:3000/health | grep -q "ok"; then
        echo "✅ Health check passed"
        echo ""
        echo "🚁 Backend is live at: http://${BACKEND_SERVER}:3000"
        echo "📱 Open HeliPartsTracker app on your iPhone!"
        echo ""
        echo "Test in app:"
        echo "  1. Login: admin / admin123"
        echo "  2. Tap Flights tab (✈️)"
        echo "  3. Start using!"
    else
        echo "⚠️  Health check failed - server may need more time to start"
        echo "   Check manually: curl http://${BACKEND_SERVER}:3000/health"
    fi
else
    echo ""
    echo "❌ Deployment failed during server restart"
    echo "   SSH to server and check logs: tail -f backend/server.log"
fi
