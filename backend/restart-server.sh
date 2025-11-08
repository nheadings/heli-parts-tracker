#!/bin/bash
# Safe server restart script

echo "Stopping any existing server processes..."
pkill -9 -f 'node server.js' 2>/dev/null || true
sleep 2

echo "Starting server..."
cd ~/backend
nohup node server.js > ~/backend/server.log 2>&1 &

sleep 3

echo "Checking server status..."
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ Server started successfully"
    ps aux | grep 'node server.js' | grep -v grep
else
    echo "❌ Server failed to start"
    tail -20 ~/backend/server.log
fi
