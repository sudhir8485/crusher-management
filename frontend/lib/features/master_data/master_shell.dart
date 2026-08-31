import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/auth_storage.dart';

class MasterShell extends StatelessWidget {
  final Widget child;
  const MasterShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            selectedIndex: _indexFor(location),
            onDestinationSelected: (i) => context.go(_routes[i]),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.business, size: 32, color: Color(0xFF1565C0)),
                  SizedBox(height: 4),
                  Text('Site Manager',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () async {
                  await AuthStorage.clear();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
            destinations: const [
              // ── Operations ──────────────────────────────────────────
              NavigationRailDestination(
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(Icons.swap_horiz),
                label: Text('Trips'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.summarize_outlined),
                selectedIcon: Icon(Icons.summarize),
                label: Text('Daily Report'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.terrain_outlined),
                selectedIcon: Icon(Icons.terrain),
                label: Text('Dabar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.water_drop_outlined),
                selectedIcon: Icon(Icons.water_drop),
                label: Text('Water Tanker'),
              ),
              // ── Master Data ──────────────────────────────────────────
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Vendors'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text('Vehicles'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.construction_outlined),
                selectedIcon: Icon(Icons.construction),
                label: Text('Machines'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Materials'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.location_on_outlined),
                selectedIcon: Icon(Icons.location_on),
                label: Text('Sites'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  static const _routes = [
    '/trips', '/daily-report', '/dabar', '/water-tanker',
    '/vendors', '/vehicles', '/machines', '/materials', '/sites',
  ];

  int _indexFor(String location) {
    final i = _routes.indexOf(location);
    return i < 0 ? 0 : i;
  }
}
