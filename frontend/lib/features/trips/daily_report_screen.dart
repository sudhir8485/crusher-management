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

// ── providers ────────────────────────────────────────────────────────────────

final _reportDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _dailyReportProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, date) async {
  final res = await ref
      .read(apiClientProvider)
      .get('/api/reports/daily', params: {'date': date});
  return Map<String, dynamic>.from(res.data);
});

final _dateFmt = DateFormat('EEEE, d MMMM yyyy');

// ── screen ────────────────────────────────────────────────────────────────────

class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_reportDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final report  = ref.watch(_dailyReportProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
        actions: [
          report.when(
            data: (d) => Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.table_chart_outlined),
                  tooltip: 'Export Excel',
                  onPressed: () => _exportExcel(context, d, selectedDate),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Export PDF',
                  onPressed: () => _exportPdf(context, d, selectedDate),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_dailyReportProvider(dateKey)),
          ),
        ],
      ),
      body: Column(
        children: [
          AppDateBar(
            selectedDate: selectedDate,
            onPick: (d) => ref.read(_reportDateProvider.notifier).state = d,
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (d) => _ReportBody(data: d, date: selectedDate),
            ),
          ),
        ],
      ),
    );
  }

  void _exportPdf(BuildContext context, Map<String, dynamic> d, DateTime date) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('d MMMM yyyy').format(date);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DSP Construction — Daily Report',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Date: $dateStr',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
      build: (ctx) => [
        ..._buildPdfSections(d),
      ],
    ));

    final bytes = await pdf.save();
    await Printing.layoutPdf(
        onLayout: (_) => bytes, name: 'DailyReport_$dateStr.pdf');
  }

  List<pw.Widget> _buildPdfSections(Map<String, dynamic> d) {
    final widgets = <pw.Widget>[];

    // Trips
    final trips = d['trips'] as Map<String, dynamic>? ?? {};
    widgets.add(_pdfSection('TRIPS'));
    widgets.add(pw.Text(
        'Total: ${trips['tripCount'] ?? 0} trips  |  ${numFmt.format(trips['totalBrass'] ?? 0)} Brass',
        style: const pw.TextStyle(fontSize: 9)));
    final byMat = trips['byMaterial'] as List? ?? [];
    if (byMat.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: ['Material', 'Trips', 'Brass'],
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        data: byMat.map((m) => [
          m['materialName'] ?? '—',
          m['tripCount'].toString(),
          '${numFmt.format(m['totalBrass'] ?? 0)} B',
        ]).toList(),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      ));
    }
    widgets.add(pw.SizedBox(height: 8));

    // Dabar
    final dabar = d['dabar'] as Map<String, dynamic>? ?? {};
    if ((dabar['entryCount'] ?? 0) > 0) {
      widgets.add(_pdfSection('DABAR (RAW STONE INTAKE)'));
      widgets.add(pw.Text(
          'Entries: ${dabar['entryCount']}  |  Trips: ${dabar['totalTrips']}  |  Brass: ${numFmt.format(dabar['totalBrass'] ?? 0)}',
          style: const pw.TextStyle(fontSize: 9)));
      widgets.add(pw.SizedBox(height: 8));
    }

    // Water Tanker
    final wt = d['waterTanker'] as Map<String, dynamic>? ?? {};
    if ((wt['entryCount'] ?? 0) > 0) {
      widgets.add(_pdfSection('WATER TANKER'));
      widgets.add(pw.Text(
          'Entries: ${wt['entryCount']}  |  Hours: ${numFmt.format(wt['totalHours'] ?? 0)}  |  KM: ${numFmt.format(wt['totalKm'] ?? 0)}  |  Amount: ${fmtCurr(wt['totalAmount'] ?? 0)}',
          style: const pw.TextStyle(fontSize: 9)));
      widgets.add(pw.SizedBox(height: 8));
    }

    // Diesel
    final diesel = d['diesel'] as Map<String, dynamic>? ?? {};
    widgets.add(_pdfSection('DIESEL'));
    widgets.add(pw.Text(
        'Received: ${numFmt.format(diesel['receivedToday'] ?? 0)} L  |  Used: ${numFmt.format(diesel['usedToday'] ?? 0)} L  |  Stock: ${numFmt.format(diesel['closingStock'] ?? 0)} L',
        style: const pw.TextStyle(fontSize: 9)));
    widgets.add(pw.SizedBox(height: 8));

    // Machine
    final machine = d['machine'] as Map<String, dynamic>? ?? {};
    if ((machine['entryCount'] ?? 0) > 0) {
      widgets.add(_pdfSection('MACHINE WORK'));
      widgets.add(pw.Text(
          'Total: ${numFmt.format(machine['totalHours'] ?? 0)} hrs  |  Bucket: ${numFmt.format(machine['bucketHours'] ?? 0)} hrs  |  Breaker: ${numFmt.format(machine['breakerHours'] ?? 0)} hrs',
          style: const pw.TextStyle(fontSize: 9)));
      widgets.add(pw.SizedBox(height: 8));
    }

    // Attendance
    final att = d['attendance'] as Map<String, dynamic>? ?? {};
    if ((att['total'] ?? 0) > 0) {
      widgets.add(_pdfSection('ATTENDANCE'));
      widgets.add(pw.Text(
          'Present: ${att['present']}  |  Half-Day: ${att['halfDay']}  |  Absent: ${att['absent']}  |  Leave: ${att['onLeave']}  |  Unmarked: ${att['unmarked']}',
          style: const pw.TextStyle(fontSize: 9)));
      widgets.add(pw.SizedBox(height: 8));
    }

    // Financial
    final fin = d['financial'] as Map<String, dynamic>? ?? {};
    if ((fin['invoiceCount'] ?? 0) > 0 || (fin['paymentCount'] ?? 0) > 0) {
      widgets.add(_pdfSection('FINANCIAL'));
      if ((fin['invoiceCount'] ?? 0) > 0)
        widgets.add(pw.Text(
            'Invoices: ${fin['invoiceCount']}  |  Amount: ${fmtCurr(fin['invoiceTotal'] ?? 0)}',
            style: const pw.TextStyle(fontSize: 9)));
      if ((fin['paymentCount'] ?? 0) > 0)
        widgets.add(pw.Text(
            'Payments: ${fin['paymentCount']}  |  Amount: ${fmtCurr(fin['paymentTotal'] ?? 0)}',
            style: const pw.TextStyle(fontSize: 9)));
    }

    return widgets;
  }

  pw.Widget _pdfSection(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold)));

  void _exportExcel(BuildContext context, Map<String, dynamic> d, DateTime date) async {
    final wb    = xl.Excel.createExcel();
    final sheet = wb['Daily Report'];
    wb.delete('Sheet1');

    void cell(int r, int c, dynamic v) {
      final ce = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      ce.value = v is double ? xl.DoubleCellValue(v)
               : v is int    ? xl.IntCellValue(v)
               : xl.TextCellValue(v.toString());
    }

    cell(0, 0, 'DSP Construction — Daily Report');
    cell(1, 0, 'Date: ${DateFormat('d MMMM yyyy').format(date)}');
    cell(2, 0, 'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}');

    int row = 4;

    // Trips
    cell(row++, 0, 'TRIPS');
    final trips = d['trips'] as Map<String, dynamic>? ?? {};
    cell(row, 0, 'Total Trips'); cell(row, 1, (trips['tripCount'] ?? 0) as int); row++;
    cell(row, 0, 'Total Brass'); cell(row, 1, (trips['totalBrass'] as num?)?.toDouble() ?? 0.0); row++;
    row++;
    cell(row, 0, 'Material'); cell(row, 1, 'Trips'); cell(row, 2, 'Brass'); row++;
    for (final m in (trips['byMaterial'] as List? ?? [])) {
      cell(row, 0, m['materialName'] ?? '—');
      cell(row, 1, (m['tripCount'] ?? 0) as int);
      cell(row, 2, (m['totalBrass'] as num?)?.toDouble() ?? 0.0);
      row++;
    }
    row++;

    // Diesel
    cell(row++, 0, 'DIESEL');
    final diesel = d['diesel'] as Map<String, dynamic>? ?? {};
    cell(row, 0, 'Received Today'); cell(row, 1, (diesel['receivedToday'] as num?)?.toDouble() ?? 0.0); cell(row, 2, 'L'); row++;
    cell(row, 0, 'Used Today');     cell(row, 1, (diesel['usedToday']    as num?)?.toDouble() ?? 0.0); cell(row, 2, 'L'); row++;
    cell(row, 0, 'Closing Stock');  cell(row, 1, (diesel['closingStock'] as num?)?.toDouble() ?? 0.0); cell(row, 2, 'L'); row++;
    row++;

    // Machine
    final machine = d['machine'] as Map<String, dynamic>? ?? {};
    if ((machine['entryCount'] ?? 0) > 0) {
      cell(row++, 0, 'MACHINE WORK');
      cell(row, 0, 'Total Hours');   cell(row, 1, (machine['totalHours']   as num?)?.toDouble() ?? 0.0); row++;
      cell(row, 0, 'Bucket Hours');  cell(row, 1, (machine['bucketHours']  as num?)?.toDouble() ?? 0.0); row++;
      cell(row, 0, 'Breaker Hours'); cell(row, 1, (machine['breakerHours'] as num?)?.toDouble() ?? 0.0); row++;
      row++;
    }

    // Attendance
    final att = d['attendance'] as Map<String, dynamic>? ?? {};
    if ((att['total'] ?? 0) > 0) {
      cell(row++, 0, 'ATTENDANCE');
      cell(row, 0, 'Present');   cell(row, 1, (att['present']  ?? 0) as int); row++;
      cell(row, 0, 'Half Day');  cell(row, 1, (att['halfDay']  ?? 0) as int); row++;
      cell(row, 0, 'Absent');    cell(row, 1, (att['absent']   ?? 0) as int); row++;
      cell(row, 0, 'Leave');     cell(row, 1, (att['onLeave']  ?? 0) as int); row++;
      cell(row, 0, 'Unmarked');  cell(row, 1, (att['unmarked'] ?? 0) as int); row++;
    }

    final bytes = wb.save();
    if (bytes == null) return;
    await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'DailyReport_${DateFormat('yyyy-MM-dd').format(date)}.xlsx');
  }
}

