# DSP Construction — Ratnagiri Site Digital System
## Master Project Reference

**Prepared by:** Sudhir
**Date:** 29 August 2026
**Purpose:** Consolidated reference for all product, technical, business, and support decisions made to date. Written to be carried into terminal-based development (Claude Code) as project context — keep this file in the repo root (e.g. `PROJECT_REFERENCE.md`) and update it as decisions evolve.

---

## 1. Project Overview & Business Context

**Client:** DSP Construction — Ratnagiri site
**Vendor:** R.D. Samant — a transport & machinery contractor whose vehicles and machines work at DSP's site. Not a separate paying client; a vendor *within* DSP's data.

### How the business works
- Raw boulder ("**Dabar**") is brought to the crusher by vendor vehicles. Each vehicle's trip count for the day is logged (**"Kopa" = trips**), with a running total.
- The crusher processes Dabar into sized material — 20mm, 30mm, GSB, etc.
- Sized material is transported out for sale/delivery — logged with loading location, unloading location/channel, material, size, quantity (Brass), vehicle, and **both DSP's and the vendor's challan numbers** (dual challan, because both sides bill off the same trip).
- Machines (JCB, Comosko, etc.) do site work — tracked via opening/closing hour-meter readings, with a bucket or breaker attachment mode.
- Vehicles run on diesel bought by **either DSP or the vendor** — both sources must be tracked, alongside how much diesel each vehicle actually used.
- Some vehicles (e.g. a water tanker) are logged as a combined daily record: location, odometer reading, KM, day/night trip counts, and diesel — all in one entry.
- All of the above rolls up into a **Daily Report** — the document the site actually runs on day to day; this is the product's spine, not an afterthought.
- Periodically, DSP issues a GST invoice for material sold and settles payments with the vendor.

### Design principle: built for one client now, ready for more later
The platform is architected multi-tenant from day one (see Section 7), even though DSP is the only paying client today. This is a deliberate cost/time tradeoff made early because retrofitting multi-tenancy later is expensive; adding it now is cheap.

---

## 2. Product Scope & Phasing

**Decision (updated): build the website first, mobile app second** — reversed from the original app-first plan.

| Phase | Scope |
|---|---|
| **Phase 1 — Website** | Browser app covering all core modules: Dabar intake, transportation/sale trips, machine work, diesel (both sources), vehicle daily logs, attendance, dashboard. Interim framing: the **office digitizes what's still collected on paper at the site** — real value (live dashboard, Daily Report, GST invoices) from day one, without waiting on the field workflow |
| **Phase 2 — Mobile App** | Same backend/codebase, screens rebuilt/adapted for field use — pushes data entry out to the site itself, removing the paper step entirely |

**Tradeoff to keep in mind:** the original pain point (replacing paper/Excel at the point of use) isn't solved until Phase 2 ships. Build every Phase 1 screen mobile-responsively from day one regardless — Flutter's adaptive layout makes this cheap now and expensive to retrofit later.

### Language
- **Release 1: English only.** All app text lives in an external strings file (Flutter `.arb` files / Spring Boot message properties) — nothing hardcoded into screens.
- Free-text fields (locations, remarks, work descriptions) accept **Unicode Marathi from day one** at no extra cost — field staff can type Marathi even in the English-UI release.
- **Release 2** (after Phase 1 is proven): Marathi UI added by translating the existing strings file — not rebuilding screens.

### Historical data
- Existing Excel registers (Oct 2025 onward) stay exactly where they are, as an **archived reference only**.
- The system starts empty and captures everything **going forward** from go-live. No migration in Phase 1.
- Known data-quality issues in the old sheets that make migration nontrivial (for future reference, if migration is ever revisited): dates typed as text, blank date cells meaning "same as row above," inconsistent spelling across months/files.

---

## 3. Technology Stack

