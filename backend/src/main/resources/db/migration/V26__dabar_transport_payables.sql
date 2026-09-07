-- Generic transport payables table.
-- source_type discriminator allows MACHINE_WORK to reuse the same engine in future —
-- do NOT create a separate payables table when adding machine ownership payables.
CREATE TABLE transport_payables (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT NOT NULL,
    site_id         BIGINT NOT NULL,
    entry_date      DATE NOT NULL,
    source_type     VARCHAR(30) NOT NULL DEFAULT 'DABAR',
    source_entry_id BIGINT NOT NULL,
    vehicle_id      BIGINT,
    party_id        BIGINT NOT NULL REFERENCES vendors(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE transport_payables ENABLE ROW LEVEL SECURITY;

CREATE POLICY transport_payables_tenant ON transport_payables
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);
