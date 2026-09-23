import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final usersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/users');
  return List<Map<String, dynamic>>.from(res.data);
});

final _usersSitesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/sites');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── role config ───────────────────────────────────────────────────────────────

const _roles = ['OWNER_ADMIN', 'OFFICE_ACCOUNTANT', 'SITE_STAFF'];

const _roleLabels = {
  'OWNER_ADMIN': 'Owner / Admin',
  'OFFICE_ACCOUNTANT': 'Office / Accountant',
  'SITE_STAFF': 'Site Staff',
};

const _roleColors = {
  'OWNER_ADMIN': Colors.purple,
  'OFFICE_ACCOUNTANT': Colors.blue,
  'SITE_STAFF': Colors.teal,
};

const _roleIcons = {
  'OWNER_ADMIN': Icons.admin_panel_settings,
  'OFFICE_ACCOUNTANT': Icons.account_balance_wallet_outlined,
  'SITE_STAFF': Icons.engineering_outlined,
};

// ── screen ────────────────────────────────────────────────────────────────────

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    final sitesAsync = ref.watch(_usersSitesProvider);
    final sites = sitesAsync.valueOrNull ?? [];
    final siteNameById = {for (final s in sites) s['id'] as int: s['name'] as String};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Text('No users found',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          final active = data.where((u) => u['status'] == 'ACTIVE').toList();
          final inactive =
              data.where((u) => u['status'] != 'ACTIVE').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('Active (${active.length})'),
                ...active.map((u) => _UserCard(
                      user: u,
                      siteName: siteNameById[u['siteId'] as int?],
                      onEdit: () => _showForm(context, ref, u),
                      onDeactivate: () =>
                          _confirmDeactivate(context, ref, u),
                    )),
              ],
              if (inactive.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('Inactive (${inactive.length})'),
                ...inactive.map((u) => _UserCard(
                      user: u,
                      siteName: siteNameById[u['siteId'] as int?],
                      onEdit: () => _showForm(context, ref, u),
                      onDeactivate: null,
                      onReactivate: () =>
                          _confirmReactivate(context, ref, u),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey)),
      );

  void _showForm(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic>? user) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _UserForm(
        existing: user,
        onSaved: () => ref.invalidate(usersProvider),
      ),
    );
  }

  void _confirmDeactivate(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> user) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text(
            'Deactivate ${user['fullName']}? They will no longer be able to log in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(apiClientProvider).delete('/api/users/${user['id']}');
              } catch (err) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(_errorMessage(err)),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (!ctx.mounted) return;
              ref.invalidate(usersProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  // Pull the server's business-language message ({"error": "..."}) out of a
  // failed request, falling back to a generic line.
  String _errorMessage(Object err) {
    try {
      final data = (err as dynamic).response?.data;
      if (data is Map && data['error'] is String) return data['error'] as String;
    } catch (_) {}
    return 'Could not complete the action. Please try again.';
  }

  void _confirmReactivate(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> user) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reactivate User'),
        content: Text(
            'Reactivate ${user['fullName']}? They will be able to log in again immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(apiClientProvider)
                    .patch('/api/users/${user['id']}/reactivate');
              } catch (_) { return; }
              if (!ctx.mounted) return;
              ref.invalidate(usersProvider);
            },
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
  }
}

