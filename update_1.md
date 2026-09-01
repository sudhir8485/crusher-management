You are working on an existing software project called "Site Manager" / "Crusher Management".

IMPORTANT:
Do NOT treat this as a simple UI redesign.
This is a real-world site/crusher management application that will be used for daily operational work, accounting, vehicle management, material tracking, diesel tracking, machine work, attendance, invoices, payments, and ledgers.

Your job is to thoroughly inspect the existing codebase, understand the current architecture and data relationships, and then improve the application without unnecessarily breaking existing functionality.

==================================================
1. FIRST: UNDERSTAND THE EXISTING APPLICATION
==================================================

Before changing code:

1. Inspect the complete project structure.
2. Identify:
   - frontend framework
   - backend
   - database
   - API structure
   - state management
   - routing
   - reusable components
   - form components
   - modal/dialog components
   - tables/lists
   - existing validation
   - existing calculations
   - authentication/user system
   - existing export/print functionality
3. Understand all existing database models/tables and their relationships.
4. Understand how:
   - trips
   - vendors
   - vehicles
   - materials
   - diesel
   - machine work
   - invoices
   - payments
   - attendance
   - vehicle logs
   - users
   - reports
   are connected.

DO NOT create duplicate models or duplicate business logic if equivalent functionality already exists.

Do not blindly rewrite the application.

First understand what already works, then improve it.

==================================================
2. CURRENT APPLICATION MODULES
==================================================

The current application contains these major sections:

- Dashboard
- Trips
- Daily Report
- Dabar (Raw Stone Intake)
- Water Tanker
- Diesel
- Machine Work
- GST Invoices
- Vendor Payments
- Attendance
- Vehicle Daily Log
- Users
- Ledger / financial reporting should be added or significantly improved

The application is intended for crusher/site operations.

==================================================
3. PRIMARY GOAL
==================================================

The #1 priority is:

EXTREMELY USER-FRIENDLY UI/UX.

The user should be able to operate the software quickly from a laptop, desktop, tablet, and eventually mobile.

The application should feel:

- simple
- clean
- professional
- fast
- predictable
- easy to learn
- visually organized
- consistent
- forgiving of user mistakes
- suitable for non-technical site staff
- suitable for accountants
- suitable for management/owners

Do not make the UI unnecessarily fancy.

Prioritize usability over visual effects.

A person should be able to look at a screen and immediately understand:

1. What page am I on?
2. What information is shown?
3. What happened today?
4. What action can I perform?
5. Where do I add something?
6. What does each number mean?
7. What is the current balance/status?

==================================================
4. VERY IMPORTANT: FIX THE CURRENT UI PROBLEMS
==================================================

The screenshots show serious layout problems that MUST be fixed.

There are visible Flutter/web-style overflow warnings:

- "BOTTOM OVERFLOWED BY 242 PIXELS"
- "RIGHT OVERFLOWED BY 24 PIXELS"

These are not acceptable in production.

There must be ZERO overflow warnings.

Audit every page and every modal/dialog.

Pay particular attention to:

- sidebar
- bottom navigation/sidebar items
- dialogs
- forms
- date selectors
- long forms
- invoice creation
- dropdowns
- tables
- cards
- action buttons
- small laptop screens
- browser zoom
- different screen sizes

==================================================
5. RESPONSIVE DESIGN
==================================================

The application must work correctly at:

- 1366x768
- 1440x900
- 1600x900
- 1920x1080
- tablet widths
- smaller laptop screens
- mobile widths where applicable

Never allow content to simply extend outside the viewport.

For long pages:

- page content should scroll
- dialogs should have internal scrolling
- headers/actions should remain accessible
- Save/Cancel buttons should remain reachable
- important fields should never be hidden below the viewport

For dialogs:

Use a maximum width and maximum height.

Example behavior:

Dialog
--------------------------
Title
--------------------------
Scrollable form area
Scrollable form area
Scrollable form area
--------------------------
Cancel       Save
--------------------------

The footer buttons must always remain visible.

Do NOT make the entire browser page unusable because a modal is too tall.

For very long forms, divide the form into logical sections.

==================================================
6. SIDEBAR IMPROVEMENT
==================================================

The current sidebar contains many items and overflows at the bottom.

Fix this completely.

The sidebar should:

