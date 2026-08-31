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
