-- Audit tracking (who created / last edited) for all operational entry tables,
-- matching the pattern already used by trips (created_by_name / updated_by_name).
-- Excluded: Party, Vehicle, Machine, Material, Site, Service, Attendance.

ALTER TABLE dabar_entries
    ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(200);

ALTER TABLE diesel_receipts
    ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(200);

ALTER TABLE diesel_usages
    ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(200);

ALTER TABLE machine_work_logs
    ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(200);

ALTER TABLE gst_invoices
    ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(200);

ALTER TABLE job_work_invoices
    ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(200);

ALTER TABLE vendor_payments
    ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(200);
