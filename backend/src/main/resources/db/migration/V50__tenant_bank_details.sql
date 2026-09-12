-- Bank details on tenant profile — used on printed invoices
ALTER TABLE tenants
    ADD COLUMN IF NOT EXISTS bank_name        VARCHAR(200),
    ADD COLUMN IF NOT EXISTS bank_account_no  VARCHAR(50),
    ADD COLUMN IF NOT EXISTS bank_ifsc        VARCHAR(20);
