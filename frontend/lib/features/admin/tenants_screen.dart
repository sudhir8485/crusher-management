import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

// ── provider ──────────────────────────────────────────────────────────────────

final tenantsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/admin/tenants');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ────────────────────────────────────────────────────────────────────

class TenantsScreen extends ConsumerWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tenantsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Tenant',
            style: TextStyle(color: Colors.white)),
        onPressed: () => _showCreateDialog(context, ref),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tenants) {
          if (tenants.isEmpty) {
            return const Center(
              child: Text('No tenants yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tenants.length,
            itemBuilder: (ctx, i) =>
                _TenantCard(tenant: tenants[i], ref: ref),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateTenantDialog(onCreated: () {
        ref.invalidate(tenantsProvider);
      }),
    );
  }
}

// ── tenant card ───────────────────────────────────────────────────────────────

class _TenantCard extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final WidgetRef ref;
  const _TenantCard({required this.tenant, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isActive = tenant['status'] == 'ACTIVE';
    final created = tenant['createdAt'] != null
        ? DateFormat('d MMM yyyy')
            .format(DateTime.parse(tenant['createdAt']))
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.deepPurple.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.domain,
                  color: isActive ? Colors.deepPurple : Colors.grey,
                  size: 22),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tenant['name'] ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      _StatusChip(isActive: isActive),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (tenant['ownerName'] != null)
                    Text(
                      tenant['ownerName'],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  if (tenant['ownerEmail'] != null)
                    Text(
                      tenant['ownerEmail'],
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Created $created',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // Actions menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (action) =>
                  _handleAction(context, action, tenant, ref),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: isActive ? 'deactivate' : 'reactivate',
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.block_outlined
                            : Icons.check_circle_outline,
                        size: 18,
                        color: isActive ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Deactivate' : 'Reactivate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_outlined,
                          size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Reset Password'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action,
      Map<String, dynamic> tenant, WidgetRef ref) {
    final id = tenant['id'];
    final name = tenant['name'] ?? 'this tenant';

    switch (action) {
      case 'deactivate':
        _confirmAction(
          context: context,
          title: 'Deactivate "$name"?',
          message:
              'The tenant will be marked inactive. Their users can still log in but the account is flagged as inactive.',
          confirmLabel: 'Deactivate',
          confirmColor: Colors.red,
          onConfirm: () async {
            await ref
                .read(apiClientProvider)
                .patch('/api/admin/tenants/$id/deactivate');
            ref.invalidate(tenantsProvider);
          },
        );
        break;
      case 'reactivate':
        _confirmAction(
          context: context,
          title: 'Reactivate "$name"?',
          message: 'The tenant will be marked active again.',
          confirmLabel: 'Reactivate',
          confirmColor: Colors.green,
          onConfirm: () async {
            await ref
                .read(apiClientProvider)
                .patch('/api/admin/tenants/$id/reactivate');
            ref.invalidate(tenantsProvider);
          },
        );
        break;
      case 'reset_password':
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ResetPasswordDialog(
            tenantId: id,
            tenantName: name,
            onReset: () => ref.invalidate(tenantsProvider),
          ),
        );
        break;
    }
  }

  void _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await onConfirm();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.teal.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.teal.shade200 : Colors.red.shade200,
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.teal.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

// ── create tenant dialog ──────────────────────────────────────────────────────

class _CreateTenantDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateTenantDialog({required this.onCreated});

  @override
  ConsumerState<_CreateTenantDialog> createState() =>
      _CreateTenantDialogState();
}

class _CreateTenantDialogState extends ConsumerState<_CreateTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bizCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _bizCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/api/admin/tenants', data: {
        'businessName': _bizCtrl.text.trim(),
        'ownerFullName': _nameCtrl.text.trim(),
        'ownerEmail': _emailCtrl.text.trim(),
        'ownerPassword': _passCtrl.text,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tenant created successfully'),
              backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to create tenant. Check details and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.domain_add,
                        color: Colors.deepPurple, size: 22),
                    const SizedBox(width: 10),
                    const Text('New Tenant',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Business'),
                TextFormField(
                  controller: _bizCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Business Name', isDense: true),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Owner / Admin'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Full Name', isDense: true),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email', isDense: true),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          size: 18),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Confirm Password', isDense: true),
                  obscureText: _obscure,
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Tenant'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── reset password dialog ─────────────────────────────────────────────────────

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  final int tenantId;
  final String tenantName;
  final VoidCallback onReset;
  const _ResetPasswordDialog({
    required this.tenantId,
    required this.tenantName,
    required this.onReset,
  });

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref
          .read(apiClientProvider)
          .post('/api/admin/tenants/${widget.tenantId}/reset-password',
              data: {'newPassword': _passCtrl.text});
      if (mounted) {
        Navigator.pop(context);
        widget.onReset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password reset successfully'),
              backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      setState(() => _error = 'Reset failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_reset,
                        color: Colors.orange, size: 22),
                    const SizedBox(width: 10),
                    const Text('Reset Password',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Resetting owner/admin password for "${widget.tenantName}".',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          size: 18),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Confirm Password', isDense: true),
                  obscureText: _obscure,
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade700),
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Reset Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
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
