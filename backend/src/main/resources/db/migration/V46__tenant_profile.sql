-- V46: extend tenants table with full business profile fields
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS phone   VARCHAR(50);
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS email   VARCHAR(200);
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS logo_base64 TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS updated_at  TIMESTAMP;
