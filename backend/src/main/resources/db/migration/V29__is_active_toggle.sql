-- V29: is_active toggle on Vehicle, Machine, Vendor
-- is_active = false → hidden from pickers and default lists (reversible)
-- status = 'INACTIVE' → permanently soft-deleted (irreversible)

ALTER TABLE vehicles ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE machines ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE vendors  ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
