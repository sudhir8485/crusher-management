-- V32: Machine Work hire credit to vendor vehicle owner (mirrors V31 for trips)
--
-- When CUSTOMER_BILLABLE machine work's rate is SET and the machine is linked to a
-- VENDOR-owned vehicle, a VendorPayment (mode=TRANSPORT_CREDIT) is auto-created for
-- the vehicle owner so their account shows what DSP owes them for the machine hire.

ALTER TABLE machine_work_logs ADD COLUMN transport_payment_id BIGINT REFERENCES vendor_payments(id);