// ── Report body ───────────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime date;
  const _ReportBody({required this.data, required this.date});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _dateFmt.format(date),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _TripsCard(trips: data['trips'] as Map<String, dynamic>? ?? {}),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _DabarCard(
              dabar: data['dabar'] as Map<String, dynamic>? ?? {})),
          const SizedBox(width: 8),
          Expanded(child: _WaterTankerCard(
              wt: data['waterTanker'] as Map<String, dynamic>? ?? {})),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _DieselCard(
              diesel: data['diesel'] as Map<String, dynamic>? ?? {})),
          const SizedBox(width: 8),
          Expanded(child: _MachineCard(
              machine: data['machine'] as Map<String, dynamic>? ?? {})),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _AttendanceCard(
              att: data['attendance'] as Map<String, dynamic>? ?? {})),
          const SizedBox(width: 8),
          Expanded(child: _FinancialCard(
              fin: data['financial'] as Map<String, dynamic>? ?? {})),
        ]),
        const SizedBox(height: 8),
        // Trips detail table
        _TripsDetailTable(
            trips: List<Map<String, dynamic>>.from(
                (data['trips'] as Map<String, dynamic>?)?['trips'] as List? ?? [])),
      ],
    );
  }
}

// ── Section cards ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const _SectionCard({
    required this.title, required this.icon, required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
              ]),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

