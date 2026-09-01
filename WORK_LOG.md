# DSP Crusher Management — Work Log

## 2026-08-31

### Done
- Read and analyzed full project reference document (`DSP_Ratnagiri_Master_Reference.md`)
- Explored all 12 real Excel registers in `documents/` — understood actual column structure, vehicle names, material sizes, diesel rate history, GST invoice format
- Finalized technology stack: Spring Boot 3 + PostgreSQL (RLS) + Flutter Web
- Resolved "how to verify backend without frontend" → Swagger UI at /swagger-ui.html
- Planned M1 scope: Auth (JWT) + Master Data CRUD (Tenant, User, Vendor, Site, Vehicle, Machine, Material)
- Scaffolded Spring Boot backend project in `backend/`
- Wrote V1 Flyway migration: full schema + PostgreSQL RLS policies
- Implemented JWT auth (`POST /api/auth/login`)
- Implemented CRUD for: Vendor, Site, Vehicle, Machine, Material
- Scaffolded Flutter Web frontend in `frontend/`

### Key Decisions Made
- **Brass** = volume unit; some newer records also use Tons — both accommodated in Material model
- Vehicle "names" in old Excel were last 4 digits; clean plate number stored in master, display name configurable
- Channel No. (unloading location) is free text on Trip record, not a master table — matches how DSP uses it
- Diesel rate changes per purchase — stored per receipt record, not a fixed config
- Water tanker (MH 12 LT 6091) is DSP-owned but rented to vendor — handled by `owner=DSP, vendor_id=RDS_vendor`

### Verified
- Backend: login, JWT, all 5 master data APIs — all passing
- Security probes: wrong password → clean error, no token → 403, bad token → 403, malformed body → field validation errors
- RLS confirmed: all seeded rows scoped to tenantId=1 correctly

---

## 2026-09-01

### Done — M2: Transportation / Material Sale Trips + Daily Report

**Backend:**
- `V2__transportation_trips.sql` — `trips` table + RLS policy
- `Trip.java` entity, `TripRepository.java`, `TripRequest.java`, `TripResponse.java` (enriched with vehicle/material/vendor names), `DailyReportResponse.java`
- `TripService.java` — CRUD + daily report (rollup by material, grand total)
- `TripController.java` — `GET /api/trips`, `GET /api/trips/daily-report?date=`, POST/PUT/DELETE
- Added `spring.flyway.validate-on-migrate=false` to avoid checksum error on existing DB

**Frontend:**
- `trips_screen.dart` — date nav bar (prev/next/picker), trip cards (vehicle, material, qty, challan pair), Add Trip FAB, edit/delete
- `daily_report_screen.dart` — date nav bar, summary card (brass by material + green grand total), DataTable of all trips
- `app_router.dart` — Trips and Daily Report added; default landing after login changed to `/trips`
- `master_shell.dart` — Trips + Daily Report at top of nav rail, master data below
- `login_screen.dart` — fixed post-login `context.go('/trips')` (was `/vendors`)

### Verified
- 3 trips created via API: 2201→20MM 5.5B, 2201→20MM 4B, 2301→10MM 3.5B
- Daily report for 2026-08-31: 20MM 9.5B + 10MM 3.5B = **Grand Total 13 Brass** ✓
- UI confirmed via Playwright screenshots: login, trips screen (empty state + Add Trip FAB), daily report (summary card + DataTable)

### Gotcha (for future sessions)
- Flutter 3.47 uses CanvasKit renderer in Chrome (no `flt-semantics` text, no `--web-renderer` flag). Headless Playwright gets HTML renderer and works for screenshots.
- Old backend process must be killed before restarting: `kill $(lsof -ti :8080)`

---

### Done — M3: Dabar Register + Water Tanker Log

**Backend:**
- `V3__dabar_tanker_log.sql` — `dabar_entries` + `water_tanker_logs` tables + RLS
- `DabarEntry.java`, `WaterTankerLog.java` entities
- Full CRUD: `DabarService` + `DabarController` (`/api/dabar`), `WaterTankerService` + `WaterTankerController` (`/api/water-tanker`)
- Water tanker `amount` computed server-side: `hoursWorked × rate` (falls back to `tripsCount × rate`)

