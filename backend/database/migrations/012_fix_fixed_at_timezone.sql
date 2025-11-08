-- Fix timezone handling for fixed_at column in logbook_entries

ALTER TABLE logbook_entries
  ALTER COLUMN fixed_at TYPE timestamptz
  USING fixed_at AT TIME ZONE 'UTC';
