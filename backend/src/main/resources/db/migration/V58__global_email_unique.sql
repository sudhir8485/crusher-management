-- V58: Global email uniqueness across all tenants
--
-- Previously: UNIQUE (tenant_id, email) — allowed the same email in different tenants.
-- Now:        UNIQUE (email)            — one email, one account, anywhere in the system.
--
-- Login has no way to tell which tenant a duplicate email belongs to, so duplicates
-- are a real security/usability bug. Application code now also checks before insert/update
-- and returns a business-language error; this DB constraint is the safety net.
--
-- PREREQUISITE: Run this check and resolve any rows before applying:
--   SELECT email, array_agg(tenant_id) FROM users GROUP BY email HAVING COUNT(*) > 1;

-- Drop the SUPER_ADMIN-only partial index (superseded by the global constraint below)
DROP INDEX IF EXISTS users_platform_email_unique;

-- Drop the old per-tenant unique constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_tenant_id_email_key;

-- Add global unique constraint: one email, one account, across every tenant
ALTER TABLE users ADD CONSTRAINT users_email_global_unique UNIQUE (email);
