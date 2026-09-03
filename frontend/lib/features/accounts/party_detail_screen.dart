import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';
import '../vendor_payments/vendor_payments_screen.dart' show showRecordPaymentDialog;

// ── Date range presets ────────────────────────────────────────────────────────

enum _Preset { thisMonth, lastMonth, thisYear, prevYear, custom }

class _Range { final DateTime from, to; const _Range(this.from, this.to); }

_Range _presetRange(_Preset p) {
  final now = DateTime.now();
  switch (p) {
    case _Preset.thisMonth:
      return _Range(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
    case _Preset.lastMonth:
      final m = now.month == 1 ? 12 : now.month - 1;
      final y = now.month == 1 ? now.year - 1 : now.year;
      return _Range(DateTime(y, m, 1), DateTime(y, m + 1, 0));
    case _Preset.thisYear:
      return _Range(DateTime(now.year, 4, 1), DateTime(now.year + 1, 3, 31));
    case _Preset.prevYear:
      return _Range(DateTime(now.year - 1, 4, 1), DateTime(now.year, 3, 31));
    case _Preset.custom:
      return _Range(now, now);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _statementProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, key) async {
  // key: "vendorId|from|to"
  final parts = key.split('|');
  final res = await ref.read(apiClientProvider).get(
    '/api/parties/${parts[0]}/statement',
    params: {'from': parts[1], 'to': parts[2]},
  );
  return Map<String, dynamic>.from(res.data as Map);
});

final _dateFmtKey  = DateFormat('yyyy-MM-dd');
final _dateFmtLong = DateFormat('d MMM yyyy');
final _dateFmtShort = DateFormat('d MMM yy');
final _numFmt = NumberFormat('#,##,##0.##');

// ── Screen ────────────────────────────────────────────────────────────────────

class PartyDetailScreen extends ConsumerStatefulWidget {
  final int vendorId;
  final String vendorName;
  const PartyDetailScreen({super.key, required this.vendorId, required this.vendorName});

  @override
  ConsumerState<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends ConsumerState<PartyDetailScreen> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from;
  late DateTime _to;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    final r = _presetRange(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  String get _key => '${widget.vendorId}|${_dateFmtKey.format(_from)}|${_dateFmtKey.format(_to)}';

  void _applyPreset(_Preset p) {
    if (p == _Preset.custom) return;
    final r = _presetRange(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
        context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
        context: context, initialDate: _to,
        firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  Future<void> _printStatement(Map<String, dynamic> data) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final bytes = await _buildPdf(data);
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: '${widget.vendorName.replaceAll(' ', '_')}_Statement.pdf',
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final font     = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final vendorName = data['vendorName'] as String? ?? widget.vendorName;
    final contact    = data['vendorContact'] as String? ?? '';
    final from       = data['from'] as String? ?? _dateFmtKey.format(_from);
    final to         = data['to']   as String? ?? _dateFmtKey.format(_to);
    final opening    = (data['openingBalance']  as num?)?.toDouble() ?? 0;
    final closing    = (data['closingBalance']  as num?)?.toDouble() ?? 0;
    final billed     = (data['totalBilled']     as num?)?.toDouble() ?? 0;
    final received   = (data['totalReceived']   as num?)?.toDouble() ?? 0;
    final entries    = List<Map<String, dynamic>>.from(
        (data['entries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    final isOwed    = closing > 0.5;
    final isAdvance = closing < -0.5;
    final balLabel  = isOwed ? 'Outstanding: ₹${_numFmt.format(closing)}'
        : isAdvance ? 'Advance: ₹${_numFmt.format(closing.abs())}'
        : 'Settled Up';
    final balColor  = isOwed ? PdfColors.orange900 : isAdvance ? PdfColors.blue700 : PdfColors.green800;

    String rs(double v) => '₹${_numFmt.format(v)}';
    String balStr(double v) => v > 0.5 ? rs(v) : v < -0.5 ? 'Adv ${rs(v.abs())}' : '₹0';

    pw.TextStyle bold({double size = 8.5}) => pw.TextStyle(font: fontBold, fontSize: size);
    pw.TextStyle reg({double size = 8.5, PdfColor? color}) =>
        pw.TextStyle(font: font, fontSize: size, color: color);

    pw.Widget cell(String t, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(t, style: isBold ? bold() : reg(color: color), textAlign: align));

    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('ACCOUNT STATEMENT', style: bold(size: 14)),
        pw.SizedBox(height: 4),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(vendorName, style: bold(size: 11)),
            if (contact.isNotEmpty) pw.Text(contact, style: reg(size: 9, color: PdfColors.grey600)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Period: ${_dateFmtLong.format(DateTime.parse(from))} — ${_dateFmtLong.format(DateTime.parse(to))}',
                style: reg(size: 8.5, color: PdfColors.grey700)),
            pw.SizedBox(height: 3),
            pw.Text(balLabel, style: bold(size: 10).copyWith(color: balColor)),
          ]),
        ]),
        pw.Divider(thickness: 0.8),
      ]),
      build: (_) => [
        // Summary row
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Opening Balance: ${balStr(opening)}', style: reg(size: 8)),
            pw.Text('Total Billed: ${rs(billed)}', style: reg(size: 8, color: PdfColors.orange900)),
            pw.Text('Total Received: ${rs(received)}', style: reg(size: 8, color: PdfColors.green800)),
            pw.Text('Closing: ${balStr(closing)}', style: bold(size: 8).copyWith(color: balColor)),
          ]),
        ),
        pw.SizedBox(height: 8),

        // Transactions table (ASC order for print — chronological)
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(72),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(72),
            3: pw.FixedColumnWidth(72),
            4: pw.FixedColumnWidth(78),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
              children: [
                for (final h in ['Date', 'Description', 'Billed ₹', 'Received ₹', 'Balance ₹'])
                  cell(h, isBold: true),
              ],
            ),
            // Opening balance row if non-zero
            if (opening.abs() > 0.5)
              pw.TableRow(children: [
                cell('', isBold: false),
                cell('Opening Balance', isBold: true),
                cell('', isBold: false),
                cell('', isBold: false),
                cell(balStr(opening), isBold: true),
              ]),
            // Entries
            ...entries.map((e) {
              final type    = e['type'] as String;
              final isBill  = type == 'BILLED';
              final desc    = e['description'] as String? ?? '—';
              final amt     = (e['amount'] as num?)?.toDouble() ?? 0;
              final bal     = (e['runningBalance'] as num?)?.toDouble() ?? 0;
              final dateStr = _dateFmtLong.format(DateTime.parse(e['date'] as String));
              final gstRate = (e['gstRate'] as num?)?.toDouble() ?? 0;

              final rows = <pw.TableRow>[];
              rows.add(pw.TableRow(children: [
                cell(dateStr),
                cell(desc),
                cell(isBill ? rs(amt) : '', align: pw.TextAlign.right,
                    color: isBill ? PdfColors.orange900 : null),
                cell(!isBill ? rs(amt) : '', align: pw.TextAlign.right,
                    color: !isBill ? PdfColors.green800 : null),
                cell(balStr(bal), isBold: true),
              ]));

              // GST sub-rows for taxable trip entries
              if (isBill && gstRate > 0.01) {
                // For GST trips, the taxable base is the trip amount (transport excluded per prior decision)
                final halfRate = gstRate / 2;
                final sgst = amt * halfRate / 100;
                final cgst = amt * halfRate / 100;
                rows.add(pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  children: [
                    cell(''),
                    pw.Padding(
                        padding: const pw.EdgeInsets.fromLTRB(12, 1, 5, 1),
                        child: pw.Text('SGST @$halfRate% = ₹${_numFmt.format(sgst)}  |  CGST @$halfRate% = ₹${_numFmt.format(cgst)}',
                            style: reg(size: 7.5, color: PdfColors.grey600))),
                    cell(''), cell(''), cell(''),
                  ],
                ));
              }
              return rows;
            }).expand((r) => r),
          ],
        ),
      ],
    ));
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final statement = ref.watch(_statementProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendorName),
        actions: [
          if (statement.valueOrNull != null)
            statement.maybeWhen(
              data: (d) {
                final contact = d['vendorContact'] as String? ?? '';
                return contact.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.phone_outlined), tooltip: contact, onPressed: () {})
                    : const SizedBox.shrink();
              },
              orElse: () => const SizedBox.shrink(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_statementProvider(_key)),
          ),
        ],
      ),
      body: Column(children: [
        _DateFilterBar(preset: _preset, from: _from, to: _to,
            onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo),
        Expanded(
          child: statement.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _StatementBody(
              data: data,
              printing: _printing,
              onPrint: () => _printStatement(data),
              onRecordPayment: () => showRecordPaymentDialog(
                context, ref,
                initialVendorId:   widget.vendorId,
                initialVendorName: widget.vendorName,
                onSaved: () => ref.invalidate(_statementProvider(_key)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Date filter bar ───────────────────────────────────────────────────────────

class _DateFilterBar extends StatelessWidget {
  final _Preset preset;
  final DateTime from, to;
  final ValueChanged<_Preset> onPreset;
  final VoidCallback onPickFrom, onPickTo;

  const _DateFilterBar({
    required this.preset, required this.from, required this.to,
    required this.onPreset, required this.onPickFrom, required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (lbl, p) in [
              ('This Month', _Preset.thisMonth), ('Last Month', _Preset.lastMonth),
              ('This FY', _Preset.thisYear), ('Prev FY', _Preset.prevYear),
            ])
              Padding(padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(lbl, style: const TextStyle(fontSize: 11)),
                    selected: preset == p,
                    onSelected: (_) => onPreset(p),
                    visualDensity: VisualDensity.compact,
                  )),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          _datePill(_dateFmtShort.format(from), onPickFrom, cs),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('→', style: TextStyle(fontSize: 12))),
          _datePill(_dateFmtShort.format(to), onPickTo, cs),
        ]),
      ]),
    );
  }

  Widget _datePill(String label, VoidCallback onTap, ColorScheme cs) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    ),
  );
}

