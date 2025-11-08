-- Add banner functionality to logbook_categories, eliminate maintenance_schedules

-- Add banner-related fields to logbook_categories
ALTER TABLE logbook_categories
ADD COLUMN IF NOT EXISTS display_in_flight_view BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS interval_hours DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS threshold_warning INTEGER DEFAULT 25;

-- Create helicopter-category assignments table (replaces helicopter_maintenance_templates)
CREATE TABLE IF NOT EXISTS helicopter_category_banners (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER NOT NULL REFERENCES helicopters(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES logbook_categories(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(helicopter_id, category_id)
);

CREATE INDEX IF NOT EXISTS idx_heli_category_banners_helicopter
ON helicopter_category_banners(helicopter_id);

CREATE INDEX IF NOT EXISTS idx_heli_category_banners_category
ON helicopter_category_banners(category_id);

CREATE TRIGGER update_helicopter_category_banners_updated_at
BEFORE UPDATE ON helicopter_category_banners
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Migrate data from maintenance_schedules to logbook_categories
-- Update categories with banner settings from templates (take first match per category)
UPDATE logbook_categories lc SET
    display_in_flight_view = true,
    interval_hours = subq.interval_hours,
    threshold_warning = subq.threshold_warning
FROM (
    SELECT DISTINCT ON (logbook_category_id)
        logbook_category_id,
        interval_hours,
        threshold_warning
    FROM maintenance_schedules
    WHERE display_in_flight_view = true
    AND logbook_category_id IS NOT NULL
    ORDER BY logbook_category_id, id
) subq
WHERE lc.id = subq.logbook_category_id;

-- Migrate helicopter assignments
INSERT INTO helicopter_category_banners (helicopter_id, category_id, is_enabled)
SELECT DISTINCT hmt.helicopter_id, ms.logbook_category_id, hmt.is_enabled
FROM helicopter_maintenance_templates hmt
JOIN maintenance_schedules ms ON hmt.template_id = ms.id
WHERE ms.logbook_category_id IS NOT NULL
ON CONFLICT (helicopter_id, category_id) DO NOTHING;

-- Drop old tables
DROP TABLE IF EXISTS helicopter_maintenance_templates CASCADE;
DROP TABLE IF EXISTS maintenance_schedule_history CASCADE;
DROP TABLE IF EXISTS maintenance_schedules CASCADE;

COMMENT ON COLUMN logbook_categories.display_in_flight_view IS 'Show this category as a maintenance banner in Flight View';
COMMENT ON COLUMN logbook_categories.interval_hours IS 'Hours between maintenance for this category';
COMMENT ON COLUMN logbook_categories.threshold_warning IS 'Hours remaining to show warning color';
COMMENT ON TABLE helicopter_category_banners IS 'Which helicopters show which category banners';
