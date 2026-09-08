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
      itemBuilder: (v) {
        final plate = v['plateNumber'] as String;
        final display = v['displayName'] as String?;
        final linkedMachineName = v['linkedMachineName'] as String?;
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
          title: Text('$plate${display != null ? "  ($display)" : ""}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${v['owner']} · ${v['vehicleType'] ?? ""}'),
              if (linkedMachineName != null)
                Row(children: [
                  Icon(Icons.construction, size: 12, color: Colors.teal.shade600),
                  const SizedBox(width: 4),
                  Text('Linked to Machine: $linkedMachineName',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade700)),
                ]),
            ],
          ),
          isThreeLine: linkedMachineName != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(context, ref, v)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, v['id'] as int,
                    '$plate${display != null ? " ($display)" : ""}'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VehicleForm(existing: existing, onSaved: () => ref.invalidate(vehiclesProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Deactivate vehicle?'),
        content: Text('Deactivate "$name"? It will be hidden from new trip entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(apiClientProvider).delete('/api/vehicles/$id');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_apiError(e)),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              if (!context.mounted) return;
              ref.invalidate(vehiclesProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

String _apiError(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
  } catch (_) {}
  return e.toString();
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
  late final _plate   = TextEditingController(text: widget.existing?['plateNumber'] as String?);
  late final _display = TextEditingController(text: widget.existing?['displayName'] as String?);
  late final _type    = TextEditingController(text: widget.existing?['vehicleType'] as String?);
  String _owner = 'VENDOR';
  int? _vendorId;
  int? _linkedMachineId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.existing?['owner'] as String? ?? 'VENDOR';
    _vendorId = widget.existing?['vendorId'] as int?;
    _linkedMachineId = widget.existing?['linkedMachineId'] as int?;
  }

  @override
  void dispose() { _plate.dispose(); _display.dispose(); _type.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'owner': _owner,
      'vendorId': _vendorId,
      'plateNumber': _plate.text.trim(),
      'displayName': _display.text.trim().isEmpty ? null : _display.text.trim(),
      'vehicleType': _type.text.trim().isEmpty ? null : _type.text.trim(),
      'linkedMachineId': _linkedMachineId,
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/vehicles', data: data);
      } else {
        await api.put('/api/vehicles/${widget.existing!['id']}', data: data);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${_apiError(e)}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorListProvider);
    final machinesAsync = ref.watch(_machinesForPickerProvider);
    final isEdit = widget.existing != null;

    return AppDialog(
      title: isEdit ? 'Edit Vehicle' : 'Add Vehicle',
      maxWidth: 440,
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isEdit ? 'Update' : 'Save')),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _plate,
              decoration: const InputDecoration(labelText: 'Plate Number *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
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
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
            const SizedBox(height: 12),
            machinesAsync.when(
              data: (machineList) => SearchablePicker(
                items: [{'id': null, 'label': 'None'}, ...machineList],
                itemLabel: (m) => m['label'] as String? ?? m['name'] as String,
                fieldLabel: 'Linked Machine (optional)',
                value: _linkedMachineId,
                onChanged: (v) => setState(() => _linkedMachineId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _e) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

// Provider for machine list in the linked-machine picker
final _machinesForPickerProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/machines');
  final list = List<Map<String, dynamic>>.from(res.data);
  return list.map((m) => {
    'id': m['id'],
    'label': m['name'] as String,
  }).toList();
});
