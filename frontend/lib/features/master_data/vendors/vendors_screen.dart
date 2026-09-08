import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Active-only — used by pickers (trip form, payment form, etc.)
final vendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

/// All non-deleted including inactive — show-inactive admin view.
final _vendorsAllProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties', params: {'includeInactive': 'true'});
  return List<Map<String, dynamic>>.from(res.data);
});

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});
  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final provider = _showInactive ? _vendorsAllProvider : vendorsProvider;
    final vendors  = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties'),
        actions: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Show Inactive', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(width: 4),
            Switch(
              value: _showInactive,
              onChanged: (v) => setState(() => _showInactive = v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            ref.invalidate(vendorsProvider);
            ref.invalidate(_vendorsAllProvider);
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Party'),
      ),
      body: vendors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No parties yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
              SizedBox(height: 4),
              Text('Tap + to add a party', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ]));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _PartyCard(
              party: list[i],
              onEdit: () => _showForm(context, ref, list[i]),
              onDelete: () => _confirmDelete(context, ref, list[i]['id'] as int, list[i]['name'] as String),
              onToggle: () => _toggleActive(context, ref, list[i]['id'] as int),
            ),
          );
        },
      ),
    );
  }

  void _toggleActive(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(apiClientProvider).patch('/api/parties/$id/toggle-active');
      ref.invalidate(vendorsProvider);
      ref.invalidate(_vendorsAllProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_apiError(e)), backgroundColor: Colors.red));
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _VendorForm(
        existing: existing,
        onSaved: () {
          ref.invalidate(vendorsProvider);
          ref.invalidate(_vendorsAllProvider);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete party?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Permanently remove "$name"?'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'If this party has any trips, invoices, or payments, delete will be blocked. '
                'Use the toggle switch to deactivate them instead.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(apiClientProvider).delete('/api/parties/$id');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_apiError(e)), backgroundColor: Colors.red));
                return;
              }
              if (!context.mounted) return;
              ref.invalidate(vendorsProvider);
              ref.invalidate(_vendorsAllProvider);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Party card ────────────────────────────────────────────────────────────────

class _PartyCard extends StatelessWidget {
  final Map<String, dynamic> party;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _PartyCard({required this.party, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final name        = party['name'] as String? ?? '';
    final gstin       = party['gstin'] as String? ?? '';
    final contact     = party['contact'] as String? ?? '';
    final outstanding = (party['outstandingAmount'] as num?)?.toDouble() ?? 0.0;
    final hasOutstanding = outstanding > 0;
    final isActive    = party['active'] as bool? ?? true;

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              backgroundColor: !isActive
                  ? Colors.grey.shade200
                  : hasOutstanding ? Colors.red.shade50 : Colors.green.shade50,
              child: Icon(Icons.people,
                  color: !isActive ? Colors.grey : hasOutstanding ? Colors.red : Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                    child: Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ),
              ]),
              if (gstin.isNotEmpty || contact.isNotEmpty)
                Text([if (gstin.isNotEmpty) gstin, if (contact.isNotEmpty) contact].join('  ·  '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 6),
              if (isActive) ...[
                hasOutstanding
                    ? _badge('Outstanding: ${_currFmt.format(outstanding)}', Colors.red)
                    : _badge('No outstanding', Colors.green),
              ],
            ])),
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (isActive)
                TextButton(
                  onPressed: () => context.go('/ledger'),
                  child: const Text('Ledger', style: TextStyle(fontSize: 12)),
                ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                // Active/Inactive toggle
                Switch(
                  value: isActive,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: onDelete,
                ),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String label, MaterialColor color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.shade50, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.shade200),
    ),
    child: Text(label, style: TextStyle(fontSize: 12, color: color.shade700, fontWeight: FontWeight.w600)),
  );
}

String _apiError(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
  } catch (_) {}
  return e.toString();
}

// ── Vendor form ───────────────────────────────────────────────────────────────

class _VendorForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _VendorForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends ConsumerState<_VendorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name    = TextEditingController(text: widget.existing?['name']);
  late final TextEditingController _gstin   = TextEditingController(text: widget.existing?['gstin'] ?? '');
  late final TextEditingController _contact = TextEditingController(text: widget.existing?['contact'] ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.existing?['address'] ?? '');
  bool _gstRegistered = false;
  bool _isRegular     = false;
  bool _saving        = false;

  @override
  void initState() {
    super.initState();
    _gstRegistered = widget.existing?['gstRegistered'] as bool? ?? false;
    _isRegular     = widget.existing?['isRegular']     as bool? ?? false;
  }

  @override
  void dispose() { _name.dispose(); _gstin.dispose(); _contact.dispose(); _address.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api  = ref.read(apiClientProvider);
    final data = {
      'name': _name.text, 'gstRegistered': _gstRegistered, 'isRegular': _isRegular,
      if (_gstin.text.trim().isNotEmpty) 'gstin': _gstin.text.trim(),
      if (_contact.text.trim().isNotEmpty) 'contact': _contact.text.trim(),
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
    };
    try {
      if (widget.existing == null) {
        await api.post('/api/parties', data: data);
      } else {
        await api.put('/api/parties/${widget.existing!['id']}', data: data);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _typeBtn(String label, bool selected, VoidCallback onTap) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.grey.shade700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Party' : 'Edit Party'),
      content: SizedBox(width: 400, child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _typeBtn('Regular', _isRegular, () => setState(() => _isRegular = true))),
            const SizedBox(width: 8),
            Expanded(child: _typeBtn('Occasional', !_isRegular, () => setState(() => _isRegular = false))),
          ]),
          const SizedBox(height: 4),
          Text(
            _isRegular
                ? 'Appears in Trip quick-select list by default'
                : 'Reachable via search in Trip form — not in default list',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const Divider(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('GST Registered', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Generates Tax Invoice instead of Delivery Challan', style: TextStyle(fontSize: 11)),
            value: _gstRegistered,
            onChanged: (v) => setState(() => _gstRegistered = v),
          ),
          if (_gstRegistered) ...[
            const SizedBox(height: 4),
            TextFormField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN *'),
                validator: (v) => _gstRegistered && (v == null || v.trim().isEmpty)
                    ? 'GSTIN required for GST-registered party' : null),
          ] else
            TextFormField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN (optional)')),
          const SizedBox(height: 12),
          TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact')),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
        ]),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
