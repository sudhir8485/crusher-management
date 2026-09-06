-- Track which trips/dabar entries have been consumed by a Job-Work invoice line.
-- Unique constraint: a trip (or dabar entry) can only be billed once per service.
-- On invoice delete: rows are removed, releasing the records back to "available".

CREATE TABLE trip_jw_billing (
    id                  BIGSERIAL PRIMARY KEY,
    trip_id             BIGINT NOT NULL REFERENCES trips(id),
    service_id          BIGINT NOT NULL REFERENCES services(id),
    job_work_invoice_id BIGINT NOT NULL REFERENCES job_work_invoices(id),
    CONSTRAINT uq_trip_service_billing UNIQUE (trip_id, service_id)
);

CREATE TABLE dabar_jw_billing (
    id                  BIGSERIAL PRIMARY KEY,
    dabar_entry_id      BIGINT NOT NULL REFERENCES dabar_entries(id),
    service_id          BIGINT NOT NULL REFERENCES services(id),
    job_work_invoice_id BIGINT NOT NULL REFERENCES job_work_invoices(id),
    CONSTRAINT uq_dabar_service_billing UNIQUE (dabar_entry_id, service_id)
);
