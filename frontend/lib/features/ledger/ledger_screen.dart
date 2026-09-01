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

enum DateRangePreset { thisMonth, lastMonth, thisYear, custom }

class _DateRange {
  final DateTime from;
  final DateTime to;
  const _DateRange(this.from, this.to);
}

_DateRange _presetRange(DateRangePreset p) {
  final now = DateTime.now();
  switch (p) {
    case DateRangePreset.thisMonth:
      return _DateRange(DateTime(now.year, now.month, 1), now);
    case DateRangePreset.lastMonth:
      final first = DateTime(now.year, now.month - 1, 1);
      final last  = DateTime(now.year, now.month, 0);
      return _DateRange(first, last);
    case DateRangePreset.thisYear:
      // Financial year starts April
      final fyStart = now.month >= 4
          ? DateTime(now.year, 4, 1)
          : DateTime(now.year - 1, 4, 1);
      return _DateRange(fyStart, now);
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
    setState(() {
      _preset = p;
      _from = r.from;
      _to   = r.to;
    });
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
      appBar: AppBar(
        title: const Text('Vendor Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_vendorId != null) {
                ref.invalidate(_ledgerProvider(
                    _LedgerParams(_vendorId!, _fromStr, _toStr)));
              }
            },
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
                // Vendor picker
                vendors.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (list) {
                    final active =
                        list.where((v) => v['status'] == 'ACTIVE').toList();
                    return DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Select Vendor',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      value: _vendorId,
                      isExpanded: true,
                      items: active
                          .map((v) => DropdownMenuItem<int>(
                                value: v['id'] as int,
                                child: Text(v['name'] as String,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _vendorId = v;
                          _vendorName = active
                              .firstWhere((e) => e['id'] == v)['name'] as String;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Date range presets + pickers
                Row(
                  children: [
                    ...[
                      ('This Month', DateRangePreset.thisMonth),
                      ('Last Month', DateRangePreset.lastMonth),
                      ('This FY',    DateRangePreset.thisYear),
                    ].map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t.$1,
                                style: const TextStyle(fontSize: 12)),
                            selected: _preset == t.$2,
                            onSelected: (_) => _applyPreset(t.$2),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                    const Spacer(),
                    // Custom from-to
                    _DateChip(
                        label: DateFormat('d MMM yy').format(_from),
                        onTap: _pickFrom),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('→',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    _DateChip(
                        label: DateFormat('d MMM yy').format(_to),
                        onTap: _pickTo),
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
  const _LedgerContent(
      {required this.params,
      required this.vendorName,
      required this.from,
      required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_ledgerProvider(params));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (d) => _LedgerTable(data: d, vendorName: vendorName, from: from, to: to),
    );
  }
}

// ── Ledger table ──────────────────────────────────────────────────────────────

class _LedgerTable extends StatelessWidget {
  final Map<String, dynamic> data;
  final String vendorName;
  final DateTime from;
  final DateTime to;
  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _shortDateFmt = DateFormat('d MMM yy');

  const _LedgerTable(
      {required this.data,
      required this.vendorName,
      required this.from,
      required this.to});

  List<Map<String, dynamic>> get _entries =>
      List<Map<String, dynamic>>.from(data['entries'] as List? ?? []);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = _entries;
    final openingBal = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final totalDebit = (data['totalDebit'] as num?)?.toDouble() ?? 0;
    final totalCredit = (data['totalCredit'] as num?)?.toDouble() ?? 0;
    final closingBal = (data['closingBalance'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        // ── Summary strip ───────────────────────────────────────────────
        Container(
          color: cs.primary.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  vendorName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_shortDateFmt.format(from)} – ${_shortDateFmt.format(to)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              // Export buttons
              TextButton.icon(
                onPressed: () => _exportExcel(context),
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Excel', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _exportPdf(context),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // ── Balance summary row ─────────────────────────────────────────
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _BalTile('Opening', openingBal, Colors.grey),
              const _Divider(),
              _BalTile('Total Invoiced', totalDebit, Colors.red.shade700),
              const _Divider(),
              _BalTile('Total Paid', totalCredit, Colors.green.shade700),
              const _Divider(),
              _BalTile(
                'Outstanding',
                closingBal,
                closingBal > 0 ? Colors.orange.shade800 : Colors.green.shade700,
                bold: true,
              ),
            ],
          ),
        ),

        // ── Table ───────────────────────────────────────────────────────
        entries.isEmpty
            ? const Expanded(
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No transactions in this period',
                  hint:
                      'Try a wider date range or check if invoices/payments exist',
                ),
              )
            : Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: _buildTable(context, entries, openingBal,
                      totalDebit, totalCredit, closingBal),
                ),
              ),
      ],
    );
  }

  Widget _buildTable(BuildContext context, List<Map<String, dynamic>> entries,
      double openingBal, double totalDebit, double totalCredit, double closingBal) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(100),  // Date
            1: FixedColumnWidth(80),   // Type
            2: FixedColumnWidth(130),  // Reference
            3: FlexColumnWidth(2),     // Description
            4: FixedColumnWidth(130),  // Debit
            5: FixedColumnWidth(130),  // Credit
            6: FixedColumnWidth(140),  // Balance
          },
          border: TableBorder(
            horizontalInside:
                BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          children: [
            // Header
            TableRow(
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08)),
              children: const [
                _TH('Date'),
                _TH('Type'),
                _TH('Reference'),
                _TH('Description'),
                _TH('Debit (₹)', right: true),
                _TH('Credit (₹)', right: true),
                _TH('Balance (₹)', right: true),
              ],
            ),
            // Opening balance row
            if (openingBal != 0)
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: [
                  const _TD('—', italic: true),
                  const _TD('', italic: true),
                  const _TD('Opening', italic: true),
                  const _TD('Balance brought forward', italic: true),
                  const _TD('', right: true),
                  const _TD('', right: true),
                  _TD(fmtCurr(openingBal), right: true,
                      color: openingBal >= 0
                          ? Colors.orange.shade800
                          : Colors.green.shade700),
                ],
              ),
            // Transaction rows
            ...entries.map((e) {
              final isInvoice = e['txnType'] == 'INVOICE';
              final debit  = (e['debit']  as num?)?.toDouble();
              final credit = (e['credit'] as num?)?.toDouble();
              final balance = (e['runningBalance'] as num?)?.toDouble() ?? 0;
              final date = DateTime.parse(e['date'] as String);
              return TableRow(
                children: [
                  _TD(_dateFmt.format(date)),
                  _TD(
                    isInvoice ? 'Invoice' : 'Payment',
                    color: isInvoice ? Colors.red.shade700 : Colors.green.shade700,
                    bold: true,
                  ),
                  _TD(e['reference'] as String? ?? '—',
                      style: const TextStyle(fontSize: 11)),
                  _TD(e['description'] as String? ?? '—',
                      style: const TextStyle(fontSize: 12)),
                  _TD(debit != null ? fmtCurr(debit) : '—',
                      right: true, color: Colors.red.shade700),
                  _TD(credit != null ? fmtCurr(credit) : '—',
                      right: true, color: Colors.green.shade700),
                  _TD(fmtCurr(balance),
                      right: true,
                      bold: true,
                      color: balance > 0
                          ? Colors.orange.shade800
                          : Colors.green.shade700),
                ],
              );
            }),
            // Totals row
            TableRow(
              decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.06)),
              children: [
                const _TD('', bold: true),
                const _TD('', bold: true),
                const _TD('', bold: true),
                const _TD('TOTALS', bold: true),
                _TD(fmtCurr(totalDebit),
                    right: true, bold: true, color: Colors.red.shade700),
                _TD(fmtCurr(totalCredit),
                    right: true, bold: true, color: Colors.green.shade700),
                _TD(fmtCurr(closingBal),
                    right: true,
                    bold: true,
                    color: closingBal > 0
                        ? Colors.orange.shade800
                        : Colors.green.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── PDF Export ─────────────────────────────────────────────────────────────

  void _exportPdf(BuildContext context) async {
    final entries = _entries;
    final openingBal = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final totalDebit = (data['totalDebit'] as num?)?.toDouble() ?? 0;
    final totalCredit = (data['totalCredit'] as num?)?.toDouble() ?? 0;
    final closingBal = (data['closingBalance'] as num?)?.toDouble() ?? 0;

    final pdf = pw.Document();
    final dateStr =
        '${_dateFmt.format(from)} – ${_dateFmt.format(to)}';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DSP Construction',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Vendor Ledger — $vendorName',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: $dateStr',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Divider(),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headers: [
            'Date', 'Type', 'Reference', 'Description',
            'Debit (₹)', 'Credit (₹)', 'Balance (₹)'
          ],
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 9),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
          data: [
            if (openingBal != 0)
              ['—', 'Opening', 'Opening Balance', 'Balance b/f',
               '', '', _fmtNum(openingBal)],
            ...entries.map((e) {
              final debit  = (e['debit']  as num?)?.toDouble();
              final credit = (e['credit'] as num?)?.toDouble();
              final bal    = (e['runningBalance'] as num?)?.toDouble() ?? 0;
              final date   = DateTime.parse(e['date'] as String);
              return [
                _dateFmt.format(date),
                e['txnType'] == 'INVOICE' ? 'Invoice' : 'Payment',
                e['reference'] ?? '—',
                e['description'] ?? '—',
                debit  != null ? _fmtNum(debit)  : '—',
                credit != null ? _fmtNum(credit) : '—',
                _fmtNum(bal),
              ];
            }),
            ['', '', '', 'TOTALS',
             _fmtNum(totalDebit), _fmtNum(totalCredit), _fmtNum(closingBal)],
          ],
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _pdfSummaryRow('Opening Balance:', _fmtNum(openingBal)),
                  _pdfSummaryRow('Total Invoiced:', _fmtNum(totalDebit)),
                  _pdfSummaryRow('Total Paid:', _fmtNum(totalCredit)),
                  pw.Divider(),
                  _pdfSummaryRow('Outstanding:', _fmtNum(closingBal), bold: true),
                ],
              ),
            ),
          ],
        ),
      ],
    ));

    final bytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'Ledger_${vendorName.replaceAll(' ', '_')}_$dateStr.pdf',
    );
  }

  pw.Widget _pdfSummaryRow(String label, String value, {bool bold = false}) =>
      pw.Row(children: [
        pw.SizedBox(width: 120,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        pw.SizedBox(width: 80,
            child: pw.Text(value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
      ]);

  // ── Excel Export ───────────────────────────────────────────────────────────

  void _exportExcel(BuildContext context) async {
    final entries = _entries;
    final openingBal = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final totalDebit = (data['totalDebit'] as num?)?.toDouble() ?? 0;
    final totalCredit = (data['totalCredit'] as num?)?.toDouble() ?? 0;
    final closingBal = (data['closingBalance'] as num?)?.toDouble() ?? 0;

    final workbook = xl.Excel.createExcel();
    final sheet = workbook['Ledger'];
    workbook.delete('Sheet1');

    // Helper to set cell value
    void setCell(int r, int c, dynamic val) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      cell.value = val is double
          ? xl.DoubleCellValue(val)
          : xl.TextCellValue(val.toString());
    }

    // Header info
    setCell(0, 0, 'DSP Construction — Vendor Ledger');
    setCell(1, 0, 'Vendor: $vendorName');
    setCell(2, 0, 'Period: ${_dateFmt.format(from)} to ${_dateFmt.format(to)}');
    setCell(3, 0, 'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}');

    // Column headers (row 5)
    const headers = ['Date', 'Type', 'Reference', 'Description',
                     'Debit (₹)', 'Credit (₹)', 'Balance (₹)'];
    for (int c = 0; c < headers.length; c++) {
      setCell(5, c, headers[c]);
    }

    int row = 6;
    // Opening balance
    if (openingBal != 0) {
      setCell(row, 0, '—');
      setCell(row, 1, 'Opening');
      setCell(row, 2, 'Opening Balance');
      setCell(row, 3, 'Balance brought forward');
      setCell(row, 4, '');
      setCell(row, 5, '');
      setCell(row, 6, openingBal);
      row++;
    }

    // Transactions
    for (final e in entries) {
      final debit  = (e['debit']  as num?)?.toDouble();
      final credit = (e['credit'] as num?)?.toDouble();
      final bal    = (e['runningBalance'] as num?)?.toDouble() ?? 0;
      final date   = DateTime.parse(e['date'] as String);
      setCell(row, 0, _dateFmt.format(date));
      setCell(row, 1, e['txnType'] == 'INVOICE' ? 'Invoice' : 'Payment');
      setCell(row, 2, e['reference'] ?? '—');
      setCell(row, 3, e['description'] ?? '—');
      setCell(row, 4, debit  ?? '');
      setCell(row, 5, credit ?? '');
      setCell(row, 6, bal);
      row++;
    }

    // Totals
    row++;
    setCell(row, 3, 'TOTALS');
    setCell(row, 4, totalDebit);
    setCell(row, 5, totalCredit);
    setCell(row, 6, closingBal);
    row += 2;
    setCell(row,     0, 'Opening Balance:'); setCell(row,     1, openingBal);
    setCell(row + 1, 0, 'Total Invoiced:');  setCell(row + 1, 1, totalDebit);
    setCell(row + 2, 0, 'Total Paid:');      setCell(row + 2, 1, totalCredit);
    setCell(row + 3, 0, 'Outstanding:');     setCell(row + 3, 1, closingBal);

    final bytes = workbook.save();
    if (bytes == null) return;

    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'Ledger_${vendorName.replaceAll(' ', '_')}.xlsx',
    );
  }

  String _fmtNum(double v) => currFmt.format(v);
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
          children: [
            Text(fmtCurr(value),
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.w600,
                    fontSize: bold ? 16 : 14,
                    color: color)),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Colors.grey.shade200);
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
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _TD extends StatelessWidget {
  final String text;
  final bool right;
  final bool bold;
  final bool italic;
  final Color? color;
  final TextStyle? style;
  const _TD(this.text,
      {this.right = false,
      this.bold = false,
      this.italic = false,
      this.color,
      this.style});

  @override
  Widget build(BuildContext context) {
    TextStyle ts = style ??
        TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: color,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: ts,
          overflow: TextOverflow.ellipsis),
    );
  }
}
