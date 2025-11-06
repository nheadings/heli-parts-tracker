-- Helicopter Parts Tracking Database Schema

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    role VARCHAR(20) DEFAULT 'user', -- admin, manager, user
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Helicopters table
CREATE TABLE IF NOT EXISTS helicopters (
    id SERIAL PRIMARY KEY,
    tail_number VARCHAR(20) UNIQUE NOT NULL,
    model VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(50),
    year INTEGER,
    current_hours DECIMAL(10, 2), -- current Hobbs hours
    status VARCHAR(20) DEFAULT 'active', -- active, maintenance, retired
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Parts table
CREATE TABLE IF NOT EXISTS parts (
    id SERIAL PRIMARY KEY,
    part_number VARCHAR(100) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    manufacturer VARCHAR(100),
    category VARCHAR(50), -- engine, rotor, avionics, etc.
    quantity_in_stock INTEGER DEFAULT 0,
    minimum_quantity INTEGER DEFAULT 0,
    unit_price DECIMAL(10, 2),
    reorder_url TEXT,
    qr_code VARCHAR(255), -- stores QR code data/reference
    location VARCHAR(100), -- warehouse location
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Part installations table (tracks which parts are installed on which helicopter)
CREATE TABLE IF NOT EXISTS part_installations (
    id SERIAL PRIMARY KEY,
    part_id INTEGER REFERENCES parts(id) ON DELETE CASCADE,
    helicopter_id INTEGER REFERENCES helicopters(id) ON DELETE CASCADE,
    quantity_installed INTEGER DEFAULT 1,
    installation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    installed_by INTEGER REFERENCES users(id),
    serial_number VARCHAR(100), -- specific serial number of installed part
    hours_at_installation DECIMAL(10, 2), -- helicopter hours when installed
    notes TEXT,
    status VARCHAR(20) DEFAULT 'active', -- active, removed, replaced
    removed_date TIMESTAMP,
    removed_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory alerts table
CREATE TABLE IF NOT EXISTS inventory_alerts (
    id SERIAL PRIMARY KEY,
    part_id INTEGER REFERENCES parts(id) ON DELETE CASCADE,
    alert_type VARCHAR(20) DEFAULT 'low_stock', -- low_stock, out_of_stock, custom
    threshold_quantity INTEGER,
    is_active BOOLEAN DEFAULT true,
    email_notification BOOLEAN DEFAULT true,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory transactions table (log all inventory changes)
CREATE TABLE IF NOT EXISTS inventory_transactions (
    id SERIAL PRIMARY KEY,
    part_id INTEGER REFERENCES parts(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL, -- add, remove, adjust, install, return
    quantity_change INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    reference_type VARCHAR(50), -- installation, order, adjustment
    reference_id INTEGER,
    performed_by INTEGER REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_parts_part_number ON parts(part_number);
CREATE INDEX IF NOT EXISTS idx_parts_description ON parts(description);
CREATE INDEX IF NOT EXISTS idx_helicopters_tail_number ON helicopters(tail_number);
CREATE INDEX IF NOT EXISTS idx_installations_part ON part_installations(part_id);
CREATE INDEX IF NOT EXISTS idx_installations_helicopter ON part_installations(helicopter_id);
CREATE INDEX IF NOT EXISTS idx_installations_status ON part_installations(status);
CREATE INDEX IF NOT EXISTS idx_transactions_part ON inventory_transactions(part_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_helicopters_updated_at BEFORE UPDATE ON helicopters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_parts_updated_at BEFORE UPDATE ON parts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_part_installations_updated_at BEFORE UPDATE ON part_installations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inventory_alerts_updated_at BEFORE UPDATE ON inventory_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample helicopters (9 helicopters as mentioned)
INSERT INTO helicopters (tail_number, model, manufacturer, year, status) VALUES
    ('N100H', 'Bell 407', 'Bell', 2018, 'active'),
    ('N101H', 'Bell 407', 'Bell', 2019, 'active'),
    ('N102H', 'Airbus H125', 'Airbus', 2020, 'active'),
    ('N103H', 'Airbus H125', 'Airbus', 2020, 'active'),
    ('N104H', 'Bell 206', 'Bell', 2015, 'active'),
    ('N105H', 'Bell 206', 'Bell', 2016, 'active'),
    ('N106H', 'Robinson R44', 'Robinson', 2017, 'active'),
    ('N107H', 'Robinson R44', 'Robinson', 2018, 'active'),
    ('N108H', 'Airbus H130', 'Airbus', 2021, 'active')
ON CONFLICT (tail_number) DO NOTHING;
