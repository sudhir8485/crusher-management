-- V56: Fix DIESEL_CREDIT direction — DSP giving diesel to a party reduces the party's
--      advance/credit (payable), so it must be PAID direction (debit), not RECEIVED.
UPDATE vendor_payments
SET direction = 'PAID'
WHERE payment_mode = 'DIESEL_CREDIT'
  AND status = 'ACTIVE';
