-- GST support: material GST rate + HSN code, vendor GST registration flag,
-- trip GST rate snapshot (so old invoices are never affected by rate changes).

ALTER TABLE materials
    ADD COLUMN gst_rate  NUMERIC(5,2) DEFAULT 0 NOT NULL,
    ADD COLUMN hsn_code  VARCHAR(20);

ALTER TABLE vendors
    ADD COLUMN gst_registered BOOLEAN DEFAULT FALSE NOT NULL;

-- Trip stores the material's GST rate at creation time (snapshot).
-- Changing a material's rate after a trip is saved must not alter old invoices.
ALTER TABLE trips
    ADD COLUMN gst_rate NUMERIC(5,2) DEFAULT 0 NOT NULL;
