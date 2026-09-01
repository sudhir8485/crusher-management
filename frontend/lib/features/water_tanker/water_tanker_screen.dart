import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ────────────────────────────────────────────────────────────────

final _tankerDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _tankerProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, date) async {
  final res = await ref.read(apiClientProvider).get('/api/water-tanker', params: {'from': date, 'to': date});
  return List<Map<String, dynamic>>.from(res.data);
});

final _tankerVehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ───────────────────────────────────────────────────────────────────

class WaterTankerScreen extends ConsumerWidget {
  const WaterTankerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_tankerDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final logs = ref.watch(_tankerProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Tanker Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_tankerProvider(dateKey)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Add Log'),
      ),
      body: Column(
        children: [
          AppDateBar(
            selectedDate: selectedDate,
            onPick: (d) => ref.read(_tankerDateProvider.notifier).state = d,
          ),
          Expanded(
            child: logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.water_drop_outlined,
                    message: 'No water tanker log for ${DateFormat('d MMM yyyy').format(selectedDate)}',
                    hint: 'Tap + to add a log',
                  );
                }
                final totalAmount = list.fold<double>(
                  0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));

                return Column(
                  children: [
                    if (totalAmount > 0) _AmountBar(totalAmount: totalAmount),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: list.length,
                        separatorBuilder: (_, idx) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _TankerCard(
                          log: list[i],
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
      builder: (_) => _TankerForm(
        existing: existing,
        initialDate: date,
        onSaved: () {
          final dateKey = DateFormat('yyyy-MM-dd').format(ref.read(_tankerDateProvider));
          ref.invalidate(_tankerProvider(dateKey));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> log, String dateKey) {
    final vehicle = log['vehicleDisplayName'] ?? log['vehiclePlateNumber'] ?? '—';
    final amount  = (log['amount'] as num?)?.toDouble();
    final detail  = amount != null ? '$vehicle · ${fmtCurr(amount)}' : vehicle;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete water tanker log?'),
        content: Text('Delete: $detail?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/water-tanker/${log['id']}');
              ref.invalidate(_tankerProvider(dateKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── amount bar ───────────────────────────────────────────────────────────────

class _AmountBar extends StatelessWidget {
  final double totalAmount;
  const _AmountBar({required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop, color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Text(
            'Total: ₹${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}

// ── card ─────────────────────────────────────────────────────────────────────

class _TankerCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TankerCard({required this.log, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final vehicle = log['vehicleDisplayName'] ?? log['vehiclePlateNumber'] ?? '-';
    final hours = log['hoursWorked'];
    final km = log['kmRun'];
    final trips = log['tripsCount'];
    final rate = log['rate'];
    final amount = log['amount'];

    final metrics = <String>[];
    if (hours != null) metrics.add('$hours hrs');
    if (km != null) metrics.add('$km km');
    if (trips != null) metrics.add('$trips trips');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  if (metrics.isNotEmpty)
                    Text(metrics.join('  ·  '), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (rate != null)
                        _Badge('₹$rate / unit', Colors.indigo),
                      if (rate != null && amount != null) const SizedBox(width: 8),
                      if (amount != null)
                        _Badge('₹$amount', Colors.green),
                    ],
                  ),
                  if (log['notes'] != null && (log['notes'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(log['notes'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
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

class _TankerForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime initialDate;
  final VoidCallback onSaved;
  const _TankerForm({this.existing, required this.initialDate, required this.onSaved});

  @override
  ConsumerState<_TankerForm> createState() => _TankerFormState();
}

class _TankerFormState extends ConsumerState<_TankerForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _logDate;
  late final _hours  = TextEditingController(text: widget.existing?['hoursWorked']?.toString());
  late final _km     = TextEditingController(text: widget.existing?['kmRun']?.toString());
  late final _trips  = TextEditingController(text: widget.existing?['tripsCount']?.toString());
  late final _rate   = TextEditingController(text: widget.existing?['rate']?.toString());
  late final _notes  = TextEditingController(text: widget.existing?['notes']);
  int? _vehicleId;
  bool _saving = false;

  // live amount preview
  double? get _computedAmount {
    final rate = double.tryParse(_rate.text);
    if (rate == null) return null;
    final hours = double.tryParse(_hours.text);
    if (hours != null) return hours * rate;
    final trips = int.tryParse(_trips.text);
    if (trips != null) return trips * rate;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _logDate = widget.initialDate;
    _vehicleId = widget.existing?['vehicleId'];
    _hours.addListener(() => setState(() {}));
    _km.addListener(() => setState(() {}));
    _trips.addListener(() => setState(() {}));
    _rate.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _hours.dispose(); _km.dispose(); _trips.dispose(); _rate.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _logDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _logDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'logDate': DateFormat('yyyy-MM-dd').format(_logDate),
      'vehicleId': _vehicleId,
      'hoursWorked': _hours.text.trim().isEmpty ? null : double.tryParse(_hours.text.trim()),
      'kmRun': _km.text.trim().isEmpty ? null : double.tryParse(_km.text.trim()),
      'tripsCount': _trips.text.trim().isEmpty ? null : int.tryParse(_trips.text.trim()),
      'rate': _rate.text.trim().isEmpty ? null : double.tryParse(_rate.text.trim()),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/water-tanker', data: data);
      } else {
        await api.put('/api/water-tanker/${widget.existing!['id']}', data: data);
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
    final vehicles = ref.watch(_tankerVehiclesProvider);
    final amount = _computedAmount;

    return AppDialog(
      title: widget.existing == null ? 'Add Water Tanker Log' : 'Edit Water Tanker Log',
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
            DateField(label: 'Date', date: _logDate, onTap: _pickDate, required: true),
            const SizedBox(height: 12),
            vehicles.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => SearchablePicker(
                items: list,
                itemLabel: (v) =>
                    '${v['displayName'] ?? v['plateNumber']}',
                fieldLabel: 'Vehicle *',
                value: _vehicleId,
                onChanged: (v) => setState(() => _vehicleId = v),
                validator: (v) => v == null ? 'Select vehicle' : null,
              ),
            ),
            const SectionLabel('Work Done (fill what applies)'),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _hours,
                  decoration: const InputDecoration(labelText: 'Hours Worked', suffixText: 'hrs'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _km,
                  decoration: const InputDecoration(labelText: 'KM Run', suffixText: 'km'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _trips,
                  decoration: const InputDecoration(labelText: 'Trips'),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _rate,
                  decoration: const InputDecoration(labelText: 'Rate', prefixText: '₹'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ],
            ),
            if (amount != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.calculate_outlined, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Amount: ₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ),
            ],
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