| Layer | Choice | Reason |
|---|---|---|
| Mobile app | **Flutter** (Android first) | Same codebase later produces the website (Flutter Web) with minimal rework |
| Website (Phase 2) | **Flutter Web** | Built from the same codebase as the app |
| Backend / API | **Java (Spring Boot)** | Business logic, calculations, data rules — matches core skill set |
| Database | **PostgreSQL** | Unicode-safe (Marathi-ready); supports Row-Level Security (critical — see Section 7) |
| Auth | **JWT**, role-based | Token carries `tenant_id` and `role`; never trust a tenant ID sent from the client |

---

## 4. Master Data Model

| Entity | Scoped by | Notes |
|---|---|---|
| Tenant (business account) | — | DSP Construction is tenant #1; architecture supports more |
| User | `tenant_id` + `role` | See Section 7.2 for roles |
| Vendor | `tenant_id` | R.D. Samant is vendor #1 under DSP; not hardcoded as the only one |
| Vehicle | `tenant_id` | Includes owner flag (DSP-owned vs. vendor-owned) — drives diesel-source logic |
| Machine | `tenant_id` | JCB, Comosko, etc. |
| Material / Size | `tenant_id` | e.g. 20mm, 30mm, GSB; unit = Brass |
| Site | `tenant_id` | Ratnagiri to start; model supports additional DSP sites later |

---

## 5. Functional Modules

### 5.1 Dabar / Raw Material Intake
| Field | Notes |
|---|---|
| Date | Defaults to today |
| Vehicle | Linked to vehicle master |
| Trips (Kopa) | Number of trips that vehicle made that day |
| Running total | Calculated automatically, per day and cumulative |

### 5.2 Transportation / Material Sale (outgoing)
| Field | Notes |
|---|---|
| Date | |
| Loading location | Where material was loaded |
| Unloading location / Channel No. | Where material was delivered |
| Material & Size | e.g. 20mm, 30mm, GSB |
| Quantity (Brass) | |
| Vehicle | Linked to vehicle master |
| DSP Challan No. | DSP's own challan/reference number |
| Vendor Challan No. | The vendor's challan/reference number for the same trip |

### 5.3 Machine Work
| Field | Notes |
|---|---|
| Date | |
| Machine | Linked to machine master |
| Work description | Free text (Marathi-capable) |
| Mode | Bucket or Breaker |
| Opening / Closing reading | Hour-meter readings |
| Total hours | Calculated: Closing − Opening |

### 5.4 Diesel (dual-source stock ledger)
| Register | Field | Notes |
|---|---|---|
| Received | Date, **Source (DSP / Vendor)**, Liters, Rate, Amount | Adds to that source's diesel stock |
| Used | Date, Vehicle, Liters | Deducts from stock; the vehicle's owner (DSP/vendor) determines which balance it's checked against |
| Balance | Running total, by source | Shows how much diesel stock DSP vs. the vendor currently holds |

### 5.5 Vehicle Daily Log (for vehicles logged individually, e.g. water tanker)
| Field | Notes |
|---|---|
| Date, Vehicle | |
| Loading / Unloading location | |
| Opening / Closing reading, Total KM | Calculated: Closing − Opening |
| Trips — Day / Night | Separate counts |
| Diesel / Other note | Free text (Marathi-capable) |

### 5.6 Daily Report
Per-day, per-vehicle rollup pulling from all modules above — loading/unloading location, reading, KM, trip counts, diesel. **Build this early** — it's the single most-used view on site, not a report bolted on at the end.

### 5.7 GST Invoice
Matches DSP's existing invoice format (business details, GSTIN, line items, totals).

### 5.8 Vendor Payments / Ledger
Tracks what DSP owes the vendor (trips × rate, machine hours × rate) and what's been paid, including diesel-related adjustments where DSP-supplied diesel offsets vendor payment. **Exact formula pending client confirmation — see Section 9.**

### 5.9 Dashboard & Reports
- Live daily trip counts by vehicle and by vendor
- Diesel stock balance, DSP side and vendor side
- Machine hours by machine, by period
- Vendor payable / DSP receivable summary

### 5.10 Employee Attendance
**Scope confirmed: DSP's own staff only** — not vendor labor. No GPS/photo verification needed.