**Frontend:**
- `dabar_screen.dart` — date nav, entry cards (vehicle/vendor/trips/brass), daily totals bar, add/edit/delete
- `water_tanker_screen.dart` — date nav, log cards, live amount preview as user types hours + rate
- Nav rail: Dabar (terrain icon) + Water Tanker (water drop icon) added between Daily Report and Vendors

### Verified
- Dabar POST → vehicle enrichment, trips + brass stored ✓
- Water tanker POST (8.5 hrs × ₹500) → amount = ₹4250 ✓

---

### Done — M4: Diesel Tracking

**Backend:**
- `V4__diesel.sql` — `diesel_receipts` + `diesel_usages` tables + RLS
- `DieselReceipt.java`, `DieselUsage.java` entities
- `DieselReceiptRepository` / `DieselUsageRepository` — JPQL `SUM` queries for balance
- `DieselService` — amount stored on receipt (`qty × rate`); balance = total received − total used
- `DieselController` — 10 endpoints under `/api/diesel`: receipts CRUD, usages CRUD, `GET /balance`

**Frontend:**
- `diesel_screen.dart` — tabbed screen (Received | Used tabs)
  - Balance banner: Received · Used · Stock (turns red when < 100L)
  - Received tab: PUMP / DIRECT segmented toggle, live amount preview, vendor + invoice fields
  - Used tab: Machine / Vehicle segmented toggle, swaps picker accordingly
  - FAB switches label per active tab
- Nav rail: Diesel (⛽ gas station icon) added after Water Tanker

### Verified
- POST receipt 500 L @ ₹90.50 → amount ₹45,250 stored ✓
- POST usage 45.5 L by JCB machine ✓
- GET /balance → received 500, used 45.5, balance 454.5 ✓

---

---

### Done — M5: Machine Work Log

**Backend:** `V5__machine_work_log.sql`, `MachineWorkLog` entity, full CRUD at `/api/machine-work`. `totalHours = closingReading − openingReading` computed on save.

**Frontend:** `machine_work_screen.dart` — date nav, BUCKET/BREAKER SegmentedButton, opening/closing readings, live hours preview, summary bar.

### Verified
- POST (JCB 205, 3294.9→3296.9) → totalHours 2.0 ✓

---

### Done — M6: GST Invoices + Vendor Payments

**Backend:** `V6__gst_invoice_vendor_payment.sql`, `GstInvoice`/`GstInvoiceItem` (CASCADE), `VendorPayment`. Invoice auto-numbering `DSP/YYYY-YY/N` by fiscal year. CGST 9% + SGST 9% computed from line items. 10 endpoints under `/api/invoices` + `/api/vendor-payments`.

**Frontend:** `invoices_screen.dart` — dynamic line-item rows, live grand total preview, detail dialog. `vendor_payments_screen.dart` — CASH/BANK/CHEQUE/UPI ChoiceChips.

### Verified
- Invoice DSP/2026-27/1: subtotal ₹14L + CGST+SGST ₹2.52L = Grand Total ₹16.52L ✓
- Payment ₹5L BANK recorded ✓

---

### Done — M7: Dashboard

**Backend:** Aggregate JPQL queries added to Trip/MachineWorkLog/GstInvoice/VendorPayment repos. `GET /api/dashboard` — single call returns today's trips, diesel stock, monthly machine hours, monthly invoice total, monthly payments, material breakdown table.

**Frontend:** `dashboard_screen.dart` — Today row (trips + diesel stock card with low-stock warning), This Month row (machine hours, invoices, payments), material summary table. Dashboard is now default landing after login.

---

### Done — M8: Employee Attendance

**Backend:** `V7__employee_attendance.sql` — `employees` + `attendance_records` (UNIQUE per tenant/date/employee). `GET /api/attendance?date=` returns all active employees with their status (null = unmarked). `POST /api/attendance/mark` upserts.

