import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/storage/auth_storage.dart';
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
                      onConvert: (t) => _showConvertDialog(context, ref, t, dateKey),
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
    final customer = trip['partyDisplayName'] ?? trip['vendorName'] ?? '—';
    final material = trip['materialName'] ?? '—';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: Text('Delete trip: $customer · $material?\n\nThis cannot be undone.'),
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

  void _showConvertDialog(BuildContext context, WidgetRef ref,
      Map<String, dynamic> trip, String dateKey) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConvertCustomerDialog(
        trip: trip,
        onSaved: () {
          ref.invalidate(tripsProvider(dateKey));
          ref.invalidate(_vendorsProvider);
        },
      ),
    );
  }
}

// ── Trip List ─────────────────────────────────────────────────────────────────

class _TripsList extends StatefulWidget {
  final List<Map<String, dynamic>> list;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  final void Function(Map<String, dynamic>) onConvert;
  const _TripsList({
    required this.list,
    required this.onEdit,
    required this.onDelete,
    required this.onConvert,
  });

  @override
  State<_TripsList> createState() => _TripsListState();
}

class _TripsListState extends State<_TripsList> {
  bool _oneTimeOnly = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.list;
    final list = _oneTimeOnly
        ? all.where((t) => t['partyType'] == 'ONE_TIME').toList()
        : all;
    final oneTimeCount = all.where((t) => t['partyType'] == 'ONE_TIME').length;

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
              // One-time filter chip — tap to show only one-time customer trips
              if (oneTimeCount > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _oneTimeOnly = !_oneTimeOnly),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _oneTimeOnly
                          ? Colors.orange.shade200
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('$oneTimeCount one-time',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600)),
                      if (_oneTimeOnly) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.close, size: 12, color: Colors.orange.shade800),
                      ],
                    ]),
                  ),
                ),
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
          child: list.isEmpty
              ? const AppEmptyState(
                  icon: Icons.person_outline,
                  message: 'No one-time customer trips today',
                  hint: 'Tap the "one-time" chip again to show all trips',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TripCard(
                    trip: list[i],
                    onEdit: () => widget.onEdit(list[i]),
                    onDelete: () => widget.onDelete(list[i]),
                    onConvert: list[i]['partyType'] == 'ONE_TIME'
                        ? () => widget.onConvert(list[i])
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Trip Card ─────────────────────────────────────────────────────────────────

class _TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onConvert;
  const _TripCard({
    required this.trip,
    required this.onEdit,
    required this.onDelete,
    this.onConvert,
  });

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _expanded = false;

  static Future<void> _printChallan(BuildContext context, Map<String, dynamic> trip) async {
    // Load Noto Sans for proper ₹ Rupee symbol rendering
    final font       = await PdfGoogleFonts.notoSansRegular();
    final fontBold   = await PdfGoogleFonts.notoSansBold();
    final businessName = await AuthStorage.getTenantName() ?? '';

    final isOwn   = trip['vehicleMode'] == 'OWN_VEHICLE';
    final vehicle = isOwn
        ? "Customer's Own Vehicle"
        : '${trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '—'}';
    final party      = trip['partyDisplayName'] ?? trip['vendorName'] ?? '—';
    final partyPhone = trip['partyPhone'] ?? trip['vendorContact'] ?? '';
    final material   = trip['materialName'] ?? '—';
    final unit       = trip['quantityUnit'] ?? 'Brass';
    final billableQty = trip['billableQuantity'] ?? trip['quantityBrass'];
    final qty        = billableQty != null ? numFmt.format(billableQty) : '—';
    final loadedKg   = trip['loadedWeightKg'];
    final emptyKg    = trip['emptyWeightKg'];
    final netKg      = trip['netWeightKg'];
    final saleRate   = trip['saleRate'];
    final matAmt     = trip['materialAmount'];
    final transChg   = trip['transportationCharge'];
    final totalBill  = trip['totalBill'];
    final challanNo  = trip['dspChallanNo'] ?? '';
    final distKm     = trip['distanceKm'];
    final transRate  = trip['transportRatePerKm'];
    final tripDate   = trip['tripDate'] ?? '';
    final unloading  = trip['unloadingLocation'] ?? '';

    String rs(dynamic v) => v != null ? '₹${numFmt.format(v)}' : '—';
    String kg(dynamic v) => v != null ? '${numFmt.format(v)} kg' : '—';

    // Explicit font= on every pw.TextStyle so ₹ (U+20B9) routes through
    // Noto Sans rather than falling back to Helvetica (which lacks the glyph).
    pw.Widget col(String label, String val, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 100,
            child: pw.Text('$label:',
                style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700))),
        pw.Expanded(child: pw.Text(val,
            style: pw.TextStyle(
                font: bold ? fontBold : font,
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
      ]),
    );

    pw.Widget divider() => pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
      height: 0.5,
      color: PdfColors.grey400,
    );

    pw.Widget buildCopy(String copyLabel) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (businessName.isNotEmpty)
                  pw.Text(businessName,
                      style: pw.TextStyle(font: fontBold, fontSize: 13,
                          fontWeight: pw.FontWeight.bold)),
                pw.Text('DELIVERY CHALLAN',
                    style: pw.TextStyle(font: fontBold,
                        fontSize: businessName.isNotEmpty ? 11 : 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(copyLabel,
                    style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                if (challanNo.isNotEmpty)
                  pw.Text('Challan No: $challanNo',
                      style: pw.TextStyle(font: fontBold, fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: $tripDate',
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ]),
            ]),
            divider(),

            // Customer & Vehicle
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Customer',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(party,
                      style: pw.TextStyle(font: fontBold, fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                  if (partyPhone.isNotEmpty)
                    pw.Text(partyPhone,
                        style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              )),
              pw.SizedBox(width: 12),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Vehicle',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(vehicle,
                      style: pw.TextStyle(font: fontBold, fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                  if (unloading.isNotEmpty)
                    pw.Text('To: $unloading',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              )),
            ]),
            divider(),

            // Material section
            pw.Text('MATERIAL', style: pw.TextStyle(font: fontBold, fontSize: 8,
                fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.5)),
            pw.SizedBox(height: 4),
            col('Material', material, bold: true),
            if (loadedKg != null) col('Loaded Weight', kg(loadedKg)),
            if (emptyKg  != null) col('Empty Weight',  kg(emptyKg)),
            if (netKg    != null) col('Net Weight',     kg(netKg), bold: true),
            col('Quantity', '$qty $unit', bold: true),
            if (saleRate != null) col('Sale Rate', '${rs(saleRate)} / $unit'),
            if (matAmt   != null) col('Material Amount', rs(matAmt), bold: true),
            divider(),

            // Transportation section
            pw.Text('TRANSPORTATION', style: pw.TextStyle(font: fontBold, fontSize: 8,
                fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.5)),
            pw.SizedBox(height: 4),
            if (isOwn)
              col('Mode', "Customer's Own Vehicle — ${rs(0)}")
            else
              col('Vehicle', vehicle),
            if (!isOwn && billableQty != null) col('Quantity', '$qty $unit'),
            if (!isOwn && distKm != null)      col('Distance', '${numFmt.format(distKm)} km'),
            if (!isOwn && transRate != null)   col('Rate',     '${rs(transRate)} / km / $unit'),
            col('Transport Charge', rs(transChg), bold: true),
            divider(),

            // Total Bill
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL BILL',
                  style: pw.TextStyle(font: fontBold, fontSize: 11,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text(rs(totalBill),
                  style: pw.TextStyle(font: fontBold, fontSize: 13,
                      fontWeight: pw.FontWeight.bold)),
            ]),
            divider(),

            pw.SizedBox(height: 16),
            // Signatures
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(width: 140, height: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 3),
                pw.Text('Receiver Signature',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(width: 140, height: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 3),
                pw.Text('Authorised Signature',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
              ]),
            ]),
          ],
        ),
      );
    }

    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => pw.Row(
        children: [
          pw.Expanded(child: buildCopy('Original Copy')),
          pw.SizedBox(width: 12),
          pw.Expanded(child: buildCopy('Duplicate Copy')),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Widget _buildCalculationDetail() {
    final t = widget.trip;
    final loadedKg  = (t['loadedWeightKg']     as num?)?.toDouble();
    final emptyKg   = (t['emptyWeightKg']      as num?)?.toDouble();
    final netKg     = (t['netWeightKg']        as num?)?.toDouble();
    final qty       = (t['billableQuantity']   as num?)?.toDouble()
                      ?? (t['quantityBrass']   as num?)?.toDouble();
    final unit      = t['quantityUnit'] as String? ?? 'BRASS';
    final rate      = (t['saleRate']           as num?)?.toDouble();
    final matAmt    = (t['materialAmount']     as num?)?.toDouble();
    final transChg  = (t['transportationCharge'] as num?)?.toDouble();
    final total     = (t['totalBill']          as num?)?.toDouble();
    final distKm    = (t['distanceKm']         as num?)?.toDouble();
    final transRate = (t['transportRatePerKm'] as num?)?.toDouble();
    final isOwn     = t['vehicleMode'] == 'OWN_VEHICLE';
    final isDirect  = t['transportMode'] == 'DIRECT';

    Widget row(String label, String value, {bool strong = false, bool totalRow = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          decoration: BoxDecoration(
            color: totalRow
                ? Colors.green.shade50
                : (strong ? Colors.grey.shade100 : null),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(children: [
            Expanded(child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: totalRow ? Colors.green.shade800 : Colors.grey[600],
                    fontWeight: totalRow ? FontWeight.bold : FontWeight.normal))),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    color: totalRow ? Colors.green.shade800 : null,
                    fontWeight: (strong || totalRow) ? FontWeight.w600 : FontWeight.normal)),
          ]),
        );

    Widget sHead(String s) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text(s, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: Colors.grey[500], letterSpacing: 0.5)),
    );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loadedKg != null && emptyKg != null && netKg != null) ...[
            sHead('WEIGHT'),
            row('Loaded Weight',  '${numFmt.format(loadedKg)} kg'),
            row('Empty Weight',   '− ${numFmt.format(emptyKg)} kg'),
            row('Net Weight',     '= ${numFmt.format(netKg)} kg', strong: true),
          ],
          if (qty != null) ...[
            sHead('MATERIAL'),
            row('Billable Quantity', '${numFmt.format(qty)} $unit'),
            if (rate != null) row('Sale Rate', '${fmtCurr(rate)} / $unit'),
            if (matAmt != null) row('Material Amount', fmtCurr(matAmt), strong: true),
          ],
          sHead('TRANSPORT'),
          if (isOwn)
            row("Customer's Own Vehicle", fmtCurr(0))
          else if (isDirect)
            row('Direct Charge', transChg != null ? fmtCurr(transChg) : '—')
          else ...[
            if (distKm    != null) row('Distance',        '${numFmt.format(distKm)} km'),
            if (transRate != null) row('Rate / km',        fmtCurr(transRate)),
            if (transChg  != null) row('Transport Charge', fmtCurr(transChg), strong: true),
          ],
          if (total != null) ...[
            const Divider(height: 16),
            row('TOTAL BILL', fmtCurr(total), totalRow: true),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip    = widget.trip;
    final isOwn   = trip['vehicleMode'] == 'OWN_VEHICLE';
    final vehicle = isOwn
        ? 'Own Vehicle'
        : (trip['vehicleDisplayName'] ?? trip['vehiclePlateNumber'] ?? '—');
    final material    = trip['materialName'] ?? '—';
    final billableQty = (trip['billableQuantity'] as num?)?.toDouble()
        ?? (trip['quantityBrass'] as num?)?.toDouble();
    final unit      = trip['quantityUnit'] ?? 'Brass';
    final totalBill = (trip['totalBill'] as num?)?.toDouble();
    final party     = trip['partyDisplayName'] ?? trip['vendorName'] ?? '—';
    final isOneTime = trip['partyType'] == 'ONE_TIME';

    final badgeLabel = isOwn
        ? 'OWN'
        : vehicle.length > 4 ? vehicle.substring(vehicle.length - 4) : vehicle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle badge — tap anywhere on card to expand/collapse detail
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isOwn
                          ? Colors.blue.shade100
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(badgeLabel,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(material,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          if (billableQty != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text('${numFmt.format(billableQty)} $unit',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade800,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
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
                          Expanded(child: Text(party,
                              style: TextStyle(fontSize: 13, color: Colors.grey[800],
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          Expanded(child: Text(vehicle,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
                          if (totalBill != null && totalBill > 0)
                            Text(fmtCurr(totalBill),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade700)),
                        ]),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit')   widget.onEdit();
                    if (v == 'delete') widget.onDelete();
                    if (v == 'challan') _printChallan(context, trip);
                    if (v == 'convert' && widget.onConvert != null) widget.onConvert!();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'challan',
                        child: Row(children: [
                          Icon(Icons.print_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Print Challan'),
                        ])),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isOneTime)
                      const PopupMenuItem(
                          value: 'convert',
                          child: Row(children: [
                            Icon(Icons.person_add_outlined, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Convert to Regular Customer',
                                style: TextStyle(color: Colors.blue)),
                          ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            // Tap card body to reveal full calculation chain
            if (_expanded) _buildCalculationDetail(),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Customer',
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
      ),
    );
  }
}

// ── Vehicle Picker Dialog ─────────────────────────────────────────────────────

class _VehiclePickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles;
  final int? currentId;
  const _VehiclePickerDialog({required this.vehicles, this.currentId});

  @override
  State<_VehiclePickerDialog> createState() => _VehiclePickerDialogState();
}

class _VehiclePickerDialogState extends State<_VehiclePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.vehicles
        : widget.vehicles.where((v) {
            final plate = (v['plateNumber'] as String? ?? '').toLowerCase();
            final name  = (v['displayName']  as String? ?? '').toLowerCase();
            return plate.contains(_query) || name.contains(_query);
          }).toList();
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Vehicle',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search by plate or name…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (q) => setState(() => _query = q.toLowerCase().trim()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No vehicles found',
                          style: TextStyle(color: Colors.grey))))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final v = filtered[i];
                        final id = v['id'] as int?;
                        final isSelected = id == widget.currentId;
                        final label = '${v['displayName'] ?? v['plateNumber'] ?? '—'}';
                        final sub   = v['vehicleType'] as String? ?? '';
                        return ListTile(
                          dense: true,
                          title: Text(label,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: sub.isNotEmpty ? Text(sub) : null,
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
      ),
    );
  }
}

