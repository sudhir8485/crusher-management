CREATE TABLE machine_work_logs (
    id               BIGSERIAL PRIMARY KEY,
    tenant_id        BIGINT NOT NULL REFERENCES tenants(id),
    log_date         DATE NOT NULL,
    machine_id       BIGINT NOT NULL REFERENCES machines(id),
    work_description VARCHAR(500),
    mode             VARCHAR(20) NOT NULL DEFAULT 'BUCKET',  -- BUCKET | BREAKER
    opening_reading  NUMERIC(10, 2),
    closing_reading  NUMERIC(10, 2),
    total_hours      NUMERIC(8, 2),                          -- stored: closing - opening
    notes            VARCHAR(500),
    status           VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE machine_work_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_machine_work_logs ON machine_work_logs
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
