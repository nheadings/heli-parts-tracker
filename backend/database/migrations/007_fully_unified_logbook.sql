-- Fully unified logbook - add specialized fields and remove old tables

-- Add specialized fields to logbook_entries
ALTER TABLE logbook_entries
ADD COLUMN IF NOT EXISTS severity VARCHAR(20),
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'completed',
ADD COLUMN IF NOT EXISTS fluid_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS quantity DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS unit VARCHAR(20),
ADD COLUMN IF NOT EXISTS fixed_by INTEGER REFERENCES users(id),
ADD COLUMN IF NOT EXISTS fixed_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS fix_notes TEXT;

-- Create indexes for new fields
CREATE INDEX IF NOT EXISTS idx_logbook_entries_severity ON logbook_entries(severity);
CREATE INDEX IF NOT EXISTS idx_logbook_entries_status ON logbook_entries(status);
CREATE INDEX IF NOT EXISTS idx_logbook_entries_fluid_type ON logbook_entries(fluid_type);

-- Drop old tables (test data only, safe to delete)
DROP TABLE IF EXISTS maintenance_completions CASCADE;
DROP TABLE IF EXISTS fluid_logs CASCADE;
DROP TABLE IF EXISTS maintenance_logs CASCADE;
DROP TABLE IF EXISTS squawks CASCADE;

-- Add comments
COMMENT ON COLUMN logbook_entries.severity IS 'Squawk severity: routine, caution, urgent';
COMMENT ON COLUMN logbook_entries.status IS 'Entry status: open, in_progress, fixed, completed, deferred';
COMMENT ON COLUMN logbook_entries.fluid_type IS 'Type of fluid: oil, hydraulic, fuel, coolant';
COMMENT ON COLUMN logbook_entries.quantity IS 'Quantity of fluid added';
COMMENT ON COLUMN logbook_entries.unit IS 'Unit of measurement: quarts, liters, gallons';
COMMENT ON COLUMN logbook_entries.fixed_by IS 'User who fixed the squawk';
COMMENT ON COLUMN logbook_entries.fixed_at IS 'When the squawk was fixed';
COMMENT ON COLUMN logbook_entries.fix_notes IS 'Notes about how the squawk was fixed';
