-- Link vendor payments to specific invoices (nullable — payments can be standalone)
ALTER TABLE vendor_payments
    ADD COLUMN invoice_id BIGINT REFERENCES gst_invoices(id) ON DELETE SET NULL;

CREATE INDEX idx_vendor_payments_invoice_id ON vendor_payments(invoice_id);
