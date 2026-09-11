# Schema.md — Database Schema Reference

Generated from actual migration files V1–V34. Tables grouped by module to match Rules.md.

---

## Legend

- **PK** = Primary key
- **FK** = Foreign key
- **RLS** = Row-Level Security (PostgreSQL) enabled — all tenant-scoped tables use `current_setting('app.tenant_id')` for isolation
- `[Vn]` = migration version that introduced or changed the column
- ~~strikethrough~~ = superseded column (still exists in DB, no longer written to by new code)

---

## Master Data

### `tenants`
Top-level business accounts. DSP Construction is tenant #1.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | BIGSERIAL | PK | |
| `name` | VARCHAR(200) | NOT NULL | |
| `gstin` | VARCHAR(20) | nullable | |
| `address` | TEXT | nullable | |
| `status` | VARCHAR(20) | NOT NULL DEFAULT 'ACTIVE' | |
| `created_at` | TIMESTAMP | NOT NULL DEFAULT NOW() | |

No RLS (top-level reference table).

---

### `users`
Authentication and role-based access.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `email` | VARCHAR(200) | UNIQUE per tenant |
| `password_hash` | VARCHAR(255) | BCrypt |
| `full_name` | VARCHAR(200) | |
| `role` | VARCHAR(30) | `OWNER_ADMIN` \| `OFFICE_ACCOUNTANT` \| `SITE_STAFF` |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `site_id` | FK → sites | [V10] nullable; SITE_STAFF locked to one site |

RLS: `tenant_isolation_users`.

---

### `vendors` (UI name: "Party")
All external parties — contractors, customers, vehicle/machine owners.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `name` | VARCHAR(200) | |
| `gstin` | VARCHAR(20) | nullable |
| `contact` | VARCHAR(100) | nullable |
| `address` | TEXT | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `gst_registered` | BOOLEAN | [V17] DEFAULT FALSE; drives auto-invoice logic |
| `is_regular` | BOOLEAN | [V18] FALSE = occasional customer; TRUE = regular party |
| `is_active` | BOOLEAN | [V29] DEFAULT TRUE; soft visibility toggle (reversible) |

RLS: `tenant_isolation_vendors`.

**Note (V18 — Unified Party Model):** One-time trip customers were migrated to real vendor records with `is_regular=FALSE`. Old snapshot columns `one_time_customer_*` on `trips` remain as audit trail but are no longer written by new code.

---

### `sites`
Physical locations (crusher sites, client sites).

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `name` | VARCHAR(200) | |
| `location` | TEXT | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `site_type` | VARCHAR(20) | [V21] `OWN` \| `CLIENT_SITE`; default 'OWN' |
| `linked_party_id` | FK → vendors | [V21] nullable; party that owns a CLIENT_SITE |

RLS: `tenant_isolation_sites`.

---

### `vehicles`
Transportation fleet.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `owner` | VARCHAR(10) | `TENANT` \| `VENDOR` |
| `vendor_id` | FK → vendors | nullable; set when owner=VENDOR |
| `plate_number` | VARCHAR(20) | |
| `display_name` | VARCHAR(100) | short display label |
| `vehicle_type` | VARCHAR(100) | Dumper, Tanker, Truck, etc. |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `linked_machine_id` | FK → machines | [V28] nullable; soft bidirectional pairing |
| `is_active` | BOOLEAN | [V29] DEFAULT TRUE |

RLS: `tenant_isolation_vehicles`.

---

### `machines`
Equipment and plant (JCB, crushers, generators).

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `owner` | VARCHAR(10) | `TENANT` \| `VENDOR` |
| `vendor_id` | FK → vendors | nullable |
| `name` | VARCHAR(100) | e.g. "JCB 205 Machine" |
| `machine_type` | VARCHAR(100) | JCB, Comosko, Generator, etc. |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `linked_vehicle_id` | FK → vehicles | [V28] nullable; soft bidirectional pairing |
| `is_active` | BOOLEAN | [V29] DEFAULT TRUE |

RLS: `tenant_isolation_machines`.

---