// ── Statement body ────────────────────────────────────────────────────────────

class _StatementBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool printing;
  final VoidCallback onPrint;
  final VoidCallback onRecordPayment;

  const _StatementBody({
    required this.data, required this.printing,
    required this.onPrint, required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final closing  = (data['closingBalance'] as num?)?.toDouble() ?? 0;
    final rawEntries = List<Map<String, dynamic>>.from(
        (data['entries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    final isOwed    = closing > 0.5;
    final isAdvance = closing < -0.5;
    final balLabel  = isOwed    ? 'Owes ${fmtCurr(closing)}'
        : isAdvance ? 'Advance ${fmtCurr(closing.abs())}'
        : 'Settled Up';
    final balColor  = isOwed    ? Colors.orange.shade800
        : isAdvance ? Colors.blue.shade700
        : Colors.green.shade700;
    final balBg     = isOwed    ? Colors.orange.shade50
        : isAdvance ? Colors.blue.shade50
        : Colors.green.shade50;

    // Display newest-first. Balance-per-row is already computed correctly
    // (ASC/oldest-first) by the backend and stored on each entry — reversing
    // the display order does NOT affect those stored values.
    final displayEntries = rawEntries.reversed.toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: balBg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: balColor.withValues(alpha: 0.3)),
            ),
            child: Text(balLabel,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: balColor),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: printing ? null : onPrint,
              icon: printing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print Statement'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: onRecordPayment,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Record Payment'),
            )),
          ]),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: rawEntries.isEmpty
            ? AppEmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No transactions in this period',
                hint: 'Try changing the date range',
              )
            : _EntryList(entries: displayEntries),
      ),
    ]);
  }
}

