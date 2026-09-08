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
      itemBuilder: (m) {
        final workTypes = (m['workTypes'] as List<dynamic>? ?? []);
        final linkedVehicleName = m['linkedVehicleName'] as String?;
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.construction)),
          title: Text(m['name'] as String),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${m['owner']} · ${m['machineType'] ?? ""}'),
              if (workTypes.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: workTypes.take(3).map<Widget>((wt) {
                    final rate = wt['defaultRate'];
                    return Chip(
                      label: Text(
                        rate != null
                            ? '${wt['label']} ₹${(rate as num).toStringAsFixed(0)}/hr'
                            : wt['label'] as String,
                        style: const TextStyle(fontSize: 11),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              if (linkedVehicleName != null)
                Row(children: [
                  Icon(Icons.local_shipping, size: 12, color: Colors.teal.shade600),
                  const SizedBox(width: 4),
                  Text('Linked to Vehicle: $linkedVehicleName',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade700)),
                ]),
            ],
          ),
          isThreeLine: workTypes.isNotEmpty || linkedVehicleName != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(context, ref, m)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, m['id'] as int, m['name'] as String),
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
      builder: (_) => _MachineForm(existing: existing, onSaved: () => ref.invalidate(machinesProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Deactivate machine?'),
        content: Text('Deactivate "$name"? It will be hidden from new work log entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(apiClientProvider).delete('/api/machines/$id');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_apiError(e)),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              if (!context.mounted) return;
              ref.invalidate(machinesProvider);
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

// ── Machine form ──────────────────────────────────────────────────────────────

class _MachineForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _MachineForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_MachineForm> createState() => _MachineFormState();
}

class _MachineFormState extends ConsumerState<_MachineForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?['name'] as String?);
  late final _type = TextEditingController(text: widget.existing?['machineType'] as String?);
  String _owner = 'VENDOR';
  int? _vendorId;
  int? _linkedVehicleId;
  bool _saving = false;

  // Work types list: each is a Map with optional 'id', 'label', 'defaultRate', 'defaultGstRate', 'sacCode'
  late List<Map<String, dynamic>> _workTypes;

  @override
  void initState() {
    super.initState();
    _owner = widget.existing?['owner'] as String? ?? 'VENDOR';
    _vendorId = widget.existing?['vendorId'] as int?;
    _linkedVehicleId = widget.existing?['linkedVehicleId'] as int?;
    final existingTypes = widget.existing?['workTypes'] as List<dynamic>?;
    _workTypes = existingTypes == null
        ? []
        : existingTypes.map((wt) => Map<String, dynamic>.from(wt as Map)).toList();
  }

  @override
  void dispose() { _name.dispose(); _type.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'owner': _owner,
      'vendorId': _vendorId,
      'name': _name.text.trim(),
      'machineType': _type.text.trim().isEmpty ? null : _type.text.trim(),
      'linkedVehicleId': _linkedVehicleId,
      'workTypes': _workTypes.asMap().entries.map((e) => {
        'id': e.value['id'],
        'label': e.value['label'],
        'defaultRate': e.value['defaultRate'],
        'defaultGstRate': e.value['defaultGstRate'],
        'sacCode': e.value['sacCode'],
        'displayOrder': e.key,
      }).toList(),
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/machines', data: data);
      } else {
        await api.put('/api/machines/${widget.existing!['id']}', data: data);
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

  void _addWorkType() {
    _showWorkTypeDialog(null, (newType) {
      setState(() => _workTypes.add(newType));
    });
  }

  void _editWorkType(int idx) {
    _showWorkTypeDialog(_workTypes[idx], (updated) {
      setState(() => _workTypes[idx] = updated);
    });
  }

  void _removeWorkType(int idx) {
    setState(() => _workTypes.removeAt(idx));
  }

  void _showWorkTypeDialog(Map<String, dynamic>? existing, Function(Map<String, dynamic>) onSave) {
    final labelCtrl = TextEditingController(text: existing?['label'] as String? ?? '');
    final rateCtrl = TextEditingController(
      text: existing?['defaultRate'] != null ? existing!['defaultRate'].toString() : '',
    );
    final gstCtrl = TextEditingController(
      text: existing?['defaultGstRate'] != null ? existing!['defaultGstRate'].toString() : '',
    );
    final sacCtrl = TextEditingController(text: existing?['sacCode'] as String? ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Work Type' : 'Edit Work Type'),
        content: SizedBox(
          width: 340,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Label *', hintText: 'e.g. Bucket, Breaker, Crushing'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Default Rate ₹/hr (optional)',
                  prefixText: '₹',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: gstCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Default GST % (optional)',
                  suffixText: '%',
                  hintText: 'e.g. 18',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sacCtrl,
                decoration: const InputDecoration(labelText: 'SAC Code (optional)'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              onSave({
                'id': existing?['id'],
                'label': labelCtrl.text.trim(),
                'defaultRate': double.tryParse(rateCtrl.text.trim()),
                'defaultGstRate': double.tryParse(gstCtrl.text.trim()),
                'sacCode': sacCtrl.text.trim().isEmpty ? null : sacCtrl.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorListProvider);
    // Fetch vehicles for the linked-vehicle picker
    final vehiclesAsync = ref.watch(_vehiclesForPickerProvider);
    final isEdit = widget.existing != null;

    return AppDialog(
      title: isEdit ? 'Edit Machine' : 'Add Machine',
      maxWidth: 480,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Machine Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _type,
              decoration: const InputDecoration(labelText: 'Type (e.g. JCB, Comosko)'),
            ),
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

            // Linked Vehicle
            const SizedBox(height: 12),
            vehiclesAsync.when(
              data: (vehicleList) => SearchablePicker(
                items: [{'id': null, 'label': 'None'}, ...vehicleList],
                itemLabel: (v) => v['label'] as String? ?? v['plateNumber'] as String,
                fieldLabel: 'Linked Vehicle (optional)',
                value: _linkedVehicleId,
                onChanged: (v) => setState(() => _linkedVehicleId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _e) => const SizedBox(),
            ),

            // Work Types section
            const SectionLabel('Work Types'),
            if (_workTypes.isEmpty)
              Text('No work types — Mode section will be hidden in Machine Work entries.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ..._workTypes.asMap().entries.map((e) {
              final idx = e.key;
              final wt = e.value;
              final rate = wt['defaultRate'];
              final gst = wt['defaultGstRate'];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  title: Text(wt['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    if (rate != null) '₹${(rate as num).toStringAsFixed(0)}/hr',
                    if (gst != null) 'GST ${(gst as num).toStringAsFixed(0)}%',
                    if (wt['sacCode'] != null) 'SAC: ${wt['sacCode']}',
                  ].join(' · ')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editWorkType(idx)),
                    IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        onPressed: () => _removeWorkType(idx)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _addWorkType,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Work Type'),
            ),
          ],
        ),
      ),
    );
  }
}

// Provider for vehicle list in the linked-vehicle picker
final _vehiclesForPickerProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  final list = List<Map<String, dynamic>>.from(res.data);
  return list.map((v) {
    final plate = v['plateNumber'] as String;
    final display = v['displayName'] as String?;
    return {
      'id': v['id'],
      'label': display != null && display.isNotEmpty ? '$plate ($display)' : plate,
    };
  }).toList();
});