### `machine_work_types`
Per-machine work mode catalog (replaces hardcoded BUCKET/BREAKER enum). [V28]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `machine_id` | FK → machines | each machine has its own types |
| `label` | VARCHAR(100) | "Bucket", "Breaker", custom |
| `default_rate` | NUMERIC(12,2) | nullable; ₹/hr for billable work |
| `default_gst_rate` | NUMERIC(5,2) | nullable |
| `sac_code` | VARCHAR(20) | nullable |
| `display_order` | INT | DEFAULT 0 |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |

RLS: `tenant_isolation_machine_work_types`. Auto-seeded from existing BUCKET/BREAKER logs during V28 migration.

---

### `materials`
Product catalog (stone sizes, aggregate, dabar).

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `name` | VARCHAR(100) | "20 MM", "GSB", "Dabar", etc. |
| `size_label` | VARCHAR(50) | nullable |
| `unit` | VARCHAR(10) | DEFAULT 'BRASS'; also 'TON' |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `default_sale_rate` | NUMERIC(10,2) | [V11] nullable |
| `kg_per_brass` | NUMERIC(10,3) | [V11] nullable; conversion factor |
| `code` | VARCHAR(50) | [V12] nullable |
| `default_sale_rate_brass` | NUMERIC(10,2) | [V12] nullable; separate rate for brass unit |
| `default_transport_rate` | NUMERIC(10,2) | [V13] nullable; auto-fills trip transport rate |
| `gst_rate` | NUMERIC(5,2) | [V17] DEFAULT 0 |
| `hsn_code` | VARCHAR(20) | [V17] nullable |
| `gst_rate_configured` | BOOLEAN | [V19] DEFAULT FALSE; distinguishes "not set" from "deliberately 0%" |

RLS: `tenant_isolation_materials`.

---

### `services`
Job-work service master (crushing fees, dabar loading, transport). [V21]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `name` | VARCHAR(200) | |
| `code` | VARCHAR(50) | nullable |
| `default_unit` | VARCHAR(20) | DEFAULT 'TON' |
| `default_rate` | NUMERIC(12,2) | nullable; NULL = unconfigured |
| `gst_rate` | NUMERIC(5,2) | DEFAULT 0 |
| `gst_rate_configured` | BOOLEAN | DEFAULT FALSE |
| `sac_code` | VARCHAR(20) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `auto_calc_source` | VARCHAR(30) | [V24] `NONE` \| `TRIP_QUANTITIES` \| `DABAR_QUANTITIES`; drives JW invoice auto-qty |

RLS: `tenant_isolation_services`.

---

## Trip Module

### `trips`
Core operational record: transportation jobs.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `site_id` | FK → sites | [V10] NOT NULL |
| `trip_date` | DATE | NOT NULL |
| `loading_location` | VARCHAR(300) | nullable |
| `unloading_location` | VARCHAR(300) | nullable |
| `channel_no` | VARCHAR(50) | nullable |
| `material_id` | FK → materials | nullable |
| ~~`quantity_brass`~~ | NUMERIC(10,3) | [V2] superseded by `billable_quantity` + `quantity_unit` |
| ~~`loaded_weight_ton`~~ | NUMERIC(10,3) | [V2] superseded by `_kg` variants |
| ~~`empty_weight_ton`~~ | NUMERIC(10,3) | [V2] superseded by `_kg` variants |
| `vehicle_id` | FK → vehicles | nullable |
| `vendor_id` | FK → vendors | nullable |
| `dsp_challan_no` | VARCHAR(50) | nullable |
| `vendor_challan_no` | VARCHAR(50) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `party_type` | VARCHAR(20) | [V11] `REGULAR` (default); historical, always REGULAR post-V18 |
| ~~`one_time_customer_name`~~ | VARCHAR(200) | [V11] legacy audit; no longer written post-V18 |
| ~~`one_time_customer_phone`~~ | VARCHAR(50) | [V11] legacy audit |
| ~~`one_time_customer_addr`~~ | TEXT | [V11] legacy audit |
| `vehicle_mode` | VARCHAR(20) | [V11] `COMPANY` \| `OWN_VEHICLE` |
| `loaded_weight_kg` | NUMERIC(12,2) | [V11] nullable |
| `empty_weight_kg` | NUMERIC(12,2) | [V11] nullable |
| `net_weight_kg` | NUMERIC(12,2) | [V11] nullable |
| `quantity_unit` | VARCHAR(10) | [V11] `BRASS` \| `TON` |
| `billable_quantity` | NUMERIC(12,3) | [V11] current quantity field |
| `sale_rate` | NUMERIC(10,2) | [V11] nullable |
| `material_amount` | NUMERIC(14,2) | [V11] nullable |
| `distance_km` | NUMERIC(8,2) | [V11] nullable |
| `transport_rate_per_km` | NUMERIC(10,2) | [V11] nullable |
| `transportation_charge` | NUMERIC(14,2) | [V11] NOT NULL DEFAULT 0 |
| `total_bill` | NUMERIC(14,2) | [V11] nullable |
| `notes` | TEXT | [V11] nullable |
| `transport_mode` | VARCHAR(20) | [V12] `CALCULATE` \| `DIRECT`; controls transport charge method |
| `created_by_name` | VARCHAR(200) | [V14] audit — set at creation, never changes |
| `updated_by_name` | VARCHAR(200) | [V14] audit — updated on every edit [name fix: V16] |
| `gst_rate` | NUMERIC(5,2) | [V17] snapshot at creation; DEFAULT 0 |
| `material_suppressed` | BOOLEAN | [V24] DEFAULT FALSE; zeroes material amount for CLIENT_SITE owner billing |
| `gst_invoice_id` | FK → gst_invoices | [V30] nullable; auto-created GST invoice |
| `auto_invoiced` | BOOLEAN | [V30] DEFAULT FALSE; TRUE = trip is on auto-invoice, not direct ledger debit |
| `transport_payment_id` | FK → vendor_payments | [V31] nullable; vendor vehicle owner credit |

