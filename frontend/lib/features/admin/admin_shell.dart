import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/auth_storage.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    AuthStorage.getName().then((n) {
      if (mounted) setState(() => _userName = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(userName: _userName),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  final String? userName;
  const _AdminSidebar({this.userName});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        size: 22, color: Colors.deepPurple),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Platform Admin',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.deepPurple),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _AdminNavItem(
                    icon: Icons.domain_outlined,
                    selectedIcon: Icons.domain,
                    label: 'Tenants',
                    path: '/admin/tenants',
                    currentPath: location,
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (userName != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                Colors.deepPurple.withValues(alpha: 0.12),
                            child: Text(
                              userName![0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Platform Admin',
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

class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
  final String currentPath;

  const _AdminNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentPath == path;
    const color = Colors.deepPurple;

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
          leading: Icon(isSelected ? selectedIcon : icon,
              size: 20, color: isSelected ? color : Colors.grey[600]),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? color : Colors.grey[700],
            ),
          ),
          onTap: () => context.go(path),
        ),
      ),
    );
  }
}