// ── Entry list with date grouping (newest first) ──────────────────────────────

class _EntryList extends StatelessWidget {
  final List<Map<String, dynamic>> entries; // already reversed (newest first)

  const _EntryList({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Group by date — entries are already in DESC order, so groups are too
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final key = e['date'] as String;
      grouped.putIfAbsent(key, () => []).add(e);
    }
    // Preserve DESC order of date keys (they appear in the order first encountered)
    final dates = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date = dates[i];
        final dayEntries = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _dateFmtLong.format(DateTime.parse(date)),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600, letterSpacing: 0.3),
              ),
            ),
            const Divider(height: 1),
            ...dayEntries.map((e) => _EntryRow(entry: e)),
          ],
        );
      },
    );
  }
}

// ── Single entry row ──────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type    = entry['type'] as String;
    final isBill  = type == 'BILLED';
    final desc    = entry['description'] as String? ?? '—';
    final amount  = (entry['amount']         as num?)?.toDouble() ?? 0;
    final balance = (entry['runningBalance'] as num?)?.toDouble() ?? 0;

    final amtColor   = isBill ? Colors.orange.shade800 : Colors.green.shade700;
    final typeLabel  = isBill ? 'Billed' : 'Received';

    final balIsOwed = balance > 0.5;
    final balIsAdv  = balance < -0.5;
    final balText   = balIsOwed ? 'Bal. ${fmtCurr(balance)}'
        : balIsAdv  ? 'Adv. ${fmtCurr(balance.abs())}'
        : 'Settled';
    final balColor  = balIsOwed ? Colors.orange.shade700
        : balIsAdv  ? Colors.blue.shade700
        : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(balText, style: TextStyle(fontSize: 11, color: balColor)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(typeLabel, style: TextStyle(fontSize: 10, color: amtColor)),
          const SizedBox(height: 2),
          Text(fmtCurr(amount),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: amtColor)),
        ]),
      ]),
    );
  }
}