- fit all menu items
- scroll internally when necessary
- keep the Site Manager logo/title at the top
- keep user/account controls organized
- never overflow
- maintain the selected-page state
- clearly show active navigation
- use consistent icons
- have tooltips if collapsed
- support responsive/collapsed mode if practical

Do not simply reduce font size until everything fits.

Instead implement proper scrolling/layout.

Suggested structure:

Site Manager
----------------
Dashboard
Trips
Daily Report
Dabar
Water Tanker
Diesel
Machine Work
Invoices
Payments
Attendance
Vehicle Log
Ledger
Users
Settings
----------------
User/Profile

If Settings or other existing pages already exist, preserve them.

==================================================
7. DESIGN SYSTEM
==================================================

Create one consistent design system and reuse it everywhere.

Use consistent:

- typography
- spacing
- card radius
- button radius
- input height
- border style
- shadows
- colors
- icon sizes
- section headings
- dialog sizes
- date controls
- empty states
- loading states
- error states
- success messages

Do not design each screen independently.

The following should look like the same application:

- Add Trip
- Add Dabar Entry
- Add Water Tanker Log
- Add Diesel Receipt
- Add Machine Work
- New GST Invoice
- Record Payment
- Attendance
- Vehicle Daily Log

==================================================
8. FORMS — MAKE THEM EXTREMELY EASY
==================================================

The current forms are functional but can be improved substantially.

Every form should:

- clearly distinguish required vs optional fields
- show labels
- use sensible defaults
- validate input immediately where appropriate
- show useful validation messages
- prevent invalid numbers
- prevent impossible dates
- avoid unnecessary typing
- use dropdowns when selecting existing entities
- use autocomplete/search for long lists
- automatically calculate values where possible
- preserve entered data when validation fails
- clearly show Save/Cancel
- show loading state while saving
- prevent duplicate submissions
- show success/error feedback

Do NOT use placeholder text as the only label for important fields.

Use proper labels.

Example:

BAD:
[ Quantity (Brass) ]

BETTER:

Quantity
[ 5.00 ] Brass

==================================================
9. SMART FORM BEHAVIOR
==================================================

The software should reduce manual work.

Examples:

TRIP:

When selecting vehicle:
- show vehicle number
- optionally show vehicle type

When selecting vendor:
- show vendor name

When entering loaded and empty weights:
- calculate net weight automatically.

If Quantity (Brass) is manually entered, preserve it.

Do not overwrite user-entered values unexpectedly.

DIESEL:

When entering:
- litres
- rate/litre

automatically calculate:

Total = litres × rate/litre

Show the calculated amount clearly.

Also maintain diesel stock:

Opening Stock
+ Receipts
- Usage
= Closing Stock

Never allow stock to silently become negative.

If negative stock is possible, clearly warn the user and require confirmation or prevent the transaction depending on the existing business rules.

MACHINE WORK:

Opening Reading
Closing Reading

Automatically calculate:

Hours Worked = Closing Reading - Opening Reading

If the closing reading is less than opening reading:

Show validation warning.

Do not silently accept invalid readings.

==================================================
10. DATE HANDLING
==================================================

Date is extremely important in this application.

Every date-based page should have a consistent date navigation component.

Example:

<       Tuesday, 1 September 2026       >
                    Today

Use the same behavior across:

- Trips
- Daily Report
- Dabar
- Water Tanker
- Diesel
- Machine Work
- Attendance
- Vehicle Log
- Ledger
- reports

Requirements:

- previous day
- next day
- Today button
- date picker
- correct locale formatting
- no accidental timezone date shifts
- consistent date format

The selected date should be visually obvious.

==================================================
11. DASHBOARD
==================================================

The dashboard should become the operational control center.

It should show useful information rather than just decorative cards.

At minimum consider:

TODAY:

Trips
Total Brass
Diesel Used
Diesel Received
Machine Hours
Dabar Quantity
Water Tanker Trips
Vehicle Trips
Attendance

FINANCIAL:

Invoices
Invoice Amount
Payments Received
Outstanding Receivables
Vendor Payables
Payments Made
Net Position

OPERATIONS:

Vehicles Active
Trips Today
Machine Hours
Diesel Stock
Material Movement

Do not overload the dashboard.

Use hierarchy.

Most important information should appear first.

Cards should be clickable where useful.

For example:

Diesel Stock → opens Diesel

Outstanding Vendor Balance → opens Ledger/Payments

Trips Today → opens Trips filtered to today

Invoices → opens invoices

