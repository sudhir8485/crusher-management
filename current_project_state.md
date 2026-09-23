# Current Project State — Crusher Management SaaS

**Date:** 2026-09-18 | **Version:** V58 (Flyway) | **Branch:** master

---

## 1. Platform Vision

This is a **multi-tenant SaaS platform**. DSP Construction (crusher business) is tenant #1 — the first client. The platform is designed to eventually support any business type (quarry operators, contractors, transport companies).

**SaaS Roadmap:**
- Stage 1 (current): Prove it works for DSP
- Stage 2: Onboard more clients manually
- Stage 3: Self-serve SaaS with automated signup + Razorpay billing

**Rules:**
- Never hardcode DSP-specific logic into the platform layer
- Entities are generic: Vehicle, Machine, Material, Vendor, Site — not "crusher vehicle" etc.
- Use `TENANT` not `DSP` in enum values for ownership fields

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Backend | Java 21 + Spring Boot 3.3.5 + Spring Security + Spring Data JPA |
| Database | PostgreSQL 16, DB: `crusher_management`, user: `crusher_admin`/`crusher123` |
| ORM / Migrations | Hibernate + Flyway (V1–V58 applied) |
| Auth | JWT via jjwt 0.12.6, 24h expiry |
| Multi-tenancy | Row-Level Security (RLS) + TenantContext ThreadLocal + TenantInterceptor |
| Frontend | Flutter 3.47.1 web, Riverpod (state), go_router (routing), Dio (HTTP) |
| Fonts | Noto Sans (PDFs), Poppins (mobile header) via google_fonts |
| API Docs | springdoc-openapi → Swagger UI at `/swagger-ui.html` |

**Start commands:**
```bash
cd backend && mvn spring-boot:run      # :8080
cd frontend && flutter run -d web-server --web-port 3000   # :3000
```

---

## 3. Login Credentials

| User | Email | Password | Role | tenantId | siteId |
|---|---|---|---|---|---|
| Platform Admin | superadmin@platform.com | superadmin123 | SUPER_ADMIN | null | null |
| DSP Admin | admin@dsp.com | admin123 | OWNER_ADMIN | 1 | null |
| Priya Desai | priya@dsp.com | office123 | OFFICE_ACCOUNTANT | 1 | null |
| Raju Site | raju@dsp.com | site123 | SITE_STAFF | 1 | 1 |
| Suresh Mulshi | suresh@dsp.com | site123 | SITE_STAFF | 1 | 2 |

---

## 4. Roles & Access Control

### Role Hierarchy

| Role | Access |
|---|---|
| SUPER_ADMIN | Platform Admin only — tenant provisioning. No tenant data visible (RLS blocks everything). |
| OWNER_ADMIN | Full access to all modules, all sites, all finance |
| OFFICE_ACCOUNTANT | Same as OWNER_ADMIN EXCEPT: no Users, no Site create/edit/delete, no permanent delete on master data, no Business Profile |
| SITE_STAFF | Operations only (Trips, Dabar, Diesel, Machine Work). Own site only. No Finance, Reports, Attendance, Master Data. |

### SITE_STAFF Same-Day Edit Restriction
- Can only edit/delete entries dated **today**. Past entries throw 409.
- Message: "This entry is from a previous day and can no longer be edited by site staff."
- Enforced in: TripService, DabarService, DieselService (4 methods), MachineWorkService, AttendanceService
- Frontend: lock icon replaces edit/delete in Dabar, Diesel, Machine Work, Trips; attendance chips become read-only

### SUPER_ADMIN Architecture
- `tenant_id = NULL` — structurally above all tenants
- `app.tenant_id` is never SET for SUPER_ADMIN requests → RLS evaluates to NULL → zero tenant rows visible
- Frontend: purple "Platform Admin" shell at `/#/admin/tenants`
- Router blocks SUPER_ADMIN from `/dashboard/*`; blocks tenant users from `/admin/*`
- Deactivating a tenant immediately blocks all its users from logging in

### Sidebar Route Index
```
0=dashboard    1=trips        2=daily-report   3=dabar        4=diesel
5=machine-work 6=reports      7=invoices       8=accounts     9=ledger
10=attendance  11=users       12=employees
13=parties     14=vehicles    15=machines      16=materials   17=sites   18=services
19=business-profile (Admin section, OWNER_ADMIN only)
```

