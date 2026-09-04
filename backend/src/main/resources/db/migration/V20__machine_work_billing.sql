-- V20: Customer Billable Machine Work
-- Adds work purpose (INTERNAL / CUSTOMER_BILLABLE), customer link,
-- rate/total, and rate-pending state machine to machine_work_logs.

ALTER TABLE machine_work_logs
    ADD COLUMN work_purpose VARCHAR(20) NOT NULL DEFAULT 'INTERNAL',  -- INTERNAL | CUSTOMER_BILLABLE
    ADD COLUMN customer_id  BIGINT REFERENCES vendors(id),
    ADD COLUMN rate         NUMERIC(12, 2),     -- ₹/hr, null when pending
    ADD COLUMN rate_status  VARCHAR(20),         -- PENDING | SET (null for INTERNAL)
    ADD COLUMN total_amount NUMERIC(14, 2),      -- total_hours × rate (null when pending)
    ADD COLUMN rate_set_by  VARCHAR(200),        -- audit: who locked the rate
    ADD COLUMN rate_set_at  TIMESTAMP,           -- audit: when rate was locked
    ADD COLUMN rate_prev    NUMERIC(12, 2);      -- audit: rate before lock (if pre-filled)
