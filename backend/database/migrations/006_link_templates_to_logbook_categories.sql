-- Link maintenance templates to logbook categories

-- Grant permissions first (will succeed even if already granted)
DO $$
BEGIN
    EXECUTE 'GRANT ALL ON TABLE maintenance_schedules TO heliapp';
    EXECUTE 'GRANT ALL ON TABLE logbook_categories TO heliapp';
EXCEPTION WHEN insufficient_privilege THEN
    -- Ignore permission errors, we'll try the ALTER anyway
    NULL;
END $$;

-- Add logbook_category_id to maintenance_schedules
ALTER TABLE maintenance_schedules
ADD COLUMN IF NOT EXISTS logbook_category_id INTEGER REFERENCES logbook_categories(id);

-- Create index
CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_logbook_category
ON maintenance_schedules(logbook_category_id);

-- Update existing templates to match logbook categories by name/type
-- Match based on common patterns
UPDATE maintenance_schedules SET logbook_category_id = (
    SELECT id FROM logbook_categories WHERE name = 'Oil Change' LIMIT 1
) WHERE title ILIKE '%oil%';

UPDATE maintenance_schedules SET logbook_category_id = (
    SELECT id FROM logbook_categories WHERE name = 'Inspection' LIMIT 1
) WHERE title ILIKE '%inspection%' OR title ILIKE '%annual%';

UPDATE maintenance_schedules SET logbook_category_id = (
    SELECT id FROM logbook_categories WHERE name = 'Maintenance' LIMIT 1
) WHERE logbook_category_id IS NULL;

COMMENT ON COLUMN maintenance_schedules.logbook_category_id IS 'Links maintenance template to logbook category for unified event logging';
