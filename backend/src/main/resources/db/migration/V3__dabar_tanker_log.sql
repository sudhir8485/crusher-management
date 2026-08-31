-- ============================================================
-- V3 - Dabar (raw stone intake) + Water Tanker log
-- ============================================================

CREATE TABLE dabar_entries (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT NOT NULL REFERENCES tenants(id),
    entry_date      DATE NOT NULL,
    vehicle_id      BIGINT REFERENCES vehicles(id),
    vendor_id       BIGINT REFERENCES vendors(id),
    trips_count     INT,
    quantity_brass  NUMERIC(10,3),
    notes           VARCHAR(500),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE dabar_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_dabar ON dabar_entries
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

-- ────────────────────────────────────────────────────────────

CREATE TABLE water_tanker_logs (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT NOT NULL REFERENCES tenants(id),
    log_date        DATE NOT NULL,
    vehicle_id      BIGINT REFERENCES vehicles(id),
    hours_worked    NUMERIC(8,2),
    km_run          NUMERIC(8,2),
    trips_count     INT,
    rate            NUMERIC(10,2),
    notes           VARCHAR(500),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE water_tanker_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_water_tanker ON water_tanker_logs
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
