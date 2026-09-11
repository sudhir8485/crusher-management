# Design.md — Visual & UX Principles

This is a living document. A full visual-design pass (design system, Impeccable or
similar tooling) is deliberately deferred until functional/business-logic work settles
— see ImplementationPlan.md. What's below governs decisions made along the way so far.

---

## 1. Product principles (non-negotiable, client-stated)

- **Simplicity, plain language, consistency** — of both features and wording — across
  the whole app. Avoid an overly complex system. Target user is non-technical field/
  office staff.
- **One term per concept, used everywhere.** "Party" not Customer/Vendor. "Receivable"/
  "Payable" not Owes/Advance.
- **Cheap, reversible mistakes.** Prefer Active/Inactive toggles over deletion. Prefer
  Cancel/void with a clear warning over silent data loss.
- **Pick-from-list, not free-type**, wherever a master record exists for the thing
  being entered.
- **Live calculations, shown before save**, not computed only after.
- **Hide optional fields by default**; surface them progressively.
- **Auto-fill what the system already knows** (e.g. Party from Vehicle Owner) — but
  only where the inference is genuinely unambiguous. Where real ambiguity exists (e.g.
  Dabar's "was this haul arranged by DSP"), ask explicitly rather than guessing — see
  Rules.md for the specific cases this applies to.

## 2. Navigation & consistency patterns established so far

- **Period browsing:** Day / Week / Month / Year / Custom tabs, backend-aggregated (no
  client-side summing), applied consistently across Trips, Diesel, (Dabar and Machine
  Work pending — see Tracker.md).
- **List screens:** search bar + filter chips + a running summary strip, consistent
  shape across Trips/Dabar/Diesel.
- **Detail/drill-down:** every list row is collapsed by default (label, key numbers,
  running balance where relevant); tap to expand full detail. No sprawling inline
  detail cluttering the list.
- **One edit surface per entity.** No parallel "quick edit" paths — e.g. Machine Work's
  rate is edited via the single normal Edit form, never a separate "Edit Rate" dialog.
  Accounts/Ledger never edits anything itself; it navigates to the entity's home module.
- **Back-navigation preserves state** (scroll position, selected period/filters) when
  navigating away to an entity's home module and returning.

## 3. Error handling (a known gap — see Tracker.md)

Errors should speak business language, not technical language:
- ❌ "HTTP 409 Conflict" → ✅ "This invoice has already been created."
- ❌ "Foreign key constraint violation" → ✅ "This vehicle is used in existing trips
  and can't be deleted — deactivate it instead."
- ❌ "Validation failed" → ✅ "Please enter the quantity."

## 4. Destructive actions

Always a clear confirmation naming the specific consequence, e.g. "This trip is already
included in an invoice — deleting it may affect billing," not a generic "Are you sure?".
GST/Job-Work Invoices specifically use Cancel/void (not delete/edit) given their status
as sequential legal documents — this is intentional, not a missing feature.

## 5. Terminology reference (keep in sync with Rules.md)

| Avoid | Use |
|---|---|
| Owes | Receivable |
| Advance (as a party-balance term) | Payable |
| Customer / Vendor | Party |
| (raw DB/enum values shown to users, e.g. "Ownership Type: EXTERNAL") | Plain labels — vehicle/machine name + owning Party's name |

## 6. Deferred to the later design phase (not yet started)

- Unified visual language / design system (typography, spacing, component rules) across
  every screen.
- Dashboard rebuild: revenue/maintenance trend graphs + "needs attention" highlights,
  decision-oriented, no configuration.
- Reports rebuild: one tab per entity (Trips, Dabar, Diesel, Machine Work, Attendance),
  consistent filter pattern per entity, Print + Excel export for each — ledger export
  already sufficient via Accounts; GST invoice gets its own real print layout from the
  Invoices module, not a Reports tab.
- Broader navigation restructuring toward task-oriented framing was proposed externally
  (see project notes) — deliberately NOT adopted yet; current module-based navigation
  stays as-is until functional work is done, given past experience that large
  screen-merges (Invoices/Job-Work) introduced real bugs.
