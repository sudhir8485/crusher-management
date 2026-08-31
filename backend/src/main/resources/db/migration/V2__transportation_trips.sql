-- ============================================================
-- V2 - Transportation Trips
-- ============================================================

CREATE TABLE trips (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id),
    trip_date           DATE NOT NULL,
    loading_location    VARCHAR(300),
    unloading_location  VARCHAR(300),
    channel_no          VARCHAR(50),
    material_id         BIGINT REFERENCES materials(id),
    quantity_brass      NUMERIC(10,3),
    loaded_weight_ton   NUMERIC(10,3),
    empty_weight_ton    NUMERIC(10,3),
    vehicle_id          BIGINT REFERENCES vehicles(id),
    vendor_id           BIGINT REFERENCES vendors(id),
    dsp_challan_no      VARCHAR(50),
    vendor_challan_no   VARCHAR(50),
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_trips ON trips
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
