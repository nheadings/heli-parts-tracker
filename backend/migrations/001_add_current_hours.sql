-- Add current_hours column to helicopters table
ALTER TABLE helicopters ADD COLUMN IF NOT EXISTS current_hours DECIMAL(10, 2);

-- Update current_hours from most recent flight hobbs_end for each helicopter
UPDATE helicopters h
SET current_hours = (
    SELECT f.hobbs_end
    FROM flights f
    WHERE f.helicopter_id = h.id
      AND f.hobbs_end IS NOT NULL
    ORDER BY f.departure_time DESC
    LIMIT 1
)
WHERE EXISTS (
    SELECT 1
    FROM flights f
    WHERE f.helicopter_id = h.id
      AND f.hobbs_end IS NOT NULL
);