// ── Material Picker Dialog ────────────────────────────────────────────────────

class _MaterialPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  final int? currentId;
  const _MaterialPickerDialog({required this.materials, this.currentId});

  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.materials
        : widget.materials.where((m) {
            final name = (m['name'] as String? ?? '').toLowerCase();
            final code = (m['code'] as String? ?? '').toLowerCase();
            return name.contains(_query) || code.contains(_query);
          }).toList();
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Material',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or code…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (q) => setState(() => _query = q.toLowerCase().trim()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No materials found',
                          style: TextStyle(color: Colors.grey))))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final id = m['id'] as int?;
                        final isSelected = id == widget.currentId;
                        final name = m['name'] as String? ?? '—';
                        final code = m['code'] as String? ?? '';
                        final unit = m['unit'] as String? ?? '';
                        final rateT = m['defaultSaleRate'];
                        final rateB = m['defaultSaleRateBrass'];
                        final rateLine = [
                          if (rateT != null) 'TON ₹$rateT',
                          if (rateB != null) 'BRASS ₹$rateB',
                        ].join('  ·  ');
                        return ListTile(
                          dense: true,
                          title: Text(
                              code.isNotEmpty ? '$name  ($code)' : name,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              rateLine.isNotEmpty ? '$unit  ·  $rateLine' : unit),
                          trailing: isSelected
                              ? Icon(Icons.check, color: cs.primary, size: 20)
                              : null,
                          tileColor: isSelected
                              ? cs.primary.withValues(alpha: 0.06)
                              : null,
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Convert One-Time to Regular Customer ──────────────────────────────────────

class _ConvertCustomerDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onSaved;
  const _ConvertCustomerDialog({required this.trip, required this.onSaved});

  @override
  ConsumerState<_ConvertCustomerDialog> createState() => _ConvertCustomerDialogState();
}

