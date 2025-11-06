#!/bin/bash

# Script to run the flights and squawks migration

# Database connection details
DB_NAME="heli_parts_tracker"
MIGRATION_FILE="database/flights-squawks-migration.sql"

echo "Running Flights and Squawks Migration..."
echo "Database: $DB_NAME"
echo "Migration file: $MIGRATION_FILE"
echo ""

# Run the migration
psql $DB_NAME < $MIGRATION_FILE

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration completed successfully!"
else
    echo ""
    echo "❌ Migration failed!"
    exit 1
fi