**Employee (master data)**
| Field | Notes |
|---|---|
| Name | |
| Designation | Office staff, Site Supervisor, Driver, Operator, etc. |
| Wage type | Daily / Monthly |
| Wage rate | Per day or fixed monthly amount |
| Status | Active / Inactive |

**Attendance entry**
| Field | Notes |
|---|---|
| Date | Defaults to today |
| Employee | Linked to Employee master |
| Status | Present / Absent / Half-day / Leave |
| Marked by | The supervisor who recorded it |

Capture method: **supervisor marks a daily list** — one screen showing all active employees for the day, quick tap per person to set status. Not a per-employee "add attendance" form. Only Supervisor/Office/Admin roles can mark attendance — an employee never marks their own.

---

## 6. Automatic Calculations

- Dabar running trip total = sum of Kopa entries per vehicle, per day and cumulative
- Machine work total hours = Closing Reading − Opening Reading
- Vehicle daily log total KM = Closing Reading − Opening Reading
- Diesel amount (Received) = Liters × Rate
- Diesel balance (by source) = Total Received − Total Used
- Vendor payable = (Trips × Rate) + (Machine Hours × Rate) − agreed diesel adjustments − Paid Amount *(exact formula pending Section 9)*
- Wage payable (daily-wage staff) = (Present days × Daily rate) + (Half-day count × 0.5 × Daily rate)

---

## 7. Multi-Tenant Architecture & Data Isolation

Three distinct layers — do not conflate them:

| Layer | Question it answers |
|---|---|
| Tenant isolation | Can Client A ever see Client B's data? |
| Role-based access | Within one client, who can see/do what? |
| Vendor-level scoping | Is data correctly attributed to the right vendor within one client's account? |

### 7.1 Tenant isolation — two independent enforcement layers

**Never rely on "remember to filter by tenant_id in every query" alone** — one missed `WHERE` clause causes a cross-client data leak.

1. **Application-level automatic filtering.** JWT carries `tenant_id`, taken from the verified token server-side — never from client input. Use a base repository/service pattern (Hibernate filters in Spring Data JPA) so scoping is applied automatically, not manually re-added per screen.
2. **PostgreSQL Row-Level Security (RLS).** Attach a policy to every tenant-scoped table so the database itself refuses to return rows outside the current session's tenant — enforced by the database engine, independent of application code. This is the safety net that catches bugs in layer 1.
3. **Automated cross-tenant test, run in CI forever.** Log in as Tenant A, deliberately attempt to fetch Tenant B's data by ID, assert it always fails. This is the kind of bug that's invisible until it destroys a client relationship — verify it continuously, not just once at launch.

### 7.2 Role-based access (within one tenant)

| Role | Access |
|---|---|
| Owner/Admin | Everything — all modules, reports, user management, payments |
| Office/Accountant | Trips, diesel, machine work, invoices, payments — not user management |
| Site Staff | Data entry only (trips, diesel, machine work) — no payments/invoices/reports |

Enforce at the API layer (Spring Security `@PreAuthorize`), not just by hiding UI buttons.

### 7.3 Vendor-level scoping (correct attribution, not security isolation)

- Trip, Diesel, Machine Work, and Payment records carry both `tenant_id` and `vendor_id`.
- All still belongs to DSP's tenant — DSP staff see all vendors. This buys accurate vendor-wise reporting (R.D. Samant's numbers cleanly separate from any future vendor), not security isolation.
- **If a vendor is ever given their own login** (e.g. R.D. Samant checking their own trip/payment status), that becomes real isolation: filter by `tenant_id` AND `vendor_id` — same RLS mechanism, one more condition.

### 7.4 Scoping summary table

| Table | Scoped by |
|---|---|
| Users | `tenant_id` + `role` |
| Vehicle, Machine, Material, Site | `tenant_id` |
| Vendor | `tenant_id` |
| Trip, Diesel, Machine Work, Payment | `tenant_id` **+** `vendor_id` |

---