**Frontend:** `attendance_screen.dart` — 4 inline colored chips per employee (Present/Half-Day/Absent/Leave), tap to mark instantly, summary bar counts. `employees_screen.dart` — DAILY/MONTHLY SegmentedButton wage form.

### Verified
- POST mark Ramesh PRESENT, Suresh HALF_DAY → summary: 1P + 1H + 0 unmarked ✓

---

### Done — M9: Vehicle Daily Log

**Backend:** `V8__vehicle_daily_log.sql` — date, vehicle, loading/unloading location, opening/closing reading, `total_km` computed (closing−opening), day/night trips, `total_trips` computed (day+night), diesel note. 5 endpoints at `/api/vehicle-daily-log`.

**Frontend:** `vehicle_daily_log_screen.dart` — date nav, summary bar (vehicles + trips + km), log cards showing location arrow, odometer readings, km chip, day/night badges. Form with live km preview + running trip total preview.

### Verified
- POST (MH 47 AS 5199, reading 12450.5→12532.0, 3 day trips) → totalKm 81.5, totalTrips 3 ✓

---

### Done — M10: User Management

**Backend:** `UserService`/`UserController` at `/api/users` — list, create (bcrypt password), update (blank password = keep existing), deactivate. No new migration — users table already in V1.

**Frontend:** `users_screen.dart` — active/inactive grouped list, role selector cards (Owner/Admin, Office/Accountant, Site Staff) with descriptions, password field with show/hide toggle.

### Verified
- Created Priya Desai (OFFICE_ACCOUNTANT) → login with priya@dsp.com/office123 OK ✓

---

## All Modules Complete — Full App

**Navigation rail (16 items):**
Dashboard · Trips · Daily Report · Dabar · Water Tanker · Diesel · Machine Work · Invoices · Payments · Attendance · Vehicle Log · Users · Employees · Vendors · Vehicles · Machines · Materials · Sites

**Backend:** 8 Flyway migrations (V1–V8), 19 controllers, 30+ DTOs, full RLS on all tables.

**Frontend:** 16 screens + master shell + auth.

---

## Improvement Phases (2026-09-01, continuation)

### Phase 1 — Design System + Sidebar Overflow (commit: afbe33e)
- Created `frontend/lib/core/widgets/app_widgets.dart` — shared widgets: `AppDateBar`, `AppDialog` (max-height 88vh, scrollable body, pinned footer), `AppEmptyState`, `SectionLabel`, `DateField`, `fmtCurr`/`fmtNum`/`currFmt`/`numFmt`
- Replaced NavigationRail with custom 200px scrollable sidebar grouped into: Operations / Finance / Workforce / Vehicles / Master Data / Admin
- Fixed RIGHT OVERFLOW on invoice form by splitting 4-column row into 2×2
- All 9 date-based screens migrated to shared `AppDateBar`
- All form dialogs migrated to `AppDialog` (Save/Cancel always visible, no scroll cutoff)

### Phase 2 — Vendor Ledger (commit: e2f8bcc)
- `LedgerController.java` + `LedgerService.java` — `GET /api/ledger/vendor/{id}?from=&to=`
- Running balance, opening balance from pre-range history
- `ledger_screen.dart` — vendor selector, date presets (This Month/Last Month/This FY/Custom), Debit/Credit/Balance table, PDF + Excel export
- Sidebar: Ledger under Finance, index 10

### Phase 3 — Operational Reports (commit: 95d19a6)
- `ReportController.java` + `ReportService.java` + `ReportResponse.java` — 4 endpoints: vehicle-log, machine-work, diesel, trips
- `reports_screen.dart` — 4 tabs, date presets (Today through This FY + Custom), entity filter dropdowns, PDF + Excel export
- Sidebar: Reports under Operations, index 7

