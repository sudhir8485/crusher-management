-- V10: Add site_id to users and all operational tables
-- Users: SITE_STAFF is assigned to one site; admins have site_id NULL (see all sites)
ALTER TABLE users ADD COLUMN site_id BIGINT REFERENCES sites(id);

-- Operational tables: every record belongs to one physical site
-- Backfill existing rows to site 1 (Ratnagiri Crusher Site) using DEFAULT 1
ALTER TABLE trips              ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);
ALTER TABLE dabar_entries      ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);
ALTER TABLE diesel_receipts    ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);
ALTER TABLE diesel_usages      ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);
ALTER TABLE machine_work_logs  ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);
ALTER TABLE water_tanker_logs  ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);
ALTER TABLE attendance_records ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);
ALTER TABLE vehicle_daily_logs ADD COLUMN site_id BIGINT NOT NULL DEFAULT 1 REFERENCES sites(id);

-- Remove defaults (site_id must be supplied explicitly going forward)
ALTER TABLE trips              ALTER COLUMN site_id DROP DEFAULT;
ALTER TABLE dabar_entries      ALTER COLUMN site_id DROP DEFAULT;
ALTER TABLE diesel_receipts    ALTER COLUMN site_id DROP DEFAULT;
ALTER TABLE diesel_usages      ALTER COLUMN site_id DROP DEFAULT;
ALTER TABLE machine_work_logs  ALTER COLUMN site_id DROP DEFAULT;
ALTER TABLE water_tanker_logs  ALTER COLUMN site_id DROP DEFAULT;
ALTER TABLE attendance_records ALTER COLUMN site_id DROP DEFAULT;
ALTER TABLE vehicle_daily_logs ALTER COLUMN site_id DROP DEFAULT;