class _ConvertCustomerDialogState extends ConsumerState<_ConvertCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name  = TextEditingController(
      text: widget.trip['oneTimeCustomerName']  as String? ?? '');
  late final _phone = TextEditingController(
      text: widget.trip['oneTimeCustomerPhone'] as String? ?? '');
  late final _addr  = TextEditingController(
      text: widget.trip['oneTimeCustomerAddr']  as String? ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _addr.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    try {
      // 1. Create a regular customer/party record
      final partyRes = await api.post('/api/parties', data: {
        'name':   _name.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'contact': _phone.text.trim(),
        if (_addr.text.trim().isNotEmpty)  'address': _addr.text.trim(),
        'status': 'ACTIVE',
      });
      final newVendorId = partyRes.data['id'];

      // 2. Update trip: switch to REGULAR party, preserve all billing fields
      final t = widget.trip;
      final body = <String, dynamic>{
        'tripDate':      t['tripDate'],
        'partyType':     'REGULAR',
        'vendorId':      newVendorId,
        'materialId':    t['materialId'],
        'quantityUnit':  t['quantityUnit'] ?? 'BRASS',
        'vehicleMode':   t['vehicleMode']   ?? 'COMPANY',
        'transportMode': t['transportMode'] ?? 'CALCULATE',
      };
      if (t['loadedWeightKg']     != null) body['loadedWeightKg']     = t['loadedWeightKg'];
      if (t['emptyWeightKg']      != null) body['emptyWeightKg']      = t['emptyWeightKg'];
      if (t['saleRate']           != null) body['saleRate']           = t['saleRate'];
      if (t['vehicleId']          != null) body['vehicleId']          = t['vehicleId'];
      if (t['distanceKm']         != null) body['distanceKm']         = t['distanceKm'];
      if (t['transportRatePerKm'] != null) body['transportRatePerKm'] = t['transportRatePerKm'];
      // Re-send stored charge for DIRECT mode
      if (t['transportMode'] == 'DIRECT' && t['transportationCharge'] != null) {
        body['transportationChargeDirect'] = t['transportationCharge'];
      }
      // Only send billableQuantity when weights are absent (backend recalculates from weights)
      if (t['loadedWeightKg'] == null || t['emptyWeightKg'] == null) {
        final qty = t['billableQuantity'] ?? t['quantityBrass'];
        if (qty != null) body['billableQuantity'] = qty;
      }
      for (final k in ['dspChallanNo', 'vendorChallanNo',
                        'loadingLocation', 'unloadingLocation', 'notes']) {
        if (t[k] != null) body[k] = t[k];
      }

      await api.put('/api/trips/${t['id']}', data: body);

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_name.text.trim()} added as a regular customer'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Convert to Regular Customer',
      maxWidth: 440,
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _convert,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save & Convert'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creates a new Customer entry and links this trip to them. '
              'Trip history and billing amounts are preserved.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Customer Name *'),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addr,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
          ],
        ),
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
  final _loadedKg       = TextEditingController();
  final _emptyKg        = TextEditingController();
  final _manualQty      = TextEditingController();
  final _saleRate       = TextEditingController();
  final _materialTotal  = TextEditingController(); // direct entry when qty or rate absent

  // Vehicle
  String _vehicleMode = 'COMPANY';
  int? _vehicleId;
  String _vehicleName = '';
  String? _vehicleError;
  final _distance              = TextEditingController();
  final _transportRate         = TextEditingController();
  final _transportChargeDirect = TextEditingController(); // direct entry when dist or rate absent

  // Additional
  bool _showAdditional = false;
  final _dspChallan   = TextEditingController();
  final _vdrChallan   = TextEditingController();
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

      // Pre-fill materialTotal when qty or rate was absent
      if (billableQty == null && qtyBrass == null || sr == null) {
        final matAmt = (e['materialAmount'] as num?)?.toDouble();
        if (matAmt != null && matAmt > 0) {
          _materialTotal.text = matAmt.toStringAsFixed(2);
        }
      }

      final dist = (e['distanceKm'] as num?)?.toDouble();
      final tr   = (e['transportRatePerKm'] as num?)?.toDouble();
      final tc   = (e['transportationCharge'] as num?)?.toDouble();
      if (dist != null) _distance.text = dist.toStringAsFixed(1);
      if (tr != null)   _transportRate.text = tr.toStringAsFixed(2);
      // Pre-fill transportChargeDirect when dist or rate absent
      if ((dist == null || tr == null) && tc != null && tc > 0) {
        _transportChargeDirect.text = tc.toStringAsFixed(2);
      }

      _vehicleName   = e['vehicleDisplayName'] ?? e['vehiclePlateNumber'] ?? '';
      _dspChallan.text   = e['dspChallanNo'] ?? '';
      _vdrChallan.text   = e['vendorChallanNo'] ?? '';
      _loadingLoc.text   = e['loadingLocation'] ?? '';
      _unloadingLoc.text = e['unloadingLocation'] ?? '';
      _notes.text        = e['notes'] ?? '';

      // Expand additional if any field has content
      _showAdditional = [_vdrChallan, _loadingLoc, _unloadingLoc, _notes]
          .any((c) => c.text.isNotEmpty);
    }

    for (final ctrl in [_loadedKg, _emptyKg, _manualQty, _saleRate, _materialTotal,
                        _distance, _transportRate, _transportChargeDirect]) {
      ctrl.addListener(_recalculate);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    for (final ctrl in [
      _oneTimeName, _oneTimePhone, _oneTimeAddr,
      _loadedKg, _emptyKg, _manualQty, _saleRate, _materialTotal,
      _distance, _transportRate, _transportChargeDirect,
      _dspChallan, _vdrChallan, _loadingLoc, _unloadingLoc, _notes,
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
    // Material: auto when qty+rate both available, else direct entry
    final matAmt = (qty != null && rate != null)
        ? qty * rate
        : double.tryParse(_materialTotal.text.trim());

    double? transport;
    if (_vehicleMode == 'OWN_VEHICLE') {
      transport = 0.0;
    } else {
      final dist = double.tryParse(_distance.text.trim());
      final tr   = double.tryParse(_transportRate.text.trim());
      if (dist != null && tr != null && qty != null) {
        // Auto: qty × km × rate
        transport = dist * qty * tr;
      } else {
        // Direct entry when dist or rate absent
        transport = double.tryParse(_transportChargeDirect.text.trim());
      }
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
      _materialId    = id;
      _material      = mat;
      _materialError = null;
      if (mat != null) {
        final u = mat['unit'] as String?;
        if (u == 'TON' || u == 'BRASS') _quantityUnit = u!;
        // Load sale rate: try the material's default unit first, fall back to the other unit
        double? defRate = _rateForUnit(_quantityUnit, mat);
        if (defRate == null) {
          final other = _quantityUnit == 'TON' ? 'BRASS' : 'TON';
          defRate = _rateForUnit(other, mat);
          if (defRate != null) _quantityUnit = other; // switch unit to match the available rate
        }
        if (defRate != null) _saleRate.text = defRate.toStringAsFixed(2);
        // Always prefill transport rate from material default
        final defTrans = (mat['defaultTransportRate'] as num?)?.toDouble();
        if (defTrans != null) _transportRate.text = defTrans.toStringAsFixed(2);
      }
    });
    _recalculate();
  }

  double? _rateForUnit(String unit, Map<String, dynamic> mat) {
    if (unit == 'TON') return (mat['defaultSaleRate'] as num?)?.toDouble();
    return (mat['defaultSaleRateBrass'] as num?)?.toDouble();
  }

  void _onUnitChanged(String newUnit) {
    setState(() => _quantityUnit = newUnit);
    if (_material != null) {
      final defRate = _rateForUnit(newUnit, _material!);
      if (defRate != null) _saleRate.text = defRate.toStringAsFixed(2);
    }
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

  String? _materialError;

  Future<void> _save() async {
    // Manual validation for dialog pickers (not in Form tree)
    setState(() {
      _vendorError   = (_partyType == 'REGULAR' && _vendorId == null) ? 'Select a customer' : null;
      _vehicleError  = (_vehicleMode == 'COMPANY' && _vehicleId == null) ? 'Select a vehicle' : null;
      _materialError = _materialId == null ? 'Select a material' : null;
    });

    if (_vendorError != null || _vehicleError != null || _materialError != null) return;
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

    // Material direct total — sent when qty or rate is absent
    if (_billableQty == null || sr == null) {
      final md = double.tryParse(_materialTotal.text.trim());
      if (md != null) b['materialAmountDirect'] = md;
    }

    b['vehicleMode'] = _vehicleMode;
    if (_vehicleMode == 'COMPANY') {
      b['vehicleId'] = _vehicleId;
      final dist = double.tryParse(_distance.text.trim());
      final tr   = double.tryParse(_transportRate.text.trim());
      if (dist != null && tr != null) {
        // Auto-calculate mode: send dist and rate, backend computes qty×km×rate
        b['transportMode']       = 'CALCULATE';
        b['distanceKm']          = dist;
        b['transportRatePerKm']  = tr;
      } else {
        // Direct mode: send the entered total
        b['transportMode'] = 'DIRECT';
        final tc = double.tryParse(_transportChargeDirect.text.trim());
        if (tc != null) b['transportationChargeDirect'] = tc;
      }
    } else {
      b['transportMode'] = 'CALCULATE';
    }

    void opt(String key, String val) {
      final t = val.trim();
      if (t.isNotEmpty) b[key] = t;
    }
    opt('dspChallanNo',      _dspChallan.text);
    opt('vendorChallanNo',   _vdrChallan.text);
    opt('loadingLocation',   _loadingLoc.text);
    opt('unloadingLocation', _unloadingLoc.text);
    opt('notes',             _notes.text);

    final api    = ref.read(apiClientProvider);
    final siteId = ref.read(selectedSiteIdProvider);

    // Creating a trip requires a specific site to be selected
    if (widget.existing == null && siteId == null) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a specific site before creating a trip.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    try {
      if (widget.existing == null) {
        await api.post('/api/trips', data: b, params: {'siteId': siteId});
      } else {
        await api.put('/api/trips/${widget.existing!['id']}', data: b);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data is Map
                ? (e.response!.data['error'] ?? e.response!.data.toString())
                : e.response?.data?.toString() ?? e.message ?? 'Request failed')
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
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

  // Inline formula row: [slot1] × [slot2?] × [slot3] = [totalSlot]
  // totalSlot is either _readonlyBox (auto-computed) or a TextFormField (direct entry)
  Widget _formulaRow({
    required Widget slot1,
    Widget? slot2,
    required Widget slot3,
    required Widget totalSlot,
  }) {
    const op = Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text('×', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w300)),
    );
    const eq = Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text('=', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w300)),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: slot1),
        op,
        if (slot2 != null) ...[Expanded(child: slot2), op],
        Expanded(child: slot3),
        eq,
        Expanded(child: totalSlot),
      ],
    );
  }

  // Read-only display box that matches the visual weight of a TextFormField
  Widget _readonlyBox(String value, String label, {bool isTotal = false}) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isTotal ? Colors.green.shade50 : Colors.grey.shade100,
      border: const OutlineInputBorder(),
      enabledBorder: isTotal
          ? OutlineInputBorder(borderSide: BorderSide(color: Colors.green.shade200))
          : const OutlineInputBorder(),
    ),
    child: Text(value,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isTotal ? Colors.green.shade800 : Colors.grey.shade800)),
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
          labelText: 'Customer *',
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

  Widget _materialPickerField(List<Map<String, dynamic>> materials) {
    final selected = _materialId != null
        ? materials.where((m) => m['id'] == _materialId).cast<Map<String, dynamic>?>().firstOrNull
        : null;
    final label = selected != null
        ? (selected['code'] as String? ?? '').isNotEmpty
            ? '${selected['name']}  (${selected['code']})'
            : selected['name'] as String? ?? ''
        : '';
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => _MaterialPickerDialog(materials: materials, currentId: _materialId),
        );
        if (result != null) _onMaterialChanged(result['id'] as int?, materials);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Material *',
          errorText: _materialError,
          suffixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
        isEmpty: label.isEmpty,
        child: label.isNotEmpty
            ? Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _vehiclePickerField(List<Map<String, dynamic>> vehicles) {
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => _VehiclePickerDialog(vehicles: vehicles, currentId: _vehicleId),
        );
        if (result != null) {
          setState(() {
            _vehicleId   = result['id'] as int?;
            _vehicleName = '${result['displayName'] ?? result['plateNumber'] ?? ''}';
            _vehicleError = null;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Vehicle *',
          errorText: _vehicleError,
          suffixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
        isEmpty: _vehicleName.isEmpty,
        child: _vehicleName.isNotEmpty
            ? Text(_vehicleName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))
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
          else if (_transportCharge != null) ...[
            _bRow(
                (_billableQty != null &&
                        _distance.text.isNotEmpty &&
                        _transportRate.text.isNotEmpty)
                    ? '${numFmt.format(_billableQty!)} $_quantityUnit'
                      ' × ${_distance.text} km'
                      ' × ₹${_transportRate.text}/km/$_quantityUnit'
                    : 'Transportation',
                fmtCurr(transAmt)),
          ],
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

            // ── 2. Customer ─────────────────────────────────────────────────
            _sectionHead('CUSTOMER'),
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
              data: _materialPickerField,
            ),
            const SizedBox(height: 14),
            // Unit toggle — also auto-switches sale rate to the matching material default
            Row(children: [
              Text('Unit:', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(width: 12),
              _pill('BRASS', _quantityUnit == 'BRASS', () => _onUnitChanged('BRASS')),
              const SizedBox(width: 8),
              _pill('TON',   _quantityUnit == 'TON',   () => _onUnitChanged('TON')),
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

            const SizedBox(height: 12),
            // Quantity × Sale Rate = Amount (auto when both filled, editable otherwise)
            _formulaRow(
              slot1: _qtyFromWeights && _billableQty != null
                  ? _readonlyBox(
                      '${numFmt.format(_billableQty!)} $_quantityUnit',
                      'Qty ($_quantityUnit)')
                  : TextFormField(
                      controller: _manualQty,
                      decoration: InputDecoration(
                        labelText: 'Quantity *',
                        suffixText: _quantityUnit,
                        helperText: _netWeightKg == null ? 'Or fill weights above' : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter quantity';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        if (double.parse(v.trim()) < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
              slot3: TextFormField(
                controller: _saleRate,
                decoration: InputDecoration(
                  labelText: 'Rate',
                  prefixText: '₹ ',
                  suffixText: '/$_quantityUnit',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty &&
                      double.tryParse(v.trim()) == null) return 'Invalid';
                  return null;
                },
              ),
              // Total: read-only if qty×rate computable, editable otherwise
              totalSlot: (_billableQty != null &&
                      double.tryParse(_saleRate.text.trim()) != null)
                  ? _readonlyBox(
                      _materialAmount != null ? fmtCurr(_materialAmount!) : '—',
                      'Amount', isTotal: true)
                  : TextFormField(
                      controller: _materialTotal,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty &&
                            double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
            ),

            // ── 4. Vehicle & Transportation ─────────────────────────────────
            _sectionHead('VEHICLE & TRANSPORTATION'),
            // Toggle: Customer's Own Vehicle (default OFF = company vehicle)
            Row(
              children: [
                Switch(
                  value: _vehicleMode == 'OWN_VEHICLE',
                  onChanged: (on) {
                    setState(() {
                      _vehicleMode = on ? 'OWN_VEHICLE' : 'COMPANY';
                      _vehicleError = null;
                    });
                    _recalculate();
                  },
                ),
                const SizedBox(width: 4),
                Text("Customer's Own Vehicle",
                    style: TextStyle(
                        fontSize: 14,
                        color: _vehicleMode == 'OWN_VEHICLE'
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 8),
            if (_vehicleMode == 'COMPANY') ...[
              vehs.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading vehicles: $e'),
                data: _vehiclePickerField,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 4),
              // Quantity × KM × Rate = Total (auto when dist+rate filled, editable otherwise)
              _formulaRow(
                slot1: _readonlyBox(
                  _billableQty != null
                      ? '${numFmt.format(_billableQty!)} $_quantityUnit'
                      : '—',
                  'Qty',
                ),
                slot2: TextFormField(
                  controller: _distance,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    suffixText: 'km',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty &&
                        double.tryParse(v.trim()) == null) return 'Invalid';
                    return null;
                  },
                ),
                slot3: TextFormField(
                  controller: _transportRate,
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty &&
                        double.tryParse(v.trim()) == null) return 'Invalid';
                    return null;
                  },
                ),
                // Total: read-only if dist+rate both filled, editable otherwise
                totalSlot: (double.tryParse(_distance.text.trim()) != null &&
                        double.tryParse(_transportRate.text.trim()) != null)
                    ? _readonlyBox(
                        _transportCharge != null ? fmtCurr(_transportCharge!) : '—',
                        'Transport', isTotal: true)
                    : TextFormField(
                        controller: _transportChargeDirect,
                        decoration: const InputDecoration(
                          labelText: 'Transport',
                          prefixText: '₹ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty &&
                              double.tryParse(v.trim()) == null) return 'Invalid';
                          return null;
                        },
                      ),
              ),
            ],

            // ── 5. Billing Summary ──────────────────────────────────────────
            _billingSummary(),

            // ── 6. Challan Number (main form) ───────────────────────────────
            const SizedBox(height: 16),
            TextFormField(
              controller: _dspChallan,
              decoration: const InputDecoration(labelText: 'Challan Number'),
            ),

            // ── 7. Additional Details (collapsible) ─────────────────────────
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                    _showAdditional
                        ? 'Additional Details'
                        : '+ Additional Details (Vendor Challan, Notes)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                initiallyExpanded: _showAdditional,
                onExpansionChanged: (v) => setState(() => _showAdditional = v),
                children: [
                  TextFormField(
                      controller: _vdrChallan,
                      decoration: const InputDecoration(labelText: 'Vendor Challan Number')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextFormField(
                        controller: _loadingLoc,
                        decoration: const InputDecoration(labelText: 'Loading Location'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                        controller: _unloadingLoc,
                        decoration: const InputDecoration(labelText: 'Unloading Location'))),
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
