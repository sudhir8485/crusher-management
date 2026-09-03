-- V18: Unified Party model — is_regular flag + ONE_TIME trip migration
--
-- After this migration:
--   * Every trip has a real vendor_id pointing to an actual Party record.
--   * party_type is set to 'REGULAR' for all formerly ONE_TIME trips.
--   * Old snapshot columns (one_time_customer_*) are kept as audit trail; new code stops writing them.
--   * is_regular = false means Occasional customer (not in Trip quick-select default list).
--   * is_regular = true means Regular customer (appears in Trip quick-select default list).
--   * is_regular is INDEPENDENT of gst_registered.

-- 1. Add is_regular to vendors (default false so existing vendors start as Occasional)
ALTER TABLE vendors ADD COLUMN is_regular BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Mark existing known vendors as Regular (they were established before this flag existed)
UPDATE vendors SET is_regular = TRUE
WHERE status = 'ACTIVE'
  AND id IN (1, 2); -- R.D. Samant and Malganga are established regular customers

-- 3. Create a temporary key column to link the INSERT back for the UPDATE
ALTER TABLE vendors ADD COLUMN _ot_key TEXT;

-- 4. Insert distinct one-time customer snapshots as real Party records
--    Distinct on: normalized name + phone (phone blank-coalesced to '' for matching)
--    DISTINCT ON + ORDER BY id ensures we take the first-seen snapshot for duplicates.
INSERT INTO vendors (tenant_id, name, contact, address, is_regular, gst_registered, status, created_at, _ot_key)
SELECT DISTINCT ON (LOWER(TRIM(one_time_customer_name)), COALESCE(TRIM(one_time_customer_phone), ''))
    tenant_id,
    one_time_customer_name,
    one_time_customer_phone,
    one_time_customer_addr,
    FALSE,   -- Occasional customer
    FALSE,
    'ACTIVE',
    NOW(),
    -- Unique key for matching in the UPDATE below
    LOWER(TRIM(one_time_customer_name)) || '||' || COALESCE(TRIM(one_time_customer_phone), '')
FROM trips
WHERE party_type = 'ONE_TIME'
  AND one_time_customer_name IS NOT NULL
  AND status = 'ACTIVE'
ORDER BY LOWER(TRIM(one_time_customer_name)), COALESCE(TRIM(one_time_customer_phone), ''), id ASC;

-- 5. Re-point one-time trips to their newly created Party records
UPDATE trips t
SET
    vendor_id  = v.id,
    party_type = 'REGULAR'
FROM vendors v
WHERE t.party_type   = 'ONE_TIME'
  AND t.status       = 'ACTIVE'
  AND t.one_time_customer_name IS NOT NULL
  AND v._ot_key      = LOWER(TRIM(t.one_time_customer_name)) || '||' || COALESCE(TRIM(t.one_time_customer_phone), '')
  AND v.status       = 'ACTIVE';

-- 6. Clean up the temporary key column
ALTER TABLE vendors DROP COLUMN _ot_key;

-- Note: one_time_customer_name/phone/addr columns are intentionally LEFT in place
-- as an audit trail. New code will no longer write to them.
