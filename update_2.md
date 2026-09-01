# update_2.md — Session State (2026-09-01)

## Context
Continuation of crusher-management project. M1–M10 all done.
This session implemented Phases 1–6 from update_1.md, plus all improvement items.

---

## Completed Phases (committed on master)

### Phase 1 — Sidebar + Design System (commit: afbe33e)
- `frontend/lib/core/widgets/app_widgets.dart` — shared widgets: `AppDateBar`, `AppDialog`, `AppEmptyState`, `SectionLabel`, `DateField`, `fmtCurr/fmtNum`
- Sidebar replaced `NavigationRail` with custom scrollable 200px sidebar grouped into: Operations / Finance / Workforce / Vehicles / Master Data / Admin
- Invoice form 4-column row split into 2×2 to fix RIGHT OVERFLOW
- All 9 date-based screens now use shared `AppDateBar`
- All form dialogs use `AppDialog` — Save/Cancel always visible

### Phase 2 — Vendor Ledger (commit: e2f8bcc)
- `backend/.../controller/LedgerController.java` — `GET /api/ledger/vendor/{id}?from=&to=`
- `backend/.../service/LedgerService.java` — merges invoices+payments, running balance, opening balance from pre-range history
- `frontend/lib/features/ledger/ledger_screen.dart` — vendor selector, date presets (This Month/Last Month/This FY/Custom), transaction table with Debit/Credit/Balance columns, PDF + Excel export
- Sidebar: Ledger under Finance (account_balance icon), index 10

### Phase 3 — Operational Reports (commit: 95d19a6)
- `backend/.../controller/ReportController.java` — 4 endpoints:
  - `GET /api/reports/vehicle-log?vehicleId=&from=&to=`
  - `GET /api/reports/machine-work?machineId=&from=&to=`
  - `GET /api/reports/diesel?from=&to=`
  - `GET /api/reports/trips?vehicleId=&materialId=&vendorId=&from=&to=`
- `backend/.../service/ReportService.java` — aggregates each module
- `backend/.../dto/ReportResponse.java` — generic Row + Summary DTO
- `frontend/lib/features/reports/reports_screen.dart` — 4 tabs (Vehicles/Machines/Diesel/Trips), date presets (Today/This Week/This Month/Last Month/This FY/Custom), entity dropdowns, PDF + Excel export
- Sidebar: Reports under Operations (bar_chart icon), index 7

