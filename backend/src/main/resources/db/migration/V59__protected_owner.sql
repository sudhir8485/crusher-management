-- V59: Protect the founding owner account from deactivation
--
-- Problem: an OWNER_ADMIN could deactivate every user in their tenant, including
-- themselves. Login rejects any INACTIVE user (even with a correct password), and
-- superadmin can only reset the owner's password — not their status. The result is
-- a permanent lockout with the tenant's data stranded and no recovery path.
--
-- Fix: mark each tenant's founding owner (the OWNER_ADMIN created by superadmin
-- during tenant provisioning) as protected. Protected owners can never be
-- deactivated, guaranteeing at least one active owner always remains.

ALTER TABLE users ADD COLUMN protected_owner BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: mark the earliest OWNER_ADMIN per tenant as the protected founding owner.
UPDATE users SET protected_owner = TRUE
WHERE id IN (
    SELECT MIN(id) FROM users
    WHERE role = 'OWNER_ADMIN'
    GROUP BY tenant_id
);