### Phase 4 — Invoice Payment Tracking (commit: de0db2f)
- `V9__payment_invoice_link.sql` — adds nullable `invoice_id FK` on `vendor_payments`
- `GstInvoiceResponse` enriched with `totalPaid`, `outstandingAmount`, `paymentStatus` (UNPAID/PARTIAL/PAID)
- `GET /api/invoices/{id}/payments` endpoint
- Invoices screen: status badge, outstanding amount per card, summary strip, "Record Payment" popup action
- Invoice detail dialog: 2 tabs (Line Items / Payments history)
- Payment form: "Apply to Invoice" dropdown filtered to vendor's open invoices, auto-fills outstanding amount

### Phase 5 — Consolidated Daily Report (commit: 0183fa8)
- `DailyReportService.java` + `ConsolidatedDailyReport.java` — aggregates all 7 modules for a date
- `GET /api/reports/daily?date=` — single API call replaces 7 separate calls
- `daily_report_screen.dart` rewritten: 7 section cards (Trips full-width, Dabar+WaterTanker, Diesel+Machine, Attendance+Financial), trip detail table, PDF (A4) + Excel export

### Phase 6 — Dashboard Overhaul + Monthly Attendance (commit: 0b43773)
- `DashboardService.java` updated: populates `todayAttendancePresent/Total`, `todayMachineHours`, `todayDabarBrass`, `totalInvoiced`, `totalPaymentsLinked`, `totalOutstanding`
- `AttendanceMonthlyResponse.java` DTO + `getMonth(YearMonth)` in `AttendanceService`
- `GET /api/attendance/monthly?month=YYYY-MM` — returns employee × day grid (null = no record)
- `dashboard_screen.dart` rewritten: Today row (Trips, Attendance X/Y, Diesel, Machine Hrs, Dabar — all tappable), Financial Position card (Outstanding large + red, Total Invoiced + Total Paid as sub-tiles), This Month section, material summary table
- `attendance_screen.dart` updated: Daily / Monthly tab bar; Monthly tab = scrollable employee × day grid with P/H/A/L cells, day summary columns, Excel export

---

## Post-Phase Polish (2026-09-01, continuation)

### Role-Based Sidebar (commit: bf7a632)
- `_AppSidebar` converted from `StatelessWidget` to `StatefulWidget`
- Reads role from `AuthStorage` on mount (SharedPreferences, < 1ms)
- `SITE_STAFF`: Finance section (Invoices/Payments/Ledger) + Admin section (Users) hidden entirely including section headers
- `OWNER_ADMIN` / `OFFICE_ACCOUNTANT`: no change

### Currency Formatting Consolidation (commit: 1434bab)
- Removed all local `NumberFormat` definitions scattered across screens
- All monetary displays now use `fmtCurr()` / `currFmt` from `app_widgets.dart` (Indian comma grouping: ₹1,23,456.00)
- Affected: dashboard, vendor_payments, daily_report, ledger (`_fmtNum`), employees (wage rate label)

### Delete Confirmations with Entity Details (commit: 8d561f4)
- Every delete/deactivate dialog now names the specific item being removed
- Dabar: vehicle · vendor · brass qty; Water Tanker: vehicle · amount (fmtCurr)
- Diesel: litres + source (receipt) or consumer (usage); Vendors/Vehicles/Machines/Materials/Sites: entity name
- Screens already showing entity details (trips, invoices, payments, machine work, vehicle log, users, employees) left unchanged

### Pagination — Invoices + Payments (commit: 1692fec)
- `PageResponse<T>` DTO: `content`, `page`, `size`, `totalElements`, `totalPages`, `last`
- Spring Data `Page<T>` overloads added to `GstInvoiceRepository` + `VendorPaymentRepository`
- `GET /api/invoices?page=0&size=25` and `GET /api/vendor-payments?page=0&size=25`
- Frontend: `StateNotifier` (_InvoicesNotifier / _PaymentsNotifier) accumulates pages in `items` list
- "Load more" `OutlinedButton` appended after last item when `hasMore = true`
- Summary strip shows "N of M" when not all records are loaded
- `_vendorOpenInvoicesProvider` (payment form dropdown) updated to read `content[]` from paged response, passes `size=200`