### Phase 4 — Invoice Payment Tracking (commit: de0db2f)
- `V9__payment_invoice_link.sql` — adds `invoice_id FK` (nullable) to `vendor_payments`
- `GstInvoiceResponse` now has: `totalPaid`, `outstandingAmount`, `paymentStatus` (UNPAID/PARTIAL/PAID)
- `GET /api/invoices/{id}/payments` — list payments for a specific invoice
- `VendorPaymentRequest/Response` — `invoiceId` + `invoiceNo` fields
- Invoices screen: status badge (UNPAID/PARTIAL/PAID) + outstanding amount on each card, summary strip (Unpaid/Partial/Paid counts), "Record Payment" in popup menu
- Invoice detail: 2-tab dialog — Line Items + Payments history
- Payments form: "Apply to Invoice" dropdown (filtered to vendor's open invoices, auto-fills outstanding amount)

### Phase 5 — Consolidated Daily Report (commit: 0183fa8)
- `backend/.../service/DailyReportService.java` — aggregates 7 modules for a date
- `backend/.../dto/ConsolidatedDailyReport.java` — sections: Trips, Dabar, WaterTanker, Diesel, Machine, Attendance, Financial
- `GET /api/reports/daily?date=` — single call for all modules
- `frontend/.../trips/daily_report_screen.dart` — completely rewritten:
  - 7 section cards: Trips (full width), Dabar+WaterTanker, Diesel+Machine, Attendance+Financial
  - Trip detail table at bottom
  - PDF export (A4, all sections) + Excel export buttons in AppBar

### Phase 6 — Dashboard Overhaul + Monthly Attendance (commit: 0b43773)
- Dashboard: Today row (Trips, Attendance X/Y, Diesel, Machine Hrs, Dabar), Financial Position card (Outstanding large + prominent), This Month section, all cards clickable via `context.go('/route')`
- Backend: `DashboardService` populates todayAttendancePresent/Total, todayMachineHours, todayDabarBrass, totalInvoiced, totalPaymentsLinked, totalOutstanding
- Monthly Attendance: Attendance screen has Daily / Monthly tabs; Monthly = employee × day grid (P/H/A/L cells) with Excel export
- Backend: `GET /api/attendance/monthly?month=YYYY-MM` → `AttendanceMonthlyResponse`

---

## Post-Phase Improvements (all committed on master)

### Role-Based Sidebar (commit: bf7a632)
- `SITE_STAFF` role: Finance section (Invoices/Payments/Ledger) + Admin section (Users) hidden
- `OWNER_ADMIN` and `OFFICE_ACCOUNTANT`: full sidebar
- Implemented via `StateWidget` reading role from `AuthStorage` on mount

### Currency Formatting (commit: 1434bab)
- All monetary displays consolidated onto shared `fmtCurr()` / `currFmt` from `app_widgets.dart`
- Removed local `NumberFormat` definitions from: dashboard, vendor_payments, daily_report, ledger, employees screens
- Indian comma grouping: ₹1,23,456.00 everywhere

### Delete Confirmations (commit: 8d561f4)
- Every delete/deactivate dialog now names the specific item being removed
- Dabar: vehicle · vendor · brass qty; Water Tanker: vehicle · amount
- Diesel: litres + source/consumer; Vendors/Vehicles/Machines/Materials/Sites: entity name

### Pagination (commit: 1692fec)
- `PageResponse<T>` DTO — wraps content, page, size, totalElements, totalPages, last
- `GET /api/invoices?page=0&size=25` and `GET /api/vendor-payments?page=0&size=25`
- Frontend: `StateNotifier` accumulates pages; "Load more" button at list bottom
- Summary strip shows "N of M" when not all records are loaded
- Spring Data `Page<T>` overloads added to both repositories

### Searchable Pickers (commit: a831f58)
- `SearchablePicker` widget in `app_widgets.dart` — `FormField<int>` that opens a search dialog
- 200ms debounce on typing, client-side filter, checkmark on selected item
- `clearable: true` adds "None / All X" row for optional fields and report filters
- Replaced all 19 entity pickers across 12 screens (vehicle, vendor, material, machine everywhere)

---

## Sidebar Route Index (current master)
```
0:  /dashboard
1:  /trips
2:  /daily-report
3:  /dabar
4:  /water-tanker
5:  /diesel
6:  /machine-work
7:  /reports
8:  /invoices
9:  /vendor-payments
10: /ledger
11: /attendance
12: /vehicle-daily-log
13: /users
14: /employees
15: /vendors
16: /vehicles
17: /machines
18: /materials
19: /sites
```

---

## Nothing remaining from update_1.md
All items from the original spec are complete:
- ✅ All 10 modules (M1–M10)
- ✅ Phases 1–6
- ✅ Role-based UI hiding
- ✅ Currency formatting (Indian)
- ✅ Delete confirmations with entity details
- ✅ Pagination (invoices + payments)
- ✅ Debounced search in all entity pickers
- ✅ Monthly attendance with Excel export
- Print layouts (§53) — PDF already covers this; not needed

---

## Running the app
```bash
bash ~/crusher-management/start.sh    # starts backend :8080 + frontend :3000
bash ~/crusher-management/stop.sh     # stops both
```
Login: admin@dsp.com / admin123

## Git state
Branch: master
Last commit: a831f58 (Searchable pickers)
No stash. Clean working tree.

## DB
PostgreSQL `crusher_management`, Flyway V1–V9
DB user: crusher_admin / crusher123
