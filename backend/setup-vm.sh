#!/bin/bash
# Helicopter Parts Tracker - VM Setup Script
# Run this on your Ubuntu VM (192.168.68.6)

set -e  # Exit on error

echo "========================================="
echo "Heli Parts Tracker - VM Setup"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please don't run as root. Run as regular user with sudo access."
    exit 1
fi

print_info "Starting installation..."
echo ""

# Step 1: Update system
print_info "Step 1/8: Updating system..."
sudo apt update && sudo apt upgrade -y
print_status "System updated"
echo ""

# Step 2: Install Node.js
print_info "Step 2/8: Installing Node.js 18..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    print_status "Node.js installed: $(node --version)"
else
    print_status "Node.js already installed: $(node --version)"
fi
echo ""

# Step 3: Install PostgreSQL
print_info "Step 3/8: Installing PostgreSQL..."
if ! command -v psql &> /dev/null; then
    sudo apt install -y postgresql postgresql-contrib
    print_status "PostgreSQL installed: $(psql --version | head -1)"
else
    print_status "PostgreSQL already installed"
fi
echo ""

# Step 4: Install PM2 for process management
print_info "Step 4/8: Installing PM2..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    print_status "PM2 installed"
else
    print_status "PM2 already installed"
fi
echo ""

# Step 5: Set up PostgreSQL database
print_info "Step 5/8: Setting up database..."

# Generate random password
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)

# Create database and user
sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS heli_parts_tracker;
DROP USER IF EXISTS heliapp;
CREATE DATABASE heli_parts_tracker;
CREATE USER heliapp WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE heli_parts_tracker TO heliapp;
\c heli_parts_tracker
GRANT ALL ON SCHEMA public TO heliapp;
EOF

print_status "Database created: heli_parts_tracker"
print_status "Database user created: heliapp"
echo ""

# Step 6: Load database schema
print_info "Step 6/8: Loading database schema..."
if [ -f "database/schema.sql" ]; then
    sudo -u postgres psql heli_parts_tracker < database/schema.sql
    print_status "Database schema loaded (9 helicopters pre-configured)"
else
    print_error "schema.sql not found. Make sure you're in the backend directory!"
    exit 1
fi
echo ""

# Step 7: Configure application
print_info "Step 7/8: Configuring application..."

# Install npm dependencies
npm install
print_status "NPM dependencies installed"

# Create .env file
cat > .env <<EOF
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=heli_parts_tracker
DB_USER=heliapp
DB_PASSWORD=$DB_PASSWORD

# JWT Secret
JWT_SECRET=$JWT_SECRET

# Server Port
PORT=3000
EOF

print_status ".env file created with secure credentials"
echo ""

# Step 8: Configure firewall
print_info "Step 8/8: Configuring firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 3000/tcp
    sudo ufw --force enable
    print_status "Firewall configured (port 3000 open)"
else
    print_info "UFW not installed, skipping firewall configuration"
fi
echo ""

# Start the application with PM2
print_info "Starting application with PM2..."
pm2 delete heli-parts-api 2>/dev/null || true
pm2 start server.js --name heli-parts-api
pm2 save
pm2 startup | grep "sudo" | bash || true
print_status "Application started and configured for auto-start"
echo ""

# Get VM IP address
VM_IP=$(hostname -I | awk '{print $1}')

# Test the API
print_info "Testing API..."
sleep 2
if curl -s http://localhost:3000/health > /dev/null; then
    print_status "API is running!"
else
    print_error "API test failed. Check logs with: pm2 logs heli-parts-api"
fi
echo ""

# Print summary
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "API Server: http://$VM_IP:3000"
echo "Database: heli_parts_tracker"
echo "Database User: heliapp"
echo ""
echo "SAVE THESE CREDENTIALS:"
echo "  DB Password: $DB_PASSWORD"
echo "  JWT Secret: $JWT_SECRET"
echo ""
echo "Next Steps:"
echo "  1. Create first user:"
echo "     curl -X POST http://$VM_IP:3000/api/auth/register \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"username\":\"admin\",\"email\":\"admin@example.com\",\"password\":\"admin123\",\"full_name\":\"Admin User\",\"role\":\"admin\"}'"
echo ""
echo "  2. Test health endpoint:"
echo "     curl http://$VM_IP:3000/health"
echo ""
echo "  3. Check application status:"
echo "     pm2 status"
echo ""
echo "  4. View logs:"
echo "     pm2 logs heli-parts-api"
echo ""
echo "  5. On your Mac, the Flutter app is already configured to use:"
echo "     http://192.168.68.6:3000/api"
echo ""
print_status "All done! Your backend is running."
echo ""
