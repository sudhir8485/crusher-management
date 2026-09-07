-- Diesel: Party Advance receipts and external-vehicle diesel payables
--
-- advance_party_id / advance_payment_id: used when source='PARTY_ADVANCE'.
--   The associated VendorPayment credit is stored via advance_payment_id so
--   that deactivating the receipt can cascade the credit deactivation.
--
-- rate_per_liter on diesel_usages: required to compute the ₹ value of diesel
--   given to external (VENDOR-owned) vehicles, enabling an automatic credit
--   entry in the owning party's ledger (diesel_payment_id points to it).

ALTER TABLE diesel_receipts
    ADD COLUMN advance_party_id   BIGINT REFERENCES vendors(id),
    ADD COLUMN advance_payment_id BIGINT REFERENCES vendor_payments(id);

ALTER TABLE diesel_usages
    ADD COLUMN rate_per_liter    DECIMAL(10,2),
    ADD COLUMN diesel_payment_id BIGINT REFERENCES vendor_payments(id);
