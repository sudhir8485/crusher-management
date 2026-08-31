-- ============================================================
-- V1 - Initial Schema: DSP Crusher Management
-- Multi-tenant with PostgreSQL Row-Level Security
-- ============================================================

-- Tenants (top-level business accounts)
CREATE TABLE tenants (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    gstin       VARCHAR(20),
    address     TEXT,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Users
CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    tenant_id     BIGINT NOT NULL REFERENCES tenants(id),
    email         VARCHAR(200) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(200) NOT NULL,
    role          VARCHAR(30) NOT NULL,  -- OWNER_ADMIN, OFFICE_ACCOUNTANT, SITE_STAFF
    status        VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, email)
);

-- Vendors (contractors working within a tenant's site)
CREATE TABLE vendors (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT NOT NULL REFERENCES tenants(id),
    name        VARCHAR(200) NOT NULL,
    gstin       VARCHAR(20),
    contact     VARCHAR(100),
    address     TEXT,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Sites (physical locations, e.g. Ratnagiri crusher site)
CREATE TABLE sites (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT NOT NULL REFERENCES tenants(id),
    name        VARCHAR(200) NOT NULL,
    location    TEXT,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Vehicles
CREATE TABLE vehicles (
    id             BIGSERIAL PRIMARY KEY,
    tenant_id      BIGINT NOT NULL REFERENCES tenants(id),
    owner          VARCHAR(10) NOT NULL,  -- TENANT or VENDOR
    vendor_id      BIGINT REFERENCES vendors(id),
    plate_number   VARCHAR(20) NOT NULL,
    display_name   VARCHAR(100),          -- short name used in reports (e.g. "2201")
    vehicle_type   VARCHAR(100),          -- Dumper, Tanker, Truck etc.
    status         VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Machines
CREATE TABLE machines (
    id             BIGSERIAL PRIMARY KEY,
    tenant_id      BIGINT NOT NULL REFERENCES tenants(id),
    owner          VARCHAR(10) NOT NULL,  -- TENANT or VENDOR
    vendor_id      BIGINT REFERENCES vendors(id),
    name           VARCHAR(100) NOT NULL, -- e.g. "JCB 205 Machine"
    machine_type   VARCHAR(100),          -- JCB, Comosko, Generator etc.
    status         VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Materials (crushed stone sizes and types)
CREATE TABLE materials (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT NOT NULL REFERENCES tenants(id),
    name         VARCHAR(100) NOT NULL,   -- e.g. "20 MM", "GSB", "Dabar"
    size_label   VARCHAR(50),             -- display label
    unit         VARCHAR(10) NOT NULL DEFAULT 'BRASS',  -- BRASS or TON
    status       VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Enable Row-Level Security on all tenant-scoped tables
-- ============================================================

ALTER TABLE users     ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors   ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites     ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE machines  ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;

-- RLS policies: each row is visible only when tenant_id matches
-- the session variable set by the application on every request.

CREATE POLICY tenant_isolation_users ON users
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

CREATE POLICY tenant_isolation_vendors ON vendors
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

CREATE POLICY tenant_isolation_sites ON sites
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

CREATE POLICY tenant_isolation_vehicles ON vehicles
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

CREATE POLICY tenant_isolation_machines ON machines
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

CREATE POLICY tenant_isolation_materials ON materials
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

-- ============================================================
-- Grant the app user permission to bypass RLS for admin ops
-- (app connects as crusher_admin which is granted BYPASSRLS
--  only for the tenants table; all other tables use RLS)
-- ============================================================

-- ============================================================
-- Seed: DSP Construction tenant + admin user
-- Password hash = BCrypt of "admin123"
-- ============================================================

INSERT INTO tenants (name, gstin, address)
VALUES ('DSP Construction', '27APDPD6268D1Z2',
        'Flat No.12, A Wing, Sai Business Court, Opp. Shirur Tahasil Office, Shirur, Dist.- Pune 412210');

-- Set tenant context to allow insert into RLS-protected table
SET app.tenant_id = 1;

INSERT INTO users (tenant_id, email, password_hash, full_name, role)
VALUES (1, 'admin@dsp.com',
        '$2a$12$FP0bOsFNyuwC379jOrFxWOOzHhqZP3.9fmkmru/UVjxCKwDqJb0eG',
        'DSP Admin', 'OWNER_ADMIN');

-- Seed: R.D. Samant as vendor
INSERT INTO vendors (tenant_id, name, gstin, address)
VALUES (1, 'R.D. Samant Contractors Pvt. Ltd.', '27AABCR0368J1ZA',
        'House No. 366, Shanti Sadan, Bajarpeth, Pali Devtale, Pali, Ratnagiri');

-- Seed: Ratnagiri site
INSERT INTO sites (tenant_id, name, location)
VALUES (1, 'Ratnagiri Crusher Site', 'Parchuri, Ratnagiri, Maharashtra');

-- Seed: Vehicles
-- Vendor-owned (R.D. Samant fleet)
INSERT INTO vehicles (tenant_id, owner, vendor_id, plate_number, display_name, vehicle_type) VALUES
(1, 'VENDOR', 1, 'MH AS 2201',  '2201', 'Ashok Leyland Dumper'),
(1, 'VENDOR', 1, 'MH AS 2301',  '2301', 'Ashok Leyland Dumper'),
(1, 'VENDOR', 1, 'MH 46 BF 9955', '9955', 'Tata Dumper'),
(1, 'VENDOR', 1, 'MH 36 AA 0653', '0653', 'Dumper');

-- Tenant-owned vehicles (DSP's own fleet)
INSERT INTO vehicles (tenant_id, owner, vendor_id, plate_number, display_name, vehicle_type) VALUES
(1, 'TENANT', NULL, 'MH 47 AS 5199', '5199', 'Tata Dumper'),
(1, 'TENANT', NULL, 'MH 12 YQ 8117', '8117', 'Diesel Tanker'),
-- Water tanker: tenant-owned but assigned/rented to vendor
(1, 'TENANT', 1,    'MH 12 LT 6091', '6091', 'Water Tanker');

-- Seed: Machines
INSERT INTO machines (tenant_id, owner, vendor_id, name, machine_type) VALUES
(1, 'VENDOR', 1,    'JCB 205 Machine', 'JCB'),
(1, 'VENDOR', 1,    'JCB 140 Machine', 'JCB'),
(1, 'VENDOR', 1,    'Comosko Machine', 'Comosko'),
(1, 'VENDOR', 1,    '500 KV DG Set',   'Generator'),
(1, 'TENANT', NULL, 'JCB 205',         'JCB');

-- Seed: Materials
INSERT INTO materials (tenant_id, name, size_label, unit) VALUES
(1, '4 MM',  '4 MM',  'BRASS'),
(1, '5 MM',  '5 MM',  'BRASS'),
(1, '10 MM', '10 MM', 'BRASS'),
(1, '20 MM', '20 MM', 'BRASS'),
(1, '30 MM', '30 MM', 'BRASS'),
(1, 'GSB',   'GSB',   'BRASS'),
(1, 'Dabar', 'Dabar', 'BRASS');

-- Reset tenant context after seed
RESET app.tenant_id;