// ── user card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String? siteName;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;
  const _UserCard(
      {required this.user,
      this.siteName,
      required this.onEdit,
      this.onDeactivate,
      this.onReactivate});

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String? ?? 'SITE_STAFF';
    final isActive = user['status'] == 'ACTIVE';
    final color = _roleColors[role] ?? Colors.grey;
    final icon = _roleIcons[role] ?? Icons.person;
    final createdAt = user['createdAt'] != null
        ? DateFormat('d MMM yyyy')
            .format(DateTime.parse(user['createdAt'] as String))
        : '';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? color.withValues(alpha: 0.12) : Colors.grey[200],
          child: Icon(icon,
              color: isActive ? color : Colors.grey, size: 20),
        ),
        title: Text(user['fullName'] as String? ?? '—',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? null : Colors.grey)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] as String? ?? '—',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withValues(alpha: 0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _roleLabels[role] ?? role,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? color : Colors.grey),
                  ),
                ),
                if (user['protectedOwner'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user,
                            size: 11, color: Color(0xFF8D6E00)),
                        SizedBox(width: 2),
                        Text('Primary owner',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8D6E00))),
                      ],
                    ),
                  ),
                ],
                if (role == 'SITE_STAFF' && siteName != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.location_on, size: 12, color: Colors.teal),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(siteName!,
                        style: const TextStyle(fontSize: 11, color: Colors.teal),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            if (createdAt.isNotEmpty)
              Text('Added $createdAt',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'deactivate') onDeactivate?.call();
            if (v == 'reactivate') onReactivate?.call();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            // The founding owner (created by superadmin) can never be
            // deactivated — hide the option so the tenant can't lock itself out.
            if (onDeactivate != null && user['protectedOwner'] != true)
              const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Deactivate',
                      style: TextStyle(color: Colors.orange))),
            if (onReactivate != null)
              const PopupMenuItem(
                  value: 'reactivate',
                  child: Text('Reactivate',
                      style: TextStyle(color: Colors.green))),
          ],
        ),
      ),
    );
  }
}

// ── form ──────────────────────────────────────────────────────────────────────

class _UserForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _UserForm({required this.existing, required this.onSaved});

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'OFFICE_ACCOUNTANT';
  int? _siteId;
  bool _saving = false;
  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['fullName'] as String? ?? '';
      _emailCtrl.text = e['email'] as String? ?? '';
      _role = e['role'] as String? ?? 'OFFICE_ACCOUNTANT';
      _siteId = e['siteId'] as int?;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'fullName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text.isEmpty ? null : _passCtrl.text,
      'role': _role,
      if (_role == 'SITE_STAFF') 'siteId': _siteId,
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    try {
      if (e == null) {
        await api.post('/api/users', data: body);
      } else {
        await api.put('/api/users/${e['id']}', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $err'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final sitesAsync = ref.watch(_usersSitesProvider);
    final sitesLoading = _role == 'SITE_STAFF' && !sitesAsync.hasValue;
    final sites = sitesAsync.valueOrNull ?? [];

    return AlertDialog(
      title: Text(isEdit ? 'Edit User' : 'Add User'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: !_showPass,
                decoration: InputDecoration(
                  labelText: isEdit
                      ? 'New Password (leave blank to keep)'
                      : 'Password *',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () =>
                        setState(() => _showPass = !_showPass),
                  ),
                ),
                validator: (v) {
                  if (!isEdit && (v == null || v.isEmpty)) {
                    return 'Password required for new user';
                  }
                  if (v != null && v.isNotEmpty && v.length < 6) {
                    return 'Min 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Role',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              ..._roles.map((r) {
                final color = _roleColors[r] ?? Colors.grey;
                final icon = _roleIcons[r] ?? Icons.person;
                final isSelected = _role == r;
                return GestureDetector(
                  onTap: () => setState(() {
                    _role = r;
                    if (r != 'SITE_STAFF') _siteId = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon,
                            color: isSelected ? color : Colors.grey,
                            size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(_roleLabels[r] ?? r,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? color
                                          : null)),
                              Text(
                                _roleDesc(r),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle,
                              color: color, size: 20),
                      ],
                    ),
                  ),
                );
              }),

              // Assigned Site — shown only for SITE_STAFF
              if (_role == 'SITE_STAFF') ...[
                const SizedBox(height: 16),
                if (sitesLoading)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<int?>(
                    initialValue: _siteId,
                    decoration: const InputDecoration(
                        labelText: 'Assigned Site *',
                        border: OutlineInputBorder()),
                    items: sites
                        .map((s) => DropdownMenuItem<int?>(
                              value: s['id'] as int?,
                              child: Text(s['name'] as String? ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _siteId = v),
                    validator: (_) =>
                        _siteId == null ? 'Select a site' : null,
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_saving || sitesLoading) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update' : 'Create User'),
        ),
      ],
    );
  }

  String _roleDesc(String role) => switch (role) {
        'OWNER_ADMIN' => 'Full access — all modules, user management, reports',
        'OFFICE_ACCOUNTANT' =>
          'Trips, diesel, invoices, payments — no user management',
        'SITE_STAFF' => 'Data entry only — trips, diesel, machine work',
        _ => '',
      };
}
