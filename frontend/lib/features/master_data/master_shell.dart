import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    '/trips', '/daily-report', '/dabar', '/water-tanker', '/diesel', '/machine-work',
    '/invoices', '/vendor-payments', '/attendance', '/vehicle-daily-log',
    '/users', '/employees', '/vendors', '/vehicles', '/machines', '/materials', '/sites',
  ];

  int _indexFor(String location) {
    final i = _routes.indexOf(location);
    return i < 0 ? 0 : i;
  }
}

// ── sidebar ───────────────────────────────────────────────────────────────────

class _AppSidebar extends StatelessWidget {
  final int selectedIndex;
  const _AppSidebar({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
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

          // ── Scrollable nav items ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavSection('Operations'),
                _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard,
                    label: 'Dashboard', index: 0, selected: selectedIndex),
                _NavItem(icon: Icons.swap_horiz_outlined, selectedIcon: Icons.swap_horiz,
                    label: 'Trips', index: 1, selected: selectedIndex),
                _NavItem(icon: Icons.summarize_outlined, selectedIcon: Icons.summarize,
                    label: 'Daily Report', index: 2, selected: selectedIndex),
                _NavItem(icon: Icons.terrain_outlined, selectedIcon: Icons.terrain,
                    label: 'Dabar', index: 3, selected: selectedIndex),
                _NavItem(icon: Icons.water_drop_outlined, selectedIcon: Icons.water_drop,
                    label: 'Water Tanker', index: 4, selected: selectedIndex),
                _NavItem(icon: Icons.local_gas_station_outlined, selectedIcon: Icons.local_gas_station,
                    label: 'Diesel', index: 5, selected: selectedIndex),
                _NavItem(icon: Icons.construction_outlined, selectedIcon: Icons.construction,
                    label: 'Machine Work', index: 6, selected: selectedIndex),

                const SizedBox(height: 4),
                _NavSection('Finance'),
                _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long,
                    label: 'Invoices', index: 7, selected: selectedIndex),
                _NavItem(icon: Icons.payments_outlined, selectedIcon: Icons.payments,
                    label: 'Payments', index: 8, selected: selectedIndex),

                const SizedBox(height: 4),
                _NavSection('Workforce'),
                _NavItem(icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check,
                    label: 'Attendance', index: 9, selected: selectedIndex),
                _NavItem(icon: Icons.badge_outlined, selectedIcon: Icons.badge,
                    label: 'Employees', index: 12, selected: selectedIndex),

                const SizedBox(height: 4),
                _NavSection('Vehicles'),
                _NavItem(icon: Icons.directions_car_outlined, selectedIcon: Icons.directions_car,
                    label: 'Vehicle Log', index: 10, selected: selectedIndex),
                _NavItem(icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping,
                    label: 'Vehicles', index: 14, selected: selectedIndex),

                const SizedBox(height: 4),
                _NavSection('Master Data'),
                _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people,
                    label: 'Vendors', index: 13, selected: selectedIndex),
                _NavItem(icon: Icons.precision_manufacturing_outlined, selectedIcon: Icons.precision_manufacturing,
                    label: 'Machines', index: 15, selected: selectedIndex),
                _NavItem(icon: Icons.category_outlined, selectedIcon: Icons.category,
                    label: 'Materials', index: 16, selected: selectedIndex),
                _NavItem(icon: Icons.location_on_outlined, selectedIcon: Icons.location_on,
                    label: 'Sites', index: 17, selected: selectedIndex),

                const SizedBox(height: 4),
                _NavSection('Admin'),
                _NavItem(icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts,
                    label: 'Users', index: 11, selected: selectedIndex),
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
    '/trips', '/daily-report', '/dabar', '/water-tanker', '/diesel', '/machine-work',
    '/invoices', '/vendor-payments', '/attendance', '/vehicle-daily-log',
    '/users', '/employees', '/vendors', '/vehicles', '/machines', '/materials', '/sites',
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
