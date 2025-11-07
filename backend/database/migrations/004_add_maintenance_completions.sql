-- Create maintenance completions tracking table

CREATE TABLE IF NOT EXISTS maintenance_completions (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER NOT NULL REFERENCES helicopters(id) ON DELETE CASCADE,
    template_id INTEGER NOT NULL REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
    completed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hours_at_completion DECIMAL(10, 2) NOT NULL,
    notes TEXT,
    completed_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_maintenance_completions_helicopter
ON maintenance_completions(helicopter_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_completions_template
ON maintenance_completions(template_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_completions_completed_at
ON maintenance_completions(completed_at DESC);

-- Create trigger for updated_at
CREATE TRIGGER update_maintenance_completions_updated_at
BEFORE UPDATE ON maintenance_completions
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
