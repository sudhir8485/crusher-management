-- V11: Trip billing redesign — add pricing, weight (kg), one-time customer, vehicle mode

-- ── trips: new billing columns ──────────────────────────────────────────────
ALTER TABLE trips
    ADD COLUMN party_type               VARCHAR(20)   NOT NULL DEFAULT 'REGULAR',
    ADD COLUMN one_time_customer_name   VARCHAR(200),
    ADD COLUMN one_time_customer_phone  VARCHAR(50),
    ADD COLUMN one_time_customer_addr   TEXT,
    ADD COLUMN vehicle_mode             VARCHAR(20)   NOT NULL DEFAULT 'COMPANY',
    ADD COLUMN loaded_weight_kg         NUMERIC(12,2),
    ADD COLUMN empty_weight_kg          NUMERIC(12,2),
    ADD COLUMN net_weight_kg            NUMERIC(12,2),
    ADD COLUMN quantity_unit            VARCHAR(10)   NOT NULL DEFAULT 'BRASS',
    ADD COLUMN billable_quantity        NUMERIC(12,3),
    ADD COLUMN sale_rate                NUMERIC(10,2),
    ADD COLUMN material_amount          NUMERIC(14,2),
    ADD COLUMN distance_km              NUMERIC(8,2),
    ADD COLUMN transport_rate_per_km    NUMERIC(10,2),
    ADD COLUMN transportation_charge    NUMERIC(14,2) NOT NULL DEFAULT 0,
    ADD COLUMN total_bill               NUMERIC(14,2),
    ADD COLUMN notes                    TEXT;

-- migrate existing weight data: old columns stored tons → convert to kg
UPDATE trips
SET loaded_weight_kg = ROUND(loaded_weight_ton * 1000, 2),
    empty_weight_kg  = ROUND(empty_weight_ton  * 1000, 2),
    net_weight_kg    = ROUND(
        (COALESCE(loaded_weight_ton, 0) - COALESCE(empty_weight_ton, 0)) * 1000, 2)
WHERE loaded_weight_ton IS NOT NULL;

-- migrate existing quantity_brass → billable_quantity for continuity
UPDATE trips
SET billable_quantity = quantity_brass,
    quantity_unit     = COALESCE(
        (SELECT m.unit FROM materials m WHERE m.id = trips.material_id),
        'BRASS')
WHERE quantity_brass IS NOT NULL;

-- ── materials: default pricing columns ──────────────────────────────────────
ALTER TABLE materials
    ADD COLUMN default_sale_rate NUMERIC(10,2),
    ADD COLUMN kg_per_brass      NUMERIC(10,3);
