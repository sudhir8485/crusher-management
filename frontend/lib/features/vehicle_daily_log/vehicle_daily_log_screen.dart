import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final _dateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _logsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, date) async {
  final res = await ref
      .read(apiClientProvider)
      .get('/api/vehicle-daily-log', params: {'from': date, 'to': date});
  return List<Map<String, dynamic>>.from(res.data);
});

final _vehiclesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ────────────────────────────────────────────────────────────────────

class VehicleDailyLogScreen extends ConsumerWidget {
  const VehicleDailyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_dateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final logs = ref.watch(_logsProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Daily Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_logsProvider(dateKey)),
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
            onPick: (d) => ref.read(_dateProvider.notifier).state = d,
          ),
          logs.when(
            loading: () => const SizedBox(),
            error: (_, s) => const SizedBox(),
            data: (data) => _SummaryBar(logs: data),
          ),
          Expanded(
            child: logs.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No vehicle logs for this date',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length,
                  separatorBuilder: (_, idx) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LogCard(
                    log: data[i],
                    onEdit: () =>
                        _showForm(context, ref, data[i], selectedDate),
                    onDelete: () =>
                        _confirmDelete(context, ref, data[i], dateKey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? log,
      DateTime date) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _LogForm(
        existing: log,
        defaultDate: date,
        onSaved: () {
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          ref.invalidate(_logsProvider(dateKey));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> log, String dateKey) {
    final name = log['vehicleDisplayName'] ?? 'this vehicle';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete daily log for $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(apiClientProvider)
                  .delete('/api/vehicle-daily-log/${log['id']}');
              ref.invalidate(_logsProvider(dateKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _SummaryBar({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox();
    int totalTrips = 0;
    double totalKm = 0;
    for (final l in logs) {
      totalTrips += (l['totalTrips'] as int? ?? 0);
      totalKm += (l['totalKm'] as num?)?.toDouble() ?? 0;
    }
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, size: 18),
          const SizedBox(width: 8),
          Text('${logs.length} ${logs.length == 1 ? 'vehicle' : 'vehicles'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (totalTrips > 0) ...[
            const Icon(Icons.repeat, size: 16),
            const SizedBox(width: 4),
            Text('$totalTrips trips',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
          ],
          if (totalKm > 0) ...[
            const Icon(Icons.speed, size: 16),
            const SizedBox(width: 4),
            Text('${totalKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

// ── log card ──────────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _LogCard(
      {required this.log, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final vehicleName = log['vehicleDisplayName'] ?? '—';
    final plate = (log['vehiclePlateNumber'] as String?) ?? '';
    final loading = (log['loadingLocation'] as String?)?.trim() ?? '';
    final unloading = (log['unloadingLocation'] as String?)?.trim() ?? '';
    final opening = log['openingReading'];
    final closing = log['closingReading'];
    final totalKm = log['totalKm'];
    final tripsDay = log['tripsDay'] as int? ?? 0;
    final tripsNight = log['tripsNight'] as int? ?? 0;
    final totalTrips = log['totalTrips'] as int? ?? 0;
    final dieselNote = (log['dieselNote'] as String?)?.trim() ?? '';
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.local_shipping, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicleName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (plate.isNotEmpty)
                        Text(plate,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                // Total trips badge
                if (totalTrips > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$totalTrips trips',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 13)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            // Location row
            if (loading.isNotEmpty || unloading.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (loading.isNotEmpty) ...[
                    const Icon(Icons.upload_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(loading,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700]))),
                  ],
                  if (loading.isNotEmpty && unloading.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward,
                          size: 14, color: Colors.grey),
                    ),
                  if (unloading.isNotEmpty) ...[
                    const Icon(Icons.download_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(unloading,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700]))),
                  ],
                ],
              ),
            ],
            // Reading + KM row
            if (opening != null || closing != null || totalKm != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _Reading('Open', opening),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child:
                        Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  ),
                  _Reading('Close', closing),
                  if (totalKm != null) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                          '${(totalKm as num).toStringAsFixed(1)} km',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal)),
                    ),
                  ],
                ],
              ),
            ],
            // Trips day/night
            if (tripsDay > 0 || tripsNight > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  _TripBadge('Day', tripsDay, Colors.amber),
                  const SizedBox(width: 8),
                  _TripBadge('Night', tripsNight, Colors.indigo),
                ],
              ),
            ],
            // Diesel note
            if (dieselNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_gas_station_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(dieselNote,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  final String label;
  final dynamic value;
  const _Reading(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: Colors.grey[500])),
          Text(
            value != null
                ? (value as num).toStringAsFixed(1)
                : '—',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      );
}

class _TripBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _TripBadge(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$label: $count',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8))),
      );
}

// ── form ──────────────────────────────────────────────────────────────────────

