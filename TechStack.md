# TechStack.md — Technical Stack Reference

All versions and paths verified against actual files in this repo as of 2026-09-12.

---

## Runtime Environment

| Layer | Technology | Version |
|-------|-----------|---------|
| Frontend | Flutter (web) | **3.47.1** (stable) |
| Frontend language | Dart | 3.13.1 |
| Backend | Spring Boot | **3.3.5** |
| Backend language | Java | **21** |
| Database | PostgreSQL | 15+ (localhost:5432) |
| DB migrations | Flyway | bundled with Spring Boot 3.3.5 |

---

## Frontend — Flutter

### SDK & Tooling
```
Flutter 3.47.1 • channel stable
Dart 3.13.1
DevTools 2.60.0
```

### pubspec.yaml — Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^2.6.1 | State management (primary) |
| `riverpod_annotation` | ^2.6.1 | Code-gen annotations for Riverpod |
| `go_router` | ^14.6.2 | Navigation / routing |
| `dio` | ^5.7.0 | HTTP client |
| `shared_preferences` | ^2.3.3 | Auth token + session storage (localStorage on web) |
| `intl` | ^0.19.0 | Date/number formatting |
| `pdf` | ^3.11.1 | PDF generation (reports screen) |
| `printing` | ^5.13.2 | PDF preview + print (reports screen) |
| `excel` | ^4.0.6 | Excel export (reports screen) |
| `cupertino_icons` | ^1.0.8 | Icon set |

**Dev dependencies:**
- `build_runner` ^2.4.13 — Riverpod code generation
- `riverpod_generator` ^2.6.1 — generates providers from annotations
- `flutter_lints` ^6.0.0

### State Management Pattern
Riverpod with `FutureProvider.autoDispose` for all data fetching. `StateProvider` for local UI state (selected dates, filter modes). No ChangeNotifier or BLoC.

### Routing
`go_router` with a redirect guard in `app_router.dart` that checks `AuthStorage.isLoggedIn()`. All routes are named shell routes under a single `ShellRoute` (persistent bottom nav).

### Auth Storage
`AuthStorage` (`core/storage/auth_storage.dart`) — static utility wrapping `SharedPreferences`. Keys stored with `flutter.` prefix (web localStorage). Stores: `jwt_token`, `user_role`, `user_name`, `tenant_id`, `site_id`, `tenant_name`.

### API Client
`ApiClient` (`core/api/api_client.dart`) — `Dio` wrapper. Base URL: `http://localhost:8080`. JWT injected via interceptor from `SharedPreferences`. 401 response clears auth and navigates to login.

---

## Frontend — File Structure

```
frontend/
├── pubspec.yaml
└── lib/
    ├── main.dart
    ├── core/
    │   ├── api/
    │   │   └── api_client.dart          — Dio client, JWT interceptor
    │   ├── providers/
    │   │   └── site_provider.dart       — Selected site state
    │   ├── router/
    │   │   └── app_router.dart          — GoRouter config + auth guard
    │   ├── storage/
    │   │   └── auth_storage.dart        — SharedPreferences wrapper
    │   └── widgets/
    │       └── app_widgets.dart         — Shared widgets (AppDialog, AppEmptyState, etc.)
    └── features/
        ├── auth/
        │   └── login_screen.dart
        ├── dashboard/
        │   └── dashboard_screen.dart    — Stats tiles (today + month)
        ├── trips/
        │   ├── trips_screen.dart        — Main trip entry + RECORD INFO drill-down
        │   └── daily_report_screen.dart — Printable daily trip report
        ├── dabar/
        │   └── dabar_screen.dart        — Dabar intake + period tabs + detail dialog
        ├── diesel/
        │   └── diesel_screen.dart       — Receipts + usages tabs + period tabs
        ├── machine_work/
        │   └── machine_work_screen.dart — Machine work logs + period tabs
        ├── invoices/
        │   └── invoices_screen.dart     — GST + Job-Work invoice management
        ├── vendor_payments/
        │   └── vendor_payments_screen.dart
        ├── accounts/
        │   ├── accounts_screen.dart     — Party ledger overview
        │   └── party_detail_screen.dart — Drillable party ledger
        ├── ledger/
        │   └── ledger_screen.dart       — Full receivable/payable ledger
        ├── reports/
        │   └── reports_screen.dart      — Operational reports + PDF/Excel export
        ├── attendance/
        │   ├── attendance_screen.dart
        │   └── employees_screen.dart
        ├── master_data/
        │   ├── master_shell.dart
        │   ├── vendors/vendors_screen.dart
        │   ├── vehicles/vehicles_screen.dart
        │   ├── machines/machines_screen.dart
        │   ├── materials/materials_screen.dart
        │   ├── services/services_screen.dart
        │   ├── sites/sites_screen.dart
        │   └── widgets/master_list_screen.dart
        └── users/
            └── users_screen.dart
```

---

## Backend — Spring Boot