RLS: `tenant_isolation_trips`. Indexes: `idx_trips_gst_invoice_id`.

---

## Dabar Module

### `dabar_entries`
Raw stone intake / dabar haul logs. [V3]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `site_id` | FK → sites | [V10] NOT NULL |
| `entry_date` | DATE | NOT NULL |
| `vehicle_id` | FK → vehicles | nullable |
| `vendor_id` | FK → vendors | nullable |
| `trips_count` | INT | nullable |
| `quantity_brass` | NUMERIC(10,3) | nullable |
| `notes` | VARCHAR(500) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `created_by_name` | VARCHAR(200) | [V34] |
| `updated_by_name` | VARCHAR(200) | [V34] |

RLS: `tenant_isolation_dabar`.

---

## Diesel Module

### `diesel_receipts`
Diesel fuel purchase records. [V4]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `site_id` | FK → sites | [V10] NOT NULL |
| `receipt_date` | DATE | NOT NULL |
| `source` | VARCHAR(20) | `PUMP` \| `DIRECT` \| `PARTY_ADVANCE` |
| `quantity_liters` | NUMERIC(10,2) | NOT NULL |
| `rate_per_liter` | NUMERIC(10,2) | nullable |
| `amount` | NUMERIC(12,2) | nullable; = qty × rate |
| `vendor_id` | FK → vendors | nullable |
| `invoice_no` | VARCHAR(50) | nullable |
| `notes` | VARCHAR(500) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `advance_party_id` | FK → vendors | [V27] nullable; party that provided advance diesel |
| `advance_payment_id` | FK → vendor_payments | [V27] nullable; credit record; deactivated if receipt deactivated |
| `created_by_name` | VARCHAR(200) | [V34] |
| `updated_by_name` | VARCHAR(200) | [V34] |

RLS: `tenant_isolation_diesel_receipts`.

---

### `diesel_usages`
Diesel consumption records (per machine or vehicle). [V4]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `site_id` | FK → sites | [V10] NOT NULL |
| `usage_date` | DATE | NOT NULL |
| `machine_id` | FK → machines | nullable |
| `vehicle_id` | FK → vehicles | nullable |
| `quantity_liters` | NUMERIC(10,2) | NOT NULL |
| `notes` | VARCHAR(500) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `rate_per_liter` | DECIMAL(10,2) | [V27] nullable; for computing value when giving diesel to external vehicle |
| `diesel_payment_id` | FK → vendor_payments | [V27] nullable; auto-created DIESEL_CREDIT for vendor vehicle owner |
| `created_by_name` | VARCHAR(200) | [V34] |
| `updated_by_name` | VARCHAR(200) | [V34] |

RLS: `tenant_isolation_diesel_usages`.

---

## Machine Work Module

