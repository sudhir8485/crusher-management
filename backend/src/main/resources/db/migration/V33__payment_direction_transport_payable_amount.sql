-- Payment direction: RECEIVED (party pays DSP, or system credits like TRANSPORT_CREDIT)
--                   PAID     (DSP pays out cash to party to settle a payable)
ALTER TABLE vendor_payments
    ADD COLUMN direction VARCHAR(20) NOT NULL DEFAULT 'RECEIVED';

-- Link a PAID payment to the specific transport_payable it settles (optional)
ALTER TABLE vendor_payments
    ADD COLUMN transport_payable_id BIGINT REFERENCES transport_payables(id);

-- Transport payable now carries an amount once the rate is agreed
ALTER TABLE transport_payables
    ADD COLUMN amount DECIMAL(15,2);

-- Once settled by a PAID vendor_payment, mark it closed
ALTER TABLE transport_payables
    ADD COLUMN settled BOOLEAN NOT NULL DEFAULT FALSE;