### pom.xml — Key Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `spring-boot-starter-web` | 3.3.5 | REST controllers |
| `spring-boot-starter-data-jpa` | 3.3.5 | JPA / Hibernate ORM |
| `spring-boot-starter-security` | 3.3.5 | Auth, JWT filter |
| `spring-boot-starter-validation` | 3.3.5 | Bean validation |
| `postgresql` | runtime | JDBC driver |
| `flyway-core` | bundled | DB migrations |
| `flyway-database-postgresql` | bundled | Flyway PostgreSQL support |
| `jjwt-api` | 0.12.6 | JWT creation/validation |
| `jjwt-impl` | 0.12.6 | JWT runtime |
| `jjwt-jackson` | 0.12.6 | JWT JSON binding |
| `springdoc-openapi-starter-webmvc-ui` | 2.6.0 | Swagger UI at `/swagger-ui.html` |
| `lombok` | optional | `@Getter`, `@Setter`, `@RequiredArgsConstructor` |

### application.properties

```properties
# Database
spring.datasource.url=jdbc:postgresql://localhost:5432/crusher_management
spring.datasource.username=crusher_admin
spring.datasource.password=crusher123

# JPA
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=false

# Flyway
spring.flyway.enabled=true
spring.flyway.locations=classpath:db/migration
spring.flyway.baseline-on-migrate=true
spring.flyway.validate-on-migrate=false

# JWT
app.jwt.secret=dsp-crusher-management-jwt-secret-key-2026-ratnagiri-site-secure
app.jwt.expiration-ms=86400000   # 24 hours

# Swagger
springdoc.api-docs.path=/api-docs
springdoc.swagger-ui.path=/swagger-ui.html
```

### Multi-Tenant Pattern
- Every request sets `app.tenant_id` PostgreSQL session variable via `TenantInterceptor`
- All tenant-scoped tables have Row-Level Security policies keyed on `current_setting('app.tenant_id')`
- `TenantContext.get()` / `SiteContext.get()` thread-local helpers used in services

### JWT Auth
- `JwtAuthFilter` reads `Authorization: Bearer <token>` header
- Token claims: `sub` = user ID, `tenantId`, `role`
- Filter sets Spring Security principal to user ID (string of Long); services parse with `Long.parseLong(principal)` then look up user by ID for full name

---

## Backend — File Structure

```
backend/src/main/java/com/dsp/crusher/
├── CrusherManagementApplication.java
├── config/
│   ├── JwtConfig.java
│   ├── SecurityConfig.java          — role-based URL security rules
│   ├── SiteContext.java             — thread-local site ID
│   ├── SwaggerConfig.java
│   ├── TenantContext.java           — thread-local tenant ID
│   ├── TenantInterceptor.java       — sets app.tenant_id session var
│   └── WebMvcConfig.java
├── controller/                      — REST controllers (one per module)
├── dto/                             — Request/Response DTOs
├── entity/                          — JPA entities
├── exception/
│   ├── GlobalExceptionHandler.java
│   ├── ResourceNotFoundException.java
│   └── UnauthorizedException.java
├── filter/
│   └── JwtAuthFilter.java
├── repository/                      — Spring Data JPA repositories
└── service/                         — Business logic

backend/src/main/resources/
├── application.properties
└── db/migration/
    └── V1__init_schema.sql … V34__audit_fields_all_modules.sql
```

### Key Patterns
- **Service → enrich()**: Every service has a private `enrich(List<Entity>)` method that joins related data and builds response DTOs
- **getCurrentUserName()**: Present in TripService, DabarService, DieselService, MachineWorkService, GstInvoiceService, JobWorkInvoiceService, VendorPaymentService — looks up full name from SecurityContext principal (user ID) → `userRepo.findById()` → `getFullName()`
- **Status vs is_active**: `status='INACTIVE'` = permanent soft delete; `is_active=false` = reversible hide from UI pickers

---

## Database

| Setting | Value |
|---------|-------|
| Engine | PostgreSQL |
| Port | 5432 |
| Database | `crusher_management` |
| User | `crusher_admin` |
| Password | `crusher123` |
| RLS | Enabled on all tenant-scoped tables |
| Migrations | Flyway, V1–V34 |

---

## Build & Run Commands

### Start everything (backend + frontend)
```bash
./start.sh
# Backend on :8080, Frontend on :3000
```

### Stop everything
```bash
./stop.sh
```

### Backend only
```bash
cd backend
mvn spring-boot:run
# or
mvn compile       # compile check
mvn test          # run tests
```

### Frontend only
```bash
cd frontend
flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0
# or for release build:
flutter build web --release
# then serve build/web/ with any static server
```

### Database setup (first time)
```bash
# PostgreSQL must be running
psql -h localhost -U postgres -c "CREATE USER crusher_admin WITH PASSWORD 'crusher123';"
psql -h localhost -U postgres -c "CREATE DATABASE crusher_management OWNER crusher_admin;"
# Flyway runs automatically on first boot and applies V1–V34
```

### API docs
```
http://localhost:8080/swagger-ui.html
http://localhost:8080/api-docs
```

---

## URL / Port Map

| Service | URL | Notes |
|---------|-----|-------|
| Frontend (dev) | http://localhost:3000 | Flutter dev server |
| Frontend (built) | http://localhost:5000 | `python3 -m http.server 5000 --directory build/web` |
| Backend API | http://localhost:8080 | Spring Boot |
| Swagger UI | http://localhost:8080/swagger-ui.html | |
| Health check | http://localhost:8080/actuator/health | |
