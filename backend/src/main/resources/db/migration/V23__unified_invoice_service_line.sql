-- V23: Support service-type line items in gst_invoice_items.
--      Allows the unified Invoices module to mix Material and Service lines
--      on the same invoice without a separate job_work_invoices flow.
ALTER TABLE gst_invoice_items
    ADD COLUMN service_id BIGINT REFERENCES services(id);
