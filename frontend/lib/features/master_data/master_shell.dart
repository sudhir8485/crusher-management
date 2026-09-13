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
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      // Accounts module is party-level (not site-specific) — hide site bar
      final showSiteBar = !location.startsWith('/accounts');
      return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showSiteBar) _MobileSiteBar(),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: _MobileBottomNav(location: location),
      );
    }

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
    '/trips', '/dabar', '/diesel', '/machine-work', '/reports',
    '/invoices', '/accounts', '/ledger',
    '/attendance',
    '/users', '/employees', '/parties', '/vehicles', '/machines', '/materials', '/sites',
    '/services',
  ];

  int _indexFor(String location) {
    final i = _routes.indexOf(location);
    return i < 0 ? 0 : i;
  }
}

// ── Mobile site switcher bar ──────────────────────────────────────────────────

class _MobileSiteBar extends ConsumerStatefulWidget {
  const _MobileSiteBar();

  @override
  ConsumerState<_MobileSiteBar> createState() => _MobileSiteBarState();
}

class _MobileSiteBarState extends ConsumerState<_MobileSiteBar> {
  String? _role;

  @override
  void initState() {
    super.initState();
    AuthStorage.getRole().then((r) {
      if (mounted) setState(() => _role = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    // SITE_STAFF are pinned to their assigned site — no switcher needed
    if (_role != 'OWNER_ADMIN' && _role != 'OFFICE_ACCOUNTANT') {
      return const SizedBox.shrink();
    }

    final sites = ref.watch(sitesProvider);
    final selectedId = ref.watch(selectedSiteIdProvider);
    final color = Theme.of(context).colorScheme.primary;

    final siteName = sites.valueOrNull
            ?.where((s) => s['id'] == selectedId)
            .firstOrNull?['name'] as String? ??
        'All Sites';

    return Material(
      color: color.withValues(alpha: 0.05),
      child: InkWell(
        onTap: () => _showSiteSheet(context, sites.valueOrNull ?? []),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  siteName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  void _showSiteSheet(BuildContext context, List<Map<String, dynamic>> sites) {
    final selectedId = ref.read(selectedSiteIdProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Select Site',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: Icon(Icons.all_inclusive,
                    color: selectedId == null ? cs.primary : Colors.grey),
                title: const Text('All Sites'),
                selected: selectedId == null,
                selectedColor: cs.primary,
                onTap: () {
                  ref.read(selectedSiteIdProvider.notifier).state = null;
                  Navigator.pop(sheetCtx);
                },
              ),
              ...sites.map((s) {
                final id = s['id'] as int?;
                return ListTile(
                  leading: Icon(Icons.location_on,
                      color: id == selectedId ? cs.primary : Colors.grey),
                  title: Text(s['name'] as String,
                      overflow: TextOverflow.ellipsis),
                  selected: id == selectedId,
                  selectedColor: cs.primary,
                  onTap: () {
                    ref.read(selectedSiteIdProvider.notifier).state = id;
                    Navigator.pop(sheetCtx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ── Mobile bottom navigation (6 items) ───────────────────────────────────────

class _MobileBottomNav extends ConsumerStatefulWidget {
  final String location;
  const _MobileBottomNav({required this.location});

  @override
  ConsumerState<_MobileBottomNav> createState() => _MobileBottomNavState();
}

class _MobileBottomNavState extends ConsumerState<_MobileBottomNav> {
  String? _role;

  @override
  void initState() {
    super.initState();
    AuthStorage.getRole().then((r) {
      if (mounted) setState(() => _role = r);
    });
  }

  // null (loading) → SITE_STAFF to avoid sensitive tabs flashing
  bool get _isSiteStaff => _role == null || _role == 'SITE_STAFF';

  // Five direct-route tabs (index 5 = More is appended in build)
  static const _adminTabs = [
    (label: 'Home',     icon: Icons.dashboard_outlined,               activeIcon: Icons.dashboard,               route: '/dashboard'),
    (label: 'Trips',    icon: Icons.swap_horiz_outlined,              activeIcon: Icons.swap_horiz,              route: '/trips'),
    (label: 'Work',     icon: Icons.construction_outlined,            activeIcon: Icons.construction,            route: '/machine-work'),
    (label: 'Diesel',   icon: Icons.local_gas_station_outlined,       activeIcon: Icons.local_gas_station,       route: '/diesel'),
    (label: 'Accounts', icon: Icons.account_balance_wallet_outlined,  activeIcon: Icons.account_balance_wallet,  route: '/accounts'),
  ];

  // SITE_STAFF can't access Accounts; show Dabar instead
  static const _siteStaffTabs = [
    (label: 'Home',   icon: Icons.dashboard_outlined,           activeIcon: Icons.dashboard,           route: '/dashboard'),
    (label: 'Trips',  icon: Icons.swap_horiz_outlined,          activeIcon: Icons.swap_horiz,          route: '/trips'),
    (label: 'Work',   icon: Icons.construction_outlined,        activeIcon: Icons.construction,        route: '/machine-work'),
    (label: 'Diesel', icon: Icons.local_gas_station_outlined,   activeIcon: Icons.local_gas_station,   route: '/diesel'),
    (label: 'Dabar',  icon: Icons.terrain_outlined,             activeIcon: Icons.terrain,             route: '/dabar'),
  ];

  List<({String label, IconData icon, IconData activeIcon, String route})>
      get _directTabs => _isSiteStaff ? _siteStaffTabs : _adminTabs;

  bool get _isMoreActive =>
      !_directTabs.any((t) => t.route == widget.location);

  @override
  Widget build(BuildContext context) {
    final tabs = _directTabs;
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: Colors.grey.shade200),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: _NavBarItem(
                        icon: tab.icon,
                        activeIcon: tab.activeIcon,
                        label: tab.label,
                        isSelected: tab.route == widget.location,
                        color: color,
                        onTap: () => context.go(tab.route),
                      ),
                    ),
                  Expanded(
                    child: _NavBarItem(
                      icon: Icons.menu_rounded,
                      activeIcon: Icons.menu_rounded,
                      label: 'More',
                      isSelected: _isMoreActive,
                      color: color,
                      onTap: () => _openMoreSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MobileMoreSheet(role: _role, location: widget.location),
    );
  }
}

// ── Compact nav bar item ──────────────────────────────────────────────────────

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = isSelected ? color : Colors.grey[600]!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, size: 22, color: itemColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: itemColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── More bottom sheet ─────────────────────────────────────────────────────────

class _MobileMoreSheet extends StatelessWidget {
  final String? role;
  final String location;
  const _MobileMoreSheet({this.role, required this.location});

  bool _visible(int index) {
    switch (role) {
      case 'OWNER_ADMIN':
        return true;
      case 'OFFICE_ACCOUNTANT':
        return index != 10 && index != 18;
      default:
        // SITE_STAFF or null (loading) — most restrictive
        return !const {5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18}
            .contains(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    Widget item(IconData icon, IconData activeIcon, String label, String route) {
      final isActive = location == route;
      return ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Icon(isActive ? activeIcon : icon,
            size: 20, color: isActive ? color : Colors.grey[700]),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? color : Colors.grey[800],
          ),
        ),
        tileColor: isActive ? color.withValues(alpha: 0.06) : null,
        onTap: () {
          Navigator.pop(context);
          context.go(route);
        },
      );
    }

    Widget section(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
              letterSpacing: 0.8,
            ),
          ),
        );

    final showFinance = _visible(5) || _visible(6);
    final showWorkforce = _visible(9) || _visible(11);
    final showMasterData = _visible(12) || _visible(13) ||
        _visible(14) || _visible(15) || _visible(16) || _visible(17);
    final showAdmin = _visible(10) || _visible(18);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Menu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // OPERATIONS — Dabar (visible to all; Diesel/Work are in bottom nav)
                section('Operations'),
                item(Icons.terrain_outlined, Icons.terrain, 'Dabar', '/dabar'),

                // FINANCE
                if (showFinance) ...[
                  const SizedBox(height: 4),
                  section('Finance'),
                  if (_visible(6)) item(Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices', '/invoices'),
                  if (_visible(5)) item(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', '/reports'),
                ],

                // WORKFORCE
                if (showWorkforce) ...[
                  const SizedBox(height: 4),
                  section('Workforce'),
                  if (_visible(9))  item(Icons.fact_check_outlined, Icons.fact_check, 'Attendance', '/attendance'),
                  if (_visible(11)) item(Icons.badge_outlined, Icons.badge, 'Employees', '/employees'),
                ],

                // MASTER DATA
                if (showMasterData) ...[
                  const SizedBox(height: 4),
                  section('Master Data'),
                  if (_visible(12)) item(Icons.people_outline, Icons.people, 'Parties', '/parties'),
                  if (_visible(13)) item(Icons.local_shipping_outlined, Icons.local_shipping, 'Vehicles', '/vehicles'),
                  if (_visible(14)) item(Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Machines', '/machines'),
                  if (_visible(15)) item(Icons.category_outlined, Icons.category, 'Materials', '/materials'),
                  if (_visible(16)) item(Icons.location_on_outlined, Icons.location_on, 'Sites', '/sites'),
                  if (_visible(17)) item(Icons.handyman_outlined, Icons.handyman, 'Services', '/services'),
                ],

                // ADMIN (OWNER_ADMIN only)
                if (showAdmin) ...[
                  const SizedBox(height: 4),
                  section('Admin'),
                  if (_visible(10)) item(Icons.manage_accounts_outlined, Icons.manage_accounts, 'Users', '/users'),
                  if (_visible(18)) item(Icons.store_outlined, Icons.store, 'Business Profile', '/business-profile'),
                ],

                // SYSTEM
                const SizedBox(height: 8),
                const Divider(),
                section('System'),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: const Icon(Icons.logout, color: Colors.grey, size: 20),
                  title: const Text('Logout',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  onTap: () async {
                    Navigator.pop(context);
                    await AuthStorage.clear();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  String? _userName;

  @override
  void initState() {
    super.initState();
    AuthStorage.getRole().then((r) {
      if (mounted) setState(() => _role = r);
    });
    AuthStorage.getName().then((n) {
      if (mounted) setState(() => _userName = n);
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
        // Hides: Users (10), Business Profile (18) — OWNER_ADMIN only
        return index != 10 && index != 18;
      default:
        // SITE_STAFF or null (loading): operations only
        return !const {5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18}.contains(index);
    }
  }

  String _roleLabel(String? role) => switch (role) {
        'OWNER_ADMIN'       => 'Owner / Admin',
        'OFFICE_ACCOUNTANT' => 'Office / Accountant',
        'SITE_STAFF'        => 'Site Staff',
        _                   => '',
      };

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
    final showFinance    = _visible(6) || _visible(7) || _visible(8);
    final showWorkforce  = _visible(9) || _visible(11);
    final showMasterData = _visible(12) || _visible(13) || _visible(14) || _visible(15) || _visible(16) || _visible(17);
    final showAdmin      = _visible(10) || _visible(18);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 200,
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
                  _item(Icons.terrain_outlined, Icons.terrain, 'Dabar', 2),
                  _item(Icons.local_gas_station_outlined, Icons.local_gas_station, 'Diesel', 3),
                  _item(Icons.construction_outlined, Icons.construction, 'Machine Work', 4),
                  _item(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', 5),

                  if (showFinance) ...[
                    const SizedBox(height: 4),
                    _NavSection('Finance'),
                    _item(Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices', 6),
                    _item(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Accounts', 7),
                  ],

                  if (showWorkforce) ...[
                    const SizedBox(height: 4),
                    _NavSection('Workforce'),
                    _item(Icons.fact_check_outlined, Icons.fact_check, 'Attendance', 9),
                    _item(Icons.badge_outlined, Icons.badge, 'Employees', 11),
                  ],

                  if (showMasterData) ...[
                    const SizedBox(height: 4),
                    _NavSection('Master Data'),
                    _item(Icons.people_outline, Icons.people, 'Parties', 12),
                    _item(Icons.local_shipping_outlined, Icons.local_shipping, 'Vehicles', 13),
                    _item(Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Machines', 14),
                    _item(Icons.category_outlined, Icons.category, 'Materials', 15),
                    _item(Icons.location_on_outlined, Icons.location_on, 'Sites', 16),
                    _item(Icons.handyman_outlined, Icons.handyman, 'Services', 17),
                  ],

                  if (showAdmin) ...[
                    const SizedBox(height: 4),
                    _NavSection('Admin'),
                    _item(Icons.manage_accounts_outlined, Icons.manage_accounts, 'Users', 10),
                    _item(Icons.store_outlined, Icons.store, 'Business Profile', 18),
                  ],
                ],
              ),
            ),

            // ── Footer: logged-in user + logout ──────────────────────────────
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_userName != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            child: Text(
                              _userName![0].toUpperCase(),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName!,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _roleLabel(_role),
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.logout,
                          size: 18, color: Colors.grey),
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
            ),
          ],
        ),
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
    '/trips', '/dabar', '/diesel', '/machine-work', '/reports',
    '/invoices', '/accounts', '/ledger',
    '/attendance',
    '/users', '/employees', '/parties', '/vehicles', '/machines', '/materials', '/sites',
    '/services',           // 17 — Master Data: Services
    '/business-profile',   // 18 — Admin: Business Profile
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
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
      error: (_, _) => const SizedBox.shrink(),
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

// ── site switcher (admin/accountant) — desktop sidebar ───────────────────────

class _SiteSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final selectedId = ref.watch(selectedSiteIdProvider);

    return sites.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
                      child: Text(s['name'] as String,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
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
