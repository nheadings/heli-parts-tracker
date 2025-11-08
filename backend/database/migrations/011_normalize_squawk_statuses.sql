-- Normalize squawk statuses to use Active instead of Open/In Progress
-- Update existing entries to use new status values

UPDATE logbook_entries
SET status = 'active'
WHERE status IN ('open', 'in_progress', 'pending')
  AND category_id = 8;  -- Squawk category only

-- Update completed/resolved/closed to 'fixed' for consistency
UPDATE logbook_entries
SET status = 'fixed'
WHERE status IN ('completed', 'resolved', 'closed')
  AND category_id = 8;  -- Squawk category only