## 8. Development Milestones

*(Website-first order — see Section 2. All screens built mobile-responsive regardless.)*

| Milestone | Delivers | Rough duration |
|---|---|---|
| M1 | Login, Site, Vendor, Vehicle, Machine, Material master data — web screens | 1–2 weeks |
| M2 | Transportation / Material Sale trip entry (dual challan) + Daily Report view | 2 weeks |
| M3 | Dabar intake entry + Vehicle Daily Log | 1–2 weeks |
| M4 | Diesel — Received & Used, dual source, running balance | 1–2 weeks |
| M5 | Machine Work entries | 1 week |
| M6 | GST Invoice + Vendor Payments/Ledger | 1–2 weeks |
| M7 | Dashboard & Reports, client testing, fixes | ongoing |
| M8 | Employee Attendance (master data, daily marking, wage calc) | 1 week — independent, can run parallel to M2–M7 |
| Phase 2 | Mobile app (same backend/codebase, field-optimized screens) | after Phase 1 is live |

Payment structure: tie the one-time development fee to these milestones, not a single lump sum (see Section 12).

---

## 9. Open Questions to Confirm with DSP

- Exact vendor payment formula — how do trips, machine hours, and DSP-supplied diesel combine into what's owed to the vendor?
- GST invoice numbering rule — continue the existing sequence, or start fresh?
- Is R.D. Samant the only vendor expected, or should onboarding others be expected soon?
- Who enters the Daily Report in practice — site supervisor, or compiled in the office from vehicle-level entries?
- Reliable internet at the Ratnagiri site, or does entry need offline support with later sync?
- Is Brass the only unit used, or is some material also sold/measured in tonnes?

---

## 10. Out of Scope for Phase 1

- Marathi UI (English only in Release 1)
- Migrating historical Excel data (kept as reference only)
- iOS app (Android only)
- Additional DSP sites beyond Ratnagiri (data model supports it, not built/tested in Phase 1)
- Offline mode, unless Section 9 confirms it's required

---

## 11. Deployment & Infrastructure Cost

*(Figures checked live as of Aug 2026 — re-verify before quoting if significant time has passed.)*

### One-time
| Item | Cost | Notes |
|---|---|---|
| Google Play Developer account | $25 (one-time) | Register as **Organization**, not Personal — needs a D-U-N-S number, start early |
| Domain (year 1) | $10–20 (.com) or cheaper (.in) | |
| SSL certificate | $0 | Let's Encrypt, free & auto-renewing |

### Recurring (monthly)
| Item | Cost | Notes |
|---|---|---|
| Backend server (Spring Boot + Postgres, self-hosted, single VPS) | $12–24/mo | 2GB RAM tier is the practical minimum for reliability — don't go smaller to save money |
| Backups/snapshots | ~$1–2/mo | |
| Domain renewal (averaged monthly) | ~$1–2/mo | |

**Total: ~$35–45 one-time + ~$14–28/month.** Free during dev/test if using a cloud provider's trial credit.

### Ownership — the key cost-minimization lever
**Register the Play Store account, domain, and hosting account in DSP's name, with DSP's own payment method** — not Sudhir's. This makes Sudhir's own out-of-pocket investment $0, and gives DSP ownership of their own infrastructure (a trust point, not just a cost trick). Fallback if DSP wants it "handled": bill hosting as a clean, itemized monthly pass-through, always separate from the development fee.

---

## 12. Business / Money Model

Two revenue streams, not one:

1. **One-time development fee** — tied to milestones M1–M7 above.
2. **Recurring subscription** — hosting, maintenance, updates, support, starting from go-live, continuing indefinitely.

### Why recurring matters more than the one-time fee
- The multi-tenant-ready architecture only pays off if each *additional* client is mostly margin — recurring revenue is what makes that real.
- Ongoing responsibility (uptime, bug fixes, support) is ongoing cost of time — should be ongoing revenue, not absorbed for free post-launch.

