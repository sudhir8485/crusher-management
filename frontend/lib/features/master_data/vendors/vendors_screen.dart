import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../widgets/master_list_screen.dart';

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
    return MasterListScreen(
      title: 'Parties',
      items: vendors,
      onRefresh: () => ref.invalidate(vendorsProvider),
      onAdd: () => _showForm(context, ref, null),
      itemBuilder: (v) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.people)),
        title: Text(v['name']),
        subtitle: Text(v['gstin'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(context, ref, v)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, v['id'] as int, v['name'] as String)),
          ],
        ),
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