### `machine_work_logs`
Machine utilization records. [V5]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `site_id` | FK → sites | [V10] NOT NULL |
| `log_date` | DATE | NOT NULL |
| `machine_id` | FK → machines | NOT NULL |
| `work_description` | VARCHAR(500) | nullable |
| ~~`mode`~~ | VARCHAR(20) | [V5] `BUCKET` \| `BREAKER`; superseded by `work_type_id` (V28), column retained |
| `opening_reading` | NUMERIC(10,2) | nullable |
| `closing_reading` | NUMERIC(10,2) | nullable |
| `total_hours` | NUMERIC(8,2) | nullable; = closing − opening |
| `notes` | VARCHAR(500) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `work_purpose` | VARCHAR(20) | [V20] `INTERNAL` \| `CUSTOMER_BILLABLE` |
| `customer_id` | FK → vendors | [V20] nullable; who is being billed |
| `rate` | NUMERIC(12,2) | [V20] nullable; ₹/hr |
| `rate_status` | VARCHAR(20) | [V20] `PENDING` \| `SET`; null for INTERNAL |
| `total_amount` | NUMERIC(14,2) | [V20] nullable; total_hours × rate |
| `rate_set_by` | VARCHAR(200) | [V20] audit: who locked the rate |
| `rate_set_at` | TIMESTAMP | [V20] audit: when rate was locked |
| `rate_prev` | NUMERIC(12,2) | [V20] audit: previous rate value |
| `gst_invoice_id` | FK → gst_invoices | [V22] nullable; auto-created invoice for GST-registered customer |
| `work_type_id` | FK → machine_work_types | [V28] nullable; replaces hardcoded mode enum |
| `transport_payment_id` | FK → vendor_payments | [V32] nullable; vendor machine hire credit |
| `created_by_name` | VARCHAR(200) | [V34] |
| `updated_by_name` | VARCHAR(200) | [V34] |

RLS: `tenant_isolation_machine_work_logs`.

---

## Invoices Module

### `gst_invoices`
GST tax invoices raised against vendors/customers. [V6]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `vendor_id` | FK → vendors | NOT NULL |
| `invoice_no` | VARCHAR(50) | NOT NULL; auto-generated sequence |
| `invoice_date` | DATE | NOT NULL |
| `supply_date` | DATE | nullable |
| `po_no` | VARCHAR(50) | nullable |
| `cgst_rate` | NUMERIC(5,2) | NOT NULL DEFAULT 9.00 |
| `sgst_rate` | NUMERIC(5,2) | NOT NULL DEFAULT 9.00 |
| `subtotal` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `cgst_amount` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `sgst_amount` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `grand_total` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `notes` | TEXT | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `gst_status` | VARCHAR(10) | [V19] `PENDING` (rate unset at creation) \| `SET` (locked) |
| `gst_recalculated_by` | VARCHAR(200) | [V19] audit |
| `gst_recalculated_at` | TIMESTAMP | [V19] audit |
| `gst_prev_sgst_rate` | NUMERIC(5,2) | [V19] audit: rate before recalculation |
| `gst_prev_cgst_rate` | NUMERIC(5,2) | [V19] audit |
| `created_by_name` | VARCHAR(200) | [V34] |
| `updated_by_name` | VARCHAR(200) | [V34] |

RLS: `tenant_isolation_gst_invoices`.

---

### `gst_invoice_items`
Line items within a GST invoice. [V6]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `invoice_id` | FK → gst_invoices ON DELETE CASCADE | NOT NULL |
| `description` | VARCHAR(300) | NOT NULL |
| `hsn` | VARCHAR(20) | nullable |
| `quantity_brass` | NUMERIC(12,3) | nullable |
| `rate` | NUMERIC(10,2) | nullable |
| `amount` | NUMERIC(14,2) | NOT NULL |
| `material_id` | FK → materials | [V19] nullable; for GST recalculation |
| `service_id` | FK → services | [V23] nullable; for service-type line items |

No separate RLS (protected via CASCADE from parent).

---