---

## 5. All Modules

### 5.1 Dashboard
- Role-split: OWNER_ADMIN/ACCOUNTANT get full dashboard; SITE_STAFF get simplified dashboard (own site only)
- Shows: charts, billing breakdown, party receivables, "Needs Attention" section
- Quick actions: jump to Reports, Attendance
- SiteStaffDashboardResponse: trips today, diesel balance, machine hours — NO attendance

### 5.2 Trips (Kopa)
**Billing formula:**
- Material: `Qty × Sale Rate = Amount`
- Transport (CALCULATE): `Qty × KM × Rate(₹/km/unit) = Total` — quantity always a factor
- Transport (DIRECT): user enters total when dist/rate absent
- Smart auto/direct: formula rows go auto (green, read-only) when all inputs filled; editable otherwise

**Form fields:**
- Customer: dialog picker (search by name/phone)
- Material: dialog picker (search by name/code; auto-fills Sale Rate + Transport Rate)
- Vehicle: dialog picker (search by plate/name); hidden when "Customer's Own Vehicle" ON
- Own Vehicle toggle: single Switch; hides vehicle + entire transport section → ₹0 transport
- Additional Details (collapsible): Vendor Challan No., Loading/Unloading Location, Notes
- Channel No: REMOVED

**Rate auto-fill logic:**
- Always loads `defaultSaleRate`/`defaultSaleRateBrass` matching selected unit
- Fallback: tries other unit's rate, switches unit toggle to match
- `defaultTransportRate` from material auto-fills transport rate
- Switching materials ALWAYS updates rates (no isEmpty guard)

**Trip card features:**
- Tap to expand inline calculation chain (Loaded−Empty=Net → Qty → ×Rate = Material → +Transport = Total)
- Lock icon when: invoice is active (shows "Cancel Invoice & Edit" dialog) OR SITE_STAFF + past date
- Popup menu: Download Challan / Tax Invoice | Edit | Convert to Regular Customer (one-time only) | Delete
- OWN badge, payment status badge (Paid / Balance ₹X / Advance ₹X)

**Auto-invoice:**
- GST party: auto-creates GstInvoice on save (PENDING if material.gstRateConfigured=false)
- Non-GST party: direct "Delivery" debit entry in party ledger (no invoice)
- VENDOR-owned vehicle: auto-creates TRANSPORT_CREDIT VendorPayment to vehicle owner

**PDF Challan:**
- A4 landscape, 2 copies (Original + Duplicate)
- Noto Sans fonts, business name from `AuthStorage.getTenantName()`
- Full itemized: weights, qty, rate, amounts, transport formula shown

**Material Suppression (Ratnagiri billing):**
When trip.siteId is CLIENT_SITE AND trip.vendorId == site.linkedPartyId → materialAmount = 0 (transport only)

### 5.3 Daily Report
- Consolidated view of all operational modules for the day
- PDF + Excel export; business name from Business Profile (dynamic, not hardcoded)

### 5.4 Dabar (Raw Material Intake)
- Pure intake record — NOT a billable quantity source for invoices
- Vehicle auto-fills Party on selection
- No. of Trips defaults to 1
- Transport payable detection:
  - TENANT vehicle → no payable
  - VENDOR vehicle, owner == site.linkedPartyId (CLIENT_SITE) → NETS (no payable)
  - VENDOR vehicle, different party → ELIGIBLE → "Arranged by DSP" toggle
- Period browsing: Day / Week / Month / Year / Custom (same pattern as Diesel/Machine Work)
- Site-aware: orange banner when no site selected

### 5.5 Diesel
- Per-site stock tracking (balance = received − used, per site)
- Receipt sources: Pump | Direct | Party Advance
  - PARTY_ADVANCE: posts VendorPayment credit to the party
- Usage: tracks rate/liter; VENDOR-owned vehicles get DIESEL_CREDIT VendorPayment
- Period browsing: Day / Week / Month / Year / Custom
- Balance banner only shown when a specific site is selected (never global combined)
- Diesel Direct mode REMOVED (V54)

### 5.6 Machine Work
- Work Types per machine (V28): label, defaultRate, defaultGstRate, SAC code
  - 0 work types: Mode section hidden
  - 1 work type: auto-selected silently
  - 2+ work types: ChoiceChip selector (Wrap)
