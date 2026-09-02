import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/site_provider.dart';
import '../../core/storage/auth_storage.dart';

class MasterShell extends StatelessWidget {
  final Widget child;
  const MasterShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexFor(location);

    return Scaffold(
      body: Row(
        children: [
          _AppSidebar(selectedIndex: selectedIndex),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  static const _routes = [
    '/dashboard',
    '/trips', '/daily-report', '/dabar', '/water-tanker', '/diesel', '/machine-work', '/reports',
    '/invoices', '/party-payments', '/ledger',
    '/attendance', '/vehicle-daily-log',
    '/users', '/employees', '/parties', '/vehicles', '/machines', '/materials', '/sites',
  ];

  int _indexFor(String location) {
    final i = _routes.indexOf(location);
    return i < 0 ? 0 : i;
  }
}

// ── sidebar ───────────────────────────────────────────────────────────────────

class _AppSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  const _AppSidebar({required this.selectedIndex});

  @override
  ConsumerState<_AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<_AppSidebar> {
  String? _role;

  @override
  void initState() {
    super.initState();
    AuthStorage.getRole().then((r) {
      if (mounted) setState(() => _role = r);
    });
    // For SITE_STAFF: pre-select their assigned site on load
    AuthStorage.getSiteId().then((sid) {
      if (sid != null && mounted) {
        ref.read(selectedSiteIdProvider.notifier).state = sid;
      }
    });
  }

  // Role-based sidebar visibility.
  // Default (null = still loading) behaves like SITE_STAFF — most restrictive,
  // prevents any sensitive item from flashing before the role is loaded.
  bool _visible(int index) {
    switch (_role) {
      case 'OWNER_ADMIN':
        return true; // sees everything
      case 'OFFICE_ACCOUNTANT':
        // Hides: Users (13) — OWNER_ADMIN only
        return index != 13;
      default:
        // SITE_STAFF or null (loading): operations only
        // Hides: Finance (8,9,10), Users (13), Employees (14),
        //        Parties (15), Vehicles (16), Machines (17), Materials (18), Sites (19)
        return !const {8, 9, 10, 13, 14, 15, 16, 17, 18, 19}.contains(index);
    }
  }

  Widget _item(IconData icon, IconData selIcon, String label, int index) {
    if (!_visible(index)) return const SizedBox.shrink();
    return _NavItem(
      icon: icon, selectedIcon: selIcon,
      label: label, index: index,
      selected: widget.selectedIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFinance = _visible(8) || _visible(9) || _visible(10);
    final showAdmin   = _visible(13);

    return Container(
      width: 200,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo/header ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business,
                      size: 22, color: Color(0xFF1565C0)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Site Manager',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1565C0)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Site context ──────────────────────────────────────────────────
          if (_role == 'SITE_STAFF')
            _SiteLabel()
          else if (_role == 'OWNER_ADMIN' || _role == 'OFFICE_ACCOUNTANT')
            _SiteSwitcher(),

          // ── Scrollable nav items ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavSection('Operations'),
                _item(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
                _item(Icons.swap_horiz_outlined, Icons.swap_horiz, 'Trips', 1),
                _item(Icons.summarize_outlined, Icons.summarize, 'Daily Report', 2),
                _item(Icons.terrain_outlined, Icons.terrain, 'Dabar', 3),
                _item(Icons.water_drop_outlined, Icons.water_drop, 'Water Tanker', 4),
                _item(Icons.local_gas_station_outlined, Icons.local_gas_station, 'Diesel', 5),
                _item(Icons.construction_outlined, Icons.construction, 'Machine Work', 6),
                _item(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', 7),

                if (showFinance) ...[
                  const SizedBox(height: 4),
                  _NavSection('Finance'),
                  _item(Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices', 8),
                  _item(Icons.payments_outlined, Icons.payments, 'Payments', 9),
                  _item(Icons.account_balance_outlined, Icons.account_balance, 'Ledger', 10),
                ],

                const SizedBox(height: 4),
                _NavSection('Workforce'),
                _item(Icons.fact_check_outlined, Icons.fact_check, 'Attendance', 11),
                _item(Icons.badge_outlined, Icons.badge, 'Employees', 14),

                const SizedBox(height: 4),
                _NavSection('Vehicles'),
                _item(Icons.directions_car_outlined, Icons.directions_car, 'Vehicle Log', 12),
                _item(Icons.local_shipping_outlined, Icons.local_shipping, 'Vehicles', 16),

                const SizedBox(height: 4),
                _NavSection('Master Data'),
                _item(Icons.people_outline, Icons.people, 'Parties', 15),
                _item(Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Machines', 17),
                _item(Icons.category_outlined, Icons.category, 'Materials', 18),
                _item(Icons.location_on_outlined, Icons.location_on, 'Sites', 19),

                if (showAdmin) ...[
                  const SizedBox(height: 4),
                  _NavSection('Admin'),
                  _item(Icons.manage_accounts_outlined, Icons.manage_accounts, 'Users', 13),
                ],
              ],
            ),
          ),

          // ── Footer: logout ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.logout, size: 18, color: Colors.grey),
              title: const Text('Logout',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              onTap: () async {
                await AuthStorage.clear();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String label;
  const _NavSection(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
              letterSpacing: 0.8),
        ),
      );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final int selected;
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.selected,
  });

  static const _routes = [
    '/dashboard',
    '/trips', '/daily-report', '/dabar', '/water-tanker', '/diesel', '/machine-work', '/reports',
    '/invoices', '/party-payments', '/ledger',
    '/attendance', '/vehicle-daily-log',
    '/users', '/employees', '/parties', '/vehicles', '/machines', '/materials', '/sites',
  ];

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == index;
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          size: 18,
          color: isSelected ? color : Colors.grey[600],
        ),
        title: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? color : Colors.grey[800]),
        ),
        selected: isSelected,
        onTap: () => context.go(_routes[index]),
      ),
    );
  }
}

// ── site label (read-only, for SITE_STAFF) ───────────────────────────────────

class _SiteLabel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final siteId = ref.watch(selectedSiteIdProvider);

    return sites.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final site = list.firstWhere(
          (s) => s['id'] == siteId,
          orElse: () => <String, dynamic>{},
        );
        final name = site['name'] as String? ?? 'Unknown Site';
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── site switcher (admin/accountant) ─────────────────────────────────────────

class _SiteSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final selectedId = ref.watch(selectedSiteIdProvider);

    return sites.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: selectedId,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              icon: const Icon(Icons.location_on, size: 16),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Sites', style: TextStyle(fontSize: 13)),
                ),
                ...list.map((s) => DropdownMenuItem<int?>(
                  value: s['id'] as int?,
                  child: Text(s['name'] as String, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (val) {
                ref.read(selectedSiteIdProvider.notifier).state = val;
              },
            ),
          ),
        );
      },
    );
  }
}
