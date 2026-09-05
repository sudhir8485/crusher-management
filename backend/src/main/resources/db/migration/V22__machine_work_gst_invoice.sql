-- V22: Machine Work → GST Invoice linkage
-- When a Customer Billable machine work entry's rate is set for a GST-registered party,
-- a GST Invoice is auto-created. This column tracks the link so the ledger does not
-- double-count the entry (the GST invoice takes over from the flat MachineWork debit).

ALTER TABLE machine_work_logs
    ADD COLUMN gst_invoice_id BIGINT REFERENCES gst_invoices(id);
