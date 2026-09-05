-- V21: Site Type + Party Linkage, Service Master, Job-Work Invoices

-- ── 1. Sites: add type and linked party ──────────────────────────────────────

ALTER TABLE sites
    ADD COLUMN site_type       VARCHAR(20) NOT NULL DEFAULT 'OWN',
    ADD COLUMN linked_party_id BIGINT REFERENCES vendors(id);

SET app.tenant_id = 1;

-- Ratnagiri Crusher Site (id=1 from seed) → CLIENT_SITE linked to R.D. Samant (vendor id=1)
UPDATE sites SET site_type = 'CLIENT_SITE', linked_party_id = 1 WHERE id = 1;

-- Add Policewadi as OWN site if not already present
INSERT INTO sites (tenant_id, name, location, site_type)
SELECT 1, 'Policewadi Crusher Site', 'Policewadi, Maharashtra', 'OWN'
WHERE NOT EXISTS (
    SELECT 1 FROM sites WHERE tenant_id = 1 AND LOWER(name) LIKE '%policewadi%'
);

-- ── 2. Service Master ─────────────────────────────────────────────────────────

CREATE TABLE services (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id),
    name                VARCHAR(200) NOT NULL,
    code                VARCHAR(50),
    default_unit        VARCHAR(20) NOT NULL DEFAULT 'TON',
    default_rate        NUMERIC(12, 2),         -- ₹/unit; NULL = not yet configured
    gst_rate            NUMERIC(5, 2) NOT NULL DEFAULT 0,
    gst_rate_configured BOOLEAN NOT NULL DEFAULT FALSE,
    sac_code            VARCHAR(20),
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE services ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_services ON services
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

-- Seed 3 services from historical ledger.
-- IMPORTANT: default_rate and gst_rate are left unconfigured (NULL / 0 + gst_rate_configured=FALSE).
-- Admin must set rates before creating invoices — invoices created without a configured
-- GST rate will be marked PENDING and must be Recalculated once the rate is set.
INSERT INTO services (tenant_id, name, default_unit, gst_rate_configured) VALUES
(1, 'Two Stage Crushing Aggregate',        'TON', FALSE),
(1, 'Dabar Breaking Loading And Transport','TON', FALSE),
(1, 'Aggregate Loading',                   'TON', FALSE);

-- ── 3. Job-Work Invoices ──────────────────────────────────────────────────────

CREATE TABLE job_work_invoices (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id),
    vendor_id           BIGINT NOT NULL REFERENCES vendors(id),
    site_id             BIGINT NOT NULL REFERENCES sites(id),
    invoice_no          VARCHAR(50) NOT NULL,
    invoice_date        DATE NOT NULL,
    cgst_rate           NUMERIC(5, 2) NOT NULL DEFAULT 0,
    sgst_rate           NUMERIC(5, 2) NOT NULL DEFAULT 0,
    subtotal            NUMERIC(14, 2) NOT NULL DEFAULT 0,
    cgst_amount         NUMERIC(14, 2) NOT NULL DEFAULT 0,
    sgst_amount         NUMERIC(14, 2) NOT NULL DEFAULT 0,
    grand_total         NUMERIC(14, 2) NOT NULL DEFAULT 0,
    notes               TEXT,
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    gst_status          VARCHAR(20) NOT NULL DEFAULT 'SET',
    gst_recalculated_by VARCHAR(200),
    gst_recalculated_at TIMESTAMP,
    gst_prev_sgst_rate  NUMERIC(5, 2),
    gst_prev_cgst_rate  NUMERIC(5, 2),
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE job_work_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_job_work_invoices ON job_work_invoices
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

-- Items: no tenant_id — protected via cascade from parent
CREATE TABLE job_work_invoice_items (
    id          BIGSERIAL PRIMARY KEY,
    invoice_id  BIGINT NOT NULL REFERENCES job_work_invoices(id) ON DELETE CASCADE,
    service_id  BIGINT REFERENCES services(id),
    description VARCHAR(300) NOT NULL,
    sac_code    VARCHAR(20),
    quantity    NUMERIC(12, 3),
    rate        NUMERIC(10, 2),
    amount      NUMERIC(14, 2) NOT NULL
);

RESET app.tenant_id;
