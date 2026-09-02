import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

final vendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(vendorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(vendorsProvider),
          ),
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
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No parties yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Tap + to add a party', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _PartyCard(
              party: list[i],
              onEdit: () => _showForm(context, ref, list[i]),
              onDelete: () => _confirmDelete(context, ref, list[i]['id'] as int, list[i]['name'] as String),
            ),
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _VendorForm(existing: existing, onSaved: () => ref.invalidate(vendorsProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate party?'),
        content: Text('Deactivate "$name"? They will be marked inactive and hidden from new entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final api = ref.read(apiClientProvider);
              await api.delete('/api/parties/$id');
              ref.invalidate(vendorsProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

// ── party card ────────────────────────────────────────────────────────────────

class _PartyCard extends StatelessWidget {
  final Map<String, dynamic> party;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PartyCard({required this.party, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = party['name'] as String? ?? '';
    final gstin = party['gstin'] as String? ?? '';
    final contact = party['contact'] as String? ?? '';
    final outstanding = (party['outstandingAmount'] as num?)?.toDouble() ?? 0.0;
    final hasOutstanding = outstanding > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: hasOutstanding
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: Icon(
                Icons.people,
                color: hasOutstanding ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  if (gstin.isNotEmpty || contact.isNotEmpty)
                    Text(
                      [if (gstin.isNotEmpty) gstin, if (contact.isNotEmpty) contact].join('  ·  '),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hasOutstanding) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Outstanding: ${_currFmt.format(outstanding)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'No outstanding',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => context.go('/ledger'),
                  child: const Text('Ledger', style: TextStyle(fontSize: 12)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit),
                    IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        onPressed: onDelete),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _VendorForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends ConsumerState<_VendorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name   = TextEditingController(text: widget.existing?['name']);
  late final TextEditingController _gstin  = TextEditingController(text: widget.existing?['gstin']);
  late final TextEditingController _contact= TextEditingController(text: widget.existing?['contact']);
  late final TextEditingController _address= TextEditingController(text: widget.existing?['address']);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _gstin.dispose(); _contact.dispose(); _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final data = {'name': _name.text, 'gstin': _gstin.text, 'contact': _contact.text, 'address': _address.text};
    if (widget.existing == null) {
      await api.post('/api/parties', data: data);
    } else {
      await api.put('/api/parties/${widget.existing!['id']}', data: data);
    }
    if (mounted) { Navigator.pop(context); widget.onSaved(); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Party' : 'Edit Party'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
              const SizedBox(height: 12),
              TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact')),
              const SizedBox(height: 12),
              TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