### `job_work_invoices`
Service-based invoices (job-work / crushing fees). [V21]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `vendor_id` | FK → vendors | NOT NULL; auto-derived from site.linked_party_id |
| `site_id` | FK → sites | NOT NULL |
| `invoice_no` | VARCHAR(50) | NOT NULL |
| `invoice_date` | DATE | NOT NULL |
| `period_from` | DATE | [V24] nullable; billing period start |
| `period_to` | DATE | [V24] nullable; billing period end |
| `cgst_rate` | NUMERIC(5,2) | NOT NULL DEFAULT 0 |
| `sgst_rate` | NUMERIC(5,2) | NOT NULL DEFAULT 0 |
| `subtotal` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `cgst_amount` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `sgst_amount` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `grand_total` | NUMERIC(14,2) | NOT NULL DEFAULT 0 |
| `notes` | TEXT | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `gst_status` | VARCHAR(20) | `PENDING` \| `SET` |
| `gst_recalculated_by` | VARCHAR(200) | nullable |
| `gst_recalculated_at` | TIMESTAMP | nullable |
| `gst_prev_sgst_rate` | NUMERIC(5,2) | nullable |
| `gst_prev_cgst_rate` | NUMERIC(5,2) | nullable |
| `created_at` | TIMESTAMP | |
| `created_by_name` | VARCHAR(200) | [V34] |
| `updated_by_name` | VARCHAR(200) | [V34] |

RLS: `tenant_isolation_job_work_invoices`.

---

### `job_work_invoice_items`
Line items within a job-work invoice. [V21]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `invoice_id` | FK → job_work_invoices ON DELETE CASCADE | NOT NULL |
| `service_id` | FK → services | nullable |
| `description` | VARCHAR(300) | NOT NULL |
| `sac_code` | VARCHAR(20) | nullable |
| `quantity` | NUMERIC(12,3) | nullable |
| `rate` | NUMERIC(10,2) | nullable |
| `amount` | NUMERIC(14,2) | NOT NULL |

No separate RLS (protected via CASCADE).

---

## Payments Module

### `vendor_payments`
All payment records — received from parties, paid to parties, auto-credits. [V6]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `vendor_id` | FK → vendors | NOT NULL |
| `payment_date` | DATE | NOT NULL |
| `amount` | NUMERIC(14,2) | NOT NULL |
| `payment_mode` | VARCHAR(20) | `CASH` \| `BANK` \| `CHEQUE` \| `UPI` \| `DIESEL_ADVANCE` \| `DIESEL_CREDIT` \| `TRANSPORT_CREDIT` |
| `reference_no` | VARCHAR(100) | nullable |
| `notes` | VARCHAR(500) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `invoice_id` | FK → gst_invoices ON DELETE SET NULL | [V9] nullable |
| `allocation_summary` | TEXT | [V15] FIFO allocation breakdown (human-readable) |
| `direction` | VARCHAR(20) | [V33] `RECEIVED` (party pays DSP) \| `PAID` (DSP pays party) |
| `transport_payable_id` | FK → transport_payables | [V33] nullable; links PAID payment to the payable it settles |
| `created_by_name` | VARCHAR(200) | [V34] |
| `updated_by_name` | VARCHAR(200) | [V34] |

RLS: `tenant_isolation_vendor_payments`. Index: `idx_vendor_payments_invoice_id`.

API endpoint: `/api/party-payments` (controller maps to this URL, not `/api/vendor-payments`).

---

## Payables Module

### `transport_payables`
Tracks transport amounts owed to external vehicle/machine owners. [V26]

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | BIGINT NOT NULL | (no FK constraint; enforced via RLS) |
| `site_id` | BIGINT NOT NULL | |
| `entry_date` | DATE | NOT NULL |
| `source_type` | VARCHAR(30) | `DABAR` \| `MACHINE_WORK`; discriminator for polymorphic source |
| `source_entry_id` | BIGINT | NOT NULL; references `dabar_entries.id` or `machine_work_logs.id` |
| `vehicle_id` | BIGINT | nullable |
| `party_id` | FK → vendors | NOT NULL; who is owed |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |
| `amount` | DECIMAL(15,2) | [V33] nullable; agreed transport amount |
| `settled` | BOOLEAN | [V33] DEFAULT FALSE; set to TRUE when paid via vendor_payment |

RLS: `transport_payables_tenant`.

**Design note:** Generic `source_type` discriminator avoids separate tables for each payable type.

---

## Billing Link Tables (Junction)