### Pricing
- **One-time fee:** priced against real milestone work; avoid quiet underpricing — if giving a "founding client" discount, name it explicitly.
- **Subscription:** ₹3,000–6,000/month for a single-site client — comfortably covers hosting (~₹1,150–2,300) with margin for ongoing time, and reads as a normal small-business software cost.

### Included vs. billed separately
| Included in subscription | Billed separately (quoted per request) |
|---|---|
| Hosting, uptime, backups | New modules/screens beyond scope |
| Bug fixes | Marathi UI release |
| Minor tweaks | Additional sites/vendors beyond v1 scope |
| Phase 2 website (same platform) | Custom reports not in the requirements doc |

### Scaling to more clients
- New clients cost mostly *onboarding time*, not *development time* — the platform already exists.
- Infrastructure cost grows slowly (one small VPS serves several small-business tenants before needing to scale).
- Effective return per client rises over time — opposite of one-off freelance work.

### Mechanics
- Bill the one-time fee per milestone.
- Start subscription billing from go-live (M7/launch), not from day one of development.
- Put both in a written agreement: what's one-time, what's recurring, what counts as new scope vs. included maintenance.

---

## 13. Client Support Plan

### 13.1 Infrastructure support (included)
- Uptime monitoring (e.g. free tier of UptimeRobot)
- OS/Postgres/dependency security patching over time
- Verifying backups are actually restorable, not just "completed"
- Domain/SSL renewal tracking

### 13.2 Bug support (included)
- Wrong calculations, crashes, data not saving correctly — fixed at no extra charge.
- Distinct from new-feature requests (billed separately, Section 12).

### 13.3 User support (included, but budget real time for it)
- Password/login issues, "how do I enter X," basic troubleshooting.
- **Mitigation:** build a one-page cheat sheet or short screen-recording per core screen (Trip, Diesel, Daily Report) — cuts repeat questions substantially. Consider Marathi even though the UI is English.

### 13.4 Data recovery support
- Accidental deletion/mis-entry — restore from backup or correct the record; keep simple corrections included.
- A *pattern* of repeated "undo my entries" requests signals a training gap — fix with better in-app validation or training material, not repeated manual fixes.

### 13.5 Explicitly NOT included
- New modules/screens outside original scope
- Marathi UI release
- Additional sites/vendors beyond v1
- Custom reports beyond the requirements doc
- Historical data migration, if requested later

### 13.6 Response time SLA (set explicitly, in writing)
| Severity | Response target |
|---|---|
| Critical (app down, can't log trips) | Same business day |
| Important (a feature broken, workaround exists) | 1–2 business days |
| Minor (typo, small UI issue) | Next scheduled update |

Support hours: business days only — state this plainly, especially given Sudhir may move into full-time employment alongside this.

### 13.7 Proactive touchpoint
Short monthly/quarterly update to DSP ("here's what's been fixed/updated, any issues?") — catches small problems early, and reinforces subscription value ahead of renewal or when using DSP as a reference for future clients.

---

## 14. Product & Go-to-Market Roadmap

**Aim:** turn this into a startup/SaaS product — many businesses (not just DSP) manage their paperwork on it, offered via free trial converting to paid purchase. **Current stage: Stage 1.** Don't skip ahead — building self-serve SaaS machinery before DSP is live and happy is the main risk to avoid.

### Three stages

| Stage | What it is | Onboarding |
|---|---|---|
| **1. Prove it** *(current)* | DSP's app, built well, actually used daily | Just DSP — built/configured by hand |
| **2. Validate it** | Same platform, offered to a handful more businesses | Personally onboarded (sales call → manual tenant setup) — no self-serve yet |
| **3. Scale it** | Real self-serve SaaS | Automated signup, trial, billing |

### What's already correct for this (keep holding the line)
- Nothing DSP-specific is hardcoded — "Dabar/Kopa" etc. stay as DSP's own labels, but the underlying concept (module, fields, calculations) is generic and tenant-configurable.
- A `tenant_modules` toggle table (enable/disable modules per tenant) is worth building now — not every future business will have a "crusher" concept, but most will have vehicles, trips, diesel, payments.

### Stage 2 needs (build when DSP is stable, not before)
- Simple internal admin tool (for Sudhir) to create a new tenant, set modules, invite first user — not public-facing.
- Sales via personal outreach/industry network + DSP as a working reference — not a marketing site yet.
- Trial period tracked manually (e.g. a `trial_expires_at` field, checked by hand) — no automated trial-expiry logic yet.

### Stage 3 needs (plan for, don't build yet)
- Self-service signup with auto-provisioned tenants.
- Payment gateway with subscription billing — **Razorpay** (UPI + cards + Subscriptions API) fits the Indian SMB market best.
- Automated trial gating: after trial ends, prompt payment and drop to **read-only** (not fully locked — losing visibility into your own data feels punitive).
- A real marketing site, separate from the app — this is when product naming/branding actually matters.

### Pricing direction (anchor, not final)
| Tier | Roughly for | Price anchor |
|---|---|---|
| Starter | Single site, few vehicles | ~₹3,000–4,000/mo |
| Growth | Multiple vehicles/vendors | ~₹6,000–8,000/mo |
| Business | Multiple sites | custom/negotiated |

DSP's actual usage over the coming months is the real pricing research — don't lock tiers in from guesswork.

### Business/legal — needed before Stage 3, not before Stage 1
- Registered business entity (minimum: sole proprietorship + GST registration) — construction-industry clients expect GST-compliant billing from their vendors too.
- Terms of Service + Privacy Policy once holding multiple unrelated businesses' data (India's DPDP Act applies).
- A product name distinct from any client's or reference app's branding — needed once customer-facing, not needed yet for DSP's own build.

