import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';
import '../vendor_payments/vendor_payments_screen.dart' show showRecordPaymentDialog;

// ── Date range helpers ────────────────────────────────────────────────────────

enum DateRangePreset { thisMonth, lastMonth, thisYear, prevYear, custom }

class _DateRange {
  final DateTime from;
  final DateTime to;
  const _DateRange(this.from, this.to);
}

_DateRange _presetRange(DateRangePreset p) {
  final now = DateTime.now();
  final fyStart = now.month >= 4
      ? DateTime(now.year, 4, 1)
      : DateTime(now.year - 1, 4, 1);
  switch (p) {
    case DateRangePreset.thisMonth:
      return _DateRange(DateTime(now.year, now.month, 1), now);
    case DateRangePreset.lastMonth:
      final first = DateTime(now.year, now.month - 1, 1);
      final last  = DateTime(now.year, now.month, 0);
      return _DateRange(first, last);
    case DateRangePreset.thisYear:
      return _DateRange(fyStart, now);
    case DateRangePreset.prevYear:
      final prevFyStart = DateTime(fyStart.year - 1, 4, 1);
      final prevFyEnd   = DateTime(fyStart.year, 3, 31);
      return _DateRange(prevFyStart, prevFyEnd);
    case DateRangePreset.custom:
      return _DateRange(DateTime(now.year, now.month, 1), now);
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

class _LedgerParams {
  final int vendorId;
  final String from;
  final String to;
  const _LedgerParams(this.vendorId, this.from, this.to);

  @override
  bool operator ==(Object other) =>
      other is _LedgerParams &&
      other.vendorId == vendorId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(vendorId, from, to);
}

final _ledgerProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, _LedgerParams>(
        (ref, p) async {
  final res = await ref
      .read(apiClientProvider)
      .get('/api/ledger/party/${p.vendorId}', params: {'from': p.from, 'to': p.to});
  return Map<String, dynamic>.from(res.data);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class LedgerScreen extends ConsumerStatefulWidget {
  /// When provided (from Accounts > Parties tap), the picker is pre-selected and the ledger
  /// loads immediately without the user having to pick a party.
  final int? initialVendorId;
  const LedgerScreen({super.key, this.initialVendorId});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  int? _vendorId;
  String? _vendorName;
  DateRangePreset _preset = DateRangePreset.thisMonth;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final r = _presetRange(DateRangePreset.thisMonth);
    _from = r.from;
    _to   = r.to;
    if (widget.initialVendorId != null) {
      _vendorId = widget.initialVendorId;
    }
  }

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_from);
  String get _toStr   => DateFormat('yyyy-MM-dd').format(_to);

  void _applyPreset(DateRangePreset p) {
    final r = _presetRange(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
        context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = DateRangePreset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
        context: context, initialDate: _to,
        firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = DateRangePreset.custom; });
  }

  void _recordPayment() {
    showRecordPaymentDialog(
      context, ref,
      initialVendorId:   _vendorId,
      initialVendorName: _vendorName,
      onSaved: () {
        // Refresh ledger data after payment saved
        ref.invalidate(_ledgerProvider(_LedgerParams(_vendorId!, _fromStr, _toStr)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(_vendorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Ledger'),
        actions: [
          if (_vendorId != null)
            TextButton.icon(
              onPressed: _recordPayment,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Record Payment'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter bar ──────────────────────────────────────────────────
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                vendors.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (list) {
                    final active = list.where((v) => v['status'] == 'ACTIVE').toList();
                    // Resolve name for pre-selected party (from Accounts > Parties tap)
                    if (_vendorId != null && _vendorName == null) {
                      final match = active.where((e) => e['id'] == _vendorId).toList();
                      if (match.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _vendorName = match.first['name'] as String);
                        });
                      }
                    }
                    return SearchablePicker(
                      items: active,
                      itemLabel: (v) => v['name'] as String,
                      fieldLabel: 'Select Party',
                      value: _vendorId,
                      onChanged: (v) {
                        setState(() {
                          _vendorId = v;
                          if (v != null) {
                            _vendorName = active.firstWhere((e) => e['id'] == v)['name'] as String;
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ...[
                      ('This Month',  DateRangePreset.thisMonth),
                      ('Last Month',  DateRangePreset.lastMonth),
                      ('This FY',     DateRangePreset.thisYear),
                      ('Prev FY',     DateRangePreset.prevYear),
                    ].map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t.$1, style: const TextStyle(fontSize: 12)),
                            selected: _preset == t.$2,
                            onSelected: (_) => _applyPreset(t.$2),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                    const Spacer(),
                    _DateChip(label: DateFormat('d MMM yy').format(_from), onTap: _pickFrom),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('→', style: TextStyle(color: Colors.grey)),
                    ),
                    _DateChip(label: DateFormat('d MMM yy').format(_to), onTap: _pickTo),
                  ],
                ),
              ],
            ),
          ),

          // ── Ledger content ───────────────────────────────────────────────
          Expanded(
            child: _vendorId == null
                ? const AppEmptyState(
                    icon: Icons.account_balance_outlined,
                    message: 'Select a party to view their ledger',
                    hint: 'Choose party and date range above',
                  )
                : _LedgerContent(
                    params: _LedgerParams(_vendorId!, _fromStr, _toStr),
                    vendorName: _vendorName ?? '',
                    from: _from,
                    to: _to,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}

// ── Ledger content ────────────────────────────────────────────────────────────

class _LedgerContent extends ConsumerWidget {
  final _LedgerParams params;
  final String vendorName;
  final DateTime from;
  final DateTime to;
  const _LedgerContent({required this.params, required this.vendorName, required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_ledgerProvider(params));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (d) => _LedgerView(data: d, vendorName: vendorName, from: from, to: to),
    );
  }
}

// ── Main ledger view ──────────────────────────────────────────────────────────

class _LedgerView extends StatelessWidget {
  final Map<String, dynamic> data;
  final String vendorName;
  final DateTime from;
  final DateTime to;

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _longFmt = DateFormat('dd.MM.yyyy');

  const _LedgerView({required this.data, required this.vendorName, required this.from, required this.to});

  List<Map<String, dynamic>> get _entries =>
      List<Map<String, dynamic>>.from(data['entries'] as List? ?? []);

  double get _openingBal => (data['openingBalance'] as num?)?.toDouble() ?? 0;
  double get _totalDebit  => (data['totalDebit']  as num?)?.toDouble() ?? 0;
  double get _totalCredit => (data['totalCredit'] as num?)?.toDouble() ?? 0;
  double get _closingBal  => (data['closingBalance'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Vendor + export bar ─────────────────────────────────────────
        Container(
          color: cs.primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Ledger Account  ·  '
                        '${_longFmt.format(from)} to ${_longFmt.format(to)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _print(context),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _exportPdf(context),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _exportExcel(context),
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Excel', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // ── Balance summary row ─────────────────────────────────────────
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              _BalTile('Opening Balance', _openingBal, Colors.grey.shade700),
              _vDiv(),
              _BalTile('Total Invoiced', _totalDebit, Colors.red.shade700),
              _vDiv(),
              _BalTile('Total Paid', _totalCredit, Colors.green.shade700),
              _vDiv(),
              _BalTile(
                  _closingBal < -0.005 ? 'Advance' : 'Outstanding',
                  _closingBal.abs(),
                  _closingBal < -0.005 ? Colors.blue.shade700
                      : _closingBal > 0.005 ? Colors.orange.shade800
                      : Colors.green.shade700,
                  bold: true),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Ledger table ────────────────────────────────────────────────
        entries.isEmpty
            ? const Expanded(
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No transactions in this period',
                  hint: 'Try a wider date range or check if invoices/payments exist',
                ),
              )
            : Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 860,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        child: _buildTable(context, entries),
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _vDiv() => Container(width: 1, height: 34, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12));

  Widget _buildTable(BuildContext context, List<Map<String, dynamic>> entries) {
    final cs = Theme.of(context).colorScheme;

    const colWidths = <int, TableColumnWidth>{
      0: FixedColumnWidth(100), // Date
      1: FlexColumnWidth(2.6),  // Particulars
      2: FixedColumnWidth(80),  // Voucher Type
      3: FixedColumnWidth(130), // Debit
      4: FixedColumnWidth(130), // Credit
      5: FixedColumnWidth(140), // Balance
    };

    final headerDecor = BoxDecoration(color: cs.primary.withValues(alpha: 0.10));
    final altDecor    = BoxDecoration(color: Colors.grey.shade50);
    final subDecor    = BoxDecoration(color: const Color(0xFFF8F8F8));

    List<TableRow> rows = [];

    // Header row
    rows.add(TableRow(
      decoration: headerDecor,
      children: const [
        _TH('Date'),
        _TH('Particulars'),
        _TH('Voucher Type'),
        _TH('Debit (₹)', right: true),
        _TH('Credit (₹)', right: true),
        _TH('Balance (₹)', right: true),
      ],
    ));

    // Opening balance row
    if (_openingBal != 0) {
      rows.add(TableRow(
        decoration: BoxDecoration(color: Colors.amber.shade50),
        children: [
          const _TD('—', italic: true),
          const _TD('Balance brought forward', italic: true),
          const _TD('Opening', italic: true),
          const _TD('', right: true),
          const _TD('', right: true),
          _TD(
              _openingBal < -0.005 ? 'Adv ${_fmtAmt(_openingBal.abs())}' : _fmtAmt(_openingBal),
              right: true, italic: true,
              color: _openingBal < -0.005 ? Colors.blue.shade700
                  : _openingBal >= 0 ? Colors.orange.shade800
                  : Colors.green.shade700),
        ],
      ));
    }

    bool alt = false;
    for (final e in entries) {
      final isInvoice = e['voucherType'] == 'Sales';
      final isPending = e['gstStatus'] == 'PENDING';
      final debit    = (e['debit']          as num?)?.toDouble();
      final credit   = (e['credit']         as num?)?.toDouble();
      final balance  = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final date     = DateTime.parse(e['date'] as String);
      final details  = e['details'] as List? ?? [];
      final rowDecor = isPending
          ? BoxDecoration(color: Colors.amber.shade50)
          : alt ? altDecor : const BoxDecoration(color: Colors.white);
      alt = !alt;

      // Main transaction row
      rows.add(TableRow(
        decoration: rowDecor,
        children: [
          _TD(_dateFmt.format(date)),
          // Particulars + optional amber "GST Pending" chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(e['particulars'] as String? ?? '—',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isPending)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Text('GST: Pending',
                        style: TextStyle(fontSize: 10, color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          _TD(e['voucherType'] as String? ?? '—',
              color: isInvoice ? Colors.red.shade700 : Colors.green.shade700),
          _TD(debit != null ? _fmtAmt(debit) : '—',
              right: true, color: Colors.red.shade700),
          _TD(credit != null ? _fmtAmt(credit) : '—',
              right: true, color: Colors.green.shade700),
          _TD(
              balance < -0.005 ? 'Adv ${_fmtAmt(balance.abs())}' : _fmtAmt(balance),
              right: true, bold: true,
              color: balance < -0.005 ? Colors.blue.shade700
                  : balance > 0.005 ? Colors.orange.shade800
                  : Colors.green.shade700),
        ],
      ));

      // Detail sub-rows (invoice breakdown)
      for (final d in details) {
        final label     = d['label']  as String? ?? '';
        final amountRaw = d['amount'] as num?;   // null = reference line (no monetary value)
        rows.add(TableRow(
          decoration: subDecor,
          children: [
            const _TD(''),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2, right: 8),
              child: Text('  $label',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic)),
            ),
            const _TD(''),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
              child: Text(amountRaw != null ? _fmtAmt(amountRaw.toDouble()) : '',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
            const _TD(''),
            const _TD(''),
          ],
        ));
      }
    }

    // Totals row — include opening balance in the appropriate column so that
    // TOTALS Credit − TOTALS Debit = TOTALS Balance exactly.
    final totalsDebit  = _totalDebit  + (_openingBal > 0.005 ? _openingBal  : 0);
    final totalsCredit = _totalCredit + (_openingBal < -0.005 ? -_openingBal : 0);
    rows.add(TableRow(
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.07)),
      children: [
        const _TD('', bold: true),
        const _TD('TOTALS', bold: true),
        const _TD('', bold: true),
        _TD(_fmtAmt(totalsDebit),  right: true, bold: true, color: Colors.red.shade700),
        _TD(_fmtAmt(totalsCredit), right: true, bold: true, color: Colors.green.shade700),
        _TD(
            _closingBal < -0.005 ? 'Adv ${_fmtAmt(_closingBal.abs())}' : _fmtAmt(_closingBal),
            right: true, bold: true,
            color: _closingBal < -0.005 ? Colors.blue.shade700
                : _closingBal > 0.005 ? Colors.orange.shade800
                : Colors.green.shade700),
      ],
    ));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Table(
          columnWidths: colWidths,
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200),
          ),
          children: rows,
        ),
      ),
    );
  }

  String _fmtAmt(double v) => currFmt.format(v);

  // ── Print (opens browser print dialog with same PDF layout) ──────────────

  Future<void> _print(BuildContext context) async {
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: 'Ledger_${vendorName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  Future<void> _exportPdf(BuildContext context) async {
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Ledger_${vendorName.replaceAll(' ', '_')}_'
            '${DateFormat('yyyyMMdd').format(from)}_${DateFormat('yyyyMMdd').format(to)}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Uint8List> _buildPdf() async {
    // Noto Sans — fixes ₹ (U+20B9) rendering; Helvetica lacks the glyph.
    final font     = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final entries  = _entries;
    final dateStr  = '${_longFmt.format(from)} to ${_longFmt.format(to)}';
    final genDate  = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());

    // ── Column layout ─────────────────────────────────────────────────────────
    const colWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(52),   // Date
      1: pw.FlexColumnWidth(2.6),   // Particulars
      2: pw.FixedColumnWidth(46),   // Voucher Type
      3: pw.FixedColumnWidth(66),   // Debit
      4: pw.FixedColumnWidth(66),   // Credit
      5: pw.FixedColumnWidth(70),   // Balance
    };

    // ── Helper: single table row ──────────────────────────────────────────────
    pw.Widget cell(String text, {
      bool bold = false,
      bool right = false,
      bool italic = false,
      PdfColor? color,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font:       bold ? fontBold : font,
              fontSize:   8,
              fontStyle:  italic ? pw.FontStyle.italic : pw.FontStyle.normal,
              color:      color,
            ),
          ),
        );

    // Header row (repeated on every page via header() callback)
    pw.TableRow headerRow() => pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      children: [
        cell('Date',        bold: true),
        cell('Particulars', bold: true),
        cell('Voucher Type',bold: true),
        cell('Debit (₹)',   bold: true, right: true),
        cell('Credit (₹)',  bold: true, right: true),
        cell('Balance (₹)', bold: true, right: true),
      ],
    );

    // ── Build table rows ──────────────────────────────────────────────────────
    final List<pw.TableRow> rows = [headerRow()];

    // Opening balance row
    if (_openingBal != 0) {
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.amber50),
        children: [
          cell('—', italic: true),
          cell('Balance brought forward', italic: true),
          cell('Opening', italic: true),
          cell('', right: true),
          cell('', right: true),
          cell(
            _openingBal < -0.005
                ? 'Adv ${_fmtAmt(-_openingBal)}'
                : _fmtAmt(_openingBal),
            italic: true, right: true,
          ),
        ],
      ));
    }

    bool altRow = false;
    for (final e in entries) {
      final isInvoice = e['voucherType'] == 'Sales';
      final isPending = e['gstStatus'] == 'PENDING';
      final debit   = (e['debit']          as num?)?.toDouble();
      final credit  = (e['credit']         as num?)?.toDouble();
      final balance = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final date    = DateTime.parse(e['date'] as String);
      final details = e['details'] as List? ?? [];
      // PENDING invoices get a subtle amber tint on their main row
      final bgColor = isPending
          ? PdfColors.amber50
          : altRow ? PdfColors.grey50 : PdfColors.white;
      altRow = !altRow;

      // Main transaction row
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: [
          cell(_dateFmt.format(date)),
          cell(e['particulars'] as String? ?? '—', bold: true),
          cell(
            e['voucherType'] as String? ?? '—',
            color: isInvoice ? PdfColors.red700 : PdfColors.green700,
          ),
          cell(debit  != null ? _fmtAmt(debit)  : '—',
              right: true, color: PdfColors.red700),
          cell(credit != null ? _fmtAmt(credit) : '—',
              right: true, color: PdfColors.green700),
          cell(
            balance < -0.005
                ? 'Adv ${_fmtAmt(-balance)}'
                : _fmtAmt(balance),
            right: true, bold: true,
            color: balance < -0.005 ? PdfColors.blue700
                : balance > 0.005 ? PdfColors.orange900
                : PdfColors.green700,
          ),
        ],
      ));

      // Detail sub-rows
      for (final d in details) {
        final label     = d['label']  as String? ?? '';
        final amountRaw = d['amount'] as num?;
        final isMeta = amountRaw == null;                     // reference or pending line
        final isGstPending = isMeta && label.contains('GST: Pending');
        rows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: [
            cell(''),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 18, top: 2, bottom: 2, right: 4),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font:      isGstPending ? fontBold : font,
                  fontSize:  7.5,
                  fontStyle: isMeta && !isGstPending
                      ? pw.FontStyle.italic : pw.FontStyle.normal,
                  color:     isGstPending ? PdfColors.orange800
                      : PdfColors.blueGrey600,
                ),
              ),
            ),
            cell(''),
            cell(
              amountRaw != null ? _fmtAmt(amountRaw.toDouble()) : '',
              right: true,
              color: PdfColors.blueGrey600,
            ),
            cell(''),
            cell(''),
          ],
        ));
      }
    }

    // TOTALS row — include opening balance so Credit − Debit = Balance
    final pdfTotalsDebit  = _totalDebit  + (_openingBal > 0.005 ? _openingBal  : 0);
    final pdfTotalsCredit = _totalCredit + (_openingBal < -0.005 ? -_openingBal : 0);
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.8)),
      ),
      children: [
        cell(''),
        cell('TOTALS', bold: true),
        cell(''),
        cell(_fmtAmt(pdfTotalsDebit),  bold: true, right: true, color: PdfColors.red700),
        cell(_fmtAmt(pdfTotalsCredit), bold: true, right: true, color: PdfColors.green700),
        cell(
          _closingBal < -0.005
              ? 'Adv ${_fmtAmt(_closingBal.abs())}'
              : _fmtAmt(_closingBal),
          bold: true, right: true,
          color: _closingBal < -0.005 ? PdfColors.blue700
              : _closingBal > 0.005 ? PdfColors.orange900
              : PdfColors.green700,
        ),
      ],
    ));

    // ── Summary box ───────────────────────────────────────────────────────────
    pw.Widget summaryBox() {
      final isAdv = _closingBal < -0.005;
      return pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Container(
          width: 210,
          margin: const pw.EdgeInsets.only(top: 16),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.blueGrey50,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfRow('Opening Balance',  _fmtAmt(_openingBal.abs()),   font, fontBold),
              _pdfRow('Total Invoiced',   _fmtAmt(_totalDebit),          font, fontBold),
              _pdfRow('Total Received',   _fmtAmt(_totalCredit),         font, fontBold),
              pw.Divider(thickness: 0.4, color: PdfColors.blueGrey300),
              _pdfRow(
                isAdv ? 'Advance' : 'Outstanding',
                _fmtAmt(_closingBal.abs()),
                fontBold, fontBold,
                valueColor: isAdv ? PdfColors.blue700 : PdfColors.orange900,
              ),
            ],
          ),
        ),
      );
    }

    // ── Build PDF ─────────────────────────────────────────────────────────────
    final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 24),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Business header block — separated visually from the table
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Party Ledger Account',
                        style: pw.TextStyle(font: fontBold, fontSize: 13,
                            fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                    pw.SizedBox(height: 2),
                    pw.Text(vendorName,
                        style: pw.TextStyle(font: font, fontSize: 10,
                            color: PdfColors.blueGrey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(dateStr,
                        style: pw.TextStyle(font: fontBold, fontSize: 9,
                            fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                    if (ctx.pageNumber > 1)
                      pw.Text('(continued)',
                          style: pw.TextStyle(font: font, fontSize: 7,
                              color: PdfColors.grey500)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          // Column header row — repeat on every page
          pw.Table(
            columnWidths: colWidths,
            children: [headerRow()],
            border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.4),
          ),
        ],
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated: $genDate',
                style: pw.TextStyle(font: font, fontSize: 7,
                    color: PdfColors.blueGrey400)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 7,
                    color: PdfColors.blueGrey400)),
          ],
        ),
      ),
      build: (ctx) => [
        pw.Table(
          columnWidths: colWidths,
          // Skip the header row we already rendered via header() above
          children: rows.skip(1).toList(),
          border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.3),
        ),
        summaryBox(),
      ],
    ));

    return pdf.save();
  }

  // Shared helper for summary-box rows
  pw.Widget _pdfRow(String label, String value, pw.Font f, pw.Font fb,
      {PdfColor? valueColor}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(font: f, fontSize: 8.5)),
            pw.Text(value, style: pw.TextStyle(font: fb, fontSize: 8.5,
                fontWeight: pw.FontWeight.bold, color: valueColor)),
          ],
        ),
      );

  // ── Excel Export ──────────────────────────────────────────────────────────

  void _exportExcel(BuildContext context) async {
    final entries = _entries;
    final wb = xl.Excel.createExcel();
    final sheet = wb['Ledger'];
    wb.delete('Sheet1');

    void setTxt(int r, int c, String val, {bool bold = false, String? bg}) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      cell.value = xl.TextCellValue(val);
      cell.cellStyle = xl.CellStyle(bold: bold, backgroundColorHex: xl.ExcelColor.fromHexString(bg ?? '#FFFFFF'));
    }

    // ── Header block ─────────────────────────────────────────────────────
    setTxt(0, 0, vendorName, bold: true);
    setTxt(1, 0, 'Ledger Account', bold: true);
    setTxt(2, 0, '${_longFmt.format(from)} to ${_longFmt.format(to)}');
    setTxt(3, 0, 'Generated: ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}');

    // ── Column headers (row 5) ────────────────────────────────────────────
    const headers = ['Date', 'Particulars', 'Voucher Type', 'Debit (₹)', 'Credit (₹)', 'Balance (₹)'];
    for (int c = 0; c < headers.length; c++) {
      setTxt(5, c, headers[c], bold: true, bg: '#D9D9D9');
    }

    // ── Opening balance ───────────────────────────────────────────────────
    int row = 6;
    if (_openingBal != 0) {
      setTxt(row, 0, '—');
      setTxt(row, 1, 'Balance brought forward');
      setTxt(row, 2, 'Opening');
      setTxt(row, 3, '');
      setTxt(row, 4, '');
      setTxt(row, 5, _openingBal < -0.005
          ? 'Adv ${_fmtAmt(-_openingBal)}'
          : _fmtAmt(_openingBal));
      row++;
    }

    // ── Transaction rows ─────────────────────────────────────────────────
    for (final e in entries) {
      final debit   = (e['debit']          as num?)?.toDouble();
      final credit  = (e['credit']         as num?)?.toDouble();
      final balance = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final date    = DateTime.parse(e['date'] as String);
      final details = e['details'] as List? ?? [];

      setTxt(row, 0, _dateFmt.format(date));
      setTxt(row, 1, e['particulars'] as String? ?? '—', bold: true);
      setTxt(row, 2, e['voucherType'] as String? ?? '—');
      setTxt(row, 3, debit  != null ? _fmtAmt(debit)  : '—');
      setTxt(row, 4, credit != null ? _fmtAmt(credit) : '—');
      setTxt(row, 5, balance < -0.005 ? 'Adv ${_fmtAmt(-balance)}' : _fmtAmt(balance));
      row++;

      for (final d in details) {
        final label     = d['label']  as String? ?? '';
        final amountRaw = d['amount'] as num?;   // null = reference line (no monetary value)
        setTxt(row, 0, '');
        setTxt(row, 1, '    $label');
        setTxt(row, 2, '');
        setTxt(row, 3, amountRaw != null ? _fmtAmt(amountRaw.toDouble()) : '');
        setTxt(row, 4, '');
        setTxt(row, 5, '');
        row++;
      }
    }

    // ── Totals row — include opening balance so TOTALS Credit − TOTALS Debit = Balance ──
    final xlTotalsDebit  = _totalDebit  + (_openingBal > 0.005 ? _openingBal  : 0);
    final xlTotalsCredit = _totalCredit + (_openingBal < -0.005 ? -_openingBal : 0);
    row++;
    setTxt(row, 1, 'TOTALS', bold: true, bg: '#E8E8E8');
    setTxt(row, 3, _fmtAmt(xlTotalsDebit),  bold: true, bg: '#E8E8E8');
    setTxt(row, 4, _fmtAmt(xlTotalsCredit), bold: true, bg: '#E8E8E8');
    setTxt(row, 5, _closingBal < -0.005
        ? 'Adv ${_fmtAmt(_closingBal.abs())}'
        : _fmtAmt(_closingBal),
        bold: true, bg: '#E8E8E8');
    row += 2;

    // ── Summary block ─────────────────────────────────────────────────────
    setTxt(row,     0, 'Opening Balance:');
    setTxt(row,     1, _openingBal < -0.005
        ? 'Adv ${_fmtAmt(-_openingBal)}'
        : _fmtAmt(_openingBal));
    setTxt(row + 1, 0, 'Total Invoiced:');  setTxt(row + 1, 1, _fmtAmt(_totalDebit));
    setTxt(row + 2, 0, 'Total Paid:');      setTxt(row + 2, 1, _fmtAmt(_totalCredit));
    setTxt(row + 3, 0, _closingBal < -0.005 ? 'Advance:' : 'Outstanding:', bold: true);
    setTxt(row + 3, 1, _fmtAmt(_closingBal.abs()), bold: true);

    // ── Column widths ──────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 44);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 18);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 18);

    final bytes = wb.save();
    if (bytes == null) return;

    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'Ledger_${vendorName.replaceAll(' ', '_')}_'
          '${DateFormat('yyyyMMdd').format(from)}.xlsx',
    );
  }
}

// ── Balance tile ──────────────────────────────────────────────────────────────

class _BalTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;
  const _BalTile(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fmtCurr(value),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    fontSize: bold ? 15 : 13,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      );
}

// ── Table cell widgets ────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _TD extends StatelessWidget {
  final String text;
  final bool right;
  final bool bold;
  final bool italic;
  final Color? color;
  final TextStyle? style;
  const _TD(this.text, {this.right = false, this.bold = false, this.italic = false, this.color, this.style});

  @override
  Widget build(BuildContext context) {
    final ts = style ??
        TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: color,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: ts,
          overflow: TextOverflow.ellipsis),
    );
  }
}
