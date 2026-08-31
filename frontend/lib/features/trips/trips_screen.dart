import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

// ── providers ───────────────────────────────────────────────────────────────

final tripsDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final tripsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, date) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/trips', params: {'from': date, 'to': date});
  return List<Map<String, dynamic>>.from(res.data);
});

final _materialsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/materials');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vendors');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ──────────────────────────────────────────────────────────────────

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(tripsDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final trips = ref.watch(tripsProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tripsProvider(dateKey)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Add Trip'),
      ),
      body: Column(
        children: [
          _DateBar(selectedDate: selectedDate, onPick: (d) {
            ref.read(tripsDateProvider.notifier).state = d;
          }),
          Expanded(
            child: trips.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('No trips for this date. Tap + to add one.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _TripCard(
                        trip: list[i],
                        onEdit: () => _showForm(context, ref, list[i], selectedDate),
                        onDelete: () => _confirmDelete(context, ref, list[i]['id'], dateKey),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing, DateTime date) {
    showDialog(
      context: context,
      builder: (_) => _TripForm(
        existing: existing,
        initialDate: date,
        onSaved: () {
          final dateKey = DateFormat('yyyy-MM-dd').format(ref.read(tripsDateProvider));
          ref.invalidate(tripsProvider(dateKey));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic id, String dateKey) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: const Text('This trip will be removed from the record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/trips/$id');
              ref.invalidate(tripsProvider(dateKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── date navigation bar ─────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onPick;
  const _DateBar({required this.selectedDate, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onPick(selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) onPick(picked);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    if (isToday)
                      const Text('Today', style: TextStyle(fontSize: 11, color: Colors.blue)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onPick(selectedDate.add(const Duration(days: 1))),
          ),
          if (!isToday)
            TextButton(
              onPressed: () => onPick(DateTime.now()),
              child: const Text('Today'),
            ),
        ],
      ),
    );
  }
}

// ── trip card ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TripCard({required this.trip, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final vehicle = trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '-';
    final material = trip['materialName'] ?? '-';
    final qty = trip['quantityBrass'];
    final dspChallan = trip['dspChallanNo'] ?? '';
    final vendorChallan = trip['vendorChallanNo'] ?? '';
    final unloading = trip['unloadingLocation'] ?? '';
    final channel = trip['channelNo'] ?? '';
    final dest = [unloading, if (channel.isNotEmpty) 'Ch: $channel'].join('  ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(vehicle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(material, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 8),
                      if (qty != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text('$qty Brass',
                              style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (dest.isNotEmpty)
                    Text(dest, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (dspChallan.isNotEmpty || vendorChallan.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [if (dspChallan.isNotEmpty) 'DSP: $dspChallan', if (vendorChallan.isNotEmpty) 'Vdr: $vendorChallan'].join('  ·  '),
                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
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

// ── trip form dialog ─────────────────────────────────────────────────────────

class _TripForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime initialDate;
  final VoidCallback onSaved;
  const _TripForm({this.existing, required this.initialDate, required this.onSaved});

  @override
  ConsumerState<_TripForm> createState() => _TripFormState();
}

class _TripFormState extends ConsumerState<_TripForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _tripDate;
  late final _loading    = TextEditingController(text: widget.existing?['loadingLocation']);
  late final _unloading  = TextEditingController(text: widget.existing?['unloadingLocation']);
  late final _channel    = TextEditingController(text: widget.existing?['channelNo']);
  late final _qtyBrass   = TextEditingController(text: widget.existing?['quantityBrass']?.toString());
  late final _loadedTon  = TextEditingController(text: widget.existing?['loadedWeightTon']?.toString());
  late final _emptyTon   = TextEditingController(text: widget.existing?['emptyWeightTon']?.toString());
  late final _dspChallan = TextEditingController(text: widget.existing?['dspChallanNo']);
  late final _vdrChallan = TextEditingController(text: widget.existing?['vendorChallanNo']);
  int? _materialId;
  int? _vehicleId;
  int? _vendorId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tripDate = widget.initialDate;
    _materialId = widget.existing?['materialId'];
    _vehicleId  = widget.existing?['vehicleId'];
    _vendorId   = widget.existing?['vendorId'];
  }

  @override
  void dispose() {
    _loading.dispose(); _unloading.dispose(); _channel.dispose();
    _qtyBrass.dispose(); _loadedTon.dispose(); _emptyTon.dispose();
    _dspChallan.dispose(); _vdrChallan.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tripDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _tripDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'tripDate': DateFormat('yyyy-MM-dd').format(_tripDate),
      'loadingLocation': _loading.text.trim().isEmpty ? null : _loading.text.trim(),
      'unloadingLocation': _unloading.text.trim().isEmpty ? null : _unloading.text.trim(),
      'channelNo': _channel.text.trim().isEmpty ? null : _channel.text.trim(),
      'materialId': _materialId,
      'quantityBrass': _qtyBrass.text.trim().isEmpty ? null : double.tryParse(_qtyBrass.text.trim()),
      'loadedWeightTon': _loadedTon.text.trim().isEmpty ? null : double.tryParse(_loadedTon.text.trim()),
      'emptyWeightTon': _emptyTon.text.trim().isEmpty ? null : double.tryParse(_emptyTon.text.trim()),
      'vehicleId': _vehicleId,
      'vendorId': _vendorId,
      'dspChallanNo': _dspChallan.text.trim().isEmpty ? null : _dspChallan.text.trim(),
      'vendorChallanNo': _vdrChallan.text.trim().isEmpty ? null : _vdrChallan.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    if (widget.existing == null) {
      await api.post('/api/trips', data: data);
    } else {
      await api.put('/api/trips/${widget.existing!['id']}', data: data);
    }
    if (mounted) { Navigator.pop(context); widget.onSaved(); }
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(_materialsProvider);
    final vehicles  = ref.watch(_vehiclesProvider);
    final vendors   = ref.watch(_vendorsProvider);

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Trip' : 'Edit Trip'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Trip Date *',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_tripDate)),
                  ),
                ),
                const SizedBox(height: 12),

                // Vehicle picker
                vehicles.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error loading vehicles: $e'),
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _vehicleId,
                    decoration: const InputDecoration(labelText: 'Vehicle *'),
                    items: list.map((v) => DropdownMenuItem(
                      value: v['id'] as int,
                      child: Text('${v['displayName'] ?? v['plateNumber']}  (${v['vehicleType'] ?? ''})'),
                    )).toList(),
                    onChanged: (v) => setState(() => _vehicleId = v),
                    validator: (v) => v == null ? 'Select vehicle' : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Material picker
                materials.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error loading materials: $e'),
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _materialId,
                    decoration: const InputDecoration(labelText: 'Material *'),
                    items: list.map((m) => DropdownMenuItem(
                      value: m['id'] as int,
                      child: Text(m['name']),
                    )).toList(),
                    onChanged: (v) => setState(() => _materialId = v),
                    validator: (v) => v == null ? 'Select material' : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Quantity
                TextFormField(
                  controller: _qtyBrass,
                  decoration: const InputDecoration(labelText: 'Quantity (Brass)', suffixText: 'Brass'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),

                // Loading / Unloading
                TextFormField(controller: _loading, decoration: const InputDecoration(labelText: 'Loading Location')),
                const SizedBox(height: 12),
                TextFormField(controller: _unloading, decoration: const InputDecoration(labelText: 'Unloading Location')),
                const SizedBox(height: 12),
                TextFormField(controller: _channel, decoration: const InputDecoration(labelText: 'Channel No')),
                const SizedBox(height: 12),

                // Challan numbers
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _dspChallan, decoration: const InputDecoration(labelText: 'DSP Challan No'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _vdrChallan, decoration: const InputDecoration(labelText: 'Vendor Challan No'))),
                  ],
                ),
                const SizedBox(height: 12),

                // Vendor picker
                vendors.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error loading vendors: $e'),
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _vendorId,
                    decoration: const InputDecoration(labelText: 'Vendor *'),
                    items: list.map((v) => DropdownMenuItem(
                      value: v['id'] as int,
                      child: Text(v['name']),
                    )).toList(),
                    onChanged: (v) => setState(() => _vendorId = v),
                    validator: (v) => v == null ? 'Select vendor' : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Weights (optional)
                const Text('Weights (optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      controller: _loadedTon,
                      decoration: const InputDecoration(labelText: 'Loaded (Tons)', suffixText: 'T'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _emptyTon,
                      decoration: const InputDecoration(labelText: 'Empty (Tons)', suffixText: 'T'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
