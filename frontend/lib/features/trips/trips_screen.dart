import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ───────────────────────────────────────────────────────────────

final tripsDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final tripsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, date) async {
  final siteId = ref.watch(selectedSiteIdProvider);
  final params = <String, dynamic>{'from': date, 'to': date};
  if (siteId != null) params['siteId'] = siteId;
  final res = await ref.read(apiClientProvider).get('/api/trips', params: params);
  return List<Map<String, dynamic>>.from(res.data);
});

final _materialsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/materials');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vehiclesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
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
          AppDateBar(
            selectedDate: selectedDate,
            onPick: (d) => ref.read(tripsDateProvider.notifier).state = d,
          ),
          Expanded(
            child: trips.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? AppEmptyState(
                      icon: Icons.swap_horiz_outlined,
                      message:
                          'No trips for ${DateFormat('d MMM yyyy').format(selectedDate)}',
                      hint: 'Tap + to add a trip',
                    )
                  : _TripsList(
                      list: list,
                      onEdit: (t) =>
                          _showForm(context, ref, t, selectedDate),
                      onDelete: (t) =>
                          _confirmDelete(context, ref, t, dateKey),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref,
      Map<String, dynamic>? existing, DateTime date) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TripForm(
        existing: existing,
        initialDate: date,
        onSaved: () {
          final dk = DateFormat('yyyy-MM-dd')
              .format(ref.read(tripsDateProvider));
          ref.invalidate(tripsProvider(dk));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      Map<String, dynamic> trip, String dateKey) {
    final vehicle =
        trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '—';
    final material = trip['materialName'] ?? '—';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: Text('Delete trip: $vehicle · $material?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(apiClientProvider)
                  .delete('/api/trips/${trip['id']}');
              ref.invalidate(tripsProvider(dateKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── list ─────────────────────────────────────────────────────────────────────

class _TripsList extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _TripsList(
      {required this.list, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final totalBrass = list.fold<double>(
        0, (s, t) => s + ((t['quantityBrass'] as num?)?.toDouble() ?? 0));
    return Column(
      children: [
        // Summary bar
        Container(
          color: Colors.green.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text('${list.length} trip${list.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 16),
              if (totalBrass > 0) ...[
                const Icon(Icons.inventory_2_outlined,
                    size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text('${numFmt.format(totalBrass)} Brass total',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green)),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _TripCard(
              trip: list[i],
              onEdit: () => onEdit(list[i]),
              onDelete: () => onDelete(list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── trip card ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TripCard(
      {required this.trip, required this.onEdit, required this.onDelete});

  static Future<void> _printChallan(BuildContext context, Map<String, dynamic> trip) async {
    final vehicle = trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '-';
    final party = trip['vendorName'] ?? '-';
    final material = trip['materialName'] ?? '-';
    final qty = trip['quantityBrass']?.toString() ?? '-';
    final dspNo = trip['dspChallanNo'] ?? '';
    final unloading = trip['unloadingLocation'] ?? '-';
    final tripDate = trip['tripDate'] ?? '';
    final now = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());

    // Build one challan column
    pw.Widget buildColumn(String copyLabel) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all()),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(children: [
                pw.Text('DSP CONSTRUCTION', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('DELIVERY CHALLAN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('($copyLabel)', style: const pw.TextStyle(fontSize: 9)),
              ]),
            ),
            pw.Divider(),
            _chRow('Date', tripDate),
            _chRow('Printed', now),
            _chRow('Vehicle', vehicle),
            _chRow('Party', party),
            _chRow('Delivery To', unloading),
            if (dspNo.isNotEmpty) _chRow('DSP Challan No', dspNo),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              children: [
                pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                  _th('Particulars'), _th('Qty (Brass)'),
                ]),
                pw.TableRow(children: [
                  _td(material), _td(qty),
                ]),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Authorised Signature:', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Receiver Signature:', style: const pw.TextStyle(fontSize: 9)),
            ]),
            pw.SizedBox(height: 20),
          ],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5.landscape,
      margin: const pw.EdgeInsets.all(12),
      build: (_) => pw.Row(
        children: [
          pw.Expanded(child: buildColumn('Original Copy')),
          pw.SizedBox(width: 8),
          pw.Expanded(child: buildColumn('Duplicate Copy')),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  static pw.Widget _chRow(String label, String val) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 80, child: pw.Text('$label:', style: const pw.TextStyle(fontSize: 9))),
      pw.Expanded(child: pw.Text(val, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
    ]),
  );

  static pw.Widget _th(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _td(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
  );

  @override
  Widget build(BuildContext context) {
    final vehicle =
        trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '-';
    final material = trip['materialName'] ?? '-';
    final qty = trip['quantityBrass'];
    final dspChallan = trip['dspChallanNo'] ?? '';
    final vendorChallan = trip['vendorChallanNo'] ?? '';
    final unloading = trip['unloadingLocation'] ?? '';
    final channel = trip['channelNo'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  vehicle.length > 4
                      ? vehicle.substring(vehicle.length - 4)
                      : vehicle,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(material,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                      if (qty != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.green.shade200),
                          ),
                          child: Text('$qty Brass',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(vehicle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  if (unloading.isNotEmpty || channel.isNotEmpty)
                    Text(
                      [
                        if (unloading.isNotEmpty) '→ $unloading',
                        if (channel.isNotEmpty) 'Ch: $channel'
                      ].join('  '),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  if (dspChallan.isNotEmpty || vendorChallan.isNotEmpty)
                    Text(
                      [
                        if (dspChallan.isNotEmpty) 'DSP: $dspChallan',
                        if (vendorChallan.isNotEmpty)
                          'Vdr: $vendorChallan'
                      ].join('  ·  '),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.blueGrey),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
                if (v == 'challan') _printChallan(context, trip);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'challan', child: Row(
                  children: [
                    Icon(Icons.print_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Print Challan'),
                  ],
                )),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── form dialog ──────────────────────────────────────────────────────────────

class _TripForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime initialDate;
  final VoidCallback onSaved;
  const _TripForm(
      {this.existing,
      required this.initialDate,
      required this.onSaved});

  @override
  ConsumerState<_TripForm> createState() => _TripFormState();
}

class _TripFormState extends ConsumerState<_TripForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _tripDate;
  late final _loading =
      TextEditingController(text: widget.existing?['loadingLocation']);
  late final _unloading =
      TextEditingController(text: widget.existing?['unloadingLocation']);
  late final _channel =
      TextEditingController(text: widget.existing?['channelNo']);
  late final _qtyBrass = TextEditingController(
      text: widget.existing?['quantityBrass']?.toString());
  late final _loadedTon = TextEditingController(
      text: widget.existing?['loadedWeightTon']?.toString());
  late final _emptyTon = TextEditingController(
      text: widget.existing?['emptyWeightTon']?.toString());
  late final _dspChallan =
      TextEditingController(text: widget.existing?['dspChallanNo']);
  late final _vdrChallan =
      TextEditingController(text: widget.existing?['vendorChallanNo']);
  int? _materialId;
  int? _vehicleId;
  int? _vendorId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tripDate = widget.initialDate;
    _materialId = widget.existing?['materialId'];
    _vehicleId = widget.existing?['vehicleId'];
    _vendorId = widget.existing?['vendorId'];
  }

  @override
  void dispose() {
    _loading.dispose();
    _unloading.dispose();
    _channel.dispose();
    _qtyBrass.dispose();
    _loadedTon.dispose();
    _emptyTon.dispose();
    _dspChallan.dispose();
    _vdrChallan.dispose();
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
      'loadingLocation': _loading.text.trim().isEmpty
          ? null
          : _loading.text.trim(),
      'unloadingLocation': _unloading.text.trim().isEmpty
          ? null
          : _unloading.text.trim(),
      'channelNo':
          _channel.text.trim().isEmpty ? null : _channel.text.trim(),
      'materialId': _materialId,
      'quantityBrass': _qtyBrass.text.trim().isEmpty
          ? null
          : double.tryParse(_qtyBrass.text.trim()),
      'loadedWeightTon': _loadedTon.text.trim().isEmpty
          ? null
          : double.tryParse(_loadedTon.text.trim()),
      'emptyWeightTon': _emptyTon.text.trim().isEmpty
          ? null
          : double.tryParse(_emptyTon.text.trim()),
      'vehicleId': _vehicleId,
      'vendorId': _vendorId,
      'dspChallanNo': _dspChallan.text.trim().isEmpty
          ? null
          : _dspChallan.text.trim(),
      'vendorChallanNo': _vdrChallan.text.trim().isEmpty
          ? null
          : _vdrChallan.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    final siteId = ref.read(selectedSiteIdProvider);
    final siteParams = siteId != null ? {'siteId': siteId} : null;
    try {
      if (widget.existing == null) {
        await api.post('/api/trips', data: data, params: siteParams);
      } else {
        await api.put('/api/trips/${widget.existing!['id']}', data: data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(_materialsProvider);
    final vehicles = ref.watch(_vehiclesProvider);
    final vendors = ref.watch(_vendorsProvider);
    final isEdit = widget.existing != null;

    return AppDialog(
      title: isEdit ? 'Edit Trip' : 'Add Trip',
      maxWidth: 500,
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update' : 'Save'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BASIC INFO
            const SectionLabel('Basic Information'),
            DateField(
              label: 'Trip Date',
              date: _tripDate,
              onTap: _pickDate,
              required: true,
            ),
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
                fieldLabel: 'Party *',
                value: _vendorId,
                onChanged: (v) => setState(() => _vendorId = v),
                validator: (v) => v == null ? 'Select party' : null,
              ),
            ),

            // MATERIAL
            const SectionLabel('Material'),
            materials.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => SearchablePicker(
                items: list,
                itemLabel: (m) => m['name'] as String,
                fieldLabel: 'Material *',
                value: _materialId,
                onChanged: (v) => setState(() => _materialId = v),
                validator: (v) => v == null ? 'Select material' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyBrass,
              decoration: const InputDecoration(
                  labelText: 'Quantity', suffixText: 'Brass'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                        controller: _loading,
                        decoration: const InputDecoration(
                            labelText: 'Loading Location'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _unloading,
                        decoration: const InputDecoration(
                            labelText: 'Unloading Location'))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _channel,
                decoration: const InputDecoration(labelText: 'Channel No')),

            // DOCUMENTS
            const SectionLabel('Documents'),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                        controller: _dspChallan,
                        decoration: const InputDecoration(
                            labelText: 'DSP Challan No'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _vdrChallan,
                        decoration: const InputDecoration(
                            labelText: 'Vendor Challan No'))),
              ],
            ),

            // WEIGHTS (optional)
            const SectionLabel('Weights (Optional)'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _loadedTon,
                    decoration: const InputDecoration(
                        labelText: 'Loaded Weight', suffixText: 'T'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _emptyTon,
                    decoration: const InputDecoration(
                        labelText: 'Empty Weight', suffixText: 'T'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
