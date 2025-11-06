-- Logbook Feature Database Migration
-- Run this after schema.sql to add logbook capabilities

-- Add current_hours field to helicopters table
ALTER TABLE helicopters
ADD COLUMN IF NOT EXISTS current_hours DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS serial_number VARCHAR(100);

-- Helicopter hours tracking table
CREATE TABLE IF NOT EXISTS helicopter_hours (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    hours DECIMAL(10, 2) NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    recorded_by INTEGER REFERENCES users(id),
    photo_url TEXT,
    ocr_confidence DECIMAL(5, 2), -- 0.00 to 100.00
    entry_method VARCHAR(20) DEFAULT 'manual', -- manual, ocr, automatic
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Maintenance logs table
CREATE TABLE IF NOT EXISTS maintenance_logs (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    log_type VARCHAR(50) NOT NULL, -- oil_change, inspection, repair, ad_compliance, service
    hours_at_service DECIMAL(10, 2),
    date_performed DATE NOT NULL,
    performed_by INTEGER REFERENCES users(id),
    description TEXT NOT NULL,
    cost DECIMAL(10, 2),
    next_due_hours DECIMAL(10, 2),
    next_due_date DATE,
    attachments JSONB, -- array of photo URLs
    status VARCHAR(20) DEFAULT 'completed', -- scheduled, in_progress, completed
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fluid logs table
CREATE TABLE IF NOT EXISTS fluid_logs (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    fluid_type VARCHAR(50) NOT NULL, -- engine_oil, transmission_oil, hydraulic_fluid, fuel
    quantity DECIMAL(10, 2) NOT NULL, -- in quarts or liters
    unit VARCHAR(20) DEFAULT 'quarts', -- quarts, liters, gallons
    hours DECIMAL(10, 2),
    date_added DATE NOT NULL,
    added_by INTEGER REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Life limited parts table
CREATE TABLE IF NOT EXISTS life_limited_parts (
    id SERIAL PRIMARY KEY,
    part_id INTEGER REFERENCES parts(id) ON DELETE CASCADE,
    installation_id INTEGER REFERENCES part_installations(id) ON DELETE CASCADE,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    part_serial_number VARCHAR(100),
    hour_limit DECIMAL(10, 2), -- TBO in hours
    calendar_limit_months INTEGER, -- TBO in months
    installed_hours DECIMAL(10, 2) NOT NULL,
    installed_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active', -- active, expired, removed
    alert_threshold_percent INTEGER DEFAULT 80, -- alert when 80% of life used
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Maintenance schedules table (both templates and helicopter-specific)
CREATE TABLE IF NOT EXISTS maintenance_schedules (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    interval_hours DECIMAL(10, 2), -- recurring interval in hours
    interval_days INTEGER, -- recurring interval in days
    is_template BOOLEAN DEFAULT false, -- true for global templates
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE, -- null for templates
    category VARCHAR(50), -- ad, inspection, service, overhaul
    created_by INTEGER REFERENCES users(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Maintenance schedule history (completed maintenance from schedules)
CREATE TABLE IF NOT EXISTS maintenance_schedule_history (
    id SERIAL PRIMARY KEY,
    schedule_id INTEGER REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    completed_hours DECIMAL(10, 2),
    completed_date DATE NOT NULL,
    performed_by INTEGER REFERENCES users(id),
    notes TEXT,
    next_due_hours DECIMAL(10, 2),
    next_due_date DATE,
    cost DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Logbook photos table
CREATE TABLE IF NOT EXISTS logbook_photos (
    id SERIAL PRIMARY KEY,
    reference_type VARCHAR(50) NOT NULL, -- helicopter_hours, maintenance_log, fluid_log
    reference_id INTEGER NOT NULL,
    photo_url TEXT NOT NULL,
    ocr_text TEXT, -- extracted text from photo
    thumbnail_url TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_helicopter_hours_helicopter ON helicopter_hours(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_helicopter_hours_recorded_at ON helicopter_hours(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_helicopter ON maintenance_logs(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_type ON maintenance_logs(log_type);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_date ON maintenance_logs(date_performed DESC);
CREATE INDEX IF NOT EXISTS idx_fluid_logs_helicopter ON fluid_logs(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_fluid_logs_type ON fluid_logs(fluid_type);
CREATE INDEX IF NOT EXISTS idx_life_limited_parts_helicopter ON life_limited_parts(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_life_limited_parts_status ON life_limited_parts(status);
CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_helicopter ON maintenance_schedules(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_template ON maintenance_schedules(is_template);
CREATE INDEX IF NOT EXISTS idx_schedule_history_helicopter ON maintenance_schedule_history(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_logbook_photos_reference ON logbook_photos(reference_type, reference_id);

-- Create triggers for updated_at on new tables
CREATE TRIGGER update_maintenance_logs_updated_at BEFORE UPDATE ON maintenance_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_life_limited_parts_updated_at BEFORE UPDATE ON life_limited_parts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_maintenance_schedules_updated_at BEFORE UPDATE ON maintenance_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate hours remaining on life-limited part
CREATE OR REPLACE FUNCTION calculate_life_remaining(
    p_installation_id INTEGER,
    p_current_hours DECIMAL(10, 2)
) RETURNS TABLE (
    hours_remaining DECIMAL(10, 2),
    days_remaining INTEGER,
    percent_remaining DECIMAL(5, 2)
) AS $$
DECLARE
    v_hour_limit DECIMAL(10, 2);
    v_calendar_limit_months INTEGER;
    v_installed_hours DECIMAL(10, 2);
    v_installed_date DATE;
    v_hours_used DECIMAL(10, 2);
    v_days_used INTEGER;
    v_hours_percent DECIMAL(5, 2);
    v_days_percent DECIMAL(5, 2);
BEGIN
    SELECT llp.hour_limit, llp.calendar_limit_months, llp.installed_hours, llp.installed_date
    INTO v_hour_limit, v_calendar_limit_months, v_installed_hours, v_installed_date
    FROM life_limited_parts llp
    WHERE llp.installation_id = p_installation_id
    AND llp.status = 'active';

    IF FOUND THEN
        -- Calculate hours remaining
        v_hours_used := p_current_hours - v_installed_hours;
        hours_remaining := GREATEST(0, v_hour_limit - v_hours_used);
        v_hours_percent := CASE
            WHEN v_hour_limit > 0 THEN (hours_remaining / v_hour_limit) * 100
            ELSE 100
        END;

        -- Calculate days remaining
        v_days_used := CURRENT_DATE - v_installed_date;
        days_remaining := GREATEST(0, (v_calendar_limit_months * 30) - v_days_used);
        v_days_percent := CASE
            WHEN v_calendar_limit_months > 0 THEN (days_remaining::DECIMAL / (v_calendar_limit_months * 30)) * 100
            ELSE 100
        END;

        -- Return the lesser of the two percentages (most restrictive)
        percent_remaining := LEAST(v_hours_percent, v_days_percent);

        RETURN NEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Insert sample maintenance schedules (templates)
INSERT INTO maintenance_schedules (title, description, interval_hours, interval_days, is_template, category) VALUES
    ('100-Hour Inspection', 'Standard 100-hour inspection per maintenance manual', 100, NULL, true, 'inspection'),
    ('Annual Inspection', 'Annual inspection required by FAA', NULL, 365, true, 'inspection'),
    ('Oil Change', 'Engine oil change', 50, NULL, true, 'service'),
    ('Transmission Oil Change', 'Transmission oil and filter change', 100, NULL, true, 'service'),
    ('Hydraulic Fluid Service', 'Hydraulic system fluid service', 200, NULL, true, 'service')
ON CONFLICT DO NOTHING;
