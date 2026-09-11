# PRD — DSP Crusher Management System

**Client:** DSP Construction (Ratnagiri crusher site, and other sites e.g. Policewadi)
**Prepared by:** Sudhir | **Status:** Living document — update as decisions evolve

---

## 1. What this product is

A digital replacement for DSP Construction's paper registers (Dabar/Kopa, trip challans,
machine hour-meter logs, diesel stock, GST bills, party ledgers) — built first for DSP's
real operations, with an eventual goal of becoming a multi-tenant SaaS product for other
crusher/construction businesses (free trial → paid). **Currently Stage 1: prove it with
DSP.** Do not build multi-tenant self-serve signup/billing yet.

## 2. Who uses it

Non-technical field and office staff. Roles: OWNER_ADMIN, OFFICE_ACCOUNTANT, SITE_STAFF
(role-based access; SITE_STAFF locked to their assigned site). Multi-user — accountability
matters (see Section 8, Audit Trail).

## 3. Core business relationship

- **DSP Construction** brings its own crusher machinery and vehicles to work at sites.
- **R.D. Samant Contractors Pvt. Ltd.** owns the Ratnagiri quarry site — a Client Site.
  DSP is not supplied by Samant; DSP operates AT Samant's site and bills Samant.
- **Policewadi** is DSP's own site (Own Site) — no external site owner to bill for
  crushing; only genuine material/transport sales to customers there are billed.
- A **Party** can simultaneously be a site owner, a material buyer, and an equipment
  provider (Samant is all three) — one consistent term "Party" used everywhere, never
  "Customer"/"Vendor" interchangeably.

### Ratnagiri billing model (resolved)
DSP bills Samant for two separate things, two separate ways:
1. **Crushing fee** — periodic, based on TOTAL quantity moved (every vehicle's trips
   count toward this total, regardless of owner) — billed via Job-Work Invoice.
2. **Transportation fee** — only when DSP's own vehicle carries material; a Party's own
   vehicle carrying material is tracked (counts toward the quantity total) but never
   billed transport (₹0 transport rule).

At a Client Site, a Trip billing the site's own owner suppresses Material Amount
(`material_suppressed = true`) — only transportation applies there; the crushing/material
value is captured separately via the periodic Job-Work invoice, not double-billed via Trip.

## 4. Core entities (see Schema.md for full DB detail)

Party, Vehicle, Machine, Material, Service, Site, Trip, Dabar, Diesel (Receipts/Usages),
Machine Work, GST Invoice, Job-Work Invoice, Vendor Payment, Transport Payable,
Attendance/Employee.

## 5. Key product requirements (explicit, repeated client asks)

- **Simplicity, plain language, consistency** — of both features and wording — across
  the whole app. Avoid an overly complex system.
- **One consistent term** for a business entity people transact with: "Party" (never mix
  Customer/Vendor).
- **Terminology: "Receivable"** (Party owes DSP) / **"Payable"** (DSP owes Party) —
  not "Owes"/"Advance".
- **Dabar is a pure intake record, never a billing source** — all billing is calculated
  from Trip (outbound) data only, to avoid double-counting the same material on intake
  and output.
- **Historical Excel data stays as reference only** — not migrated; system starts empty
  and captures everything going forward.
- **English only for Release 1**; free-text fields accept Marathi Unicode from day one;
  Marathi UI is a deliberate Release 2.
- **Deliberate invoice-creation checkpoint retained** — a GST invoice is a legally
  sequenced document; rate/GST review before locking matters. (See Rules.md §Invoicing
  for the current auto-invoice design and why Job-Work stays manual.)
- **Never delete records with history** — Active/Inactive toggle instead, for Party,
  Vehicle, Machine (see Rules.md §Master Data Lifecycle).
- **Multi-user accountability** — created-by/last-edited-by tracking on every
  operational entry module (not master data, not Attendance).

## 6. Explicitly out of scope (for now)

- Multi-tenant self-serve SaaS signup/billing (Stage 2/3).
- Marathi UI (Release 2).
- Attendance payroll/wage computation (tracked as a known gap, not yet requested to fix).
- Water Tanker as a standalone module (dead table `water_tanker_logs`, removed from UI —
  covered by Vehicle Daily Log instead).

## 7. Bigger-picture aim

Eventually offer this to other crusher/construction businesses as SaaS. R.D. Samant
Contractors becoming a separate paying tenant of the same software (for his own business,
independent of DSP) is a live, unscoped idea — flagged as a strong Stage 2 lead since he's
already seen the software produce correct real invoices in production.

## 8. Cross-references

- **Rules.md** — the actual business logic (billing, payables, invoicing, master data
  lifecycle) in rule form.
- **AppFlow.md** — user journeys through the app.
- **Schema.md** — current database schema (generated from the live codebase, not this
  doc — keep in sync there).
- **Design.md** — visual/UX principles.
- **ImplementationPlan.md / Tracker.md** — build status.
