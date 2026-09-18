-- V55: Per-tenant invoice prefix and terms & conditions
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS invoice_prefix VARCHAR(20) DEFAULT 'INV';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS invoice_terms  TEXT;

-- Preserve existing DSP invoice numbering by setting their prefix to 'DSP'
UPDATE tenants SET invoice_prefix = 'DSP' WHERE id = 1;
