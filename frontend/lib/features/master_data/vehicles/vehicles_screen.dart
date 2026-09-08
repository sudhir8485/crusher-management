import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_widgets.dart';
import '../widgets/master_list_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Active-only — used by pickers everywhere.
final vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

/// All non-deleted including inactive — used when "Show Inactive" is toggled on.
final _vehiclesAllProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles', params: {'includeInactive': 'true'});
  return List<Map<String, dynamic>>.from(res.data);
});

final vendorListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});
  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final provider = _showInactive ? _vehiclesAllProvider : vehiclesProvider;
    final vehicles = ref.watch(provider);

    return MasterListScreen(
      title: 'Vehicles',
      items: vehicles,
      onRefresh: () {
        ref.invalidate(vehiclesProvider);
        ref.invalidate(_vehiclesAllProvider);
      },
      onAdd: () => _showForm(context, ref, null),
      headerAction: _ShowInactiveToggle(
        value: _showInactive,
        onChanged: (v) => setState(() => _showInactive = v),
      ),
      itemBuilder: (v) {
        final plate     = v['plateNumber'] as String;
        final display   = v['displayName'] as String?;
        final linkedMachineName = v['linkedMachineName'] as String?;
        final isActive  = v['active'] as bool? ?? true;

        return Opacity(
          opacity: isActive ? 1.0 : 0.55,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? null : Colors.grey.shade200,
              child: Icon(Icons.local_shipping, color: isActive ? null : Colors.grey),
            ),
            title: Row(children: [
              Expanded(child: Text('$plate${display != null ? "  ($display)" : ""}')),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ),
            ]),
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
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              // Active/Inactive toggle
              Switch(
                value: isActive,
                onChanged: (_) => _toggleActive(context, ref, v['id'] as int, plate),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showForm(context, ref, v),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, v['id'] as int,
                    '$plate${display != null ? " ($display)" : ""}'),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _toggleActive(BuildContext context, WidgetRef ref, int id, String label) async {
    try {
      await ref.read(apiClientProvider).patch('/api/vehicles/$id/toggle-active');
      ref.invalidate(vehiclesProvider);
      ref.invalidate(_vehiclesAllProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_apiError(e)), backgroundColor: Colors.red));
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VehicleForm(
        existing: existing,
        onSaved: () {
          ref.invalidate(vehiclesProvider);
          ref.invalidate(_vehiclesAllProvider);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Permanently remove "$name"?'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'If this vehicle has any trips or entries, delete will be blocked. '
                'Use the toggle switch to deactivate it instead.',
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
                await ref.read(apiClientProvider).delete('/api/vehicles/$id');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_apiError(e)), backgroundColor: Colors.red));
                return;
              }
              if (!context.mounted) return;
              ref.invalidate(vehiclesProvider);
              ref.invalidate(_vehiclesAllProvider);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

String _apiError(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
  } catch (_) {}
  return e.toString();
}

class _ShowInactiveToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ShowInactiveToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Show Inactive', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      const SizedBox(width: 4),
      Switch(value: value, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]);
  }
}

// ── Vehicle form ───────────────────────────────────────────────────────────────

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
          content: Text('Save failed: ${_apiError(e)}'), backgroundColor: Colors.red));
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
                  items: list, itemLabel: (v) => v['name'] as String,
                  fieldLabel: 'Party', value: _vendorId,
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

// Provider for machine list in the linked-machine picker — active only
final _machinesForPickerProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/machines');
  return List<Map<String, dynamic>>.from(res.data).map((m) => {
    'id': m['id'], 'label': m['name'] as String,
  }).toList();
});
