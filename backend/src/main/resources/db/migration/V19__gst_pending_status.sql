-- V19: GST Pending state — distinguish "never configured" 0% from deliberately zero-rated
--      Adds gst_status to invoices, material_id to invoice items, and audit fields
--      for the explicit Recalculate GST action.

-- Mark materials whose GST rate has been deliberately set (even if zero)
ALTER TABLE materials
    ADD COLUMN gst_rate_configured BOOLEAN NOT NULL DEFAULT FALSE;

-- All materials that already carry a non-zero GST rate are implicitly configured
UPDATE materials SET gst_rate_configured = TRUE WHERE gst_rate > 0;

-- gst_status on the invoice: PENDING (rate was unset when raised) | SET (locked snapshot)
-- Existing invoices with non-zero rates are already locked; zero-rate legacy invoices
-- are treated as SET because we cannot retroactively distinguish intent.
ALTER TABLE gst_invoices
    ADD COLUMN gst_status VARCHAR(10) NOT NULL DEFAULT 'SET';

-- Optional link from an invoice line item back to the Material Master record.
-- NULL means the item was entered free-text; populated means it can be recalculated.
ALTER TABLE gst_invoice_items
    ADD COLUMN material_id BIGINT REFERENCES materials(id);

-- Audit trail for the explicit Recalculate GST action (reuses the same
-- createdByName/updatedByName pattern already on the Trip entity).
ALTER TABLE gst_invoices
    ADD COLUMN gst_recalculated_by  VARCHAR(100),
    ADD COLUMN gst_recalculated_at  TIMESTAMP,
    ADD COLUMN gst_prev_sgst_rate   NUMERIC(5,2),
    ADD COLUMN gst_prev_cgst_rate   NUMERIC(5,2);