### Searchable Pickers (commit: a831f58)
- `SearchablePicker` added to `app_widgets.dart` — `FormField<int>` subclass, integrates with `Form.validate()`
- Tapping opens `_SearchPickerDialog`: autofocused search field, 200ms debounce, client-side filter
- Checkmark + tinted background on currently selected item
- `clearable: true` + `clearLabel` for optional fields and report filter dropdowns ("All Vehicles" etc.)
- Replaced all 19 `DropdownButtonFormField<int>` entity pickers across 12 screens:
  - trips (vehicle, vendor, material), dabar (vehicle, vendor), water_tanker (vehicle), machine_work (machine), vehicle_daily_log (vehicle), invoices (vendor), vendor_payments (vendor), ledger (vendor), diesel (supplier, machine, vehicle), reports (vehicle ×2, machine, material, vendor), master_data/machines (vendor), master_data/vehicles (vendor)
- Removed unused `_dropDec` helper from reports_screen
- Added `app_widgets.dart` import to diesel_screen, machines_screen, vehicles_screen

---

## Production Readiness Audit (2026-09-01, commit: 6f9783c)

### Priority 1 — Ledger Redesign (matches reference Ledger.xlsx)

**Reference studied:** `documents/Ledger.xlsx` — Malganga Construction ledger with grouped invoice entries (Sales + SGST + CGST + Round Off sub-rows) and "By BANK – REF" payment rows.

**Backend:**
- `VendorLedgerResponse.java` — replaced flat DTO with grouped structure: `particulars` ("To (as per details)" / "By MODE – REF"), `voucherType` ("Sales" / "Receipt"), `invoiceNo`, `List<DetailLine>` (label + amount per breakdown line)
- `GstInvoiceRepository.java` — added `findWithItemsByVendorAndDateRange` with `JOIN FETCH i.items` to avoid N+1 on ledger queries
- `LedgerService.java` — builds grouped invoice entries (main row + Sales/SGST/CGST/Round Off detail lines), payment entries with "By MODE – REF" particulars, correct running balance

**Frontend (`ledger_screen.dart` — complete redesign):**
- Table: Date | Particulars | Voucher Type | Debit | Credit | Balance
- Invoice main row shows "To (as per details)" bold; sub-rows show indented Sales/SGST/CGST/Round Off amounts in grey italic
- Payment rows show "By BANK – REF" in green
- Print button → `Printing.layoutPdf` (browser print dialog, A4 portrait)
- PDF → A4 portrait, centered vendor/date header repeated per page, detail sub-rows, summary box (Opening/Invoiced/Paid/Outstanding), page numbers
- Excel → bold grey headers, column widths (Date=14, Particulars=44, Voucher=14, Amounts=18), `currFmt`-formatted amounts, summary block at bottom
- Added "Prev FY" date preset alongside This Month/Last Month/This FY

### Priority 2 — Financial Security (Backend Role Enforcement)

**`SecurityConfig.java`:**
- `/api/invoices/**` → requires `OWNER_ADMIN` or `OFFICE_ACCOUNTANT`
- `/api/vendor-payments/**` → same
- `/api/ledger/**` → same
- SITE_STAFF receives 403 on all three; can still access trips, attendance, diesel, etc.
- Verified: SITE_STAFF token → 403 on all financial endpoints; 200 on operational endpoints

### Priority 3 — Financial Validation

**`GlobalExceptionHandler.java`:** Added `IllegalArgumentException` → 400 Bad Request handler.

**`GstInvoiceService.java` (in `apply()`):**
- Rejects if items list is empty
- Rejects if any item `amount <= 0`
- Rejects if `quantityBrass < 0` or `rate < 0`

**`VendorPaymentService.java` (in `apply()`):**
- Rejects if `amount <= 0`
- If `invoiceId` is set: verifies invoice exists and belongs to the same vendor (cross-vendor payment rejected with clear message)

### Priority 4 — Diesel Stock Warning

**`DieselUsageResponse.java`:** Added `stockWarning` boolean field.

**`DieselService.createUsage()`:** After saving, recalculates total balance; sets `stockWarning=true` if balance < 0. Usage is still saved (site logs entries after the fact) but caller is informed.

### Verified Test Results