class _LogForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime defaultDate;
  final VoidCallback onSaved;
  const _LogForm(
      {required this.existing,
      required this.defaultDate,
      required this.onSaved});

  @override
  ConsumerState<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends ConsumerState<_LogForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  int? _vehicleId;
  final _loadCtrl = TextEditingController();
  final _unloadCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _nightCtrl = TextEditingController();
  final _dieselCtrl = TextEditingController();
  bool _saving = false;
  double? _previewKm;
  int _previewTrips = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null
        ? DateTime.parse(e['logDate'] as String)
        : widget.defaultDate;
    if (e != null) {
      _vehicleId = e['vehicleId'] as int?;
      _loadCtrl.text = e['loadingLocation'] as String? ?? '';
      _unloadCtrl.text = e['unloadingLocation'] as String? ?? '';
      final open = e['openingReading'];
      final close = e['closingReading'];
      if (open != null) _openCtrl.text = open.toString();
      if (close != null) _closeCtrl.text = close.toString();
      _dayCtrl.text = (e['tripsDay'] as int? ?? 0).toString();
      _nightCtrl.text = (e['tripsNight'] as int? ?? 0).toString();
      _dieselCtrl.text = e['dieselNote'] as String? ?? '';
    }
    _openCtrl.addListener(_updateKmPreview);
    _closeCtrl.addListener(_updateKmPreview);
    _dayCtrl.addListener(_updateTripsPreview);
    _nightCtrl.addListener(_updateTripsPreview);
    _updateTripsPreview();
  }

  void _updateKmPreview() {
    final o = double.tryParse(_openCtrl.text);
    final c = double.tryParse(_closeCtrl.text);
    setState(() {
      _previewKm = (o != null && c != null && c >= o) ? c - o : null;
    });
  }

  void _updateTripsPreview() {
    final d = int.tryParse(_dayCtrl.text) ?? 0;
    final n = int.tryParse(_nightCtrl.text) ?? 0;
    setState(() => _previewTrips = d + n);
  }

  @override
  void dispose() {
    _loadCtrl.dispose();
    _unloadCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _dayCtrl.dispose();
    _nightCtrl.dispose();
    _dieselCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'logDate': DateFormat('yyyy-MM-dd').format(_date),
      'vehicleId': _vehicleId,
      'loadingLocation': _loadCtrl.text.trim().isEmpty ? null : _loadCtrl.text.trim(),
      'unloadingLocation': _unloadCtrl.text.trim().isEmpty ? null : _unloadCtrl.text.trim(),
      'openingReading': double.tryParse(_openCtrl.text),
      'closingReading': double.tryParse(_closeCtrl.text),
      'tripsDay': int.tryParse(_dayCtrl.text) ?? 0,
      'tripsNight': int.tryParse(_nightCtrl.text) ?? 0,
      'dieselNote': _dieselCtrl.text.trim().isEmpty ? null : _dieselCtrl.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    if (e == null) {
      await api.post('/api/vehicle-daily-log', data: body);
    } else {
      await api.put('/api/vehicle-daily-log/${e['id']}', data: body);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(_vehiclesProvider);
    final isEdit = widget.existing != null;

    return AppDialog(
      title: isEdit ? 'Edit Vehicle Log' : 'Add Vehicle Daily Log',
      maxWidth: 500,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update' : 'Save'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateField(
              label: 'Date', date: _date, required: true,
              onTap: () async {
                final d = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            vehicles.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                final active = list.where((v) => v['status'] == 'ACTIVE').toList();
                return DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Vehicle *'),
                  value: _vehicleId,
                  isExpanded: true,
                  items: active.map((v) => DropdownMenuItem<int>(
                    value: v['id'] as int,
                    child: Text(
                      v['displayName'] as String? ?? v['plateNumber'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _vehicleId = v),
                  validator: (v) => v == null ? 'Select vehicle' : null,
                );
              },
            ),
            const SectionLabel('Locations'),
            TextFormField(
              controller: _loadCtrl,
              decoration: const InputDecoration(
                labelText: 'Loading Location',
                hintText: 'Where material was picked up',
                prefixIcon: Icon(Icons.upload_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _unloadCtrl,
              decoration: const InputDecoration(
                labelText: 'Unloading Location',
                hintText: 'Where material was delivered',
                prefixIcon: Icon(Icons.download_outlined, size: 18),
              ),
            ),
            const SectionLabel('Odometer Reading'),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _openCtrl,
                  decoration: const InputDecoration(labelText: 'Opening'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _closeCtrl,
                  decoration: const InputDecoration(labelText: 'Closing'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final c = double.tryParse(v);
                    final o = double.tryParse(_openCtrl.text);
                    if (c != null && o != null && c < o) return 'Must be ≥ opening';
                    return null;
                  },
                )),
              ],
            ),
            if (_previewKm != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.speed, size: 14, color: Colors.teal),
                  const SizedBox(width: 6),
                  Text('${_previewKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
            const SectionLabel('Trips'),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _dayCtrl,
                  decoration: const InputDecoration(labelText: 'Day Trips'),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _nightCtrl,
                  decoration: const InputDecoration(labelText: 'Night Trips'),
                  keyboardType: TextInputType.number,
                )),
                if (_previewTrips > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Total: $_previewTrips',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dieselCtrl,
              decoration: const InputDecoration(
                labelText: 'Diesel / Other Notes',
                hintText: 'e.g. 30L diesel received',
                prefixIcon: Icon(Icons.local_gas_station_outlined, size: 18),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
