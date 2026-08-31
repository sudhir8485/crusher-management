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

## After M2
- M3: Dabar intake (raw material, trips per vehicle per day) + Vehicle Daily Log (water tanker)
- M4: Diesel — received (both sources) + used, running balance
- M5: Machine Work entries
- M6: GST Invoice + Vendor Ledger
- M7: Dashboard + Reports
