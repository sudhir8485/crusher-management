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
    '/trips', '/dabar', '/diesel', '/machine-work', '/reports',
    '/invoices', '/accounts', '/ledger',
    '/attendance',
    '/users', '/employees', '/parties', '/vehicles', '/machines', '/materials', '/sites',
    '/services',           // 17 — Master Data: Services
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
        // Hides: Reports (5), Finance (6,7,8), Attendance (9), Users (10), Employees (11),
        //        Parties (12), Vehicles (13), Machines (14), Materials (15), Sites (16), Services (17),
        //        Business Profile (18)
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
    if (MediaQuery.of(context).size.width < 700) {
      return _buildNarrowRail(context);
    }
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
          ),
        ],
      ),
      ), // SizedBox
    ); // Material
  }

  // ── Narrow icon rail (viewport < 700 px) ─────────────────────────────────

  Widget _buildNarrowRail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: SizedBox(
        width: 56,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: const Icon(Icons.business, size: 20, color: Color(0xFF1565C0)),
            ),
            if (_role == 'SITE_STAFF')
              _buildCompactSiteLabel(context)
            else if (_role == 'OWNER_ADMIN' || _role == 'OFFICE_ACCOUNTANT')
              _buildCompactSiteButton(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _cItem(Icons.dashboard_outlined,                 Icons.dashboard,                 'Dashboard',       0),
                  _cItem(Icons.swap_horiz_outlined,                Icons.swap_horiz,                'Trips',           1),
                  _cItem(Icons.terrain_outlined,                   Icons.terrain,                   'Dabar',           2),
                  _cItem(Icons.local_gas_station_outlined,         Icons.local_gas_station,         'Diesel',          3),
                  _cItem(Icons.construction_outlined,              Icons.construction,              'Machine Work',    4),
                  _cItem(Icons.bar_chart_outlined,                 Icons.bar_chart,                 'Reports',         5),
                  _cItem(Icons.receipt_long_outlined,              Icons.receipt_long,              'Invoices',        6),
                  _cItem(Icons.account_balance_wallet_outlined,    Icons.account_balance_wallet,    'Accounts',        7),
                  _cItem(Icons.fact_check_outlined,                Icons.fact_check,                'Attendance',      9),
                  _cItem(Icons.badge_outlined,                     Icons.badge,                     'Employees',      11),
                  _cItem(Icons.people_outline,                     Icons.people,                    'Parties',        12),
                  _cItem(Icons.local_shipping_outlined,            Icons.local_shipping,            'Vehicles',       13),
                  _cItem(Icons.precision_manufacturing_outlined,   Icons.precision_manufacturing,   'Machines',       14),
                  _cItem(Icons.category_outlined,                  Icons.category,                  'Materials',      15),
                  _cItem(Icons.location_on_outlined,               Icons.location_on,               'Sites',          16),
                  _cItem(Icons.handyman_outlined,                  Icons.handyman,                  'Services',       17),
                  _cItem(Icons.manage_accounts_outlined,           Icons.manage_accounts,           'Users',          10),
                  _cItem(Icons.store_outlined,                     Icons.store,                     'Business Profile', 18),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: _buildCompactFooter(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cItem(IconData icon, IconData selIcon, String label, int index) {
    if (!_visible(index)) return const SizedBox.shrink();
    final isSelected = widget.selectedIndex == index;
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go(_NavItem._routes[index]),
            child: SizedBox(
              height: 40,
              child: Center(
                child: Icon(
                  isSelected ? selIcon : icon,
                  size: 20,
                  color: isSelected ? color : Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSiteButton(BuildContext context) {
    final sites     = ref.watch(sitesProvider);
    final selectedId = ref.watch(selectedSiteIdProvider);
    final color      = Theme.of(context).colorScheme.primary;
    final siteName   = sites.valueOrNull
        ?.where((s) => s['id'] == selectedId)
        .firstOrNull?['name'] as String?;
    return Tooltip(
      message: siteName ?? 'All Sites — tap to switch',
      child: InkWell(
        onTap: () => _showSiteSheet(context, sites.valueOrNull ?? []),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Icon(Icons.location_on, size: 18,
                color: selectedId != null ? color : Colors.grey[400]),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSiteLabel(BuildContext context) {
    final sites  = ref.watch(sitesProvider);
    final siteId = ref.watch(selectedSiteIdProvider);
    final name   = sites.valueOrNull
        ?.where((s) => s['id'] == siteId)
        .firstOrNull?['name'] as String? ?? 'Site';
    return Tooltip(
      message: name,
      child: SizedBox(
        height: 40,
        child: Center(child: Icon(Icons.location_on, size: 18, color: Colors.green[600])),
      ),
    );
  }

  Widget _buildCompactFooter(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: _userName != null ? '$_userName — Logout' : 'Logout',
      child: InkWell(
        onTap: () async {
          await AuthStorage.clear();
          if (context.mounted) context.go('/login');
        },
        child: SizedBox(
          height: 48,
          child: Center(
            child: _userName != null
                ? CircleAvatar(
                    radius: 13,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text(_userName![0].toUpperCase(),
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.bold, color: color)),
                  )
                : const Icon(Icons.logout, size: 18, color: Colors.grey),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: Icon(Icons.all_inclusive,
                    color: selectedId == null ? cs.primary : Colors.grey),
                title: const Text('All Sites'),
                selected: selectedId == null,
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
                  title: Text(s['name'] as String),
                  selected: id == selectedId,
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

// ── site switcher (admin/accountant) ─────────────────────────────────────────

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