---

## 15. Design Principles — Simplicity & Usability

**Why this matters here specifically:** the target users are non-technical, and simplicity is directly tied to trial-to-purchase conversion for the startup goal in Section 14. All backend complexity (multi-tenancy, RLS, roles, dual challan/diesel logic) must stay completely invisible to the user.

1. **One consistent screen shape everywhere** — list of today's entries, one "+" button always in the same place, tap an entry to edit. No module gets a special layout.
2. **Pick from a list, never type from memory** — every field with master data behind it (Vehicle, Vendor, Material, Machine, Employee) is a tap-to-select picker, not free text. Prevents typo-driven data corruption as a side effect.
3. **Show calculations live** — Amount fills in as Quantity/Rate are typed, not after Save. Builds trust through visibility, not explanation.
4. **Use their own vocabulary** — "Dabar," "Kopa," "Payments to R.D. Samant," not generic software terms like "Raw Material Intake" or "Vendor Ledger." Zero new vocabulary to learn.
5. **Make mistakes cheap and reversible** — editing a past entry is as easy as adding one; confirmation dialogs only for genuinely destructive actions (e.g. delete), not everywhere; clear "saving... will retry" states instead of cryptic errors on a dropped connection.
6. **Hide optional fields by default** — put rarely-used fields (e.g. ETP No., Discount) behind a "More details" expander; keep the default form to the 4–5 fields filled in every time.
7. **Guided first-run setup** — "Add your first vehicle" → "Add your first vendor" → done, on first login. Matters especially for trial conversion: the first 10 minutes matter more than raw feature count for a non-technical evaluator.
8. **Test on someone who isn't you** — before go-live, watch an actual site supervisor try to use it unassisted. Wherever they hesitate is the real simplification list.

---

## 16. Next Steps

1. Confirm open questions in Section 9 with DSP.
2. Finalize the written agreement covering: milestone-based development fee, recurring subscription scope/price, support SLA (Section 13.6).
3. Set up DSP-owned accounts (domain, hosting now; Play Store deferred until closer to Phase 2 mobile release — see Section 2).
4. Begin M1 (master data + auth), building `tenant_id` scoping and RLS in from the first migration — not retrofitted later.
5. Hold every new screen against the Section 15 checklist before considering it done.
6. Keep this document updated as decisions evolve; it is the source of truth carried into implementation.