### `trip_jw_billing` [V25]
Prevents double-billing: tracks which trips are consumed by JW invoice lines.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `trip_id` | FK → trips | NOT NULL; UNIQUE per service_id |
| `service_id` | FK → services | NOT NULL |
| `job_work_invoice_id` | FK → job_work_invoices | NOT NULL |

Constraint: UNIQUE(trip_id, service_id).

---

### `dabar_jw_billing` [V25]
Same pattern as `trip_jw_billing`, for dabar entries.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `dabar_entry_id` | FK → dabar_entries | NOT NULL; UNIQUE per service_id |
| `service_id` | FK → services | NOT NULL |
| `job_work_invoice_id` | FK → job_work_invoices | NOT NULL |

Constraint: UNIQUE(dabar_entry_id, service_id).

---

## Attendance Module

### `employees` [V7]
Site workforce.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `name` | VARCHAR(200) | NOT NULL |
| `designation` | VARCHAR(100) | nullable |
| `wage_type` | VARCHAR(20) | `DAILY` \| `MONTHLY` |
| `wage_rate` | NUMERIC(10,2) | nullable |
| `status` | VARCHAR(20) | DEFAULT 'ACTIVE' |
| `created_at` | TIMESTAMP | |

RLS: `tenant_isolation_employees`.

---

### `attendance_records` [V7]
Daily attendance per employee.

| Column | Type | Notes |
|--------|------|-------|
| `id` | BIGSERIAL PK | |
| `tenant_id` | FK → tenants | |
| `site_id` | FK → sites | [V10] NOT NULL |
| `attendance_date` | DATE | NOT NULL |
| `employee_id` | FK → employees | NOT NULL |
| `status` | VARCHAR(20) | `PRESENT` \| `ABSENT` \| `HALF_DAY` \| `LEAVE` |
| `marked_by` | VARCHAR(200) | nullable |
| `notes` | VARCHAR(300) | nullable |
| `created_at` | TIMESTAMP | |

UNIQUE(tenant_id, attendance_date, employee_id). RLS: `tenant_isolation_attendance_records`.

---

## Dead / Unused Tables

### `water_tanker_logs` [V3] — ⚠️ DEAD TABLE
Created in V3 for water tanker utilization tracking (hours, km, trips, rate). Has a site_id added in V10. **No corresponding Java entity, repository, service, or controller exists in the current backend.** No UI screen exists for it either. This table exists in the database schema but is completely unused by the application. Candidate for DROP in a future cleanup migration.

### `vehicle_daily_logs` [V8] — ⚠️ DEAD TABLE
Created in V8 for vehicle daily utilization (odometer, trips day/night, diesel notes). Same situation: **no Java entity, repository, service, controller, or UI screen**. Exists only in the DB schema. Candidate for DROP.

---

## Superseded Columns (Still in DB)

| Table | Column(s) | Superseded By | Version |
|-------|-----------|---------------|---------|
| `trips` | `quantity_brass` | `billable_quantity` + `quantity_unit` | V11 |
| `trips` | `loaded_weight_ton`, `empty_weight_ton` | `loaded_weight_kg`, `empty_weight_kg`, `net_weight_kg` | V11 |
| `trips` | `one_time_customer_name/phone/addr` | `vendor_id` on vendor record with `is_regular=FALSE` | V18 |
| `machine_work_logs` | `mode` (BUCKET/BREAKER) | `work_type_id` → `machine_work_types` | V28 |

---

## Audit Fields Summary

| Table | `created_at` | `created_by_name` | `updated_by_name` |
|-------|:---:|:---:|:---:|
| trips | V2 ✓ | V14 ✓ | V14 ✓ |
| dabar_entries | V3 ✓ | V34 ✓ | V34 ✓ |
| diesel_receipts | V4 ✓ | V34 ✓ | V34 ✓ |
| diesel_usages | V4 ✓ | V34 ✓ | V34 ✓ |
| machine_work_logs | V5 ✓ | V34 ✓ | V34 ✓ |
| gst_invoices | V6 ✓ | V34 ✓ | V34 ✓ |
| vendor_payments | V6 ✓ | V34 ✓ | V34 ✓ |
| job_work_invoices | V21 ✓ | V34 ✓ | V34 ✓ |
| employees | V7 ✓ | — | — |
| attendance_records | V7 ✓ | — | — |

Excluded by design: vendors, vehicles, machines, materials, services, sites (master data).
