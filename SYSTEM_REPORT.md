# DSP Crusher Management — Full System Report

> Generated: 8 Sep 2026  
> Stack: Flutter + Spring Boot (Java 21) + PostgreSQL  
> Migrations: V1–V29 (Flyway)

---

## 1. Architecture Overview

| Layer | Technology |
|---|---|
| Frontend | Flutter, Riverpod (state), GoRouter (navigation) |
| Backend | Spring Boot, REST API, JWT auth |
| Database | PostgreSQL with Row-Level Security (RLS) |
| Multi-tenancy | Every table has `tenant_id`; PostgreSQL RLS enforces isolation via `app.tenant_id` session variable |
| Site scoping | Most operational data scoped to `site_id`; SITE_STAFF role locked to their assigned site |
| User roles | OWNER_ADMIN, OFFICE_ACCOUNTANT, SITE_STAFF |

---

## 2. All Database Tables (V1–V29)

| Table | Module | Added |
|---|---|---|
| tenants, users | Core | V1 |
| vendors | Parties | V1 |
| sites | Sites | V1 |
| vehicles | Vehicles | V1 |
| machines | Machines | V1 |
| materials | Materials | V1 |
| trips | Trips | V2 |
| dabar_entries | Dabar | V3 |
| water_tanker_logs | (removed from UI) | V3 |
| diesel_receipts, diesel_usages | Diesel | V4 |
| machine_work_logs | Machine Work | V5 |
| gst_invoices, gst_invoice_items | Invoices (GST) | V6 |
| vendor_payments | Payments | V6 |
| employees, attendance_records | HR | V7 |
| services, job_work_invoices, job_work_invoice_items | Invoices (JW) | V21 |
| trip_jw_billing, dabar_jw_billing | JW billing links | V25 |
| transport_payables | Transport Payable | V26 |
| machine_work_types | Machine Work Types | V28 |

---

## 3. Module Reference

---

### MODULE A — TRIPS

**What it is:** A dispatch / challan record. Records that material left the site in a vehicle for a party.

**Table:** `trips`

