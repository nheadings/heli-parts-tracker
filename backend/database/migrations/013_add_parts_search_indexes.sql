-- Add indexes for efficient parts searching
-- These indexes will dramatically improve search performance for 200k+ parts

-- Ensure pg_trgm extension is enabled for trigram search (must be first)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Index for part_number searches (exact and partial matches)
CREATE INDEX IF NOT EXISTS idx_parts_part_number_lower
  ON parts (LOWER(part_number) text_pattern_ops);

-- Index for description full-text search using trigrams
CREATE INDEX IF NOT EXISTS idx_parts_description_trgm
  ON parts USING gin (description gin_trgm_ops);

-- Index for filtering by is_life_limited
CREATE INDEX IF NOT EXISTS idx_parts_is_life_limited
  ON parts (is_life_limited);

-- Index for filtering by quantity_in_stock (for "in stock" filter)
CREATE INDEX IF NOT EXISTS idx_parts_quantity_in_stock
  ON parts (quantity_in_stock);

-- Composite index for common filter combinations
CREATE INDEX IF NOT EXISTS idx_parts_stock_life_limited
  ON parts (quantity_in_stock, is_life_limited);

-- Partial index for parts that are in stock (most common query)
CREATE INDEX IF NOT EXISTS idx_parts_in_stock
  ON parts (part_number)
  WHERE quantity_in_stock > 0;
