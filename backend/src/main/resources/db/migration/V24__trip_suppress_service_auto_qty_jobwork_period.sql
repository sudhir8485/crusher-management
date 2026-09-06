-- V24: Three related features implemented together.
--
-- 1. trips.material_suppressed — tracks when material amount was zeroed out
--    because the billing party is the site owner of a CLIENT_SITE.
--    Default FALSE preserves all existing trips unchanged.
--
-- 2. services.auto_calc_source — controls how Job-Work invoice quantity is
--    computed for this service. NONE = manual entry (default, preserves existing
--    behaviour for all 3 seeded services). TRIP_QUANTITIES or DABAR_QUANTITIES
--    triggers automatic summation from underlying records.
--
-- 3. job_work_invoices.period_from / period_to — optional billing period for
--    the invoice, used as the date range for auto-quantity calculation.
--    Nullable so existing invoices are unaffected.

ALTER TABLE trips
    ADD COLUMN material_suppressed BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE services
    ADD COLUMN auto_calc_source VARCHAR(30) NOT NULL DEFAULT 'NONE';

ALTER TABLE job_work_invoices
    ADD COLUMN period_from DATE,
    ADD COLUMN period_to   DATE;