- Linked Vehicle: bidirectional soft link between Machine and Vehicle
- Rate always editable (no lock guard)
- Work Purpose: INTERNAL (default) vs CUSTOMER_BILLABLE
- Customer Billable: auto-creates GstInvoice; PENDING if no GST rate on work type
- Machine owner transport credit: auto-creates TRANSPORT_CREDIT VendorPayment to machine/vehicle owner
- Period browsing: Day / Week / Month / Year / Custom

### 5.7 Reports
**5 tabs:** Trips | Dabar | Diesel | Machine Work | Attendance

**Each tab:** Entity filters (SearchablePicker, optional) + Date presets (Today/This Week/This Month/Last Month/This FY/Custom) + Load button + Excel + Print (PDF)

**Filter fields:**
- Trips: Vehicle, Material, Party, Site
- Dabar: Vehicle, Party, Site
- Diesel: Site only
- Machine Work: Machine, Site
- Attendance: Employee, Site

SITE_STAFF: always filtered to own site (JWT-enforced)

### 5.8 Invoices
**Two types:**
- Material Invoice (GST) — for material/trip sales
- Job-Work Invoice — for service billing (JW)

**GST System (V57 — Per-item GST Rate):**
- `gst_rate` stored per line item (null=PENDING, 0=zero-rated, >0=that rate)
- Invoice gstStatus = "PENDING" if ANY item has null gst_rate; "SET" otherwise
- PENDING resolved by: open invoice → Edit → enter rate → Save
- Mismatch indicator: blue note if entered rate differs from master rate (informational only)
- Auto-fill: if material.gstRateConfigured=true → pre-fills rate on item pick
- SGST/CGST always 50/50 split (intra-state only; IGST not implemented)
- Removed APIs: `/recalculate-gst` and `/set-gst-rate` on both invoice types

**Job-Work Invoice features:**
- Billing period (from/to dates)
- Auto-calculate quantity: from trip quantities at site in period (TRIP_QUANTITIES)
  - DABAR_QUANTITIES removed — Dabar is intake-only
- Anti-duplication: once trips billed to a JW invoice, they're locked; second invoice same period shows qty=0 + overlap warning
- Drill-down: view each underlying trip/record

**Invoice PDF (V50):**
- Matches `documents/Invoice sample.pdf` exactly
- Print route: `/invoices/gst/:id/print` and `/invoices/jw/:id/print` (outside ShellRoute)
- Screen generates PDF → `window.location.replace(blobUrl)` → browser native PDF viewer
- Download saves blob to disk with invoiceNo as filename
- PDF layout: Company header | Party/Site/Invoice-details 3-col | Items table | 3-col footer (Balance till Date / Bank Details / Totals) | Amount in Words | HSN breakdown table | Signatures

**Amount field lock:** read-only (green) when both qty AND rate are filled; editable otherwise

**Invoice numbering:** DSP/2026-27/N (configured via `invoice_prefix` on tenant, V55)

### 5.9 Accounts
**Three views:**
1. **Parties tab**: list all parties, color-coded outstanding (orange=Owes/Receivable, blue=Advance/Payable, green=Settled). Search + filter chips. Tap → party detail.
2. **Party Detail screen** (`/accounts/party/:id`): invoice-based ledger, date-grouped entries, running balance per row. Collapsed by default, tap to expand sub-rows. Every entry tappable → navigates to home module (Trips/Invoices/Payments/Dabar/Machine Work) and auto-opens edit form.
3. **All Transactions tab**: chronological VendorPayments list

**Record Payment modal:**
- Direction toggle: RECEIVED (party pays DSP) vs PAID (DSP pays party)
- PAID: links to unsettled transport payable, marks it settled
- Live FIFO allocation preview, new balance after

**Terminology:** "Owes" → Receivable; "Advance" → Payable

**Export:** PDF (Noto Sans, 7-col with Balance ₹) + Excel (7-col with Balance Dr/Cr)

### 5.10 Ledger
- Invoice-based ledger view (GET /api/ledger/party/{id})
- PENDING invoices: amber card, hint to enter GST rate
- Export: PDF (running balance column, 7 cols) + Excel
- Balance column: Dr (orange) / Cr (blue) / — (green/zero)

