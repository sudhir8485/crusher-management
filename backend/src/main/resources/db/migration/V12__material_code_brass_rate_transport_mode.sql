-- V12: Material code + separate BRASS rate, Trip transport mode

-- materials: optional material code, separate brass default rate
ALTER TABLE materials
    ADD COLUMN code                  VARCHAR(50),
    ADD COLUMN default_sale_rate_brass NUMERIC(10,2);

-- trips: transport mode — CALCULATE (dist×rate) or DIRECT (manually entered total)
ALTER TABLE trips
    ADD COLUMN transport_mode VARCHAR(20) NOT NULL DEFAULT 'CALCULATE';
