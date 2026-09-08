-- V30: Trip → GST Invoice auto-linkage (mirrors V22 for machine_work_logs)
--
-- gst_invoice_id: set when a GST invoice is auto-created on trip save for a GST-registered party.
-- auto_invoiced:  TRUE for trips processed by the auto-invoice logic after this migration.
--                 Defaults FALSE so all existing historical trips are excluded from the new
--                 direct-debit ledger view — no retroactive balance changes.

ALTER TABLE trips ADD COLUMN gst_invoice_id BIGINT REFERENCES gst_invoices(id);
ALTER TABLE trips ADD COLUMN auto_invoiced   BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX idx_trips_gst_invoice_id ON trips(gst_invoice_id);
