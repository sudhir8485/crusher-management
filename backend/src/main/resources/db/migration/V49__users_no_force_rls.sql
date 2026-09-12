-- V49: Remove FORCE ROW LEVEL SECURITY from the users table.
--
-- The users table cannot use FORCE RLS because the login endpoint has no
-- JWT/tenant context yet, so findByEmailNative() would return nothing and
-- all logins would fail. Tenant isolation for users is enforced at the
-- application layer (UserService uses explicit WHERE tenant_id = ? filters).
-- All other tenant-scoped data tables keep FORCE RLS from V48.
ALTER TABLE users NO FORCE ROW LEVEL SECURITY;
