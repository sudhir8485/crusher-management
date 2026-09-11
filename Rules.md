# Rules.md — DSP Crusher Management: Business Rules Layer

A human-readable specification of the business logic. When a rule changes, it should be
changeable in ONE place in the codebase (the corresponding Service class) — if changing
one rule requires touching multiple modules, that's an architecture warning sign.

---

## SiteRules

- Site Type is OWN or CLIENT_SITE.
- CLIENT_SITE has a `linked_party_id` — the party billed for crushing/Job-Work at that
  site.
- OWN site: no linked party; machinery work tracked but never billed for crushing.

## TripRules

- `total_bill = material_amount + transportation_charge`, computed automatically at save.
- `material_amount = billable_quantity × sale_rate`.
- `transportation_charge`:
  - OWN_VEHICLE (party's own ad-hoc vehicle) → ₹0.
  - COMPANY + CALCULATE → distance_km × billable_qty × transport_rate_per_km.
  - COMPANY + DIRECT → user-entered value.
- **CLIENT_SITE material suppression:** IF trip's party = site's `linked_party_id` THEN
  `material_amount = 0`, `material_suppressed = true` — the party already owns the
  material; DSP only charges transport. Crushing value is billed separately via
  Job-Work, not duplicated here.
- **Auto-invoicing (see InvoiceRules §Trip Auto-Invoice):** total_bill > 0 → auto-invoice
  on save. total_bill = 0 → no invoice, no ledger entry.
- Trip quantity may separately be summed into a Job-Work invoice's auto-calculated
  quantity (see InvoiceRules §Job-Work) — this is independent of the trip's own
  auto-invoice status; a trip can be both auto-invoiced for its own bill AND counted
  toward a later Job-Work crushing-fee total. These are two different billing concerns
  (material/transport sale vs. periodic crushing-fee aggregation) and must never be
  coupled in code.

## DabarRules

- Dabar is a pure intake record. It NEVER drives invoice quantity — Job-Work's
  "Sum of Dabar Quantities" auto-calc source must not be used for billing (Trip
  Quantities only). This prevents double-counting the same material on intake and
  output.
- **Transport Payable eligibility** (based on the delivering Vehicle's Owner):
  - Vehicle Owner = TENANT (DSP's own) → NONE, no payable.
  - Vehicle Owner = VENDOR, and vehicle's owning Party = the Site's billed Party →
    NETS — no separate payable (already nets against that Party's receivable; would
    double-count otherwise).
  - Vehicle Owner = VENDOR, owning Party ≠ Site's billed Party → ELIGIBLE — create a
    Transport Payable (amount unset at creation; settled later, see PaymentRules).
- Vehicle owner auto-fills the Dabar entry's Party field when a vendor-owned vehicle is
  selected.

## MachineWorkRules

- Work Purpose: INTERNAL (no party, no billing, hours tracked only) or
  CUSTOMER_BILLABLE (party set, billed).
- Each Machine has one or more named **Work Types** (e.g. "Bucket", "Breaker",
  "Crushing"), each with an optional Default Rate ₹/hr and optional Default GST Rate +
  SAC code. Machine Work form derives Mode UI from the selected Machine's Work Types:
  0 types → no Mode UI; 1 → used silently; 2+ → toggle/chip selector.
- Rate resolution: auto-fills from the selected Work Type's default, shown as a normal
  editable field — no separate "Edit Rate" dialog or locked state. `rate_status` =
  PENDING only when genuinely no default exists AND left blank at entry; otherwise SET.
- **CUSTOMER_BILLABLE + rate SET** → auto-generates a GST Invoice immediately if the
  party is GST-registered (same pattern as Trip auto-invoice); if not GST-registered,
  debits the party's ledger directly, no invoice document.
- A Machine may have a `linked_vehicle_id` (see Master Data Lifecycle §Linked Assets) for
  dual-purpose assets (e.g. a tractor).

## DieselRules

Diesel has two separate meanings that must never be conflated in UI or logic:
**Operational** (how much diesel is physically available/used, per site) and
**Financial** (does this diesel movement change a Party's balance).

- **Stock is strictly per-site.** Ratnagiri's stock and Policewadi's stock (etc.) are
  never mixed or summed together.
- **Receipts — three Source types:**
  - PUMP or DIRECT → DSP bought it. Pure operating cost. No Party account touched.
  - PARTY_ADVANCE → a Party paid for diesel upfront. Auto-creates a VendorPayment
    (mode = DIESEL_ADVANCE) crediting that Party — reduces their Receivable / adds to
    what DSP owes them.
- **Usage — target ownership determines financial effect:**
  - TENANT-owned machine/vehicle → stock consumption only, no Party impact.
  - VENDOR-owned, with `rate_per_liter` set → auto-creates a VendorPayment
    (mode = DIESEL_CREDIT) — reduces what DSP owes that owning Party. `rate_per_liter`
    is a REQUIRED field whenever the selected vehicle/machine is External — a payable
    must never be silently skipped because the field was left blank.
- Both flows route through the same VendorPayment/net-settlement mechanism — no separate
  ledger. Deactivating a receipt/usage cascades to deactivate its linked payment.

## InvoiceRules

### GST Invoice (material sale)
- `invoice_no` = one continuous sequence `DSP/{FY}/{seq}` — no separate series per
  invoice type (historical `JW/...` numbers from before the merge stay as-is, not
  renumbered).
- GST rate resolution priority: explicit request rate → linked material's `gst_rate` →
  linked service's `gst_rate` → fallback placeholder with `gst_status = PENDING`.
- PENDING → SET via "Recalculate GST," which re-reads the master rate and locks it, with
  an audit trail (`gst_recalculated_by`, `gst_recalculated_at`, prior rate).
- GST invoices support mixed Material + Service line items on one invoice.

### Trip Auto-Invoice
- On Trip save: `total_bill > 0` and party GST-registered → auto-generate GST Invoice
  immediately. `total_bill > 0` and not GST-registered → direct ledger debit, no
  document. `total_bill = 0` → nothing.
- GST-unresolvable case still saves as PENDING (does not block the trip from saving).
- Applies going forward only — historical trips are never retroactively auto-invoiced.
- Must remain fully decoupled from `trip_jw_billing` (see Job-Work below) — auto-invoice
  logic never reads/writes it, and Job-Work's quantity calc never checks a trip's
  invoice status.

### Job-Work Invoice (crushing/periodic services) — the ONE deliberately manual flow
- Only CLIENT_SITE sites are eligible; party is auto-derived from
  `site.linked_party_id` and cannot be changed.
- Auto-quantity: if a Service has `auto_calc_source = TRIP_QUANTITIES`, sums unbilled
  trips' `billable_quantity` for the site + chosen period. (`DABAR_QUANTITIES` exists in
  schema but must not be used for billing — see DabarRules.)
- Included trips are marked in `trip_jw_billing` so they cannot be double-billed across
  invoices. Deleting/voiding the invoice releases them back to unbilled.
- **This remains fully manual, human-reviewed, period-based — no automation added here,
  even as Trip and Machine Work move to auto-invoicing.** The many-to-one aggregation
  over an operator-chosen period is inherently a judgment call that needs a human
  checkpoint.

## PaymentRules

- Every payment has an explicit **direction**: Received (party pays DSP, reduces
  Receivable) or Paid (DSP pays party, reduces Payable) — never inferred from amount
  sign or mode.
- Modes: CASH, BANK, CHEQUE, UPI (manual, either direction) + DIESEL_ADVANCE,
  DIESEL_CREDIT (auto-created by DieselRules, Paid/Received direction implicit in mode).
- A "Paid" payment may optionally link to a specific pending Transport Payable (settling
  it) — this link is informational/convenience, not required; an unlinked Paid payment
  still correctly reduces the Party's Payable balance.
- Deleting/editing a linked payment reverts the Transport Payable to unsettled.

## AccountRules (Party Ledger)

- **Single source of truth**, computed live — no separate ledger table.
- **Debits (increase Receivable):** GST Invoices, Job-Work Invoices, Machine Work
  (billable, rate SET, not already wrapped in a GST invoice).
- **Credits (reduce Receivable / build Payable):** Vendor Payments (all modes, both
  directions netted appropriately).
- **Info only, no amount:** Transport Payable, until settled via a linked Paid payment.
- **NOT in the ledger:** raw Trips before their auto-invoice fires, Dabar entries,
  Diesel usage (unless it created a DIESEL_CREDIT payment), Attendance, INTERNAL
  Machine Work.
- Terminology: "Receivable" (party owes DSP), "Payable" (DSP owes party) — never
  "Owes"/"Advance" in UI.

## Master Data Lifecycle Rules

- Party, Vehicle, Machine support **Active/Inactive** (never hard delete a record with
  history). Inactive records: hidden from all new-entry pickers by default, still
  render correctly on historical entries, reversible via a simple toggle.
- Deleting a record with historical references is blocked; Deactivate is offered
  instead.
- **Linked Assets:** a Machine may have a `linked_vehicle_id` (and vice versa) for one
  physical asset registered on both sides (e.g. a tractor used both as a hauling
  vehicle and as machine-mode equipment). Linking is reference-only — ownership, rates,
  and history stay fully independent per side; deleting a linked record while the link
  is active requires a warning, not silent removal.

## Audit Trail Rules

- Every operational entry module (Trip, Dabar, Diesel Receipts/Usages, Machine Work,
  GST Invoices, Job-Work Invoices, Vendor Payments) tracks `created_by` / `created_at`
  (immutable) and `last_edited_by` / `last_edited_at` (updates on every edit).
- Derived automatically from the authenticated session — never user-editable.
- Explicitly NOT applied to master data (Party, Vehicle, Machine, Material, Site,
  Service) or Attendance.
