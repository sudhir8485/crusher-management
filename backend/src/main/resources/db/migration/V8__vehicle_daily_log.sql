CREATE TABLE vehicle_daily_logs (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id),
    log_date            DATE NOT NULL,
    vehicle_id          BIGINT NOT NULL REFERENCES vehicles(id),
    loading_location    VARCHAR(300),
    unloading_location  VARCHAR(300),
    opening_reading     NUMERIC(10,1),
    closing_reading     NUMERIC(10,1),
    total_km            NUMERIC(10,1),           -- stored: closing − opening
    trips_day           INT NOT NULL DEFAULT 0,
    trips_night         INT NOT NULL DEFAULT 0,
    total_trips         INT NOT NULL DEFAULT 0,  -- stored: day + night
    diesel_note         VARCHAR(500),
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE vehicle_daily_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_vehicle_daily_logs ON vehicle_daily_logs
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
