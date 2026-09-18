-- V57: Per-item GST rate on invoice line items.
-- Replaces the previous PENDING/SET machinery driven by gstRateConfigured booleans.
-- null = PENDING (rate not yet entered); non-null (including 0) = resolved.

ALTER TABLE gst_invoice_items
    ADD COLUMN gst_rate DECIMAL(5,2);

ALTER TABLE job_work_invoice_items
    ADD COLUMN gst_rate DECIMAL(5,2);

-- Backfill SET invoices: combined rate = cgst_rate + sgst_rate stored on parent invoice.
UPDATE gst_invoice_items gii
SET gst_rate = (
    SELECT (i.cgst_rate + i.sgst_rate)
    FROM gst_invoices i
    WHERE i.id = gii.invoice_id
      AND i.gst_status = 'SET'
)
WHERE EXISTS (
    SELECT 1 FROM gst_invoices i
    WHERE i.id = gii.invoice_id
      AND i.gst_status = 'SET'
);

UPDATE job_work_invoice_items jwii
SET gst_rate = (
    SELECT (i.cgst_rate + i.sgst_rate)
    FROM job_work_invoices i
    WHERE i.id = jwii.invoice_id
      AND i.gst_status = 'SET'
)
WHERE EXISTS (
    SELECT 1 FROM job_work_invoices i
    WHERE i.id = jwii.invoice_id
      AND i.gst_status = 'SET'
);
-- PENDING invoices: gst_rate remains NULL (already the default for the new column).
