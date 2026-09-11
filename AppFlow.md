# AppFlow.md — User Journeys

How a real user moves through the system to get their job done. Each flow states the
goal in plain language first, then the steps.

---

## 1. "A truck brought raw stone to the crusher" → Record Dabar

1. Dabar screen → Add Entry.
2. Pick Vehicle → Party auto-fills from the vehicle's owner (editable).
3. No. of Trips defaults to 1. Enter Quantity (unit shown inline).
4. If the vehicle is externally owned by a different Party than the site's billed
   owner, and DSP arranged this specific haul → toggle "Arranged by DSP" ON (creates a
   Transport Payable). Off by default.
5. Save. Pure record — no billing happens here (see Rules.md — DabarRules).

## 2. "A truck left with crushed material for a party" → Record Trip

1. Trips screen → Add Trip.
2. Pick Vehicle, Material, Party (or it's auto-derived if this is a Client Site trip
   billing the site's own owner), enter weighbridge readings or direct quantity.
3. Transportation auto-calculates (or ₹0 for OWN_VEHICLE / suppressed cases).
4. Save. **The bill is now already computed and, going forward, auto-invoiced
   immediately if the party is GST-registered** (see Rules.md — Trip Auto-Invoice) —
   no separate manual invoice step for a normal trip.

## 3. "A machine worked today" → Record Machine Work

1. Machine Work screen → Add Entry.
2. Pick Machine → Mode (Work Type) UI adapts to that machine (none/silent/toggle).
3. Internal (own-site work, no billing) or Customer Billable (pick Party; Rate
   auto-fills from the Work Type's default, editable).
4. Save. If Customer Billable and rate is SET and party is GST-registered → invoice
   auto-generates immediately, same as Trip.

## 4. "Samant gave us diesel" / "We gave diesel to someone's vehicle" → Diesel

- **Received, Party Advance:** Diesel → Received tab → Add Receipt → Source: Party
  Advance → pick Party, enter amount → diesel added to that site's stock AND an advance
  credit posts to the Party's account.
- **Used, external vehicle:** Diesel → Used tab → Add Usage → pick vehicle/machine →
  if externally owned, Rate/Litre is required → diesel deducted from stock AND a credit
  automatically reduces what DSP owes that Party.

## 5. "I need to bill Samant for this period's crushing" → Job-Work Invoice

*(The one deliberately manual, human-reviewed flow — see Rules.md.)*

1. Invoices screen → New Invoice → Job-Work Invoice.
2. Pick the Client Site (party auto-locks to the site's linked owner).
3. Pick the billing period. Line items with `auto_calc_source = TRIP_QUANTITIES` show
   an auto-calculated quantity, with a drill-down of exactly which trips were summed —
   manual override still available.
4. Review the preview. Create Invoice. Included trips are marked billed (see
   `trip_jw_billing`) so they can't be double-billed by a future invoice.

## 6. "How much does Samant owe me? How much do I owe him?" → Accounts

1. Accounts → pick Party (e.g. R.D. Samant).
2. See Receivable (he owes DSP) or Payable (DSP owes him) at the top.
3. Ledger below: one consistent, collapsed row per entry (Sales, JobWork, MachineWork,
   TransportPayable, Payment). Tap any entry to open it in its real home module for
   editing — Accounts itself never edits anything directly.
4. Record Payment → choose direction (Received / Paid) → for Paid, optionally link a
   pending Transport Payable to settle it.

## 7. "I need to print/export data for a period" → Reports

1. Reports screen → pick the entity tab (Trips, Dabar, Diesel, Machine Work, etc.).
2. Set filters relevant to that entity + a date range.
3. Load → Print or Export to Excel.
4. (For a single GST invoice specifically: print directly from the Invoices module,
   not Reports — a real tax-document layout, not a filtered report.)

## 8. "What's happening today, at a glance?" → Dashboard

Owner/Admin opens Dashboard: revenue and cost trend graphs, today's key numbers
(trips, production, collections), and a short "needs attention" list (unpaid invoices,
low diesel, pending payables) — decisions, not decoration. No filtering/configuration
here; that's Reports' job.

## 9. "Who entered/changed this?" → Audit Trail

Any operational entry's detail view (Trip, Dabar, Diesel, Machine Work, Invoice,
Payment) shows "Created by [Name] on [date]" and, if edited since, "Last edited by
[Name] on [date]" — pulled automatically from the logged-in user, never manually set.
