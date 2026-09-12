-- V48: Enforce true multi-tenant isolation
--
-- Problem: crusher_admin is the table owner and bypasses RLS by default.
-- With only one tenant this was invisible. Now that a second tenant exists,
-- all tenant-scoped tables must use FORCE ROW LEVEL SECURITY so the app
-- user is also subject to the policies.
--
-- Also: the existing policy cast  current_setting(...)::BIGINT  throws when
-- the variable is not set (returns '' after RESET). Replace with NULLIF so
-- unset context → NULL → no rows visible (safe default-deny for SUPER_ADMIN).

-- NOTE: users table intentionally excluded from FORCE ROW LEVEL SECURITY.
-- The login endpoint runs without a tenant context (no JWT yet), so
-- findByEmailNative() must be able to find any user. Application-level
-- tenant filtering is enforced in UserService (explicit WHERE tenant_id = ?)
-- and in AdminService (SET LOCAL before each user query).
ALTER POLICY tenant_isolation_users ON users
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
-- No FORCE ROW LEVEL SECURITY on users table — owner bypass is intentional here.

ALTER POLICY tenant_isolation_vendors ON vendors
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE vendors FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_sites ON sites
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE sites FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_vehicles ON vehicles
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE vehicles FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_machines ON machines
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE machines FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_materials ON materials
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE materials FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_trips ON trips
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE trips FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_dabar ON dabar_entries
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE dabar_entries FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_water_tanker ON water_tanker_logs
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE water_tanker_logs FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_diesel_receipts ON diesel_receipts
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE diesel_receipts FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_diesel_usages ON diesel_usages
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE diesel_usages FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_machine_work_logs ON machine_work_logs
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE machine_work_logs FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_machine_work_types ON machine_work_types
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE machine_work_types FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_gst_invoices ON gst_invoices
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE gst_invoices FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_vendor_payments ON vendor_payments
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE vendor_payments FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_employees ON employees
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE employees FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_attendance_records ON attendance_records
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE attendance_records FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_vehicle_daily_logs ON vehicle_daily_logs
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE vehicle_daily_logs FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_services ON services
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE services FORCE ROW LEVEL SECURITY;

ALTER POLICY tenant_isolation_job_work_invoices ON job_work_invoices
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE job_work_invoices FORCE ROW LEVEL SECURITY;

ALTER POLICY transport_payables_tenant ON transport_payables
    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);
ALTER TABLE transport_payables FORCE ROW LEVEL SECURITY;
