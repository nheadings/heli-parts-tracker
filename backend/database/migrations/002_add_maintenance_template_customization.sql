-- Add customization fields to maintenance_schedules table for flight view display

-- Add color field for custom color coding (hex format)
ALTER TABLE maintenance_schedules
ADD COLUMN IF NOT EXISTS color VARCHAR(7) DEFAULT '#34C759';

-- Add display order for sorting on flight page
ALTER TABLE maintenance_schedules
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

-- Add flag to show/hide in flight view
ALTER TABLE maintenance_schedules
ADD COLUMN IF NOT EXISTS display_in_flight_view BOOLEAN DEFAULT false;

-- Add threshold for warning color (hours before due)
ALTER TABLE maintenance_schedules
ADD COLUMN IF NOT EXISTS threshold_warning INTEGER DEFAULT 10;

-- Create index for efficient querying of flight view items
CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_flight_view
ON maintenance_schedules(display_in_flight_view, display_order)
WHERE display_in_flight_view = true;

-- Insert default maintenance templates
INSERT INTO maintenance_schedules (
  title,
  description,
  interval_hours,
  is_template,
  category,
  color,
  display_order,
  display_in_flight_view,
  threshold_warning
) VALUES
  ('Oil Change', 'Regular engine oil change', 100, true, 'service', '#FF9500', 1, true, 10),
  ('Fuel Line Inspection', 'Fuel line AD compliance inspection', 100, true, 'ad_compliance', '#FF3B30', 2, true, 25),
  ('AVBlend', 'AVBlend additive service', 50, true, 'service', '#007AFF', 3, true, 5)
ON CONFLICT DO NOTHING;

-- Update any existing maintenance schedules to have default values
UPDATE maintenance_schedules
SET
  color = COALESCE(color, '#34C759'),
  display_order = COALESCE(display_order, 0),
  display_in_flight_view = COALESCE(display_in_flight_view, false),
  threshold_warning = COALESCE(threshold_warning, 10)
WHERE color IS NULL OR display_order IS NULL OR display_in_flight_view IS NULL OR threshold_warning IS NULL;
