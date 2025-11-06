-- Flights and Squawks Feature Database Migration
-- Run this to add flight tracking and squawk management capabilities

-- Flights table (tracks individual flights)
CREATE TABLE IF NOT EXISTS flights (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    pilot_id INTEGER REFERENCES users(id),
    hobbs_start DECIMAL(10, 2),
    hobbs_end DECIMAL(10, 2),
    flight_time DECIMAL(10, 2), -- calculated from hobbs_end - hobbs_start
    departure_time TIMESTAMP,
    arrival_time TIMESTAMP,
    hobbs_photo_url TEXT, -- photo of Hobbs meter
    ocr_confidence DECIMAL(5, 2), -- 0.00 to 100.00
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Squawks table (maintenance discrepancies/issues)
CREATE TABLE IF NOT EXISTS squawks (
    id SERIAL PRIMARY KEY,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    severity VARCHAR(20) NOT NULL DEFAULT 'routine', -- routine (white), caution (amber), urgent (red)
    title VARCHAR(200) NOT NULL,
    description TEXT,
    reported_by INTEGER REFERENCES users(id),
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active', -- active, fixed, deferred
    photos JSONB, -- array of photo URLs
    fixed_by INTEGER REFERENCES users(id),
    fixed_at TIMESTAMP,
    fix_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_flights_helicopter ON flights(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_flights_pilot ON flights(pilot_id);
CREATE INDEX IF NOT EXISTS idx_flights_departure_time ON flights(departure_time DESC);
CREATE INDEX IF NOT EXISTS idx_squawks_helicopter ON squawks(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_squawks_status ON squawks(status);
CREATE INDEX IF NOT EXISTS idx_squawks_severity ON squawks(severity);
CREATE INDEX IF NOT EXISTS idx_squawks_reported_at ON squawks(reported_at DESC);

-- Create triggers for updated_at
CREATE TRIGGER update_flights_updated_at BEFORE UPDATE ON flights
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_squawks_updated_at BEFORE UPDATE ON squawks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically calculate flight time
CREATE OR REPLACE FUNCTION calculate_flight_time()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.hobbs_start IS NOT NULL AND NEW.hobbs_end IS NOT NULL THEN
        NEW.flight_time := NEW.hobbs_end - NEW.hobbs_start;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_flight_time
BEFORE INSERT OR UPDATE ON flights
FOR EACH ROW
EXECUTE FUNCTION calculate_flight_time();

-- Add sample squawks for testing (optional)
-- Uncomment to add sample data
-- INSERT INTO squawks (helicopter_id, severity, title, description, reported_by, status) VALUES
--     (1, 'routine', 'VHF Radio Intermittent', 'VHF radio occasionally cuts out during transmission', 1, 'active'),
--     (1, 'caution', 'Low Hydraulic Fluid Level', 'Hydraulic fluid showing slightly low on dipstick', 1, 'active'),
--     (2, 'urgent', 'Chip Light Illuminated', 'Transmission chip light illuminated during flight', 1, 'active');
