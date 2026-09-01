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
  final res = await ref.read(apiClientProvider).get('/api/vendors');
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
      .get('/api/ledger/vendor/${p.vendorId}', params: {'from': p.from, 'to': p.to});
  return Map<String, dynamic>.from(res.data);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(_vendorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Ledger')),
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
                    return SearchablePicker(
                      items: active,
                      itemLabel: (v) => v['name'] as String,
                      fieldLabel: 'Select Vendor / Party',
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
                    message: 'Select a vendor to view their ledger',
                    hint: 'Choose vendor and date range above',
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
              _BalTile('Outstanding', _closingBal,
                  _closingBal > 0.005 ? Colors.orange.shade800 : Colors.green.shade700,
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
          _TD(_fmtAmt(_openingBal), right: true, italic: true,
              color: _openingBal >= 0 ? Colors.orange.shade800 : Colors.green.shade700),
        ],
      ));
    }

    bool alt = false;
    for (final e in entries) {
      final isInvoice = e['voucherType'] == 'Sales';
      final debit    = (e['debit']          as num?)?.toDouble();
      final credit   = (e['credit']         as num?)?.toDouble();
      final balance  = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final date     = DateTime.parse(e['date'] as String);
      final details  = e['details'] as List? ?? [];
      final rowDecor = alt ? altDecor : const BoxDecoration(color: Colors.white);
      alt = !alt;

      // Main transaction row
      rows.add(TableRow(
        decoration: rowDecor,
        children: [
          _TD(_dateFmt.format(date)),
          _TD(e['particulars'] as String? ?? '—',
              bold: true, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          _TD(e['voucherType'] as String? ?? '—',
              color: isInvoice ? Colors.red.shade700 : Colors.green.shade700),
          _TD(debit != null ? _fmtAmt(debit) : '—',
              right: true, color: Colors.red.shade700),
          _TD(credit != null ? _fmtAmt(credit) : '—',
              right: true, color: Colors.green.shade700),
          _TD(_fmtAmt(balance), right: true, bold: true,
              color: balance > 0.005 ? Colors.orange.shade800 : Colors.green.shade700),
        ],
      ));

      // Detail sub-rows (invoice breakdown)
      for (final d in details) {
        final label  = d['label']  as String? ?? '';
        final amount = (d['amount'] as num?)?.toDouble() ?? 0;
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
              child: Text(_fmtAmt(amount),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
            const _TD(''),
            const _TD(''),
          ],
        ));
      }
    }

    // Totals row
    rows.add(TableRow(
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.07)),
      children: [
        const _TD('', bold: true),
        const _TD('TOTALS', bold: true),
        const _TD('', bold: true),
        _TD(_fmtAmt(_totalDebit), right: true, bold: true, color: Colors.red.shade700),
        _TD(_fmtAmt(_totalCredit), right: true, bold: true, color: Colors.green.shade700),
        _TD(_fmtAmt(_closingBal), right: true, bold: true,
            color: _closingBal > 0.005 ? Colors.orange.shade800 : Colors.green.shade700),
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

  void _print(BuildContext context) async {
    final bytes = await _buildPdf();
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'Ledger_${vendorName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  void _exportPdf(BuildContext context) async {
    final bytes = await _buildPdf();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Ledger_${vendorName.replaceAll(' ', '_')}_'
          '${DateFormat('yyyyMMdd').format(from)}_${DateFormat('yyyyMMdd').format(to)}.pdf',
    );
  }

  Future<Uint8List> _buildPdf() async {
    final entries  = _entries;
    final dateStr  = '${_longFmt.format(from)} to ${_longFmt.format(to)}';

    final pdf = pw.Document();

    // Build all rows (data rows for pdf.MultiPage)
    List<List<String>> tableData = [];

    if (_openingBal != 0) {
      tableData.add(['—', 'Balance brought forward', 'Opening', '', '', _fmtAmt(_openingBal)]);
    }

    for (final e in entries) {
      final debit   = (e['debit']          as num?)?.toDouble();
      final credit  = (e['credit']         as num?)?.toDouble();
      final balance = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final date    = DateTime.parse(e['date'] as String);
      final details = e['details'] as List? ?? [];

      tableData.add([
        _dateFmt.format(date),
        e['particulars'] as String? ?? '—',
        e['voucherType'] as String? ?? '—',
        debit  != null ? _fmtAmt(debit)  : '—',
        credit != null ? _fmtAmt(credit) : '—',
        _fmtAmt(balance),
      ]);

      for (final d in details) {
        final label  = d['label']  as String? ?? '';
        final amount = (d['amount'] as num?)?.toDouble() ?? 0;
        tableData.add(['', '    $label', '', _fmtAmt(amount), '', '']);
      }
    }

    // Totals
    tableData.add(['', 'TOTALS', '', _fmtAmt(_totalDebit), _fmtAmt(_totalCredit), _fmtAmt(_closingBal)]);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(vendorName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Ledger Account',
              style: const pw.TextStyle(fontSize: 11)),
          pw.Text(dateStr,
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 2),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              'Generated: ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Particulars', 'Voucher Type', 'Debit (₹)', 'Credit (₹)', 'Balance (₹)'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 7.5),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(55),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FixedColumnWidth(52),
            3: const pw.FixedColumnWidth(68),
            4: const pw.FixedColumnWidth(68),
            5: const pw.FixedColumnWidth(72),
          },
          data: tableData,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
        ),
        pw.SizedBox(height: 16),
        // Summary box at bottom of last page
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 260,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              color: PdfColors.grey50,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfSumRow('Opening Balance :', _fmtAmt(_openingBal)),
                _pdfSumRow('Total Invoiced :', _fmtAmt(_totalDebit)),
                _pdfSumRow('Total Paid :', _fmtAmt(_totalCredit)),
                pw.Divider(thickness: 0.5),
                _pdfSumRow('Outstanding :', _fmtAmt(_closingBal), bold: true),
              ],
            ),
          ),
        ),
      ],
    ));

    return pdf.save();
  }

  pw.Widget _pdfSumRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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
      setTxt(row, 5, _fmtAmt(_openingBal));
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
      setTxt(row, 5, _fmtAmt(balance));
      row++;

      for (final d in details) {
        final label  = d['label']  as String? ?? '';
        final amount = (d['amount'] as num?)?.toDouble() ?? 0;
        setTxt(row, 0, '');
        setTxt(row, 1, '    $label');
        setTxt(row, 2, '');
        setTxt(row, 3, _fmtAmt(amount));
        setTxt(row, 4, '');
        setTxt(row, 5, '');
        row++;
      }
    }

    // ── Totals row ────────────────────────────────────────────────────────
    row++;
    setTxt(row, 1, 'TOTALS', bold: true, bg: '#E8E8E8');
    setTxt(row, 3, _fmtAmt(_totalDebit),  bold: true, bg: '#E8E8E8');
    setTxt(row, 4, _fmtAmt(_totalCredit), bold: true, bg: '#E8E8E8');
    setTxt(row, 5, _fmtAmt(_closingBal),  bold: true, bg: '#E8E8E8');
    row += 2;

    // ── Summary block ─────────────────────────────────────────────────────
    setTxt(row,     0, 'Opening Balance:'); setTxt(row,     1, _fmtAmt(_openingBal));
    setTxt(row + 1, 0, 'Total Invoiced:');  setTxt(row + 1, 1, _fmtAmt(_totalDebit));
    setTxt(row + 2, 0, 'Total Paid:');      setTxt(row + 2, 1, _fmtAmt(_totalCredit));
    setTxt(row + 3, 0, 'Outstanding:',  bold: true);
    setTxt(row + 3, 1, _fmtAmt(_closingBal), bold: true);

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
