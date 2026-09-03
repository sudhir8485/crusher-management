-- Fix trips where created_by_name / updated_by_name was stored as a raw
-- user ID (numeric string) instead of the user's full name.
-- This happened when TripService.getCurrentUserName() incorrectly called
-- findByEmailNative(email) where 'email' was actually the numeric JWT sub claim.

UPDATE trips
SET created_by_name = u.full_name
FROM users u
WHERE trips.created_by_name ~ '^\d+$'
  AND CAST(trips.created_by_name AS BIGINT) = u.id;

UPDATE trips
SET updated_by_name = u.full_name
FROM users u
WHERE trips.updated_by_name ~ '^\d+$'
  AND CAST(trips.updated_by_name AS BIGINT) = u.id;