Widget _statRow(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );

class _TripsCard extends StatelessWidget {
  final Map<String, dynamic> trips;
  const _TripsCard({required this.trips});

  @override
  Widget build(BuildContext context) {
    final byMat = List<Map<String, dynamic>>.from(trips['byMaterial'] as List? ?? []);
    final total = trips['totalBrass'] as num? ?? 0;

    return _SectionCard(
      title: 'TRIPS',
      icon: Icons.swap_horiz,
      color: Colors.blue,
      children: [
        _statRow('Total Trips', '${trips['tripCount'] ?? 0}'),
        const Divider(height: 12),
        ...byMat.map((m) => _statRow(
            m['materialName'] as String? ?? '—',
            '${m['tripCount']} trips · ${numFmt.format(m['totalBrass'] ?? 0)} B')),
        if (byMat.isNotEmpty) const Divider(height: 12),
        _statRow('Grand Total', '${numFmt.format(total)} Brass', bold: true),
      ],
    );
  }
}

class _DabarCard extends StatelessWidget {
  final Map<String, dynamic> dabar;
  const _DabarCard({required this.dabar});

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'DABAR',
        icon: Icons.terrain,
        color: Colors.brown,
        children: [
          _statRow('Entries', '${dabar['entryCount'] ?? 0}'),
          _statRow('Total Trips', '${dabar['totalTrips'] ?? 0}'),
          _statRow('Total Brass',
              '${numFmt.format(dabar['totalBrass'] ?? 0)} B',
              bold: true),
        ],
      );
}

class _WaterTankerCard extends StatelessWidget {
  final Map<String, dynamic> wt;
  const _WaterTankerCard({required this.wt});

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'WATER TANKER',
        icon: Icons.water_drop,
        color: Colors.lightBlue,
        children: [
          _statRow('Entries', '${wt['entryCount'] ?? 0}'),
          _statRow('Hours', '${numFmt.format(wt['totalHours'] ?? 0)} hrs'),
          _statRow('KM', '${numFmt.format(wt['totalKm'] ?? 0)} km'),
          _statRow('Amount', fmtCurr(wt['totalAmount'] ?? 0),
              bold: true),
        ],
      );
}