| Key Field | Meaning |
|---|---|
| `vendor_id` | The customer (party) receiving the material |
| `material_id` | What material (Stone 40mm, Gravel, etc.) |
| `vehicle_id` | Which vehicle carried it (null if OWN_VEHICLE) |
| `site_id` | Which crusher site dispatched it |
| `trip_date` | Date of dispatch |
| `quantity_unit` | BRASS or TON |
| `loaded_weight_kg / empty_weight_kg / net_weight_kg` | Weighbridge readings |
| `billable_quantity` | Computed: net_weight / kg_per_brass or /1000 |
| `sale_rate` | Rate per Brass/Ton agreed with party |
| `material_amount` | = billable_qty × sale_rate |
| `vehicle_mode` | COMPANY (registered vehicle) or OWN_VEHICLE (customer's ad-hoc vehicle) |
| `transport_mode` | CALCULATE (dist × qty × rate) or DIRECT (user-entered total) |
| `transportation_charge` | Computed or entered |
| `total_bill` | material_amount + transportation_charge |
| `gst_rate` | Snapshot of material's GST rate at time of creation (immutable) |
| `material_suppressed` | true = CLIENT_SITE owner's trip; material billed as ₹0 |
| `dsp_challan_no, vendor_challan_no` | Document reference numbers |

**Billing logic (computed at save):**
```
net_weight_kg = loaded_weight_kg − empty_weight_kg
billable_quantity = net_weight_kg / kg_per_brass   (if BRASS)
                  = net_weight_kg / 1000            (if TON)
material_amount = billable_quantity × sale_rate
transportation_charge:
  OWN_VEHICLE → 0
  COMPANY + CALCULATE → distance_km × billable_qty × transport_rate_per_km
  COMPANY + DIRECT → user-entered value
total_bill = material_amount + transportation_charge
```

**Material suppression (CLIENT_SITE rule):**  
If the trip's party (`vendor_id`) is the `linked_party_id` of the site, it means the client already owns the material. DSP only charges them for transport.  
→ `material_amount = 0`, `material_suppressed = true`, `total_bill = transportation_charge only`

**Does a trip affect the party's account immediately?**  
**No.** There is no ledger write on trip creation. Party's outstanding = `SUM(total_bill from trips) − SUM(vendor_payments)` — computed live.

**Does a trip auto-generate an invoice?**  
**No.** Invoices are created manually. However, trips are used as the source data for Job-Work Invoice auto-quantity calculation (when service has `auto_calc_source = TRIP_QUANTITIES`).

**Vehicle mode:**
- `COMPANY`: a vehicle from the Vehicle Master is selected (can be tenant-owned or vendor-owned)
- `OWN_VEHICLE`: customer brought their own vehicle; not in the system; transport charge = 0

**Non-billable data:** `notes`, `loading_location`, `unloading_location`, `channel_no` — operational only.

---

### MODULE B — DABAR (Raw Stone Intake)

**What it is:** Records of raw/unprocessed stone delivered to the crusher from a quarry or excavation site. This is production INPUT, not output/sales.

**Table:** `dabar_entries`

| Key Field | Meaning |
|---|---|
| `vendor_id` | The contractor/party supplying the stone |
| `vehicle_id` | The vehicle (dumper) that delivered it |
| `trips_count` | Number of trips in this batch (informational) |
| `quantity_brass` | Volume of stone delivered |
| `entry_date` | Date of delivery |
| `site_id` | Destination crusher site |

**Does a dabar entry affect any party's account?**  
Indirectly, via two mechanisms:

**Mechanism 1 — Transport Payable:**  
If the vehicle is vendor-owned AND the vehicle owner is NOT the same party as the site's billing party, a `TransportPayable` record is created. This appears in the vehicle owner's ledger as a pending obligation (no amount yet — to be settled separately).

**Transport payable eligibility rules:**
- `NONE` — tenant-owned vehicle → no payable (DSP's own vehicle)
- `NETS` — vendor vehicle but owner IS the site's billing party → skip (already billed via Job-Work invoice; creating a separate payable would double-count)
- `ELIGIBLE` — vendor vehicle, different owner → create `TransportPayable`

**Mechanism 2 — Job-Work Invoice auto-quantity:**  
When a Job-Work Invoice line item uses `auto_calc_source = DABAR_QUANTITIES`, the system sums all unbilled dabar entries for the site within the billing period and fills the quantity automatically. Each included dabar entry is then marked in `dabar_jw_billing` (so it cannot be double-billed).

**Vehicle owner auto-fill:**  
When a vendor-owned vehicle is selected in the dabar form, `vendor_id` on the entry is auto-filled with the vehicle owner's party.

---

### MODULE C — DIESEL

**What it is:** Tracks diesel fuel inventory — stock receipts (in) and machine/vehicle usage (out).

**Tables:** `diesel_receipts`, `diesel_usages`

**Diesel receipts — 3 source types:**

| Source | Meaning | Financial Effect |
|---|---|---|
| PUMP | Purchased from fuel pump | None — inventory only |
| DIRECT | Delivered directly to site | None — inventory only |
| PARTY_ADVANCE | A party paid for diesel upfront | Auto-creates a VendorPayment (DIESEL_ADVANCE) credit for that party |

**Diesel usages:**

| Usage target | Financial Effect |
|---|---|
| TENANT-owned machine/vehicle | None — just stock consumption |
| VENDOR-owned vehicle (without rate) | None — stock only |
| VENDOR-owned vehicle (with rate_per_liter set) | Auto-creates VendorPayment (DIESEL_CREDIT) — reduces what DSP owes that vehicle owner |

**Stock balance (per site):**  
`balance = SUM(receipts.quantity_liters) − SUM(usages.quantity_liters)`  
Shown in the Diesel screen with a warning if negative.

**Party Advance flow:**
```
Party pays for diesel upfront
→ Create diesel receipt (source=PARTY_ADVANCE, advance_party_id=X, advance_amount=₹Y)
→ System auto-creates VendorPayment: vendor=X, amount=₹Y, mode=DIESEL_ADVANCE
→ This CREDIT appears in X's ledger → reduces their outstanding balance
→ Deactivating the receipt cascades to deactivate the payment
```

**Diesel Credit flow (for vendor vehicle):**
```
DSP gives diesel to vendor vehicle
→ Create diesel usage (vehicle_id=V, rate_per_liter=₹R, quantity_liters=L)
→ System auto-creates VendorPayment: vendor=vehicle_owner, amount=R×L, mode=DIESEL_CREDIT
→ This CREDIT appears in vehicle owner's ledger → reduces what DSP owes them
→ Deactivating the usage cascades to deactivate the payment
```

---

### MODULE D — MACHINE WORK

**What it is:** Records of machinery operation — hours worked, work type, and optionally which customer and what rate.

**Tables:** `machine_work_logs`, `machine_work_types`

| Key Field | Meaning |
|---|---|
| `machine_id` | Which machine (JCB, Excavator, etc.) |
| `work_type_id` | Named work type per machine (e.g. "Bucket Work", "Breaker Work") |
| `opening_reading / closing_reading` | Hour-meter readings |
| `total_hours` | = closing − opening |
| `work_purpose` | INTERNAL or CUSTOMER_BILLABLE |
| `customer_id` | Party being billed (only for CUSTOMER_BILLABLE) |
| `rate` | ₹ per hour |
| `rate_status` | PENDING (rate not yet set) or SET (rate known, billing computed) |
| `total_amount` | = rate × total_hours (null when PENDING) |
| `gst_invoice_id` | Auto-generated GST invoice (for GST-registered customers) |

**Two work purposes:**

**INTERNAL:**
- No party, no billing, no ledger entry
- Pure operational record: machine used for own site work (excavation, leveling, etc.)
- Contributes to machine-hour totals in reports and dashboard

**CUSTOMER_BILLABLE:**
- Party (`customer_id`) is set
- Rate state machine: PENDING → SET
  - At creation with rate: immediately SET, `total_amount = rate × hours`
  - At creation without rate: PENDING, user sets rate later from ledger screen
- **Auto-generates a GST Invoice** when:
  - rate_status = SET
  - customer is GST-registered
  - No existing gst_invoice_id on the log
- Rate lock: once the associated GST invoice's `gst_status = SET`, rate cannot be changed

**Machine work in party ledger:**
- CUSTOMER_BILLABLE + rate SET: appears as debit (voucherType = "MachineWork"), sub-row shows `₹rate/hr × N hrs`
- CUSTOMER_BILLABLE + PENDING: appears in ledger as "Rate: Pending — tap to set rate"

**Machine Work Types (per-machine):**  
Each machine can have named work types (e.g., JCB Bucket Work, JCB Breaker Work) with `default_rate`, `default_gst_rate`, and `sac_code`. These auto-fill the form when selected.

---

### MODULE E — GST INVOICES (Material Invoice)

**What it is:** The standard tax invoice for material sales and services — the primary formal billing document.

**Tables:** `gst_invoices`, `gst_invoice_items`

| Key Field | Meaning |
|---|---|
| `vendor_id` | The billed party |
| `invoice_no` | Auto-generated: `DSP/{FY}/{seq}` |
| `invoice_date / supply_date` | Invoice date and date of supply |
| `po_no` | Purchase order reference |
| `cgst_rate / sgst_rate` | CGST and SGST rates (each = total_gst_rate / 2) |
| `subtotal` | Sum of all line item amounts |
| `cgst_amount / sgst_amount / grand_total` | Tax breakdown |
| `gst_status` | PENDING (rate not configured) or SET (rate locked) |

**Line items (`gst_invoice_items`):**

| Field | Meaning |
|---|---|
| `material_id` | Optional link to Material Master (for GST Recalculate) |
| `service_id` | Optional link to Service Master (can mix materials and services on one invoice) |
| `description` | Line item text |
| `hsn` | HSN code (for material) or SAC code (for service) |
| `quantity_brass` | Quantity |
| `rate` | Rate per unit |
| `amount` | Line total |

**Creation:** Always manual via Invoices screen.  
**Exception:** Machine Work CUSTOMER_BILLABLE entries auto-generate a GST invoice (see Module D).

**GST rate resolution (at save):**
```
Priority 1: Explicit rates from request body
Priority 2: material.gst_rate from first linked material item
Priority 3: service.gst_rate from first linked service item
Priority 4: Fallback 9% placeholder → gst_status = PENDING
```

**PENDING → SET flow:**
- If any line item's material/service has `gst_rate_configured = false` → invoice saved as PENDING
- User fixes the rate in Material/Service Master
- User taps "Recalculate GST" on the invoice → re-reads master rate, recomputes, locks as SET
- Audit trail: `gst_recalculated_by`, `gst_recalculated_at`, `gst_prev_sgst_rate`

**Party ledger effect:**  
Each GST invoice creates a debit entry (voucherType = "Sales") in the party's ledger showing line items, SGST, CGST, and grand total.

**Payment tracking:**  
`vendor_payments` rows with `invoice_id` link payments to invoices. Outstanding = `grand_total − SUM(payments.amount)`. Status: UNPAID / PARTIAL / PAID.

---

### MODULE F — JOB-WORK INVOICES

**What it is:** Periodic billing to a client site owner for services rendered (crushing, loading, transport). Used when DSP operates a crusher at a client's site or provides contracted services.

**Tables:** `job_work_invoices`, `job_work_invoice_items`

| Key Field | Meaning |
|---|---|
| `vendor_id` | Auto-derived from `site.linked_party_id` — the client |
| `site_id` | Must be a CLIENT_SITE |
| `period_from / period_to` | The billing period |
| `invoice_no` | Shared sequence with GST invoices (`DSP/{FY}/{seq}`) |

**Creation rules:**
- Only CLIENT_SITE sites can be used — an OWN site is rejected
- Party is automatically set to `site.linked_party_id` (cannot be changed)
- Each line item references a Service from Service Master

**Auto-quantity calculation:**  
If a service has `auto_calc_source` set:
- `TRIP_QUANTITIES`: sums unbilled trips' `billable_quantity` for this site in the billing period
- `DABAR_QUANTITIES`: sums unbilled dabar entries' `quantity_brass` for this site in the billing period
- After invoice is created, included records are marked in `trip_jw_billing` / `dabar_jw_billing` → cannot be double-billed
- Deactivating the invoice releases all billing links

**Party ledger effect:**  
Creates a debit entry (voucherType = "JobWork") in the client party's ledger.

**No payment tracking** (unlike GST invoices): Job-Work invoices do not have direct payment linkage — payments are made at the party level via VendorPayments.

---

### MODULE G — ACCOUNTS / PARTY LEDGER

**What it is:** A computed, read-only view of each party's financial position. No separate ledger table — derived live from all sources.

**LedgerService formula:**

```
Opening Balance (before from-date):
  + SUM(gst_invoices.grand_total WHERE vendor_id=X AND invoice_date < from AND status=ACTIVE)
  + SUM(job_work_invoices.grand_total WHERE vendor_id=X AND invoice_date < from AND status=ACTIVE)
  + SUM(machine_work_logs.total_amount WHERE customer_id=X AND rate_status=SET 
        AND gst_invoice_id IS NULL AND log_date < from AND status=ACTIVE)
  − SUM(vendor_payments.amount WHERE vendor_id=X AND payment_date < from AND status=ACTIVE)

Within date range — entries sorted by date ASC (receipts last per day):
  DEBIT  — GstInvoice         → voucherType=Sales       (grand_total)
  DEBIT  — JobWorkInvoice     → voucherType=JobWork      (grand_total)
  DEBIT  — MachineWorkLog     → voucherType=MachineWork  (total_amount, rate SET)
  INFO   — TransportPayable   → voucherType=TransportPayable (no amount, shows as pending)
  CREDIT — VendorPayment      → voucherType=Receipt      (amount)

Running balance: cumulative from opening balance
Closing balance = opening + totalDebit − totalCredit
```

**What DOES appear in the ledger:** GST invoices, Job-Work invoices, Machine Work (billable, rate SET), Payments, Transport Payables (info only)

**What does NOT appear in the ledger:** Raw trips, Dabar entries, Diesel usage, Attendance, INTERNAL machine work

**Export options:** PDF (Tally-style layout) and Excel (.xlsx Tally format)

**Accounts list balance (getBalances endpoint):**  
Same logic as ledger opening balance but for all-time (no date filter):
```
outstanding = 
  SUM(gst_invoices.grand_total)
  + SUM(job_work_invoices.grand_total)
  + SUM(machine_work_logs.total_amount WHERE CUSTOMER_BILLABLE AND SET AND gst_invoice_id IS NULL)
  − SUM(vendor_payments.amount)
```

---

### MODULE H — VENDOR PAYMENTS

**What it is:** Money received from a party or credits given to a party.

**Table:** `vendor_payments`

| Field | Meaning |
|---|---|
| `vendor_id` | The party |
| `payment_date` | When received |
| `amount` | Amount |
| `payment_mode` | CASH, BANK, CHEQUE, UPI, DIESEL_ADVANCE, DIESEL_CREDIT |
| `reference_no` | Cheque no., UTR no., etc. |
| `invoice_id` | Optional: links to a specific GST invoice |
| `allocation_summary` | FIFO allocation narrative (informational text) |

**Payment modes:**

| Mode | Created by | Meaning |
|---|---|---|
| CASH | Manual | Cash payment from party |
| BANK | Manual | Bank transfer from party |
| CHEQUE | Manual | Cheque from party |
| UPI | Manual | UPI payment from party |
| DIESEL_ADVANCE | DieselService (auto) | Party paid for diesel upfront |
| DIESEL_CREDIT | DieselService (auto) | DSP gave diesel to party's vehicle — credit |

---

### MODULE I — TRANSPORT PAYABLE

**What it is:** A placeholder record indicating DSP owes payment to an external vehicle owner for transporting dabar. No amount is set — it's a tracking entry only.

**Table:** `transport_payables`

| Field | Meaning |
|---|---|
| `party_id` | Vehicle owner party (who DSP owes) |
| `vehicle_id` | The vehicle that did the transport |
| `source_type` | DABAR (future: MACHINE_WORK) |
| `source_entry_id` | The dabar_entry_id |
| `entry_date` | Date of the obligation |

**In the ledger:** Appears as voucherType = "TransportPayable" with NO debit or credit. Shows as "Payable: Pending — rate not set". Represents an obligation not yet quantified.

**Design note:** `source_type` is a discriminator so the same table can cover MACHINE_WORK payables in the future.

---

### MODULE J — INVOICES (GST + Job-Work — combined Invoices screen)

The Invoices screen shows BOTH GST invoices and Job-Work invoices in a unified list, sorted by date. The `_src` field (`gst` vs `jw`) distinguishes them.

Summary bar shows: Unpaid / Partial / Paid counts (GST only) and GST Pending count (both).

Creation options from "New Invoice" bottom sheet:
- **Material Invoice (GST)** → `_UnifiedInvoiceForm` → POST `/api/invoices`
- **Job-Work Invoice** → `_JwForm` → POST `/api/job-work-invoices`

Payment recording is only available for GST invoices (Job-Work invoices use party-level payments).

---

### MODULE K — VEHICLES

**Table:** `vehicles`

| Field | Meaning |
|---|---|
| `owner` | TENANT (DSP's own) or VENDOR (belongs to a vendor) |
| `vendor_id` | If VENDOR-owned: which party owns it |
| `plate_number` | Registration number |
| `vehicle_type` | Free text (Ashok Leyland Dumper, Tata Dumper, Water Tanker, etc.) |
| `display_name` | Friendly name |
| `linked_machine_id` | Optional: links to a machine (bidirectional — if vehicle has an attached machine) |
| `is_active` | Toggle — inactive vehicles hidden from pickers |

**Vehicle owner impact:**
- TENANT vehicle → no payables generated, no automatic payments
- VENDOR vehicle → can trigger TransportPayable (dabar) and DIESEL_CREDIT (diesel)

---

### MODULE L — MACHINES

**Table:** `machines`

| Field | Meaning |
|---|---|
| `name` | Machine name (JCB, Excavator, etc.) |
| `machine_type` | Type identifier |
| `linked_vehicle_id` | Optional: the vehicle this machine is mounted on |
| `is_active` | Toggle |

Machines have `machine_work_types` (named work types per machine with default rates and SAC codes).

---

### MODULE M — MATERIALS

**Table:** `materials`

| Field | Meaning |
|---|---|
| `name` | Material name (Stone 40mm, Stone 20mm, Gravel, etc.) |
| `code` | Short code |
| `hsn_code` | HSN code for GST |
| `gst_rate` | GST rate (e.g., 5) |
| `gst_rate_configured` | Boolean — false = GST not yet set → invoices will be PENDING |
| `kg_per_brass` | Conversion factor for weight-to-brass calculation |
| `default_sale_rate` | Default rate auto-filled in trip form |
| `default_transport_rate` | Default transport rate per km in trip form |
| `status` | ACTIVE / INACTIVE |
| `is_active` | Toggle |

---

### MODULE N — SITES

**Table:** `sites`

| Field | Meaning |
|---|---|
| `name` | Site name |
| `site_type` | OWN or CLIENT_SITE |
| `linked_party_id` | For CLIENT_SITE: the client party being billed |
| `linked_party_name` | Denormalized party name |
| `address / lat / lng` | Location |

**OWN site:** DSP's own operation. Most data (trips, dabar, diesel, machine work) is scoped to OWN sites. No party linked.

**CLIENT_SITE:** DSP operates at a client's location. The `linked_party_id` is the billing target for Job-Work invoices. Trips to this party from this site suppress material_amount (client owns the material).

---

### MODULE O — PARTIES / VENDORS

**Table:** `vendors` (renamed to "Parties" in the UI)

| Field | Meaning |
|---|---|
| `name` | Party name |
| `contact` | Phone number |
| `gstin` | GSTIN number |
| `gst_registered` | Boolean — determines GST invoice auto-creation for machine work |
| `is_regular` | Regular customer (in default picker) vs occasional (search only) |
| `address` | Address |
| `status` | ACTIVE / INACTIVE |
| `is_active` | Toggle |

**ONE_TIME history:** Originally trips could have `party_type = ONE_TIME` with snapshot name/phone/address. V18 migration created real vendor records for all one-time customers and set `party_type = REGULAR` on those trips. The snapshot columns remain but are no longer written.

---

### MODULE P — SERVICES

**Table:** `services`

| Field | Meaning |
|---|---|
| `name` | Service name |
| `sac_code` | SAC code for GST |
| `gst_rate` | GST rate |
| `gst_rate_configured` | Boolean |
| `default_rate` | Default rate for Job-Work invoice line |
| `auto_calc_source` | MANUAL, TRIP_QUANTITIES, or DABAR_QUANTITIES |
| `status` | ACTIVE / INACTIVE |

Services are used as line items in both GST invoices (mixed material+service lines) and Job-Work invoices. The `auto_calc_source` drives auto-quantity calculation in Job-Work invoices.

---

### MODULE Q — EMPLOYEES & ATTENDANCE

**Tables:** `employees`, `attendance_records`

Attendance tracks daily presence (PRESENT / ABSENT / HALF_DAY / LEAVE) per employee per site. Wage computation is NOT implemented — the system records attendance but does not calculate payroll or generate any financial entries.

**No ledger connection.** Purely operational HR data.

---

### MODULE R — REPORTS

Three report types, all read-only:

| Report | Filterable by | Shows |
|---|---|---|
| Machine Work | Machine, date range, site | Hours per log, mode, readings, descriptions |
| Diesel | Date range, site | Stock events (received/used), running balance |
| Trips | Vehicle / Material / Party, date range, site | Trip details, brass totals per material |

---

### MODULE S — DASHBOARD

Live snapshot — no dedicated table, computed from all modules:

| Card | Source |
|---|---|
| Today's trips (count, brass) | trips table, today's date |
| Today's dabar (brass) | dabar_entries, today's date |
| Today's machine hours | machine_work_logs, today's date |
| Today's attendance | attendance_records, today's date |
| Diesel balance (per site) | diesel_receipts − diesel_usages |
| Monthly GST invoices total | gst_invoices, current month |
| Monthly payments received | vendor_payments, current month |
| Top 10 outstanding parties | vendors + invoice/payment sums |
| Monthly material breakdown | trips, current month, grouped by material |

---

## 4. Data Flow Summary

### Party Outstanding Balance — all contributing sources

```
DEBIT (increases what party owes):
  GST Invoices (grand_total)          ← created manually from Invoices screen
  Job-Work Invoices (grand_total)     ← created manually, auto-qty from trips/dabar
  Machine Work billable (total_amount)← auto-created when rate is SET on CUSTOMER_BILLABLE logs

CREDIT (reduces what party owes):
  Vendor Payments (amount)            ← manual entry or auto from diesel
    ├── CASH / BANK / CHEQUE / UPI    ← manual party payments
    ├── DIESEL_ADVANCE                ← auto when party pays for diesel
    └── DIESEL_CREDIT                 ← auto when diesel given to party's vehicle

NOT directly in ledger (operational data only):
  Trips          → feeds into GST invoice manually; auto-feeds JW invoice qty
  Dabar entries  → feeds into JW invoice qty; may create TransportPayable
  Diesel usage   → inventory tracking; may create DIESEL_CREDIT payment
  Machine work (INTERNAL) → hours tracking only
  Attendance     → HR only, no financial effect
```

### Trip → Billing Flow

```
[Trip recorded]
    ↓
total_bill computed (material_amount + transportation_charge)
    ↓ (this does NOT write to ledger)
[Optional: Job-Work Invoice created, period covers this trip]
    ↓
auto_qty calculation reads unbilled trips for the site+period
    ↓
trip marked in trip_jw_billing (cannot be double-billed)
    ↓
JW Invoice appears in party ledger as DEBIT

[Separate: Manual GST Invoice for material sale]
    ↓
Line items entered manually (same material, qty, rate)
    ↓
GST Invoice appears in party ledger as DEBIT
```

### Machine Work → Billing Flow

```
[Machine Work logged as CUSTOMER_BILLABLE]
    ↓
If rate provided at creation → rate_status = SET
If no rate → rate_status = PENDING (set later from ledger screen)
    ↓
rate_status = SET
    ↓
If customer is GST-registered:
  → GST Invoice auto-generated with machine work as the billing item
  → gst_invoice_id stored on the log (so it won't double-bill)
  → Appears in party ledger as DEBIT (voucherType=MachineWork inside a Sales invoice)
If customer is NOT GST-registered:
  → No invoice generated
  → Appears directly in party ledger as DEBIT (voucherType=MachineWork)
```

### Diesel Party Advance Flow

```
Party gives cash for diesel
    ↓
Create diesel receipt (source=PARTY_ADVANCE, advance_party_id=X)
    ↓
VendorPayment auto-created (mode=DIESEL_ADVANCE, vendor=X)
    ↓
CREDIT appears in party X's ledger → reduces their outstanding
```

### Dabar → Transport Payable Flow

```
Dabar entry recorded with vendor-owned vehicle
    ↓
DabarService checks eligibility:
  NONE → vehicle is TENANT-owned, stop
  NETS → vehicle owner = site billing party, stop (would double-count)
  ELIGIBLE → create TransportPayable
    ↓
TransportPayable created (party = vehicle owner)
    ↓
Appears in vehicle owner's ledger as INFO entry "Payable: Pending"
(no financial amount — to be settled outside the system)
```

---

## 5. Which Vehicle in Which Module

| Module | Vehicle Field | Vehicle Owner Type | Financial Effect |
|---|---|---|---|
| Trips | `vehicle_id` (nullable) | TENANT or VENDOR | OWN_VEHICLE = no transport charge; COMPANY = transport charged to party |
| Dabar | `vehicle_id` | TENANT or VENDOR | VENDOR vehicle + eligible → creates TransportPayable |
| Diesel Usage | `vehicle_id` (or machine_id) | TENANT or VENDOR | VENDOR vehicle + rate_per_liter → creates DIESEL_CREDIT payment |
| Machine Work | linked via `linked_vehicle_id` on machine | — | No direct vehicle-based billing |

---

## 6. Key Screen → Route → API Mapping

| Screen | Route | Primary API |
|---|---|---|
| Dashboard | /dashboard | GET /api/dashboard |
| Trips | /trips | GET/POST/PUT/DELETE /api/trips |
| Daily Report | /daily-report | GET /api/trips/daily-report |
| Dabar | /dabar | GET/POST/PUT/DELETE /api/dabar |
| Diesel | /diesel | GET/POST /api/diesel-receipts, /api/diesel-usages |
| Machine Work | /machine-work | GET/POST/PUT/DELETE /api/machine-work |
| Invoices (GST + JW) | /invoices | GET/POST/PUT/DELETE /api/invoices, /api/job-work-invoices |
| Accounts (party list) | /accounts | GET /api/parties/balances |
| Party Detail (ledger) | /accounts/:id | GET /api/ledger/vendor/:id |
| Vendor Payments | /party-payments | GET/POST /api/party-payments |
| Ledger | /ledger | GET /api/ledger/vendor/:id |
| Reports | /reports | GET /api/reports/machine-work, /api/reports/diesel, /api/reports/trips |
| Attendance | /attendance | GET/POST /api/attendance |
| Employees | /employees | GET/POST/PUT/DELETE /api/employees |
| Users | /users | GET/POST /api/users |
| Parties (master) | /master/parties | GET/POST/PUT/DELETE /api/parties |
| Vehicles | /master/vehicles | GET/POST/PUT/DELETE /api/vehicles |
| Machines | /master/machines | GET/POST/PUT/DELETE /api/machines |
| Materials | /master/materials | GET/POST/PUT/DELETE /api/materials |
| Sites | /master/sites | GET/POST/PUT/DELETE /api/sites |
| Services | /master/services | GET/POST/PUT/DELETE /api/services |

---

## 7. Key Source Files

| Purpose | File |
|---|---|
| Party ledger computation | `backend/.../service/LedgerService.java` |
| Trip billing calculation | `backend/.../service/TripService.java` |
| Dabar + transport payable | `backend/.../service/DabarService.java` |
| Diesel advance/credit payments | `backend/.../service/DieselService.java` |
| Machine work billing + GST auto | `backend/.../service/MachineWorkService.java` |
| GST invoice (create/recalculate) | `backend/.../service/GstInvoiceService.java` |
| Job-Work invoice (auto-qty) | `backend/.../service/JobWorkInvoiceService.java` |
| Party balance list | `backend/.../service/VendorService.java` — `getBalances()` |
| Invoice numbering | `backend/.../service/InvoiceNumberingService.java` |
| Multi-tenant RLS | `backend/.../config/TenantContext.java` |
| Router + all routes | `frontend/lib/core/router/app_router.dart` |
| Party ledger screen | `frontend/lib/features/accounts/party_detail_screen.dart` |
| Trip form (full billing UI) | `frontend/lib/features/trips/trips_screen.dart` |
| Invoice form (GST + JW) | `frontend/lib/features/invoices/invoices_screen.dart` |
| Machine work screen | `frontend/lib/features/machine_work/machine_work_screen.dart` |
| Dabar screen | (integrated in DabarScreen within dabar feature) |

---

## 8. Known Issues / Areas to Improve

1. **Trip vs Ledger disconnect**: Trips record `total_bill` but raw trips do NOT appear in the party ledger. Only GST invoices and JW invoices do. This means the trip-based outstanding (visible in trip cards) and the ledger-based outstanding can diverge if invoices are not created for trips.

2. **No trip→invoice automation**: Users must manually create GST invoices — trips do not auto-convert to invoices. This is a manual step prone to being skipped.

3. **Transport Payables are amount-less**: The amount owed to external vehicle owners is tracked only as "pending" — the actual amount is settled outside the system. There's no way to close/mark a transport payable as paid within the app.

4. **Attendance has no payroll**: The system tracks attendance but doesn't compute wages or generate salary payments.

5. **ONE_TIME customer columns**: `one_time_customer_name/phone/addr` on trips remain in the DB but are no longer written (V18 migration moved everything to vendors table). Dead columns.

6. **Water Tanker Logs**: Table exists (`water_tanker_logs`) from V3 but was removed from the UI in V28. No active feature.

7. **Job-Work Invoices have no payment link**: Unlike GST invoices, JW invoices don't have direct `invoice_id` linkage on payments — payments are at the party level only. This means it's impossible to know which JW invoice a payment was for.
