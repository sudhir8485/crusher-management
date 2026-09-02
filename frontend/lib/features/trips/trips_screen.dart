import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

// ── Providers ────────────────────────────────────────────────────────────────

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

// ── Main Screen ───────────────────────────────────────────────────────────────

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
                      message: 'No trips for ${DateFormat('d MMM yyyy').format(selectedDate)}',
                      hint: 'Tap + to add a trip',
                    )
                  : _TripsList(
                      list: list,
                      onEdit: (t) => _showForm(context, ref, t, selectedDate),
                      onDelete: (t) => _confirmDelete(context, ref, t, dateKey),
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
          final dk = DateFormat('yyyy-MM-dd').format(ref.read(tripsDateProvider));
          ref.invalidate(tripsProvider(dk));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      Map<String, dynamic> trip, String dateKey) {
    final party = trip['partyDisplayName'] ?? trip['vendorName'] ?? '—';
    final material = trip['materialName'] ?? '—';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: Text('Delete trip: $party · $material?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/trips/${trip['id']}');
              ref.invalidate(tripsProvider(dateKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Trip List ─────────────────────────────────────────────────────────────────

class _TripsList extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _TripsList({required this.list, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final totalBill = list.fold<double>(
        0, (s, t) => s + ((t['totalBill'] as num?)?.toDouble() ?? 0));
    final totalQty = list.fold<double>(0, (s, t) {
      final q = (t['billableQuantity'] as num?)?.toDouble() ??
                (t['quantityBrass'] as num?)?.toDouble() ?? 0;
      return s + q;
    });

    return Column(
      children: [
        Container(
          color: Colors.green.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text('${list.length} trip${list.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (totalQty > 0) ...[
                const SizedBox(width: 16),
                const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text('${numFmt.format(totalQty)} total',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              ],
              if (totalBill > 0) ...[
                const Spacer(),
                Text(fmtCurr(totalBill),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,
                        color: Colors.green.shade800)),
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

// ── Trip Card ─────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TripCard({required this.trip, required this.onEdit, required this.onDelete});

  static Future<void> _printChallan(BuildContext context, Map<String, dynamic> trip) async {
    final isOwn = trip['vehicleMode'] == 'OWN_VEHICLE';
    final vehicle = isOwn
        ? "Customer's Own Vehicle"
        : (trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '-');
    final party = trip['partyDisplayName'] ?? trip['vendorName'] ?? '-';
    final material = trip['materialName'] ?? '-';
    final billableQty = trip['billableQuantity'] ?? trip['quantityBrass'];
    final unit = trip['quantityUnit'] ?? 'Brass';
    final qty = billableQty != null ? '${numFmt.format(billableQty)} $unit' : '-';
    final dspNo = trip['dspChallanNo'] ?? '';
    final unloading = trip['unloadingLocation'] ?? '-';
    final tripDate = trip['tripDate'] ?? '';
    final now = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());
    final totalBill = trip['totalBill'];
    final netKg = trip['netWeightKg'];

    pw.Widget buildColumn(String copyLabel) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all()),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(children: [
                pw.Text('DSP CONSTRUCTION',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('DELIVERY CHALLAN',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
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
                pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [_th('Material'), _th('Net Wt'), _th('Qty')]),
                pw.TableRow(children: [
                  _td(material),
                  _td(netKg != null ? '${numFmt.format(netKg)} kg' : '-'),
                  _td(qty),
                ]),
              ],
            ),
            if (totalBill != null) ...[
              pw.SizedBox(height: 6),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text('Total: ₹${numFmt.format(totalBill)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ]),
            ],
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
      pw.Expanded(
          child: pw.Text(val, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
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
    final isOwn = trip['vehicleMode'] == 'OWN_VEHICLE';
    final vehicle = isOwn
        ? 'Own Vehicle'
        : (trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '—');
    final material = trip['materialName'] ?? '—';
    final billableQty = (trip['billableQuantity'] as num?)?.toDouble()
        ?? (trip['quantityBrass'] as num?)?.toDouble();
    final unit = trip['quantityUnit'] ?? 'Brass';
    final totalBill = (trip['totalBill'] as num?)?.toDouble();
    final party = trip['partyDisplayName'] ?? trip['vendorName'] ?? '—';
    final isOneTime = trip['partyType'] == 'ONE_TIME';

    // Badge label: last 4 of vehicle plate or "OWN"
    final badgeLabel = isOwn
        ? 'OWN'
        : vehicle.length > 4 ? vehicle.substring(vehicle.length - 4) : vehicle;

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
                color: isOwn
                    ? Colors.blue.shade100
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  badgeLabel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Material + qty badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(material,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      if (billableQty != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                              '${numFmt.format(billableQty)} $unit',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Party row
                  Row(
                    children: [
                      if (isOneTime)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text('ONE-TIME',
                              style: TextStyle(fontSize: 9, color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600)),
                        ),
                      Expanded(
                        child: Text(party,
                            style: TextStyle(fontSize: 13, color: Colors.grey[800],
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Vehicle + total bill row
                  Row(
                    children: [
                      Expanded(
                        child: Text(vehicle,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ),
                      if (totalBill != null && totalBill > 0)
                        Text(fmtCurr(totalBill),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700)),
                    ],
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
                PopupMenuItem(
                    value: 'challan',
                    child: Row(children: [
                      Icon(Icons.print_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Print Challan'),
                    ])),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Party Search Dialog ───────────────────────────────────────────────────────

class _PartySearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vendors;
  final int? currentId;
  const _PartySearchDialog({required this.vendors, this.currentId});

  @override
  State<_PartySearchDialog> createState() => _PartySearchDialogState();
}

class _PartySearchDialogState extends State<_PartySearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.vendors
        : widget.vendors.where((v) {
            final name = (v['name'] as String? ?? '').toLowerCase();
            final phone = (v['contact'] as String? ?? '').toLowerCase();
            return name.contains(_query) || phone.contains(_query);
          }).toList();
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Party',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or phone…',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (q) => setState(() => _query = q.toLowerCase().trim()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text('No parties found',
                            style: TextStyle(color: Colors.grey))))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = filtered[i];
                      final id = v['id'] as int?;
                      final isSelected = id == widget.currentId;
                      final contact = v['contact'] as String? ?? '';
                      return ListTile(
                        dense: true,
                        title: Text(v['name'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: contact.isNotEmpty ? Text(contact) : null,
                        trailing: isSelected
                            ? Icon(Icons.check, color: cs.primary, size: 20)
                            : null,
                        tileColor: isSelected
                            ? cs.primary.withValues(alpha: 0.06)
                            : null,
                        onTap: () => Navigator.pop(context, v),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Trip Form ─────────────────────────────────────────────────────────────────

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

  // Date
  late DateTime _tripDate;

  // Party
  String _partyType = 'REGULAR';
  int? _vendorId;
  String _vendorName = '';
  String _vendorPhone = '';
  String? _vendorError;
  final _oneTimeName  = TextEditingController();
  final _oneTimePhone = TextEditingController();
  final _oneTimeAddr  = TextEditingController();

  // Material
  int? _materialId;
  Map<String, dynamic>? _material;
  bool _materialLoaded = false;
  String _quantityUnit = 'BRASS';
  final _loadedKg    = TextEditingController();
  final _emptyKg     = TextEditingController();
  final _manualQty   = TextEditingController();
  final _saleRate    = TextEditingController();

  // Vehicle
  String _vehicleMode = 'COMPANY';
  int? _vehicleId;
  String? _vehicleError;
  final _distance       = TextEditingController();
  final _transportRate  = TextEditingController();

  // Additional
  bool _showAdditional = false;
  final _dspChallan   = TextEditingController();
  final _vdrChallan   = TextEditingController();
  final _channel      = TextEditingController();
  final _loadingLoc   = TextEditingController();
  final _unloadingLoc = TextEditingController();
  final _notes        = TextEditingController();

  // Computed
  double? _netWeightKg;
  double? _billableQty;
  bool _qtyFromWeights = false;
  double? _materialAmount;
  double? _transportCharge;
  double? _totalBill;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tripDate = widget.initialDate;

    if (e != null) {
      _partyType = e['partyType'] ?? 'REGULAR';
      _vendorId  = e['vendorId'];
      _vendorName = e['vendorName'] ?? e['partyDisplayName'] ?? '';
      _vendorPhone = e['vendorContact'] ?? e['partyPhone'] ?? '';
      _oneTimeName.text  = e['oneTimeCustomerName'] ?? '';
      _oneTimePhone.text = e['oneTimeCustomerPhone'] ?? '';
      _oneTimeAddr.text  = e['oneTimeCustomerAddr'] ?? '';

      _materialId   = e['materialId'];
      _quantityUnit = e['quantityUnit'] ?? 'BRASS';
      _vehicleMode  = e['vehicleMode'] ?? 'COMPANY';
      _vehicleId    = e['vehicleId'];

      // Weights: prefer new kg fields, fall back to ton×1000
      final loadedKg  = (e['loadedWeightKg'] as num?)?.toDouble();
      final loadedTon = (e['loadedWeightTon'] as num?)?.toDouble();
      final emptyKg   = (e['emptyWeightKg'] as num?)?.toDouble();
      final emptyTon  = (e['emptyWeightTon'] as num?)?.toDouble();
      if (loadedKg != null) {
        _loadedKg.text = loadedKg.toStringAsFixed(0);
      } else if (loadedTon != null) {
        _loadedKg.text = (loadedTon * 1000).toStringAsFixed(0);
      }
      if (emptyKg != null) {
        _emptyKg.text = emptyKg.toStringAsFixed(0);
      } else if (emptyTon != null) {
        _emptyKg.text = (emptyTon * 1000).toStringAsFixed(0);
      }

      // Billable qty: new field or legacy quantityBrass
      final billableQty = (e['billableQuantity'] as num?)?.toDouble();
      final qtyBrass    = (e['quantityBrass'] as num?)?.toDouble();
      if (billableQty != null) {
        _manualQty.text = billableQty.toStringAsFixed(3);
      } else if (qtyBrass != null) {
        _manualQty.text = qtyBrass.toStringAsFixed(3);
      }

      final sr = (e['saleRate'] as num?)?.toDouble();
      if (sr != null) _saleRate.text = sr.toStringAsFixed(2);

      final dist = (e['distanceKm'] as num?)?.toDouble();
      final tr   = (e['transportRatePerKm'] as num?)?.toDouble();
      if (dist != null) _distance.text = dist.toStringAsFixed(1);
      if (tr != null)   _transportRate.text = tr.toStringAsFixed(2);

      _dspChallan.text   = e['dspChallanNo'] ?? '';
      _vdrChallan.text   = e['vendorChallanNo'] ?? '';
      _channel.text      = e['channelNo'] ?? '';
      _loadingLoc.text   = e['loadingLocation'] ?? '';
      _unloadingLoc.text = e['unloadingLocation'] ?? '';
      _notes.text        = e['notes'] ?? '';

      // Expand additional if any field has content
      _showAdditional = [_dspChallan, _vdrChallan, _channel, _loadingLoc, _unloadingLoc, _notes]
          .any((c) => c.text.isNotEmpty);
    }

    for (final ctrl in [_loadedKg, _emptyKg, _manualQty, _saleRate, _distance, _transportRate]) {
      ctrl.addListener(_recalculate);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    for (final ctrl in [
      _oneTimeName, _oneTimePhone, _oneTimeAddr,
      _loadedKg, _emptyKg, _manualQty, _saleRate,
      _distance, _transportRate,
      _dspChallan, _vdrChallan, _channel, _loadingLoc, _unloadingLoc, _notes,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    final loaded = double.tryParse(_loadedKg.text.trim());
    final empty  = double.tryParse(_emptyKg.text.trim());

    double? net;
    if (loaded != null && empty != null) {
      net = (loaded - empty).clamp(0.0, double.infinity);
    }

    double? qty;
    bool fromWt = false;
    if (net != null) {
      if (_quantityUnit == 'TON') {
        qty = net / 1000.0;
        fromWt = true;
      } else {
        final kpb = (_material?['kgPerBrass'] as num?)?.toDouble();
        if (kpb != null && kpb > 0) {
          qty = net / kpb;
          fromWt = true;
        }
      }
    }
    if (!fromWt) {
      qty = double.tryParse(_manualQty.text.trim());
    }

    final rate = double.tryParse(_saleRate.text.trim());
    final matAmt = (qty != null && rate != null) ? qty * rate : null;

    double? transport;
    if (_vehicleMode == 'OWN_VEHICLE') {
      transport = 0.0;
    } else {
      final dist = double.tryParse(_distance.text.trim());
      final tr   = double.tryParse(_transportRate.text.trim());
      transport = (dist != null && tr != null) ? dist * tr : null;
    }

    setState(() {
      _netWeightKg     = net;
      _billableQty     = qty;
      _qtyFromWeights  = fromWt;
      _materialAmount  = matAmt;
      _transportCharge = transport;
      _totalBill       = (matAmt != null || transport != null)
          ? (matAmt ?? 0) + (transport ?? 0)
          : null;
    });
  }

  void _onMaterialChanged(int? id, List<Map<String, dynamic>> allMaterials) {
    final mat = id != null
        ? allMaterials.where((m) => m['id'] == id).cast<Map<String, dynamic>?>().firstOrNull
        : null;
    setState(() {
      _materialId = id;
      _material = mat;
      if (mat != null) {
        final u = mat['unit'] as String?;
        if (u == 'TON' || u == 'BRASS') _quantityUnit = u!;
        // Prefill sale rate from material default if field is empty
        final defRate = mat['defaultSaleRate'];
        if (defRate != null && _saleRate.text.trim().isEmpty) {
          _saleRate.text = defRate.toString();
        }
      }
    });
    _recalculate();
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
    // Manual validation for pickers
    setState(() {
      _vendorError = (_partyType == 'REGULAR' && _vendorId == null) ? 'Select a party' : null;
      _vehicleError = (_vehicleMode == 'COMPANY' && _vehicleId == null) ? 'Select a vehicle' : null;
    });

    if (_vendorError != null || _vehicleError != null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final b = <String, dynamic>{
      'tripDate': DateFormat('yyyy-MM-dd').format(_tripDate),
      'partyType': _partyType,
    };

    if (_partyType == 'REGULAR') {
      b['vendorId'] = _vendorId;
    } else {
      b['oneTimeCustomerName'] = _oneTimeName.text.trim();
      final ph = _oneTimePhone.text.trim();
      if (ph.isNotEmpty) b['oneTimeCustomerPhone'] = ph;
      final ad = _oneTimeAddr.text.trim();
      if (ad.isNotEmpty) b['oneTimeCustomerAddr'] = ad;
    }

    b['materialId']   = _materialId;
    b['quantityUnit'] = _quantityUnit;

    final loaded = double.tryParse(_loadedKg.text.trim());
    final empty  = double.tryParse(_emptyKg.text.trim());
    if (loaded != null) b['loadedWeightKg'] = loaded;
    if (empty != null)  b['emptyWeightKg']  = empty;

    // Send manual qty only when not calculated from weights
    if (!_qtyFromWeights) {
      final mq = double.tryParse(_manualQty.text.trim());
      if (mq != null) b['billableQuantity'] = mq;
    }

    final sr = double.tryParse(_saleRate.text.trim());
    if (sr != null) b['saleRate'] = sr;

    b['vehicleMode'] = _vehicleMode;
    if (_vehicleMode == 'COMPANY') {
      b['vehicleId'] = _vehicleId;
      final dist = double.tryParse(_distance.text.trim());
      final tr   = double.tryParse(_transportRate.text.trim());
      if (dist != null) b['distanceKm']           = dist;
      if (tr != null)   b['transportRatePerKm']   = tr;
    }

    void opt(String key, String val) {
      final t = val.trim();
      if (t.isNotEmpty) b[key] = t;
    }
    opt('dspChallanNo',     _dspChallan.text);
    opt('vendorChallanNo',  _vdrChallan.text);
    opt('channelNo',        _channel.text);
    opt('loadingLocation',  _loadingLoc.text);
    opt('unloadingLocation', _unloadingLoc.text);
    opt('notes',            _notes.text);

    final api    = ref.read(apiClientProvider);
    final siteId = ref.read(selectedSiteIdProvider);
    try {
      if (widget.existing == null) {
        final params = siteId != null ? {'siteId': siteId} : null;
        await api.post('/api/trips', data: b, params: params);
      } else {
        await api.put('/api/trips/${widget.existing!['id']}', data: b);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  Widget _sectionHead(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(title,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: Colors.grey[600], letterSpacing: 0.8)),
  );

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? cs.primary : null,
          border: Border.all(color: selected ? cs.primary : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13),
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool emphasis = false}) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: emphasis ? Colors.green.shade50 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: emphasis ? Colors.green.shade800 : Colors.grey[700])),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: emphasis ? FontWeight.bold : FontWeight.w500,
                color: emphasis ? Colors.green.shade800 : null)),
      ],
    ),
  );

  Widget _numField(TextEditingController ctrl, String label,
      {String? suffix, String? prefix, bool required = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          suffixText: suffix,
          prefixText: prefix,
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      );

  Widget _partyPickerField(List<Map<String, dynamic>> vendors) {
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => _PartySearchDialog(vendors: vendors, currentId: _vendorId),
        );
        if (result != null) {
          setState(() {
            _vendorId    = result['id'] as int?;
            _vendorName  = result['name'] as String? ?? '';
            _vendorPhone = result['contact'] as String? ?? '';
            _vendorError = null;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Party *',
          errorText: _vendorError,
          suffixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
        isEmpty: _vendorName.isEmpty,
        child: _vendorName.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_vendorName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  if (_vendorPhone.isNotEmpty)
                    Text(_vendorPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _billingSummary() {
    if (_totalBill == null) return const SizedBox.shrink();
    final matAmt   = _materialAmount ?? 0;
    final transAmt = _transportCharge ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BILLING SUMMARY',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey[500], letterSpacing: 0.8)),
          const SizedBox(height: 12),
          if (_billableQty != null && _saleRate.text.trim().isNotEmpty)
            _bRow(
                '${numFmt.format(_billableQty!)} $_quantityUnit'
                ' × ₹${_saleRate.text.trim()}',
                fmtCurr(matAmt)),
          if (_vehicleMode == 'OWN_VEHICLE')
            _bRow("Customer's Own Vehicle", '₹ 0.00')
          else if (_transportCharge != null)
            _bRow(
                (_distance.text.isNotEmpty && _transportRate.text.isNotEmpty)
                    ? '${_distance.text} km × ₹${_transportRate.text}/km'
                    : 'Transportation',
                fmtCurr(transAmt)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL BILL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(fmtCurr(_totalBill!),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );

  // ── Main Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mats    = ref.watch(_materialsProvider);
    final vehs    = ref.watch(_vehiclesProvider);
    final vendors = ref.watch(_vendorsProvider);
    final isEdit  = widget.existing != null;

    // Sync material object when editing (for kgPerBrass lookups)
    if (!_materialLoaded && _materialId != null) {
      mats.whenData((list) {
        if (_material == null) {
          final found = list.where((m) => m['id'] == _materialId).cast<Map<String, dynamic>?>().firstOrNull;
          if (found != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _material == null) {
                setState(() { _material = found; _materialLoaded = true; });
                _recalculate();
              }
            });
          }
        }
      });
    }

    final brassMissingConversion = _quantityUnit == 'BRASS'
        && _netWeightKg != null
        && ((_material?['kgPerBrass'] as num?)?.toDouble() ?? 0) <= 0;

    return AppDialog(
      title: isEdit ? 'Edit Trip' : 'Add Trip',
      maxWidth: 700,
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update Trip' : 'Save Trip'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 1. Trip Date ────────────────────────────────────────────────
            _sectionHead('TRIP DATE'),
            DateField(
                label: 'Trip Date', date: _tripDate,
                onTap: _pickDate, required: true),

            // ── 2. Party / Customer ─────────────────────────────────────────
            _sectionHead('PARTY / CUSTOMER'),
            Row(children: [
              Expanded(child: _pill('Regular Customer', _partyType == 'REGULAR', () {
                setState(() { _partyType = 'REGULAR'; _vendorError = null; });
              })),
              const SizedBox(width: 8),
              Expanded(child: _pill('One-Time Customer', _partyType == 'ONE_TIME', () {
                setState(() { _partyType = 'ONE_TIME'; _vendorError = null; });
              })),
            ]),
            const SizedBox(height: 12),
            if (_partyType == 'REGULAR')
              vendors.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading parties: $e'),
                data: _partyPickerField,
              )
            else ...[
              TextFormField(
                controller: _oneTimeName,
                decoration: const InputDecoration(labelText: 'Customer Name *'),
                validator: (v) =>
                    (_partyType == 'ONE_TIME' && (v == null || v.trim().isEmpty))
                        ? 'Name is required' : null,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(
                    controller: _oneTimePhone,
                    decoration: const InputDecoration(labelText: 'Phone Number'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                    controller: _oneTimeAddr,
                    decoration: const InputDecoration(labelText: 'Address'))),
              ]),
            ],

            // ── 3. Material & Quantity ──────────────────────────────────────
            _sectionHead('MATERIAL & QUANTITY'),
            mats.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading materials: $e'),
              data: (list) => SearchablePicker(
                items: list,
                itemLabel: (m) => m['name'] as String,
                fieldLabel: 'Material *',
                value: _materialId,
                onChanged: (v) => _onMaterialChanged(v, list),
                validator: (v) => v == null ? 'Select material' : null,
              ),
            ),
            const SizedBox(height: 14),
            // Unit toggle
            Row(children: [
              Text('Unit:', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(width: 12),
              _pill('BRASS', _quantityUnit == 'BRASS', () {
                setState(() => _quantityUnit = 'BRASS');
                _recalculate();
              }),
              const SizedBox(width: 8),
              _pill('TON', _quantityUnit == 'TON', () {
                setState(() => _quantityUnit = 'TON');
                _recalculate();
              }),
            ]),
            const SizedBox(height: 12),
            // Weights
            Row(children: [
              Expanded(child: TextFormField(
                controller: _loadedKg,
                decoration: const InputDecoration(
                    labelText: 'Loaded Weight', suffixText: 'kg'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Invalid number';
                    if (n < 0) return 'Cannot be negative';
                  }
                  return null;
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _emptyKg,
                decoration: const InputDecoration(
                    labelText: 'Empty Weight', suffixText: 'kg'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Invalid number';
                    if (n < 0) return 'Cannot be negative';
                    final loaded = double.tryParse(_loadedKg.text.trim());
                    if (loaded != null && n > loaded) {
                      return 'Cannot exceed loaded weight';
                    }
                  }
                  return null;
                },
              )),
            ]),
            if (_netWeightKg != null)
              _calcRow('Net Weight', '${numFmt.format(_netWeightKg!)} kg'),

            // BRASS conversion warning
            if (brassMissingConversion)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Brass conversion (kg/brass) not configured for this material. '
                      'Enter quantity manually below.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ]),
              ),

            const SizedBox(height: 10),
            // Billable quantity: read-only computed display or manual entry
            if (_qtyFromWeights && _billableQty != null)
              _calcRow(
                  'Billable Quantity',
                  '${_billableQty!.toStringAsFixed(3)} $_quantityUnit',
                  emphasis: true)
            else
              TextFormField(
                controller: _manualQty,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  suffixText: _quantityUnit,
                  helperText: _netWeightKg == null
                      ? 'Enter quantity directly, or fill weights above to auto-calculate'
                      : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter quantity';
                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                  if (double.parse(v.trim()) < 0) return 'Cannot be negative';
                  return null;
                },
              ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _saleRate,
              decoration: InputDecoration(
                labelText: 'Sale Rate',
                prefixText: '₹ ',
                suffixText: '/ $_quantityUnit',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                }
                return null;
              },
            ),
            if (_materialAmount != null)
              _calcRow('Material Amount', fmtCurr(_materialAmount!), emphasis: true),

            // ── 4. Vehicle & Transportation ─────────────────────────────────
            _sectionHead('VEHICLE & TRANSPORTATION'),
            Row(children: [
              Expanded(child: _pill('Company Vehicle', _vehicleMode == 'COMPANY', () {
                setState(() { _vehicleMode = 'COMPANY'; _vehicleError = null; });
                _recalculate();
              })),
              const SizedBox(width: 8),
              Expanded(child: _pill("Customer's Own Vehicle", _vehicleMode == 'OWN_VEHICLE', () {
                setState(() { _vehicleMode = 'OWN_VEHICLE'; _vehicleError = null; });
                _recalculate();
              })),
            ]),
            const SizedBox(height: 12),
            if (_vehicleMode == 'COMPANY') ...[
              vehs.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading vehicles: $e'),
                data: (list) => SearchablePicker(
                  items: list,
                  itemLabel: (v) =>
                      '${v['displayName'] ?? v['plateNumber']}  (${v['vehicleType'] ?? ''})',
                  fieldLabel: 'Vehicle *',
                  value: _vehicleId,
                  onChanged: (v) => setState(() {
                    _vehicleId = v;
                    _vehicleError = null;
                  }),
                  validator: (_) => _vehicleError,
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numField(_distance, 'Distance', suffix: 'km')),
                const SizedBox(width: 12),
                Expanded(child: _numField(
                    _transportRate, 'Transport Rate', prefix: '₹ ', suffix: '/km')),
              ]),
              if (_transportCharge != null)
                _calcRow('Transportation Charge', fmtCurr(_transportCharge!)),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.blue.shade600, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    "Customer's own vehicle — no transportation charge",
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                  ),
                ]),
              ),

            // ── 5. Billing Summary ──────────────────────────────────────────
            _billingSummary(),

            // ── 6. Additional Details (collapsible) ─────────────────────────
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                    _showAdditional
                        ? 'Additional Details'
                        : '+ Additional Details (DSP/Vendor Challan, Channel, Notes)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                initiallyExpanded: _showAdditional,
                onExpansionChanged: (v) => setState(() => _showAdditional = v),
                children: [
                  Row(children: [
                    Expanded(child: TextFormField(
                        controller: _dspChallan,
                        decoration:
                            const InputDecoration(labelText: 'DSP Challan No'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                        controller: _vdrChallan,
                        decoration:
                            const InputDecoration(labelText: 'Vendor Challan No'))),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _channel,
                      decoration: const InputDecoration(labelText: 'Channel No')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextFormField(
                        controller: _loadingLoc,
                        decoration:
                            const InputDecoration(labelText: 'Loading Location'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                        controller: _unloadingLoc,
                        decoration:
                            const InputDecoration(labelText: 'Unloading Location'))),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