==================================================
12. TRIPS MODULE
==================================================

The Trip module is a core operational module.

Trip fields may include:

- Date
- Vehicle
- Material
- Quantity (Brass)
- Loading Location
- Unloading Location
- Channel No
- DSP Challan No
- Vendor Challan No
- Vendor
- Loaded Weight
- Empty Weight
- Net Weight
- Notes

Improve the UI so that users don't feel overwhelmed.

Group fields:

BASIC INFORMATION
- Date
- Vehicle
- Vendor

MATERIAL
- Material
- Quantity
- Loading Location
- Unloading Location

DOCUMENTS
- Channel No
- DSP Challan No
- Vendor Challan No

WEIGHTS
- Loaded
- Empty
- Net

NOTES

Make optional fields visually secondary.

Trip list should show useful summary information.

Allow:

- edit
- delete with confirmation
- duplicate trip if useful
- search
- filtering
- date filtering
- vehicle filtering
- vendor filtering
- material filtering

==================================================
13. DABAR MODULE
==================================================

Dabar = Raw Stone Intake.

The current concept is good but should be made more operational.

Fields:

- Entry Date
- Vehicle
- Vendor/Supplier
- No. of Trips
- Quantity (Brass)
- Notes

Provide daily summary:

Total Trips
Total Brass
Vendor-wise quantity
Vehicle-wise quantity

Allow date filtering.

Provide monthly summary if useful.

==================================================
14. WATER TANKER MODULE
==================================================

Fields:

- Date
- Vehicle
- Hours Worked
- KM Run
- Trips
- Rate
- Amount
- Notes

If Rate and quantity are sufficient to calculate amount, calculate it automatically where appropriate.

Provide daily/monthly totals.

Allow filtering by vehicle.

==================================================
15. DIESEL MODULE
==================================================

This needs strong accounting/stock logic.

Have two major views:

RECEIVED
USED

Summary:

Opening Stock
Received
Used
Closing Stock

Every diesel receipt should contain:

- Date
- Source: Pump / Direct
- Litres
- Rate/Litre
- Total Amount
- Supplier
- Invoice/Bill No
- Notes

Diesel usage should connect logically with:

- vehicles
- machine work
- site operations

If existing architecture supports this, maintain proper references rather than duplicate diesel data.

Stock calculations must be consistent.

==================================================
16. MACHINE WORK
==================================================

Machine Work fields:

- Date
- Machine
- Mode: Bucket / Breaker
- Work Description
- Opening Reading
- Closing Reading
- Calculated Hours
- Notes

Display:

Machine
Mode
Description
Opening
Closing
Hours

Daily total hours should be displayed prominently.

Monthly machine utilization should eventually be possible.

==================================================
17. INVOICES
==================================================

GST invoice management must be robust.

Current invoice structure includes:

- Vendor
- PO No.
- Invoice Date
- Supply Date
- Line Items
- Description
- HSN
- Quantity
- Rate
- Amount
- Notes

Line item calculations should be automatic.

For each invoice:

Subtotal
CGST
SGST
Grand Total

Make tax calculations configurable instead of hardcoding them wherever practical.

Invoice details should clearly show:

Invoice number
Vendor
Date
Line items
Tax
Total
Paid amount
Outstanding amount
Payment status

Statuses:

- Draft
- Issued
- Partially Paid
- Paid
- Overdue
- Cancelled

If appropriate.

==================================================
18. PAYMENTS
==================================================

Vendor Payments should connect directly to invoices and ledgers.

Payment fields:

- Vendor
- Payment Date
- Amount
- Payment Mode
- Reference Number / Cheque Number
- Invoice allocation
- Notes

Payment modes:

- Cash
- Bank
- Cheque
- UPI

Important:

Do not just store a payment as an isolated record.

If payment is against an invoice, maintain the relationship.

Example:

Invoice:
₹16,52,000

Payment:
₹5,00,000

Outstanding:
₹11,52,000

The outstanding balance must update automatically.

Multiple payments against one invoice must be supported.

Example:

₹5,00,000
₹3,00,000
₹3,52,000

Invoice becomes Paid.

Do not allow payment allocations to create impossible balances without warning.

==================================================
19. LEDGER — VERY IMPORTANT
==================================================

A complete ledger/account statement is REQUIRED.

This is one of the most important parts of the software.

Create a dedicated:

LEDGER

module.

The ledger should support:

