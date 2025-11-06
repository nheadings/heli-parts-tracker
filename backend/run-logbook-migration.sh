#!/bin/bash

# Run logbook migration on backend database
# This script should be run on the backend server

echo "Running logbook migration..."

# Read database connection info from environment or use defaults
DB_USER="${DB_USER:-heli_user}"
DB_NAME="${DB_NAME:-heli_parts_db}"
DB_HOST="${DB_HOST:-localhost}"

# Run the migration
psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -f database/logbook-migration.sql

if [ $? -eq 0 ]; then
    echo "Logbook migration completed successfully!"
else
    echo "Logbook migration failed!"
    exit 1
fi
