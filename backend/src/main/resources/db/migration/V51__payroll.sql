-- Attendance is now tenant-wide (no site dependency)
ALTER TABLE attendance_records ALTER COLUMN site_id DROP NOT NULL;

-- Employee advance payments (separate from vendor payments)
CREATE TABLE employee_payments (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT NOT NULL REFERENCES tenants(id),
    employee_id     BIGINT NOT NULL REFERENCES employees(id),
    payment_date    DATE NOT NULL,
    amount          NUMERIC(12,2) NOT NULL,
    notes           VARCHAR(500),
    created_by_name VARCHAR(200),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE employee_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_employee_payments ON employee_payments
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
