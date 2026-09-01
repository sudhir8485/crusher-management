import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_widgets.dart';
import '../vehicles/vehicles_screen.dart' show vendorListProvider;
import '../widgets/master_list_screen.dart';

final machinesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/machines');
  return List<Map<String, dynamic>>.from(res.data);
});

class MachinesScreen extends ConsumerWidget {
  const MachinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines = ref.watch(machinesProvider);
    return MasterListScreen(
      title: 'Machines',
      items: machines,
      onRefresh: () => ref.invalidate(machinesProvider),
      onAdd: () => _showForm(context, ref, null),
      itemBuilder: (m) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.construction)),
        title: Text(m['name']),
        subtitle: Text('${m['owner']} · ${m['machineType'] ?? ""}'),
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
      builder: (_) => _MachineForm(existing: existing, onSaved: () => ref.invalidate(machinesProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate machine?'),
        content: Text('Deactivate "$name"? It will be hidden from new work log entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/machines/$id');
              ref.invalidate(machinesProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _MachineForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _MachineForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_MachineForm> createState() => _MachineFormState();
}

class _MachineFormState extends ConsumerState<_MachineForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?['name']);
  late final _type = TextEditingController(text: widget.existing?['machineType']);
  String _owner = 'VENDOR';
  int? _vendorId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.existing?['owner'] ?? 'VENDOR';
    _vendorId = widget.existing?['vendorId'];
  }

  @override
  void dispose() { _name.dispose(); _type.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {'owner': _owner, 'vendorId': _vendorId, 'name': _name.text, 'machineType': _type.text};
    final api = ref.read(apiClientProvider);
    if (widget.existing == null) {
      await api.post('/api/machines', data: data);
    } else {
      await api.put('/api/machines/${widget.existing!['id']}', data: data);
    }
    if (mounted) { Navigator.pop(context); widget.onSaved(); }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorListProvider);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Machine' : 'Edit Machine'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Machine Name *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _type, decoration: const InputDecoration(labelText: 'Type (e.g. JCB, Comosko)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _owner,
                decoration: const InputDecoration(labelText: 'Owner'),
                items: const [
                  DropdownMenuItem(value: 'TENANT', child: Text('Tenant (our own)')),
                  DropdownMenuItem(value: 'VENDOR', child: Text('Party (External)')),
                ],
                onChanged: (v) => setState(() => _owner = v!),
              ),
              if (_owner == 'VENDOR') ...[
                const SizedBox(height: 12),
                vendors.when(
                  data: (list) => SearchablePicker(
                    items: list,
                    itemLabel: (v) => v['name'] as String,
                    fieldLabel: 'Party',
                    value: _vendorId,
                    onChanged: (v) => setState(() => _vendorId = v),
                    validator: (v) => v == null ? 'Select vendor' : null,
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
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
