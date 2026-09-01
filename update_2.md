# update_2.md — Session State (2026-09-01)

## Context
Continuation of crusher-management project. M1–M10 all done.  
This session implemented Phases 1–5 from update_1.md, and Phase 6 was started but NOT committed (stashed).

---

## Completed Phases (committed on master)

### Phase 1 — Sidebar + Design System (commit: afbe33e)
- `frontend/lib/core/widgets/app_widgets.dart` — shared widgets: `AppDateBar`, `AppDialog` (max-height 88vh, scrollable body, pinned footer), `AppEmptyState`, `SectionLabel`, `DateField`, `fmtCurr/fmtNum`
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
7:  /reports        ← NEW Phase 3
8:  /invoices
9:  /vendor-payments
10: /ledger         ← NEW Phase 2
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

## Phase 6 — IN PROGRESS (stashed, NOT committed)

### What was started (git stash):
Dashboard overhaul — was partway through when context ran out.

### Files partially modified (in stash):
- `DashboardResponse.java` — added fields: `todayAttendancePresent`, `todayAttendanceTotal`, `todayMachineHours`, `todayDabarBrass`, `totalInvoiced`, `totalPaymentsLinked`, `totalOutstanding`
- `GstInvoiceRepository.java` — added `sumAllGrandTotal()` query
- `VendorPaymentRepository.java` — added `sumAllLinkedPayments()` query

### To complete Phase 6:
1. `git stash pop` to restore the partial changes
2. Update `DashboardService.java` to populate the new fields using:
   - `DailyReportService.build(today)` OR direct repo calls for today's attendance/dabar/machine hours
   - `invoiceRepo.sumAllGrandTotal()` for totalInvoiced
   - `paymentRepo.sumAllLinkedPayments()` for totalPaymentsLinked
   - `totalOutstanding = totalInvoiced - totalPaymentsLinked`
3. Rewrite `frontend/.../dashboard/dashboard_screen.dart`:
   - Today row: Trips+Brass, Attendance (X present/Y total), Diesel Stock, Machine Hours, Dabar Brass
   - Financial position: Total Invoiced, Total Paid, Outstanding (large prominent)
   - This Month: Machine hours, Invoices, Payments
   - Material summary table
   - All cards clickable → navigate to module using `context.go('/route')`
4. Add **Monthly Attendance** tab to `attendance_screen.dart`:
   - Month picker (prev/next)
   - Table: employees (rows) × days (columns) with P/H/A/L status cells
   - Summary row at bottom: count per day
   - Excel export for payroll

---

## Other remaining items from update_1.md

### High priority:
- **Role-based UI hiding** (§31): SITE_STAFF shouldn't see Invoices/Payments/Ledger/Users in sidebar
  - JWT token contains role: `OWNER_ADMIN | OFFICE_ACCOUNTANT | SITE_STAFF`
  - Read role from auth storage, hide nav items accordingly
  - Backend already has `@PreAuthorize` on some endpoints

- **Attendance monthly report** with Excel export

### Medium priority:
- Better dashboard (Phase 6)
- Indian currency formatting everywhere (₹1,23,456.00 not ₹123456.00) — partially done via `fmtCurr`
- Delete confirmations showing entity details (§36)

### Lower priority (from update_1.md):
- Print layouts (§53) — PDF serves this for now
- Pagination for large lists
- Debounced search in dropdowns

---

## Running the app
```bash
bash ~/crusher-management/start.sh    # starts backend :8080 + frontend :3000
bash ~/crusher-management/stop.sh     # stops both
```
Login: admin@dsp.com / admin123

## Git state
Branch: master
Last commit: 0183fa8 (Phase 5)
Stash: Phase 6 partial dashboard changes (git stash pop to restore)
