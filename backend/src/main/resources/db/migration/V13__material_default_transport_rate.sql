-- Add default transport rate to materials for auto-filling trip transport rate
ALTER TABLE materials ADD COLUMN default_transport_rate NUMERIC(10,2);
