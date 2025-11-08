-- Fix timezone handling for flights
-- Change departure_time and arrival_time from timestamp to timestamptz

ALTER TABLE flights
  ALTER COLUMN departure_time TYPE timestamptz
  USING departure_time AT TIME ZONE 'UTC';

ALTER TABLE flights
  ALTER COLUMN arrival_time TYPE timestamptz
  USING arrival_time AT TIME ZONE 'UTC';

ALTER TABLE flights
  ALTER COLUMN created_at TYPE timestamptz
  USING created_at AT TIME ZONE 'UTC';

-- Update default for created_at
ALTER TABLE flights
  ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;
