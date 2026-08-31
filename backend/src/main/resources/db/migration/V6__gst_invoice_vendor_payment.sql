CREATE TABLE gst_invoices (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT NOT NULL REFERENCES tenants(id),
    vendor_id    BIGINT NOT NULL REFERENCES vendors(id),
    invoice_no   VARCHAR(50) NOT NULL,
    invoice_date DATE NOT NULL,
    supply_date  DATE,
    po_no        VARCHAR(50),
    cgst_rate    NUMERIC(5,2) NOT NULL DEFAULT 9.00,
    sgst_rate    NUMERIC(5,2) NOT NULL DEFAULT 9.00,
    subtotal     NUMERIC(14,2) NOT NULL DEFAULT 0,
    cgst_amount  NUMERIC(14,2) NOT NULL DEFAULT 0,
    sgst_amount  NUMERIC(14,2) NOT NULL DEFAULT 0,
    grand_total  NUMERIC(14,2) NOT NULL DEFAULT 0,
    notes        TEXT,
    status       VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE gst_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_gst_invoices ON gst_invoices
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

-- Items have no tenant_id; they're protected through CASCADE from parent invoice
CREATE TABLE gst_invoice_items (
    id             BIGSERIAL PRIMARY KEY,
    invoice_id     BIGINT NOT NULL REFERENCES gst_invoices(id) ON DELETE CASCADE,
    description    VARCHAR(300) NOT NULL,
    hsn            VARCHAR(20),
    quantity_brass NUMERIC(12,3),
    rate           NUMERIC(10,2),
    amount         NUMERIC(14,2) NOT NULL
);

CREATE TABLE vendor_payments (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT NOT NULL REFERENCES tenants(id),
    vendor_id    BIGINT NOT NULL REFERENCES vendors(id),
    payment_date DATE NOT NULL,
    amount       NUMERIC(14,2) NOT NULL,
    payment_mode VARCHAR(20) NOT NULL DEFAULT 'CASH',  -- CASH | BANK | CHEQUE | UPI
    reference_no VARCHAR(100),
    notes        VARCHAR(500),
    status       VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE vendor_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_vendor_payments ON vendor_payments
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