class _DieselCard extends StatelessWidget {
  final Map<String, dynamic> diesel;
  const _DieselCard({required this.diesel});

  @override
  Widget build(BuildContext context) {
    final stock = (diesel['closingStock'] as num?)?.toDouble() ?? 0;
    final stockColor = stock < 100 ? Colors.red : Colors.teal;
    return _SectionCard(
      title: 'DIESEL',
      icon: Icons.local_gas_station,
      color: Colors.amber.shade800,
      children: [
        _statRow('Received', '${numFmt.format(diesel['receivedToday'] ?? 0)} L'),
        _statRow('Used', '${numFmt.format(diesel['usedToday'] ?? 0)} L'),
        const Divider(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Closing Stock',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('${numFmt.format(stock)} L',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: stockColor)),
          ],
        ),
      ],
    );
  }
}

class _MachineCard extends StatelessWidget {
  final Map<String, dynamic> machine;
  const _MachineCard({required this.machine});

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'MACHINE WORK',
        icon: Icons.construction,
        color: Colors.orange,
        children: [
          _statRow('Entries', '${machine['entryCount'] ?? 0}'),
          _statRow('Bucket', '${numFmt.format(machine['bucketHours'] ?? 0)} hrs'),
          _statRow('Breaker', '${numFmt.format(machine['breakerHours'] ?? 0)} hrs'),
          _statRow('Total Hours',
              '${numFmt.format(machine['totalHours'] ?? 0)} hrs',
              bold: true),
        ],
      );
}

class _AttendanceCard extends StatelessWidget {
  final Map<String, dynamic> att;
  const _AttendanceCard({required this.att});

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'ATTENDANCE',
        icon: Icons.fact_check,
        color: Colors.purple,
        children: [
          _statRow('Present', '${att['present'] ?? 0}',
              bold: true),
          _statRow('Half Day', '${att['halfDay'] ?? 0}'),
          _statRow('Absent',   '${att['absent'] ?? 0}'),
          _statRow('Leave',    '${att['onLeave'] ?? 0}'),
          if ((att['unmarked'] ?? 0) > 0)
            _statRow('Unmarked', '${att['unmarked']}'),
        ],
      );
}

class _FinancialCard extends StatelessWidget {
  final Map<String, dynamic> fin;
  const _FinancialCard({required this.fin});

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'FINANCIAL',
        icon: Icons.account_balance_wallet,
        color: Colors.green.shade700,
        children: [
          if ((fin['invoiceCount'] ?? 0) > 0) ...[
            _statRow('Invoices', '${fin['invoiceCount']}'),
            _statRow('Invoice Amount',
                fmtCurr(fin['invoiceTotal'] ?? 0),
                bold: true),
          ] else
            _statRow('Invoices', 'None today'),
          const Divider(height: 12),
          if ((fin['paymentCount'] ?? 0) > 0) ...[
            _statRow('Payments', '${fin['paymentCount']}'),
            _statRow('Payment Amount',
                fmtCurr(fin['paymentTotal'] ?? 0),
                bold: true),
          ] else
            _statRow('Payments', 'None today'),
        ],
      );
}

// ── Trips detail table ────────────────────────────────────────────────────────

class _TripsDetailTable extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  const _TripsDetailTable({required this.trips});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trip Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.all(color: Colors.grey.shade200),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      _TH('#'), _TH('Vehicle'), _TH('Material'),
                      _TH('Brass'), _TH('Unloading / Ch'),
                      _TH('DSP Challan'), _TH('Vdr Challan'),
                    ],
                  ),
                  ...trips.asMap().entries.map((e) {
                    final i = e.key + 1;
                    final t = e.value;
                    final loc = [
                      if ((t['unloadingLocation'] ?? '').isNotEmpty)
                        t['unloadingLocation'],
                      if ((t['channelNo'] ?? '').isNotEmpty)
                        'Ch:${t['channelNo']}',
                    ].join(' ');
                    return TableRow(children: [
                      _TD('$i'),
                      _TD(t['vehicle'] as String? ?? '—'),
                      _TD(t['material'] as String? ?? '—'),
                      _TD(t['quantityBrass'] != null
                          ? '${numFmt.format(t['quantityBrass'])} B'
                          : '—'),
                      _TD(loc.isEmpty ? '—' : loc),
                      _TD(t['dspChallanNo'] as String? ?? '—'),
                      _TD(t['vendorChallanNo'] as String? ?? '—'),
                    ]);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 11)),
      );
}

class _TD extends StatelessWidget {
  final String text;
  const _TD(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
}
