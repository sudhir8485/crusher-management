-- V47: SUPER_ADMIN — platform-level role above all tenants

-- Allow tenant_id to be NULL for SUPER_ADMIN users (no tenant scope)
ALTER TABLE users ALTER COLUMN tenant_id DROP NOT NULL;

-- Prevent duplicate SUPER_ADMIN emails (NULL tenant_id rows)
CREATE UNIQUE INDEX users_platform_email_unique ON users(email) WHERE tenant_id IS NULL;

-- Seed: Platform Admin (SUPER_ADMIN)
-- Password: superadmin123 (BCrypt strength 12)
INSERT INTO users (tenant_id, email, password_hash, full_name, role, status)
VALUES (NULL,
        'superadmin@platform.com',
        '$2a$12$cSVqaG7g94xOD9RDLSvDXuhffx1ivHSZCGKvzpixicUdgQIwlIuEO',
        'Platform Admin',
        'SUPER_ADMIN',
        'ACTIVE');
