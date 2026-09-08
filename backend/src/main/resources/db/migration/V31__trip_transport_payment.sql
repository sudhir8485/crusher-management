-- V31: Trip transport credit to vendor vehicle owner (mirrors diesel_usages.diesel_payment_id)
--
-- When a trip uses a VENDOR-owned vehicle and transportation_charge > 0,
-- a VendorPayment (mode=TRANSPORT_CREDIT) is auto-created for the vehicle owner
-- so their account reflects what DSP owes them for the haul.
-- Deactivating the trip cascades to deactivate this payment.

ALTER TABLE trips ADD COLUMN transport_payment_id BIGINT REFERENCES vendor_payments(id);
