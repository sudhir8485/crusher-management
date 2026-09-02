import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ────────────────────────────────────────────────────────────────

final _dabarDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _dabarProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, date) async {
  final siteId = ref.watch(selectedSiteIdProvider);
  final params = <String, dynamic>{'from': date, 'to': date};
  if (siteId != null) params['siteId'] = siteId;
  final res = await ref.read(apiClientProvider).get('/api/dabar', params: params);
  return List<Map<String, dynamic>>.from(res.data);
});

final _vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ───────────────────────────────────────────────────────────────────

class DabarScreen extends ConsumerWidget {
  const DabarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_dabarDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final entries = ref.watch(_dabarProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dabar (Raw Stone Intake)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_dabarProvider(dateKey)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          AppDateBar(
            selectedDate: selectedDate,
            onPick: (d) => ref.read(_dabarDateProvider.notifier).state = d,
          ),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.terrain_outlined,
                    message: 'No dabar entries for ${DateFormat('d MMM yyyy').format(selectedDate)}',
                    hint: 'Tap + to add an entry',
                  );
                }
                final totalBrass = list.fold<double>(
                  0, (sum, e) => sum + ((e['quantityBrass'] as num?)?.toDouble() ?? 0));
                final totalTrips = list.fold<int>(
                  0, (sum, e) => sum + ((e['tripsCount'] as int?) ?? 0));

                return Column(
                  children: [
                    _SummaryBar(totalBrass: totalBrass, totalTrips: totalTrips),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: list.length,
                        separatorBuilder: (_, idx) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _DabarCard(
                          entry: list[i],
                          onEdit: () => _showForm(context, ref, list[i], selectedDate),
                          onDelete: () => _confirmDelete(context, ref, list[i], dateKey),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing, DateTime date) {
    showDialog(
      context: context,
      builder: (_) => _DabarForm(
        existing: existing,
        initialDate: date,
        onSaved: () {
          final dateKey = DateFormat('yyyy-MM-dd').format(ref.read(_dabarDateProvider));
          ref.invalidate(_dabarProvider(dateKey));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> entry, String dateKey) {
    final vehicle = entry['vehicleDisplayName'] ?? entry['vehiclePlateNumber'] ?? '—';
    final vendor  = entry['vendorName'] ?? '—';
    final brass   = entry['quantityBrass'];
    final detail  = brass != null ? '$vehicle · $vendor · ${numFmt.format(brass)} Brass' : '$vehicle · $vendor';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete dabar entry?'),
        content: Text('Delete: $detail?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/dabar/${entry['id']}');
              ref.invalidate(_dabarProvider(dateKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── summary bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double totalBrass;
  final int totalTrips;
  const _SummaryBar({required this.totalBrass, required this.totalTrips});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.brown.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Total Trips', value: '$totalTrips'),
          _Stat(label: 'Total Brass', value: '${totalBrass.toStringAsFixed(3)} Brass'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.brown)),
      ],
    );
  }
}

// ── card ─────────────────────────────────────────────────────────────────────

class _DabarCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DabarCard({required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final vehicle = entry['vehicleDisplayName'] ?? entry['vehiclePlateNumber'] ?? '-';
    final vendor = entry['vendorName'] ?? '-';
    final trips = entry['tripsCount'];
    final brass = entry['quantityBrass'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.brown.shade100,
              child: Text(
                vehicle.length > 4 ? vehicle.substring(0, 4) : vehicle,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Vendor: $vendor', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (trips != null)
                        _Badge('$trips Trips', Colors.orange),
                      if (trips != null && brass != null) const SizedBox(width: 8),
                      if (brass != null)
                        _Badge('$brass Brass', Colors.green),
                    ],
                  ),
                  if (entry['notes'] != null && (entry['notes'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(entry['notes'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
    );
  }
}

// ── form ─────────────────────────────────────────────────────────────────────

class _DabarForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime initialDate;
  final VoidCallback onSaved;
  const _DabarForm({this.existing, required this.initialDate, required this.onSaved});

  @override
  ConsumerState<_DabarForm> createState() => _DabarFormState();
}

class _DabarFormState extends ConsumerState<_DabarForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _entryDate;
  late final _trips  = TextEditingController(text: widget.existing?['tripsCount']?.toString());
  late final _brass  = TextEditingController(text: widget.existing?['quantityBrass']?.toString());
  late final _notes  = TextEditingController(text: widget.existing?['notes']);
  int? _vehicleId;
  int? _vendorId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entryDate = widget.initialDate;
    _vehicleId = widget.existing?['vehicleId'];
    _vendorId  = widget.existing?['vendorId'];
  }

  @override
  void dispose() {
    _trips.dispose(); _brass.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'entryDate': DateFormat('yyyy-MM-dd').format(_entryDate),
      'vehicleId': _vehicleId,
      'vendorId': _vendorId,
      'tripsCount': _trips.text.trim().isEmpty ? null : int.tryParse(_trips.text.trim()),
      'quantityBrass': _brass.text.trim().isEmpty ? null : double.tryParse(_brass.text.trim()),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    final siteId = ref.read(selectedSiteIdProvider);
    final siteParams = siteId != null ? {'siteId': siteId} : null;
    try {
      if (widget.existing == null) {
        await api.post('/api/dabar', data: data, params: siteParams);
      } else {
        await api.put('/api/dabar/${widget.existing!['id']}', data: data);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(_vehiclesProvider);
    final vendors  = ref.watch(_vendorsProvider);

    return AppDialog(
      title: widget.existing == null ? 'Add Dabar Entry' : 'Edit Dabar Entry',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateField(label: 'Entry Date', date: _entryDate, onTap: _pickDate, required: true),
            const SizedBox(height: 12),
            vehicles.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => SearchablePicker(
                items: list,
                itemLabel: (v) =>
                    '${v['displayName'] ?? v['plateNumber']}  (${v['vehicleType'] ?? ''})',
                fieldLabel: 'Vehicle *',
                value: _vehicleId,
                onChanged: (v) => setState(() => _vehicleId = v),
                validator: (v) => v == null ? 'Select vehicle' : null,
              ),
            ),
            const SizedBox(height: 12),
            vendors.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => SearchablePicker(
                items: list,
                itemLabel: (v) => v['name'] as String,
                fieldLabel: 'Party',
                value: _vendorId,
                clearable: true,
                onChanged: (v) => setState(() => _vendorId = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _trips,
                  decoration: const InputDecoration(labelText: 'No. of Trips'),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _brass,
                  decoration: const InputDecoration(labelText: 'Quantity', suffixText: 'Brass'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