| Test | Expected | Result |
|------|----------|--------|
| Ledger opening balance (txns before range) | 9,450 carried forward | ✓ PASS |
| Ledger grouped invoice entries | To (as per details) + detail sub-rows | ✓ PASS |
| Ledger payment entries | By BANK – IDBI CA-... | ✓ PASS |
| Ledger running balance | 132300 → 0 → 141750 → 9450 | ✓ PASS |
| SITE_STAFF → /api/invoices | 403 | ✓ PASS |
| SITE_STAFF → /api/vendor-payments | 403 | ✓ PASS |
| SITE_STAFF → /api/ledger/vendor/1 | 403 | ✓ PASS |
| SITE_STAFF → /api/trips | 200 | ✓ PASS |
| Invoice with negative amount | 400 | ✓ PASS |
| Payment with amount=0 | 400 | ✓ PASS |
| Payment with another vendor's invoiceId | 400 + message | ✓ PASS |
| Diesel usage > stock | stockWarning=true | ✓ PASS |
| Backend mvn compile | Clean | ✓ PASS |
| dart analyze ledger_screen.dart | 0 issues | ✓ PASS |

---

## Rename Vendor → Party (2026-09-02, commit: 346347f)

### Context
The app used "Vendor" everywhere for the parties DSP sells material to — but in a GST invoice, DSP is the seller and R.D. Samant / Malganga Construction are the buyers (customers). However, the same entity can also supply diesel to DSP, making them a vendor in that context. Indian accounting software (Tally) uses "Party" for this dual-role concept. Changed throughout.

### Strategy
Renamed only user-visible labels and API paths. Internal Java class names (`VendorService`, `VendorController`, `Vendor` entity, `VendorPayment`, etc.) and Dart provider names left unchanged to avoid large churn with no user benefit.

### Backend (4 files)
- `VendorController.java`: `@RequestMapping("/api/vendors")` → `@RequestMapping("/api/parties")`; Swagger tag/summary strings updated
- `VendorPaymentController.java`: `@RequestMapping("/api/vendor-payments")` → `@RequestMapping("/api/party-payments")`
- `LedgerController.java`: `@GetMapping("/vendor/{vendorId}")` → `@GetMapping("/party/{partyId}")`
- `SecurityConfig.java`: path matcher `"/api/vendor-payments/**"` → `"/api/party-payments/**"`

### Frontend (13 files)
| What changed | Before | After |
|---|---|---|
| Sidebar nav item | Vendors | Parties |
| Routes | /vendors, /vendor-payments | /parties, /party-payments |
| Screen titles | Vendor Payments, Vendor Ledger | Party Payments, Party Ledger |
| Picker labels | Vendor *, Select vendor | Party *, Select party |
| Dabar picker | Vendor / Supplier | Party |
| Reports filter | Vendor, All Vendors | Party, All Parties |
| Vehicle/Machine owner | Vendor | Party (External) |
| Dashboard nav | context.go('/vendor-payments') | context.go('/party-payments') |
| All API calls | /api/vendors, /api/vendor-payments, /api/ledger/vendor/ | /api/parties, /api/party-payments, /api/ledger/party/ |

### Verified
- `GET /api/parties` → 200 ✓
- `GET /api/party-payments` → 200 ✓
- `GET /api/ledger/party/2` → 200 ✓
- Old paths (`/api/vendors`, `/api/vendor-payments`, `/api/ledger/vendor/*`) → no longer served ✓
- SITE_STAFF blocked from `/api/party-payments` → 403 ✓
- `dart analyze` → 0 errors ✓

---

## Final State

**Git:** branch `master`, last commit `346347f` (Vendor → Party rename)
**Backend:** Flyway V1–V9, 20+ controllers, `PageResponse<T>`, `AttendanceMonthlyResponse`, role-gated financial endpoints, input validation; API paths use `/api/parties`, `/api/party-payments`, `/api/ledger/party/`
**Frontend:** 20 screens, `SearchablePicker`, paginated invoices + payments, role-gated sidebar, redesigned accounting ledger; all "Vendor" labels replaced with "Party"