- Vendor Ledger
- Customer/Party Ledger if applicable
- Cash Ledger
- Bank Ledger
- Diesel/Supplier ledger where appropriate
- General transaction history

At minimum, Vendor Ledger must work perfectly.

==================================================
20. VENDOR LEDGER
==================================================

For every vendor, provide:

Vendor Name

Opening Balance

Then chronological transactions:

Date
Transaction Type
Reference
Description
Debit
Credit
Running Balance

Example:

Date        Type        Reference        Debit       Credit      Balance
---------------------------------------------------------------------------
01/09/26    Invoice     DSP/2026-27/1    ₹16,52,000  -           ₹16,52,000
01/09/26    Payment     NEFT-001         -           ₹5,00,000   ₹11,52,000
05/09/26    Payment     UPI-002          -           ₹2,00,000   ₹9,52,000

The exact debit/credit semantics should be chosen consistently based on whether this is a payable or receivable ledger.

DO NOT mix accounting directions inconsistently.

The ledger must have:

Opening Balance
Total Debit
Total Credit
Closing Balance

==================================================
21. LEDGER FILTERS
==================================================

Ledger must support:

- Vendor selection
- Date From
- Date To
- Transaction Type
- Invoice
- Payment
- All transactions

Provide:

Today
This Week
This Month
Previous Month
Financial Year
Custom Range

Make filtering extremely easy.

==================================================
22. LEDGER SEARCH
==================================================

Allow searching by:

- Vendor
- Invoice number
- Payment reference
- Challan number
- Description
- Date

Search should be fast and forgiving.

==================================================
23. LEDGER DETAIL VIEW
==================================================

Clicking a ledger transaction should show the source document.

For example:

Invoice transaction → open invoice details.

Payment transaction → open payment details.

Trip-related financial transaction → open related trip if applicable.

Do not create disconnected screens.

The entire system should behave like one connected application.

==================================================
24. LEDGER PRINTING — REQUIRED
==================================================

The user specifically needs the ledger to be printable.

Provide:

PRINT LEDGER

The printed ledger should be professional and suitable for:

- office records
- accountant
- CA
- vendor reconciliation
- management
- audit
- physical filing

The print layout should contain:

COMPANY / SITE NAME
Address/contact if available

VENDOR LEDGER

Vendor:
[Vendor Name]

Period:
[From Date] - [To Date]

Opening Balance: ₹XXXX

---------------------------------------------------------
Date | Particulars | Ref No | Debit | Credit | Balance
---------------------------------------------------------
...
---------------------------------------------------------

Total Debit: ₹XXXX
Total Credit: ₹XXXX

Closing Balance: ₹XXXX

Generated On:
Generated By:

==================================================
25. PDF LEDGER EXPORT — REQUIRED
==================================================

Add:

Export PDF

The PDF must be generated from structured ledger data.

Requirements:

- A4 paper
- portrait or landscape depending on column count
- professional header
- company/site information
- vendor name
- date range
- opening balance
- transaction table
- debit
- credit
- running balance
- totals
- closing balance
- page numbers
- generated date
- generated by
- repeat table header on every page
- proper Indian currency formatting
- no clipped columns
- no overlapping text
- no blank unnecessary pages

Long ledgers must automatically continue across multiple pages.

Do NOT create a screenshot of the webpage and put it inside a PDF.

Generate a proper document/PDF.

==================================================
26. EXCEL LEDGER EXPORT — REQUIRED
==================================================

Add:

Export Excel

The Excel file must contain actual spreadsheet data.

NOT an image.

NOT a screenshot.

NOT a single giant text cell.

Use proper Excel rows and columns.

Suggested structure:

Sheet 1:
Vendor Ledger

A: Date
B: Transaction Type
C: Reference
D: Description
E: Debit
F: Credit
G: Running Balance

At top:

Vendor Name
Period
Opening Balance

At bottom:

Total Debit
Total Credit
Closing Balance

Format:

- currency cells as INR
- date cells as dates
- bold headers
- freeze header row
- auto-fit columns
- readable column widths
- borders where appropriate
- totals clearly visible
- negative balances handled correctly
- proper number formats
- no unnecessary formulas if backend-generated values are safer
- formulas may be used where appropriate

If useful, create additional sheets:

1. Ledger
2. Summary
3. Invoice Details
4. Payment Details

But keep the primary export simple enough for an accountant to use.

