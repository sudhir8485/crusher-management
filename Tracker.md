# Tracker.md — Feature Status

Last updated: 2026-09-12 (V36). Update this file as work is completed.

---

## Core Operational Modules

| Feature | Status | Notes |
|---------|--------|-------|
| Trip entry (basic logging) | ✅ Done | |
| Trip billing (weight, qty, sale rate, transport charge) | ✅ Done | |
| Trip: own vehicle toggle | ✅ Done | `vehicle_mode = OWN_VEHICLE` |
| Trip: transport mode (Calculate vs Direct) | ✅ Done | |
| Trip: CLIENT_SITE material suppression | ✅ Done | `material_suppressed` flag |
| Trip: period tabs (Day/Week/Month/Year/Custom) | ✅ Done | |
| Trip: auto-invoicing (GST auto-create on create/update) | ✅ Done | V30, `autoCreateGstInvoice()` in TripService |
| Trip: vendor vehicle transport credit (auto VendorPayment) | ✅ Done | V31 |
| Trip: RECORD INFO audit display | ✅ Done | V14 |
| Dabar intake logging | ✅ Done | |
| Dabar: transport payable toggle | ✅ Done | V26 |
| Dabar: period tabs (Day/Week/Month/Year/Custom) | ✅ Done | |
| Dabar: RECORD INFO audit display | ✅ Done | V34 |
| Diesel: 3-source receipt (Pump / Direct / Party Advance) | ✅ Done | V27 |
| Diesel: external vehicle usage credit (auto VendorPayment) | ✅ Done | V27 |
| Diesel: per-site stock balance | ✅ Done | |
| Diesel: period tabs (Day/Week/Month/Year/Custom) | ✅ Done | |
| Diesel: RECORD INFO audit display | ✅ Done | V34 |
| Machine Work: INTERNAL / CUSTOMER_BILLABLE modes | ✅ Done | V20 |
| Machine Work: Work Types (replaces BUCKET/BREAKER) | ✅ Done | V28 |
| Machine Work: rate pending → set → GST invoice flow | ✅ Done | V22 |
| Machine Work: vendor machine hire credit | ✅ Done | V32 |
| Machine Work: period tabs (Day/Week/Month/Year/Custom) | ✅ Done | |
| Machine Work: RECORD INFO audit display | ✅ Done | V34 |

---

## Invoices & Payments

| Feature | Status | Notes |
|---------|--------|-------|
| GST Invoices: create / edit / deactivate | ✅ Done | |
| GST Invoices: GST PENDING → SET recalculation | ✅ Done | V19 |
| GST Invoices: material + service line items | ✅ Done | V23 |
| GST Invoices: payment recording + outstanding tracking | ✅ Done | |
| GST Invoices: RECORD INFO audit display | ✅ Done | V34 |
| GST Invoices: print-ready PDF (formal tax invoice format) | 🔲 Not Started | Packages available; no print button in invoices_screen |
| Job-Work Invoices: create / edit / deactivate | ✅ Done | V21 |
| Job-Work Invoices: auto-quantity from trips / dabar | ✅ Done | V24–V25 |
| Job-Work Invoices: billing link guards (no double-billing) | ✅ Done | V25 |
| Job-Work Invoices: GST PENDING → SET recalculation | ✅ Done | |
| Job-Work Invoices: RECORD INFO audit display | ✅ Done | V34 |
| Job-Work Invoices: print-ready PDF | 🔲 Not Started | Same as GST invoice gap |
| Vendor Payments: create / edit / deactivate | ✅ Done | |
| Vendor Payments: direction (RECEIVED / PAID) | ✅ Done | V33 |
| Vendor Payments: transport payable settlement | ✅ Done | V33 |
| Vendor Payments: FIFO allocation summary | ✅ Done | V15 |
| Vendor Payments: RECORD INFO audit display | ✅ Done | V34 |

---

## Ledger & Accounts

| Feature | Status | Notes |
|---------|--------|-------|
| Party ledger (Receivable / Payable terminology) | ✅ Done | |
| Ledger: collapsed drillable rows | ✅ Done | |
| Ledger: transport payable settlement from ledger | ✅ Done | |
| Ledger: navigate to home module for edit (not inline) | ✅ Done | |
| Ledger: payment direction toggle | ✅ Done | V33 |

---

## Master Data

| Feature | Status | Notes |
|---------|--------|-------|
| Party (Vendor) management | ✅ Done | |
| Vehicle management | ✅ Done | |
| Machine management | ✅ Done | |
| Material management | ✅ Done | |
| Service management | ✅ Done | V21 |
| Site management | ✅ Done | |
| Active / Inactive toggle (Party / Vehicle / Machine / Employee) | ✅ Done | V29 + V36 |
| Machine: Work Types per machine | ✅ Done | V28 |
| Machine: Linked Vehicle bidirectional pairing | ✅ Done | V28 |

---

## Dashboard & Reports

| Feature | Status | Notes |
|---------|--------|-------|
| Dashboard: stats tiles (today + month) | ✅ Done | |
| Dashboard: charts / graphs | 🔲 Not Started | No chart package in pubspec.yaml |
| Reports: operational reports (Trips / Diesel / Machine) | ✅ Done | `reports_screen.dart` |
| Reports: PDF export | ✅ Done | |
| Reports: Excel export | ✅ Done | |
| Daily trip report (printable) | ✅ Done | `daily_report_screen.dart` |

---

## Attendance

| Feature | Status | Notes |
|---------|--------|-------|
| Employee management | ✅ Done | |
| Employee: deactivate (working) | ✅ Done | V36 — was silently failing (403); now uses PATCH toggle-active |
| Employee: reactivate | ✅ Done | V36 — popup shows Reactivate (green) for inactive employees |
| Employee: Inactive section visible | ✅ Done | V36 — greyed badge, separate section |
| Daily attendance marking | ✅ Done | |
| Attendance: default Present pre-selected | ✅ Done | V36 — all unmarked employees start as Present; explicit Save required |
| Attendance: bulk Save Attendance button | ✅ Done | V36 — replaces per-tile auto-save; shows pending count |
| Attendance: site required to save | ✅ Done | V36 — banner + disabled button when no site selected; siteId passed in mark request |
| Inactive employees excluded from attendance | ✅ Done | Backend filters ACTIVE only |
| Monthly attendance grid + Excel export | ✅ Done | |

---

## Infrastructure

| Feature | Status | Notes |
|---------|--------|-------|
| Multi-tenant (RLS) | ✅ Done | All tables |
| JWT auth (login / roles) | ✅ Done | |
| Site isolation (SITE_STAFF scoping) | ✅ Done | V10 |
| Flyway migrations (V1–V34) | ✅ Done | |
| Audit trail: created_by / last_edited_by | ✅ Done | V14 (trips) + V34 (all other operational tables) |
| Dead-code cleanup (water_tanker_logs, vehicle_daily_logs, one_time_customer_* columns) | 🔲 Not Started | Tables exist in DB but are unreferenced |

---

## Status Key

| Symbol | Meaning |
|--------|---------|
| ✅ Done | Implemented, tested, in production |
| 🚧 In Progress | Currently being built |
| 🔲 Not Started | Planned but not yet begun |
| ⚠️ Partial | Backend done but no UI, or UI done but no backend |
