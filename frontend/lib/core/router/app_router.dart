import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/login_screen.dart';
import '../../features/master_data/master_shell.dart';
import '../../features/master_data/vendors/vendors_screen.dart';
import '../../features/master_data/vehicles/vehicles_screen.dart';
import '../../features/master_data/machines/machines_screen.dart';
import '../../features/master_data/materials/materials_screen.dart';
import '../../features/master_data/sites/sites_screen.dart';
import '../../features/trips/trips_screen.dart';
import '../../features/trips/daily_report_screen.dart';
import '../../features/dabar/dabar_screen.dart';
import '../../features/water_tanker/water_tanker_screen.dart';
import '../../features/diesel/diesel_screen.dart';
import '../../features/machine_work/machine_work_screen.dart';
import '../../features/invoices/invoices_screen.dart';
import '../../features/vendor_payments/vendor_payments_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/attendance/employees_screen.dart';
import '../../features/vehicle_daily_log/vehicle_daily_log_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/ledger/ledger_screen.dart';
import '../storage/auth_storage.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final loggedIn = await AuthStorage.isLoggedIn();
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MasterShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',     builder: (ctx, st) => const DashboardScreen()),
          GoRoute(path: '/trips',         builder: (ctx, st) => const TripsScreen()),
          GoRoute(path: '/daily-report', builder: (ctx, st) => const DailyReportScreen()),
          GoRoute(path: '/dabar',        builder: (ctx, st) => const DabarScreen()),
          GoRoute(path: '/water-tanker', builder: (ctx, st) => const WaterTankerScreen()),
          GoRoute(path: '/diesel',        builder: (ctx, st) => const DieselScreen()),
          GoRoute(path: '/machine-work',      builder: (ctx, st) => const MachineWorkScreen()),
          GoRoute(path: '/invoices',           builder: (ctx, st) => const InvoicesScreen()),
          GoRoute(path: '/vendor-payments',    builder: (ctx, st) => const VendorPaymentsScreen()),
          GoRoute(path: '/ledger',             builder: (ctx, st) => const LedgerScreen()),
          GoRoute(path: '/attendance',          builder: (ctx, st) => const AttendanceScreen()),
          GoRoute(path: '/vehicle-daily-log',  builder: (ctx, st) => const VehicleDailyLogScreen()),
          GoRoute(path: '/employees',          builder: (ctx, st) => const EmployeesScreen()),
          GoRoute(path: '/users',              builder: (ctx, st) => const UsersScreen()),
          GoRoute(path: '/vendors',      builder: (ctx, st) => const VendorsScreen()),
          GoRoute(path: '/vehicles',     builder: (ctx, st) => const VehiclesScreen()),
          GoRoute(path: '/machines',     builder: (ctx, st) => const MachinesScreen()),
          GoRoute(path: '/materials',    builder: (ctx, st) => const MaterialsScreen()),
          GoRoute(path: '/sites',        builder: (ctx, st) => const SitesScreen()),
        ],
      ),
    ],
  );
});
