import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_widgets.dart';
import '../widgets/master_list_screen.dart';

final vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

final vendorListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    return MasterListScreen(
      title: 'Vehicles',
      items: vehicles,
      onRefresh: () => ref.invalidate(vehiclesProvider),
      onAdd: () => _showForm(context, ref, null),
      itemBuilder: (v) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
        title: Text('${v['plateNumber']}  ${v['displayName'] != null ? "(${v['displayName']})" : ""}'),
        subtitle: Text('${v['owner']} · ${v['vehicleType'] ?? ""}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(context, ref, v)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, v['id'] as int,
                    '${v['plateNumber']}${v['displayName'] != null ? " (${v['displayName']})" : ""}')),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _VehicleForm(existing: existing, onSaved: () => ref.invalidate(vehiclesProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate vehicle?'),
        content: Text('Deactivate "$name"? It will be hidden from new trip entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/vehicles/$id');
              ref.invalidate(vehiclesProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _VehicleForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _VehicleForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends ConsumerState<_VehicleForm> {
  final _formKey = GlobalKey<FormState>();
  late final _plate   = TextEditingController(text: widget.existing?['plateNumber']);
  late final _display = TextEditingController(text: widget.existing?['displayName']);
  late final _type    = TextEditingController(text: widget.existing?['vehicleType']);
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
  void dispose() { _plate.dispose(); _display.dispose(); _type.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'owner': _owner, 'vendorId': _vendorId,
      'plateNumber': _plate.text, 'displayName': _display.text, 'vehicleType': _type.text,
    };
    final api = ref.read(apiClientProvider);
    if (widget.existing == null) {
      await api.post('/api/vehicles', data: data);
    } else {
      await api.put('/api/vehicles/${widget.existing!['id']}', data: data);
    }
    if (mounted) { Navigator.pop(context); widget.onSaved(); }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorListProvider);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Vehicle' : 'Edit Vehicle'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _plate, decoration: const InputDecoration(labelText: 'Plate Number *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _display, decoration: const InputDecoration(labelText: 'Short Name (e.g. 2201)')),
              const SizedBox(height: 12),
              TextFormField(controller: _type, decoration: const InputDecoration(labelText: 'Vehicle Type')),
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
