-- Create unified logbook system

-- ============================================================
-- LOGBOOK CATEGORIES TABLE (User-configurable)
-- ============================================================

CREATE TABLE IF NOT EXISTS logbook_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    color VARCHAR(7) DEFAULT '#007AFF',
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_logbook_categories_active
ON logbook_categories(is_active);

CREATE TRIGGER update_logbook_categories_updated_at
BEFORE UPDATE ON logbook_categories
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default categories
INSERT INTO logbook_categories (name, icon, color, display_order) VALUES
('Maintenance', 'wrench.fill', '#FF9500', 1),
('Oil Change', 'drop.fill', '#FF3B30', 2),
('Inspection', 'checkmark.seal.fill', '#34C759', 3),
('Fluid Addition', 'drop.triangle.fill', '#5AC8FA', 4),
('Part Installation', 'cube.box.fill', '#007AFF', 5),
('Flight', 'airplane', '#AF52DE', 6),
('Hours Update', 'clock.fill', '#FF2D55', 7),
('Squawk', 'exclamationmark.triangle.fill', '#FFCC00', 8);

-- ============================================================
-- LOGBOOK ENTRIES TABLE (Unified log for all events)
-- ============================================================

CREATE TABLE IF NOT EXISTS logbook_entries (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER NOT NULL REFERENCES helicopters(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES logbook_categories(id),
    event_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hours_at_event DECIMAL(10, 2),
    description TEXT NOT NULL,
    notes TEXT,
    performed_by INTEGER REFERENCES users(id),
    cost DECIMAL(10, 2),
    next_due_hours DECIMAL(10, 2),
    next_due_date DATE,

    -- Reference IDs for linked records (optional)
    flight_id INTEGER,
    maintenance_log_id INTEGER,
    maintenance_completion_id INTEGER,
    fluid_log_id INTEGER,
    part_installation_id INTEGER,
    squawk_id INTEGER,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_logbook_entries_helicopter
ON logbook_entries(helicopter_id);

CREATE INDEX IF NOT EXISTS idx_logbook_entries_category
ON logbook_entries(category_id);

CREATE INDEX IF NOT EXISTS idx_logbook_entries_date
ON logbook_entries(event_date DESC);

CREATE INDEX IF NOT EXISTS idx_logbook_entries_helicopter_date
ON logbook_entries(helicopter_id, event_date DESC);

CREATE TRIGGER update_logbook_entries_updated_at
BEFORE UPDATE ON logbook_entries
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- LOGBOOK ATTACHMENTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS logbook_attachments (
    id SERIAL PRIMARY KEY,
    entry_id INTEGER NOT NULL REFERENCES logbook_entries(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(100),
    file_size INTEGER,
    uploaded_by INTEGER REFERENCES users(id),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_logbook_attachments_entry
ON logbook_attachments(entry_id);

-- ============================================================
-- COMMENTS
-- ============================================================

COMMENT ON TABLE logbook_categories IS 'User-configurable categories for logbook entries';
COMMENT ON TABLE logbook_entries IS 'Unified logbook containing all helicopter events (flights, maintenance, fluids, parts, etc.)';
COMMENT ON TABLE logbook_attachments IS 'Photos and documents attached to logbook entries';

COMMENT ON COLUMN logbook_entries.flight_id IS 'Reference to flights table if this entry was auto-created from a flight';
COMMENT ON COLUMN logbook_entries.maintenance_log_id IS 'Reference to maintenance_logs table if this entry was auto-created from maintenance';
COMMENT ON COLUMN logbook_entries.maintenance_completion_id IS 'Reference to maintenance_completions if auto-created from template completion';
COMMENT ON COLUMN logbook_entries.fluid_log_id IS 'Reference to fluid_logs if auto-created from fluid addition';
COMMENT ON COLUMN logbook_entries.part_installation_id IS 'Reference to part_installations if auto-created from part install';
COMMENT ON COLUMN logbook_entries.squawk_id IS 'Reference to squawks if auto-created from squawk';
