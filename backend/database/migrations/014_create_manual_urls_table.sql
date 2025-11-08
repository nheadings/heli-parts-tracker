-- Create table for storing manual URLs centrally
-- This allows admins to update URLs once and all users get the changes

CREATE TABLE IF NOT EXISTS manual_urls (
  id SERIAL PRIMARY KEY,
  manual_type VARCHAR(50) UNIQUE NOT NULL,  -- e.g., 'r44_ipc', 'r44_mm'
  url TEXT NOT NULL,
  description VARCHAR(255),
  updated_by INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert default URLs
INSERT INTO manual_urls (manual_type, url, description) VALUES
  ('r44_ipc', 'https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r44_ipc_full_book_90d807fd56.pdf', 'R44 Illustrated Parts Catalog'),
  ('r44_mm', 'https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r44_mm_full_book_a0b0b62448.pdf', 'R44 Maintenance Manual')
ON CONFLICT (manual_type) DO NOTHING;

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_manual_urls_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_manual_urls_updated_at
    BEFORE UPDATE ON manual_urls
    FOR EACH ROW
    EXECUTE FUNCTION update_manual_urls_updated_at();