### 5.11 Attendance
- Daily marking per employee per site
- Default: Present
- Status: Present / Absent / Half Day / Leave
- SITE_STAFF: NO ACCESS (removed V42)

### 5.12 Users
- CRUD for users in tenant
- SITE_STAFF must have an assigned siteId (backend enforces 400 if missing)
- Roles: OWNER_ADMIN, OFFICE_ACCOUNTANT, SITE_STAFF
- is_active toggle (reversible) separate from soft-delete
- OFFICE_ACCOUNTANT: no access (index 11 hidden)

### 5.13 Employees
- Master data for payroll-eligible employees
- OFFICE_ACCOUNTANT: has access

### 5.14 Payroll (V51–V54)
- `employee_payments` table: payment_date, amount, notes, payment_type (ADVANCE), payment_method (CASH)
- Frontend: `features/payroll/payroll_screen.dart`

### 5.15 Master Data

**Parties (Vendors):**
- Unified model (V18): no "one-time customer" concept at master level (one-time trips handled inline)
- GST Registered toggle + GSTIN field
- is_active toggle + soft-delete
- Delete blocked if historical references (trips, invoices, payments)

**Vehicles:**
- Linked Machine bidirectional soft link
- Owner: TENANT or VENDOR (+ vendorId)
- is_active toggle
- Delete blocked if referenced in trips/dabar/diesel

**Machines:**
- Work Types list (per-machine, ordered)
- Linked Vehicle
- is_active toggle
- Delete blocked if referenced in machine work logs

**Materials:**
- Fields: name, code, sizeLabel, unit (BRASS/TON), defaultSaleRate (TON), defaultSaleRateBrass (BRASS), defaultTransportRate, kgPerBrass, gstRate, gstRateConfigured, hsnCode, status
- gstRateConfigured: true = confirmed rate → auto-fills on invoice; false = PENDING

**Sites:**
- site_type: OWN or CLIENT_SITE
- linkedPartyId: for CLIENT_SITE — the party billed for job-work at this site

**Services (Service Master):**
- SAC code, defaultUnit, defaultRate, gstRate, gstRateConfigured
- auto_calc_source: NONE or TRIP_QUANTITIES
- Used in Job-Work Invoices

### 5.16 Business Profile (V46)
- GET: all roles | PUT: OWNER_ADMIN only
- Fields: name, address, phone, email, gstin, logo_base64, bankName, bankAccountNo, bankIfsc
- Used in all PDFs (company header, bank details)

### 5.17 SUPER_ADMIN — Tenant Management
- List all tenants with status
- Create new tenant (auto-creates OWNER_ADMIN user)
- Deactivate / Reactivate tenants (blocks login for all tenant users)
- Reset owner password

---

## 6. Flyway Migration History (V1–V58)

