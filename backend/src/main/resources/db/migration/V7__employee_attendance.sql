CREATE TABLE employees (
    id            BIGSERIAL PRIMARY KEY,
    tenant_id     BIGINT NOT NULL REFERENCES tenants(id),
    name          VARCHAR(200) NOT NULL,
    designation   VARCHAR(100),
    wage_type     VARCHAR(20) NOT NULL DEFAULT 'DAILY',  -- DAILY | MONTHLY
    wage_rate     NUMERIC(10,2),
    status        VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_employees ON employees
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

CREATE TABLE attendance_records (
    id            BIGSERIAL PRIMARY KEY,
    tenant_id     BIGINT NOT NULL REFERENCES tenants(id),
    attendance_date DATE NOT NULL,
    employee_id   BIGINT NOT NULL REFERENCES employees(id),
    status        VARCHAR(20) NOT NULL DEFAULT 'PRESENT',  -- PRESENT | ABSENT | HALF_DAY | LEAVE
    marked_by     VARCHAR(200),
    notes         VARCHAR(300),
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, attendance_date, employee_id)
);

ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_attendance_records ON attendance_records
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