==================================================
27. PRINT / EXPORT SHOULD EXIST THROUGHOUT
==================================================

Where useful, provide:

- Print
- Export PDF
- Export Excel

for:

- Ledger
- Daily Report
- Trips
- Diesel report
- Machine Work report
- Attendance report
- Vehicle report
- Invoice

Do not add export buttons everywhere blindly.

Add them where the user naturally expects reporting.

==================================================
28. DAILY REPORT
==================================================

Daily Report should become a consolidated operational report.

For selected date show:

TRIPS
- total trips
- total brass
- vehicle-wise trips

DABAR
- total raw stone trips
- total brass

DIESEL
- received
- used
- closing stock

MACHINE
- total machine hours

WATER TANKER
- trips
- KM
- hours

ATTENDANCE
- present
- half day
- absent
- leave

FINANCIAL
- invoices
- payments
- outstanding

The report should be easy to understand.

Add:

Print Daily Report
Export PDF
Export Excel

==================================================
29. VEHICLE DAILY LOG
==================================================

Current vehicle daily log displays:

Vehicle
Registration
Loading Location
Unloading Location
Opening Odometer
Closing Odometer
KM
Day Trips
Night Trips
Diesel
Notes

Improve it.

Automatically calculate:

KM = Closing Odometer - Opening Odometer

Validate negative values.

Display daily totals:

Total Vehicles
Total Trips
Total KM
Total Diesel

Vehicle history should be accessible.

==================================================
30. ATTENDANCE
==================================================

Current attendance has:

Present
Half Day
Absent
Leave

Improve usability.

Make it extremely quick to mark attendance.

For example:

Employee
Present
Half Day
Absent
Leave

One tap/click.

Show daily summary at top.

Also support:

- monthly attendance
- employee attendance history
- attendance report
- export Excel/PDF

Do not make users open a separate form for every employee.

==================================================
31. USERS / PERMISSIONS
==================================================

The application will eventually have multiple users.

Design for role-based permissions.

Potential roles:

Admin
Manager
Accountant
Supervisor
Operator
Viewer

Permissions should control:

- view
- create
- edit
- delete
- export
- financial information
- user management

Do not assume every user should see everything.

Financial data such as:

- invoices
- payments
- vendor balances
- ledger

may need restricted access.

If authentication/authorization already exists, preserve and improve it.

==================================================
32. DATA CONSISTENCY
==================================================

This is extremely important.

The same entity must not be entered repeatedly as free text.

For example:

Vendor:
R.D. Samant Contractors Pvt. Ltd.

should have one vendor record.

Trips, invoices, payments and ledger should reference the same vendor.

Similarly:

Vehicle
Material
Machine
Employee

should use shared master records.

Do not create:

"R.D Samant"
"R.D. Samant"
"RD Samant Contractors"
"R.D. Samant Contractors Pvt Ltd"

as separate vendors because of spelling differences.

Use IDs internally.

==================================================
33. MASTER DATA
==================================================

Where appropriate create/manage master data for:

- Vendors
- Vehicles
- Materials
- Machines
- Employees
- Locations
- Users
- Payment Modes
- Tax rates

Forms should use these masters.

Long dropdowns should support search.

==================================================
34. EMPTY STATES
==================================================

Current screens show messages such as:

"No trips for this date. Tap + to add one."

This is good conceptually.

Improve empty states.

Every empty state should tell the user:

1. What is missing
2. Why it may be empty
3. What action they can take

Example:

No trips recorded for 1 Sep 2026.

[ + Add Trip ]

Do not show large empty blank areas without context.

==================================================
35. LOADING STATES
==================================================

Never leave the user wondering whether the application is working.

When loading:

- show progress indicator/skeleton
- disable duplicate submission
- preserve page context

For Save:

Saving...
then:

Saved successfully

For errors:

Something went wrong.
Please try again.

If possible show the actual useful error.

Do not expose raw stack traces to normal users.

==================================================
36. DELETE CONFIRMATIONS
==================================================

Deleting financial or operational records is dangerous.

For:

- invoice
- payment
- trip
- diesel receipt
- machine work
- attendance
- vehicle log

require confirmation where appropriate.

Example:

Delete Payment?

₹5,00,000
R.D. Samant Contractors Pvt. Ltd.
NEFT-001

This action cannot be undone.

[Cancel] [Delete]

For critical financial records, consider soft-delete/audit history rather than permanent deletion.

