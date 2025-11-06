-- Add is_life_limited column to parts table
ALTER TABLE parts ADD COLUMN IF NOT EXISTS is_life_limited BOOLEAN DEFAULT false;

-- Add index for filtering life-limited parts
CREATE INDEX IF NOT EXISTS idx_parts_life_limited ON parts(is_life_limited);
