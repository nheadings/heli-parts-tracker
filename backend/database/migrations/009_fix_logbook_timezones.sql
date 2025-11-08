-- Fix timezone handling for logbook entries
-- Change event_date from timestamp to timestamptz

ALTER TABLE logbook_entries
  ALTER COLUMN event_date TYPE timestamptz
  USING event_date AT TIME ZONE 'UTC';

-- Also fix any other timestamp columns that should be timezone-aware
ALTER TABLE logbook_entries
  ALTER COLUMN created_at TYPE timestamptz
  USING created_at AT TIME ZONE 'UTC';

ALTER TABLE logbook_entries
  ALTER COLUMN updated_at TYPE timestamptz
  USING updated_at AT TIME ZONE 'UTC';

-- Update default for created_at and updated_at
ALTER TABLE logbook_entries
  ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE logbook_entries
  ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
