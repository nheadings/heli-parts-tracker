-- Add helicopter-specific template assignments

-- Create junction table for helicopter-template relationships
CREATE TABLE IF NOT EXISTS helicopter_maintenance_templates (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER NOT NULL REFERENCES helicopters(id) ON DELETE CASCADE,
    template_id INTEGER NOT NULL REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(helicopter_id, template_id)
);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_heli_templates_helicopter
ON helicopter_maintenance_templates(helicopter_id);

CREATE INDEX IF NOT EXISTS idx_heli_templates_template
ON helicopter_maintenance_templates(template_id);

-- Create trigger for updated_at
CREATE TRIGGER update_helicopter_maintenance_templates_updated_at
BEFORE UPDATE ON helicopter_maintenance_templates
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
