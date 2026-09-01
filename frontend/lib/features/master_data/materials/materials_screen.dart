import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../widgets/master_list_screen.dart';

final materialsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/materials');
  return List<Map<String, dynamic>>.from(res.data);
});

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsProvider);
    return MasterListScreen(
      title: 'Materials',
      items: materials,
      onRefresh: () => ref.invalidate(materialsProvider),
      onAdd: () => _showForm(context, ref, null),
      itemBuilder: (m) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.category)),
        title: Text(m['name']),
        subtitle: Text('Unit: ${m['unit']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(context, ref, m)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, m['id'] as int, m['name'] as String)),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _MaterialForm(existing: existing, onSaved: () => ref.invalidate(materialsProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate material?'),
        content: Text('Deactivate "$name"? It will be hidden from new trip entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/materials/$id');
              ref.invalidate(materialsProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _MaterialForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _MaterialForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_MaterialForm> createState() => _MaterialFormState();
}

class _MaterialFormState extends ConsumerState<_MaterialForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name  = TextEditingController(text: widget.existing?['name']);
  late final _label = TextEditingController(text: widget.existing?['sizeLabel']);
  String _unit = 'BRASS';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.existing?['unit'] ?? 'BRASS';
  }

  @override
  void dispose() { _name.dispose(); _label.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {'name': _name.text, 'sizeLabel': _label.text, 'unit': _unit};
    final api = ref.read(apiClientProvider);
    if (widget.existing == null) {
      await api.post('/api/materials', data: data);
    } else {
      await api.put('/api/materials/${widget.existing!['id']}', data: data);
    }
    if (mounted) { Navigator.pop(context); widget.onSaved(); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Material' : 'Edit Material'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _label, decoration: const InputDecoration(labelText: 'Size Label (e.g. 20 MM)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: const [
                  DropdownMenuItem(value: 'BRASS', child: Text('Brass')),
                  DropdownMenuItem(value: 'TON',   child: Text('Ton')),
                ],
                onChanged: (v) => setState(() => _unit = v!),
              ),
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