| Version | Description |
|---|---|
| V1 | init_schema — full schema, RLS, seed data |
| V2 | transportation_trips — trips table + RLS |
| V3 | dabar_tanker_log — dabar_entries + water_tanker_logs |
| V4 | diesel — diesel_receipts + diesel_usages |
| V5 | machine_work_log — machine_work_logs |
| V6 | gst_invoice_vendor_payment — gst_invoices + vendor_payments |
| V7 | employee_attendance |
| V8 | vehicle_daily_log |
| V9 | payment_invoice_link |
| V10 | site_isolation — site_id on all operational tables |
| V11 | trip_billing — 16 cols on trips (party_type, weights, billing) |
| V12 | material_code_brass_rate_transport_mode |
| V13 | material_default_transport_rate |
| V14 | trip_audit_fields — created_by_name, updated_by_name |
| V15 | payment_allocation_summary |
| V16 | fix_trip_audit_names — UPDATE rows where name stored as user ID |
| V17 | gst_fields — materials.gst_rate, hsn_code, vendors.gst_registered, trips.gst_rate |
| V18 | unified_party_model — removed ONE_TIME concept |
| V19 | gst_pending_status — materials.gst_rate_configured, gst_invoices.gst_status |
| V20 | machine_work_billing — 8 billing cols on machine_work_logs |
| V21 | site_type_service_master_job_work — site_type, services, job_work_invoices |
| V22 | machine_work_gst_invoice — machine_work_logs.gst_invoice_id FK |
| V23 | unified_invoice_service_line |
| V24 | trip_suppress + service_auto_qty + jobwork_period |
| V25 | jw_invoice_billing_links — trip_jw_billing, dabar_jw_billing |
| V26 | dabar_transport_payables — transport_payables table |
| V27 | diesel_advance_payable — diesel_receipts.advance_party_id, diesel_usages.rate_per_liter |
| V28 | machine_work_types_vehicle_link — machine_work_types, linked_vehicle_id, linked_machine_id |
| V29 | is_active_toggle — vehicles, machines, vendors |
| V30 | trip_auto_invoice — trips.gst_invoice_id, trips.auto_invoiced |
| V31 | trip_transport_payment — trips.transport_payment_id FK → vendor_payments |
| V32 | machine_work_transport_payment — machine_work_logs.transport_payment_id |
| V33 | payment_direction — vendor_payments.direction (RECEIVED/PAID), transport_payables.amount |
| V34 | audit_fields_all_modules |
| V46 | tenant_profile — phone, email, logo_base64, updated_at on tenants |
| V47 | super_admin — users.tenant_id nullable, SUPER_ADMIN seed |
| V48 | force_rls_multi_tenant — FORCE ROW LEVEL SECURITY on all tenant-scoped tables |
| V49 | users_no_force_rls — users table explicitly excluded from FORCE RLS |
| V50 | tenant_bank_details — bank_name, bank_account_no, bank_ifsc |
| V51 | payroll — employee_payments table |
| V52 | employee_payment_type |
| V53 | payment_method |
| V54 | rename_dsp_challan_no |
| V55 | tenant_invoice_config — invoice_prefix, invoice_terms on tenants |
| V56 | diesel_credit_direction — UPDATE vendor_payments SET direction='PAID' WHERE mode='DIESEL_CREDIT' |
| V57 | per_item_gst_rate — gst_rate DECIMAL(5,2) on gst_invoice_items + job_work_invoice_items |
| V58 | global_email_unique — drops (tenant_id, email) unique; adds UNIQUE(email) globally |

**Gap note:** V35–V45 are embedded in V34 and V46 range — some migrations were applied inline (no separate file gaps in actual DB state; Flyway files jump from V34 to V46 in the repo).

---

## 7. Backend Architecture

### Multi-Tenant Pattern
```
JWT → JwtAuthFilter → TenantContext (ThreadLocal)
TenantInterceptor → SET app.tenant_id = ? on DB connection
PostgreSQL RLS → NULLIF(current_setting('app.tenant_id', true), '')::BIGINT
```
- SUPER_ADMIN: `app.tenant_id` never SET → evaluates NULL → zero rows visible
- Table owners (`crusher_admin`) bypass RLS for migrations/seed

### Key Patterns
- `TripService.computeBilling()`: authoritative billing calc — `qty × km × rate` (CALCULATE) or direct (DIRECT)
- `getCurrentUserName()`: SecurityContext (user ID) → `findById()` → full_name (set on audit fields)
- `resolveCreateSite()`: resolves siteId for OWNER_ADMIN creates (from header/param)
- `validateSiteStaffSameDayAccess()`: same-day edit enforcement for SITE_STAFF
- `_apiError()` helper in frontend: extracts backend JSON error message from Dio exceptions

### Exception → HTTP Mapping
| Exception | HTTP |
|---|---|
| IllegalArgumentException | 400 Bad Request |
| IllegalStateException | 409 Conflict |
| ResourceNotFoundException | 404 |
| UnauthorizedException | 401 |
| Auth missing/invalid | 403 (not 401) |

### Auth Behavior
- Backend returns **403** (not 401) when JWT is missing or invalid
- After backend restart: users must log out/in manually (stale JWT causes 403 on all screens)
- Frontend auto-clears stale token on 401 response

---

## 8. Frontend Architecture

### Project Structure
```
frontend/lib/
  main.dart
  core/
    api/api_client.dart          (Dio, auto-attaches JWT)
    router/app_router.dart       (go_router, auth guard)
    storage/auth_storage.dart    (SharedPreferences)
  features/
    auth/login_screen.dart
    master_data/
      master_shell.dart          (sidebar + mobile layout)
      widgets/master_list_screen.dart
      vendors/ vehicles/ machines/ materials/ sites/ services/
    trips/trips_screen.dart  daily_report_screen.dart
    dabar/dabar_screen.dart
    diesel/diesel_screen.dart
    machine_work/machine_work_screen.dart
    invoices/invoices_screen.dart  invoice_pdf.dart  invoice_print_screen.dart
    accounts/accounts_screen.dart  party_detail_screen.dart
    ledger/ledger_screen.dart
    reports/reports_screen.dart
    attendance/attendance_screen.dart
    payroll/payroll_screen.dart
    users/users_screen.dart
    dashboard/dashboard_screen.dart
    admin/admin_shell.dart  tenants_screen.dart
```