==================================================
37. AUDIT HISTORY
==================================================

Because this is a business application, important records should eventually track:

Created By
Created At
Updated By
Updated At

For financial records also consider:

Deleted/Cancelled By
Deleted/Cancelled At
Reason

Do not silently alter financial history.

==================================================
38. NUMBER / CURRENCY FORMATTING
==================================================

Use Indian formatting.

Examples:

₹5,00,000.00

₹16,52,000.00

₹1,26,000.00

Not:

₹500000.00

Use consistent formatting everywhere.

For quantities:

5.00 Brass

For KM:

81.5 km

For machine hours:

2.00 hrs

Do not randomly mix decimal formats.

==================================================
39. ACCESSIBILITY
==================================================

The UI should be usable with:

- keyboard
- mouse
- touch

Inputs should have proper focus behavior.

Buttons must be large enough.

Do not rely only on color.

For example:

Do not communicate "Paid" only using green.

Show:

PAID

and optionally use green.

==================================================
40. MOBILE / TABLET FUTURE
==================================================

The application may eventually become a mobile application.

Therefore:

- avoid desktop-only assumptions
- avoid fixed-width components
- avoid hardcoded pixel positioning
- use responsive layouts
- keep forms modular
- keep business logic separate from UI

The UI should be easy to adapt to Flutter/mobile later if necessary.

==================================================
41. PERFORMANCE
==================================================

Do not load huge datasets unnecessarily.

Use:

- pagination
- filtering
- server-side querying where appropriate
- indexed database columns
- efficient joins
- debounced search

Dashboard queries should be optimized.

Reports should not become slow when there are thousands of records.

==================================================
42. ERROR HANDLING
==================================================

Handle:

- network failure
- database failure
- duplicate records
- invalid input
- missing vendor
- missing vehicle
- invalid dates
- invalid amounts
- negative quantities
- negative stock
- invalid odometer readings
- invalid machine readings
- payment exceeding outstanding amount
- invoice calculations
- GST calculation errors

User should receive understandable messages.

==================================================
43. ACCOUNTING LOGIC
==================================================

Be extremely careful with financial calculations.

Invoice:

Subtotal
+ CGST
+ SGST
= Grand Total

Payment:

Invoice Total
- Payments Allocated
= Outstanding

Ledger:

Opening Balance
+ Debit
- Credit
= Running Balance

Use one consistent accounting model.

Do not duplicate calculations in multiple frontend components.

Prefer centralized calculation/business logic.

Avoid floating point errors for money.

Use appropriate decimal/numeric types.

==================================================
44. DATA RELATIONSHIPS
==================================================

The application should behave as one connected system.

Example:

Trip
↓
Vehicle
↓
Vendor
↓
Invoice
↓
Payment
↓
Ledger

Another example:

Diesel Receipt
↓
Diesel Stock

Diesel Usage
↓
Vehicle/Machine
↓
Daily Report

Machine Work
↓
Machine
↓
Daily Report

Attendance
↓
Employee
↓
Daily/Monthly Report

Do not create isolated modules that cannot communicate.

==================================================
45. SEARCH AND FILTER UX
==================================================

Lists should support appropriate filtering.

Example Trips:

[ Search vehicle/vendor/challan ]

[ Date ]

[ Vehicle ▼ ]

[ Vendor ▼ ]

[ Material ▼ ]

[ Filter ]

[ Clear ]

Make filtering easy to understand.

Do not hide important filters inside confusing menus.

==================================================
46. LIST DESIGN
==================================================

Cards are useful, but do not force everything into cards.

For simple operational records, cards can work.

For financial information and ledger data, tables are often better.

Use the right presentation for the data.

Ledger:
TABLE

Invoice:
CARD/LIST + DETAIL

Trips:
CARD/LIST

Attendance:
COMPACT ROWS

Dashboard:
SUMMARY CARDS

==================================================
47. DO NOT OVERDESIGN
==================================================

Avoid:

- excessive animations
- huge empty spaces
- unnecessary gradients
- excessive rounded containers
- oversized dialogs
- tiny text
- decorative elements that reduce usable space

The current application has too much empty space on some screens while dialogs overflow.

Fix the balance.

The software should maximize useful information without becoming cluttered.

==================================================
48. FORM DIALOG DESIGN
==================================================

Current dialogs are too large vertically and some overflow.

Use:

- max-width
- max-height
- scrollable content
- fixed footer

