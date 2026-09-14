-- Rename tenant-specific column to a generic name
ALTER TABLE trips RENAME COLUMN dsp_challan_no TO challan_no;