### Mobile Responsive Architecture (V53)
- **Breakpoint: 700px**
- Below: `Column([_MobileSiteBar(), Expanded(child)])` + `bottomNavigationBar: _MobileBottomNav`
- **Bottom nav (6 items):** Custom `_NavBarItem` Row (NOT NavigationBar) for 360px support
  - Admin/Accountant: Home | Trips | Work | Diesel | Accounts | More
  - SITE_STAFF: Home | Trips | Work | Diesel | Dabar | More
- **"More" sheet:** DraggableScrollableSheet with role-filtered grouped ListTiles
- **Site selector:** in More sheet — SITE_STAFF shows read-only label; Admin/Accountant shows picker
- **Mobile app header:** 48px persistent header (Poppins w700, blue→indigo gradient, text: 'Site Manager')
- Site bar hidden on `/accounts` routes (party-level, not site-specific)

### Key Patterns
- **Period browsing:** Day/Week/Month/Year/Custom — all 5 screens (Trips, Dabar, Diesel, Machine Work, Payments)
- **Site-aware FAB:** when FAB tapped and siteId==null → shows site picker bottom sheet → then form
- **Provider key format:** `"fromDate|toDate|siteId"` for cache isolation
- **Mode-chip filter bars:** use `Wrap(spacing:6)` NOT `Row` (overflow on 360px screens)
- **`Expanded` vs `Flexible`:** use `Expanded` when goal is "fill remaining width and prevent overflow"
- **Wide tables:** `LayoutBuilder → SingleChildScrollView(horizontal) → SizedBox(width: max(available, 700))`

### PDF Generation
- All PDFs use **Noto Sans** via `PdfGoogleFonts.notoSansRegular()/notoSansBold()` with explicit `font:` on every `pw.TextStyle`
- This fixes ₹ (U+20B9), en-dash, em-dash rendering in PDF
- Invoice print: `window.location.replace(blobUrl)` → browser native PDF viewer (no Flutter UI)

---

## 9. Key Entity Relationships

```
Tenant
  └── User (role: OWNER_ADMIN / OFFICE_ACCOUNTANT / SITE_STAFF)
  └── Site (site_type: OWN / CLIENT_SITE, linkedPartyId FK)
  └── Vendor (Party — customers + suppliers)
  └── Vehicle (owner: TENANT / VENDOR, linkedMachineId)
  └── Machine (owner: TENANT / VENDOR, linkedVehicleId, workTypes[])
  └── Material (gstRate, gstRateConfigured, hsnCode)
  └── Service (sacCode, autoCalcSource)
  └── Employee

Trip → Vendor, Vehicle, Material, Site
  └── GstInvoice (auto-created)
  └── VendorPayment (TRANSPORT_CREDIT, if VENDOR vehicle)

DabarEntry → Vehicle, Vendor (owner), Site
  └── TransportPayable (if ELIGIBLE)

DieselReceipt → Site
  └── VendorPayment (DIESEL_ADVANCE, if PARTY_ADVANCE)
DieselUsage → Vehicle, Site
  └── VendorPayment (DIESEL_CREDIT, if VENDOR vehicle)

MachineWorkLog → Machine, Vendor (customer), Site, MachineWorkType
  └── GstInvoice (auto-created for CUSTOMER_BILLABLE)
  └── VendorPayment (TRANSPORT_CREDIT)

GstInvoice → Vendor, Site
  └── GstInvoiceItem → Material (optional), gstRate (per-item)
JobWorkInvoice → Vendor, Site
  └── JobWorkInvoiceItem → Service (optional), gstRate (per-item)
  └── TripJwBilling / DabarJwBilling (anti-duplication links)

VendorPayment → Vendor (direction: RECEIVED / PAID)
  └── TransportPayable (optional FK, for PAID direction)

Employee → Tenant
AttendanceRecord → Employee, Site
EmployeePayment → Employee (payroll)
```