Example:

┌───────────────────────────────────┐
│ Add Trip                       X  │
├───────────────────────────────────┤
│                                   │
│ Date                              │
│ [01/09/2026]                     │
│                                   │
│ Vehicle                           │
│ [Select Vehicle]                  │
│                                   │
│ Material                          │
│ [Select Material]                │
│                                   │
│ Quantity                          │
│ [5.00] Brass                      │
│                                   │
│ ...                               │
│                                   │
│           scrollable              │
│                                   │
├───────────────────────────────────┤
│ Cancel                 Save       │
└───────────────────────────────────┘

The footer must remain visible.

==================================================
49. INVOICE DIALOG
==================================================

The New GST Invoice dialog currently shows a right overflow warning.

Fix this.

For invoice line items:

On desktop:

Description | HSN | Qty | Rate | Amount

On narrow screens:

Description
HSN
Qty
Rate
Amount

Do not force a 5-column layout into a narrow dialog.

Allow adding/removing line items.

Automatically calculate:

Amount = Qty × Rate

Then:

Subtotal
CGST
SGST
Grand Total

Show totals clearly.

==================================================
50. EXPORT ARCHITECTURE
==================================================

Create reusable reporting/export infrastructure.

Instead of writing separate messy export code for every page, create reusable services/components such as:

ReportService
PdfExportService
ExcelExportService
PrintService

or equivalent architecture appropriate for the existing technology.

All reports should receive structured data and generate output consistently.

==================================================
51. PDF QUALITY
==================================================

PDF exports must be business-document quality.

Check:

- margins
- page breaks
- fonts
- column widths
- currency formatting
- date formatting
- header/footer
- page numbering
- repeated table headers
- long descriptions
- multiple pages

Test with:

- 5 records
- 50 records
- 500 records

No clipping.

==================================================
52. EXCEL QUALITY
==================================================

Excel exports must be accountant-friendly.

Use:

- proper column types
- formatted headers
- frozen panes
- filters
- readable widths
- currency formatting
- dates
- totals
- summary section

If a ledger has 500+ rows, Excel must remain usable.

==================================================
53. PRINT PREVIEW
==================================================

Where practical, allow:

Print

using a clean print-specific layout.

Do not print:

- sidebar
- navigation
- Add buttons
- unnecessary UI
- dialogs
- browser-only controls

Only the report/document should print.

==================================================
54. SECURITY
==================================================

Never trust frontend calculations for financial records.

Validate important values on the backend.

Never allow a user to modify another user's protected data unless authorized.

Validate:

- permissions
- IDs
- amounts
- relationships
- ownership/access

Do not expose database credentials to frontend.

==================================================
55. TEST REAL-WORLD SCENARIOS
==================================================

Do not only test the happy path.

Test scenarios such as:

SCENARIO 1:
One vendor gets one invoice and one payment.

SCENARIO 2:
One invoice gets three partial payments.

SCENARIO 3:
Payment exceeds invoice amount.

SCENARIO 4:
Multiple invoices for same vendor.

SCENARIO 5:
Same vehicle performs 10 trips in one day.

SCENARIO 6:
Multiple vehicles operate on same day.

SCENARIO 7:
Diesel received multiple times in one day.

SCENARIO 8:
Diesel usage causes stock to reach zero.

SCENARIO 9:
Diesel usage would make stock negative.

SCENARIO 10:
Machine opening reading = previous closing reading.

SCENARIO 11:
Machine closing reading is lower than opening reading.

SCENARIO 12:
Attendance for 50 employees.

SCENARIO 13:
Ledger contains hundreds of transactions.

SCENARIO 14:
Invoice has 10 line items.

SCENARIO 15:
Invoice is partially paid.

SCENARIO 16:
Invoice is fully paid.

SCENARIO 17:
A transaction is edited after being included in a report.

SCENARIO 18:
User tries to delete a financial record.

SCENARIO 19:
Small laptop screen.

SCENARIO 20:
Browser zoom 125%.

SCENARIO 21:
Mobile/tablet width.

SCENARIO 22:
Long vendor name.

SCENARIO 23:
Long invoice description.

SCENARIO 24:
Ledger exported to PDF with multiple pages.

SCENARIO 25:
Ledger exported to Excel with 1,000+ rows.

==================================================
56. UI QA CHECKLIST
==================================================

After implementation, inspect EVERY screen.

Verify:

