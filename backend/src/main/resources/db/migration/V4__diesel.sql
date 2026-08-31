-- ============================================================
-- V4 - Diesel receipts and usage tracking
-- ============================================================

CREATE TABLE diesel_receipts (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT NOT NULL REFERENCES tenants(id),
    receipt_date    DATE NOT NULL,
    source          VARCHAR(20) NOT NULL,   -- PUMP | DIRECT
    quantity_liters NUMERIC(10,2) NOT NULL,
    rate_per_liter  NUMERIC(10,2),
    amount          NUMERIC(12,2),          -- stored = quantity * rate
    vendor_id       BIGINT REFERENCES vendors(id),
    invoice_no      VARCHAR(50),
    notes           VARCHAR(500),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE diesel_receipts ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_diesel_receipts ON diesel_receipts
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

-- ────────────────────────────────────────────────────────────

CREATE TABLE diesel_usages (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT NOT NULL REFERENCES tenants(id),
    usage_date      DATE NOT NULL,
    machine_id      BIGINT REFERENCES machines(id),
    vehicle_id      BIGINT REFERENCES vehicles(id),
    quantity_liters NUMERIC(10,2) NOT NULL,
    notes           VARCHAR(500),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE diesel_usages ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_diesel_usages ON diesel_usages
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
