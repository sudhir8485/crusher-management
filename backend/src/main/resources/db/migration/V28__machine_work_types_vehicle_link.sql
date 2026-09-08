-- V28: Machine Work Types, Machine-Vehicle bidirectional link, rate simplification

-- 1. Work Types table (replaces hardcoded BUCKET/BREAKER)
CREATE TABLE machine_work_types (
    id               BIGSERIAL PRIMARY KEY,
    tenant_id        BIGINT NOT NULL REFERENCES tenants(id),
    machine_id       BIGINT NOT NULL REFERENCES machines(id),
    label            VARCHAR(100) NOT NULL,
    default_rate     NUMERIC(12, 2),
    default_gst_rate NUMERIC(5, 2),
    sac_code         VARCHAR(20),
    display_order    INT NOT NULL DEFAULT 0,
    status           VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE machine_work_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_machine_work_types ON machine_work_types
    USING (tenant_id = current_setting('app.tenant_id', true)::BIGINT);

-- 2. Machine <-> Vehicle bidirectional soft link
ALTER TABLE machines ADD COLUMN linked_vehicle_id BIGINT REFERENCES vehicles(id);
ALTER TABLE vehicles ADD COLUMN linked_machine_id BIGINT REFERENCES machines(id);

-- 3. Link machine_work_logs to a specific work type
ALTER TABLE machine_work_logs ADD COLUMN work_type_id BIGINT REFERENCES machine_work_types(id);

-- 4. Auto-create 'Bucket' work types for machines with existing BUCKET logs
--    Uses most-recent SET rate as the default_rate (null if none ever set)
INSERT INTO machine_work_types (tenant_id, machine_id, label, default_rate, display_order)
SELECT
    m.tenant_id,
    m.id,
    'Bucket',
    (
        SELECT mwl.rate FROM machine_work_logs mwl
        WHERE mwl.machine_id = m.id
          AND mwl.mode = 'BUCKET'
          AND mwl.rate_status = 'SET'
          AND mwl.status = 'ACTIVE'
        ORDER BY mwl.id DESC
        LIMIT 1
    ),
    0
FROM machines m
WHERE EXISTS (
    SELECT 1 FROM machine_work_logs mwl
    WHERE mwl.machine_id = m.id AND mwl.mode = 'BUCKET' AND mwl.status = 'ACTIVE'
);

-- 5. Auto-create 'Breaker' work types for machines with existing BREAKER logs
INSERT INTO machine_work_types (tenant_id, machine_id, label, default_rate, display_order)
SELECT
    m.tenant_id,
    m.id,
    'Breaker',
    (
        SELECT mwl.rate FROM machine_work_logs mwl
        WHERE mwl.machine_id = m.id
          AND mwl.mode = 'BREAKER'
          AND mwl.rate_status = 'SET'
          AND mwl.status = 'ACTIVE'
        ORDER BY mwl.id DESC
        LIMIT 1
    ),
    1
FROM machines m
WHERE EXISTS (
    SELECT 1 FROM machine_work_logs mwl
    WHERE mwl.machine_id = m.id AND mwl.mode = 'BREAKER' AND mwl.status = 'ACTIVE'
);

-- 6. Back-populate work_type_id on existing logs
UPDATE machine_work_logs mwl
SET work_type_id = (
    SELECT mwt.id FROM machine_work_types mwt
    WHERE mwt.machine_id = mwl.machine_id
      AND mwt.label = CASE mwl.mode
                          WHEN 'BUCKET'  THEN 'Bucket'
                          WHEN 'BREAKER' THEN 'Breaker'
                          ELSE mwl.mode
                      END
    LIMIT 1
)
WHERE mwl.status = 'ACTIVE' AND mwl.mode IN ('BUCKET', 'BREAKER');