[ ] No horizontal overflow
[ ] No vertical overflow
[ ] No "BOTTOM OVERFLOWED" warnings
[ ] No "RIGHT OVERFLOWED" warnings
[ ] No clipped buttons
[ ] No hidden Save buttons
[ ] No hidden Cancel buttons
[ ] Dialogs scroll correctly
[ ] Sidebar scrolls correctly
[ ] Tables scroll correctly
[ ] Long text wraps correctly
[ ] Currency displays correctly
[ ] Dates display correctly
[ ] Empty states work
[ ] Loading states work
[ ] Error states work
[ ] Delete confirmations work
[ ] Forms validate
[ ] Export works
[ ] PDF works
[ ] Excel works
[ ] Print works

==================================================
57. IMPORTANT: PRESERVE EXISTING FUNCTIONALITY
==================================================

Do not break existing working features.

Before changing a component:

Understand what depends on it.

If you need to refactor:

- preserve existing API contracts where possible
- preserve database compatibility
- migrate data safely
- do not delete existing records
- do not reset existing data
- do not replace working business logic unnecessarily

==================================================
58. IMPLEMENTATION STRATEGY
==================================================

Work in phases.

PHASE 1:
Audit existing application.

PHASE 2:
Fix global layout/responsive/overflow issues.

PHASE 3:
Create consistent design system.

PHASE 4:
Improve common components:
- dialogs
- forms
- date navigation
- cards
- buttons
- tables
- empty states
- loading states

PHASE 5:
Improve operational modules:
- Trips
- Dabar
- Water Tanker
- Diesel
- Machine Work
- Vehicle Log
- Attendance

PHASE 6:
Improve financial modules:
- Invoices
- Payments
- Ledger

PHASE 7:
Implement reporting:
- Daily Report
- Monthly reports
- Ledger reports

PHASE 8:
Implement:
- PDF export
- Excel export
- Print layouts

PHASE 9:
Test real-world scenarios.

PHASE 10:
Final UI/UX audit.

==================================================
59. VERY IMPORTANT DEVELOPMENT RULE
==================================================

Do not make 100 changes at once without testing.

After each major phase:

1. Build the project.
2. Run tests.
3. Check console errors.
4. Check layout.
5. Check database operations.
6. Check calculations.
7. Check existing features.
8. Fix regressions.

==================================================
60. FINAL RESULT EXPECTATION
==================================================

The final application should feel like a professional site/crusher ERP rather than a collection of screens.

A user should be able to go from:

Trip
→ Vehicle
→ Vendor
→ Invoice
→ Payment
→ Ledger
→ PDF/Excel

without manually entering the same information repeatedly.

Similarly:

Diesel Receipt
→ Diesel Stock
→ Vehicle/Machine Usage
→ Daily Report

and:

Machine Work
→ Machine Hours
→ Daily Report

and:

Attendance
→ Daily/Monthly Report

Everything should be connected.

==================================================
61. MOST IMPORTANT PRIORITIES
==================================================

If you have to prioritize, use this order:

1. ZERO UI overflow
2. EXTREMELY USER-FRIENDLY UX
3. Responsive layout
4. Reliable data relationships
5. Correct financial calculations
6. Ledger
7. Excel export
8. PDF export
9. Print layouts
10. Reporting
11. Permissions
12. Advanced features

Do not sacrifice usability for adding more features.

==================================================
62. DO NOT ASK FOR PERMISSION FOR OBVIOUS FIXES
==================================================

If you find:

- overflow
- broken layout
- inconsistent spacing
- obvious validation bugs
- duplicate submissions
- clipped buttons
- poor responsive behavior
- incorrect formatting
- obvious UX problems

fix them.

Do not stop and ask whether you should fix an obvious production issue.

However, for major architectural/database changes that could destroy or migrate existing data, inspect the existing implementation carefully and choose the safest approach.

==================================================
63. FINAL DELIVERABLE
==================================================

After completing the work, provide a concise implementation report containing:

1. What was changed
2. Which UI problems were fixed
3. Which modules were improved
4. Ledger implementation details
5. PDF export implementation
6. Excel export implementation
7. Print implementation
8. Database changes
9. Any migrations
10. Tests performed
11. Any remaining limitations

Most importantly:

DO NOT just make the screenshots look better.

Improve the underlying usability, data flow, calculations, reporting, and business logic so this can become a reliable real-world crusher/site management system.