---

## 10. Removed Modules

| Module | Status |
|---|---|
| Water Tanker | All backend + frontend files deleted. DB table `water_tanker_logs` retained. |
| Vehicle Daily Log | All backend + frontend files deleted. DB table `vehicle_daily_logs` retained. |

---

## 11. Known Constraints / Limitations

- IGST (inter-state GST) not implemented — same-state (SGST/CGST) assumed
- Multi-select payables settlement deferred (currently single-select)
- One-time customer cross-date outstanding: no dedicated ledger view
- Business Profile logo upload: works on web only (uses dart:html)
- Invoice PDF `cgstRate/sgstRate` at invoice level = first non-null item's rate ÷ 2 (for display only; actual amounts correctly summed per-item)
- Payments list search covers party name only (not reference/notes)

---

## 12. Commit History (Most Recent First)

| Commit | Description |
|---|---|
| 4817dc6 | V58: Global email uniqueness — one email, one account across all tenants |
| d174c2b | PDF download (no print), trip invoice lock, same-day edit restriction across 5 modules |
| 8734d56 | V57: Per-item GST rate, invoice detail from Accounts, locked Amount field |
| 01f1a3f | Fix Excel double-download: use wb.encode() instead of wb.save() |
| a18d31c | Extend diesel payable deduction to vendor-owned machines |
| 2e620ef | Fix additional hardcoded values and Excel double-download across all modules |
| ac041ce | Fix 14 issues: invoice config, diesel direction, SITE_STAFF locking, Excel export |
| b61de5b | Payroll module (V51–V54 Flyway), reports redesign, challan rename |
| 5e0bcc3 | Poppins font + login logo in mobile app header |
| 81aa911 | V55: Site selector to More menu, Diesel/Dabar empty state, dashboard quick actions |
| 9714c0d | V54: SafeArea Android, SITE_STAFF mobile site label, Dabar site picker |
| 25da6fe | V53: Mobile bottom nav, site bar, site-aware FAB, Machine Work card expand |
| f1a9b5f | V52: Card layout redesign + overflow fixes |
| 921e23d | V51: Mobile responsiveness — icon rail, Reports fixes |
| b28fe56 | V50: Printable invoice PDF — sample-matched layout, print route, bank details |
| 2a7e2e3 | V47–V49: SUPER_ADMIN role — tenant provisioning, FORCE RLS |
| 6c0bcb7 | V46: Business Profile screen, dynamic company name, sidebar user footer |
| 2b9f696 | V45: Fix garbled characters in Reports PDF headers |
| 91c7053 | V44: Hide empty section headers for SITE_STAFF |
| 895437d | V43: Remove Attendance from SITE_STAFF dashboard |
| 11f0cf4 | V42: Remove Attendance access from SITE_STAFF |
| 2452279 | V41: Fix SITE_STAFF null siteId |
| bc9c055 | V37: Redesign Dashboard — simpler layout, charts, billing breakdown |
| 98c4bad | Reports redesign — 5 tabs, no summary cards, site filter |
| 0914f16 | V34: Ledger pure-router + home module auto-open + Dabar payable amount |
| 0fce063 | V30–V32: Trip auto-invoice + vendor transport credits |
| 77a65c8 | V29: is_active toggle on Vehicle/Machine/Party + JW invoice fixes |
| cde7feb | V28: Machine Work redesign, Work Types, linked vehicle, period browsing |
| 176a8ea | Diesel period browsing — Day/Week/Month/Year/Custom |
| 6d032bd | V27: Diesel redesign — per-site stock, Party Advance, external vehicle payable |
| b2bc4c8 | Dabar period browsing + drilldown dialog |
| 4f0e1c0 | V26: Dabar as pure intake + transport payable detection |
| 8a5f0d7 | V24+V25: Ratnagiri billing model, JW anti-duplication |
| a0a32f7 | V23: Merge Invoice + Job-Work into single Invoices module |
| 1454d04 | V21+V22: Site Type, Service Master, Job-Work Invoices, Machine Work GST routing |
| f5e14e2 | Machine Work billing — Work Purpose, Rate Pending/Set, ledger integration |
| e66b642 | Multi-site isolation — site_id on all tables, site switcher UI |
