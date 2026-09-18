import 'dart:html' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/widgets/app_widgets.dart';

// ── Date range preset ─────────────────────────────────────────────────────────

enum _Preset { today, thisWeek, thisMonth, lastMonth, thisYear, prevYear, custom }

class _DR {
  final DateTime from;
  final DateTime to;
  const _DR(this.from, this.to);
}

_DR _range(_Preset p) {
  final n = DateTime.now();
  final fyStart = n.month >= 4
      ? DateTime(n.year, 4, 1)
      : DateTime(n.year - 1, 4, 1);
  return switch (p) {
    _Preset.today     => _DR(DateTime(n.year, n.month, n.day), n),
    _Preset.thisWeek  => _DR(n.subtract(Duration(days: n.weekday - 1)), n),
    _Preset.thisMonth => _DR(DateTime(n.year, n.month, 1), n),
    _Preset.lastMonth => _DR(DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0)),
    _Preset.thisYear  => _DR(fyStart, n),
    _Preset.prevYear  => _DR(DateTime(fyStart.year - 1, 4, 1), DateTime(fyStart.year, 3, 31)),
    _Preset.custom    => _DR(DateTime(n.year, n.month, 1), n),
  };
}

// ── Master data providers ─────────────────────────────────────────────────────

final _vehiclesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

final _machinesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/machines');
  return List<Map<String, dynamic>>.from(res.data);
});

final _materialsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/materials');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

final _sitesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/sites');
  return List<Map<String, dynamic>>.from(res.data);
});

final _employeesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/employees');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── Report provider ───────────────────────────────────────────────────────────

class _ReportKey {
  final String endpoint;
  final Map<String, String> params;
  const _ReportKey(this.endpoint, this.params);

  @override
  bool operator ==(Object o) =>
      o is _ReportKey && o.endpoint == endpoint &&
      const MapEquality<String, String>().equals(o.params, params);

  @override
  int get hashCode => Object.hash(endpoint, params.toString());
}

final _reportProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, _ReportKey>(
        (ref, key) async {
  final res = await ref.read(apiClientProvider)
      .get(key.endpoint, params: key.params);
  return Map<String, dynamic>.from(res.data);
});

class MapEquality<K, V> {
  const MapEquality();
  bool equals(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _role;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _tabs.addListener(() => setState(() {}));
    AuthStorage.getRole().then((r) {
      if (mounted) setState(() => _role = r);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static const _tabLabels = [
    ('Trips',        Icons.swap_horiz_outlined),
    ('Dabar',        Icons.terrain_outlined),
    ('Diesel',       Icons.local_gas_station_outlined),
    ('Machine Work', Icons.construction_outlined),
    ('Attendance',   Icons.people_outline),
    ('Materials',    Icons.inventory_2_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabLabels
                .map((t) => Tab(icon: Icon(t.$2, size: 18), text: t.$1))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TripsReportTab(role: _role),
                _DabarReportTab(role: _role),
                _DieselReportTab(role: _role),
                _MachineWorkReportTab(role: _role),
                _AttendanceReportTab(role: _role),
                _MaterialsReportTab(role: _role),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared filter + report layout ─────────────────────────────────────────────

class _ReportShell extends StatelessWidget {
  final Widget filterArea;
  final _ReportKey? reportKey;
  final List<String> headers;
  final String reportTitle;
  final String filterLabel;
  // Structured filter labels shown in PDF/Excel: key=filter type, value=selected name
  final Map<String, String> filterDetails;

  const _ReportShell({
    required this.filterArea,
    required this.reportKey,
    required this.headers,
    required this.reportTitle,
    required this.filterLabel,
    this.filterDetails = const {},
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: filterArea,
          ),
          Expanded(
            child: reportKey == null
                ? const AppEmptyState(
                    icon: Icons.bar_chart_outlined,
                    message: 'Configure filters and tap Load Report',
                    hint: 'Select a date range and any optional filters',
                  )
                : _ReportData(
                    reportKey: reportKey!,
                    headers: headers,
                    reportTitle: reportTitle,
                    filterLabel: filterLabel,
                    filterDetails: filterDetails,
                  ),
          ),
        ],
      );
}

// ── Report data widget ────────────────────────────────────────────────────────

class _ReportData extends ConsumerWidget {
  final _ReportKey reportKey;
  final List<String> headers;
  final String reportTitle;
  final String filterLabel;
  final Map<String, String> filterDetails;
  const _ReportData({
    required this.reportKey,
    required this.headers,
    required this.reportTitle,
    required this.filterLabel,
    this.filterDetails = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_reportProvider(reportKey));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (d) => _ReportTable(
        data: d,
        headers: headers,
        reportTitle: reportTitle,
        filterLabel: filterLabel,
        filterDetails: filterDetails,
      ),
    );
  }
}

// ── Report table ──────────────────────────────────────────────────────────────

class _ReportTable extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<String> headers;
  final String reportTitle;
  final String filterLabel;
  final Map<String, String> filterDetails;

  static final _dfmt  = DateFormat('d MMM yyyy');
  static final _sfmt  = DateFormat('d MMM yy');
  static final _numFm = NumberFormat('#,##,##0.##', 'en_IN');

  const _ReportTable({
    required this.data,
    required this.headers,
    required this.reportTitle,
    required this.filterLabel,
    this.filterDetails = const {},
  });

  List<Map<String, dynamic>> get _rows =>
      List<Map<String, dynamic>>.from(data['rows'] as List? ?? []);

  Map<String, dynamic> get _summary =>
      Map<String, dynamic>.from(data['summary'] as Map? ?? {});

  DateTime get _from => DateTime.parse(data['fromDate'] as String);
  DateTime get _to   => DateTime.parse(data['toDate'] as String);

  String get _period => '${_sfmt.format(_from)} - ${_sfmt.format(_to)}';

  @override
  Widget build(BuildContext context) {
    final rows  = _rows;
    final sum   = _summary;
    final rtype = data['reportType'] as String? ?? '';
    final cs    = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Detail summary bar ────────────────────────────────────────────────
        Container(
          color: cs.primary.withValues(alpha: 0.04),
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDetailSummary(rtype, sum)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _exportExcel(context),
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: const Text('Excel', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () => _exportPdf(context),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('Print', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        rows.isEmpty
            ? const Expanded(
                child: AppEmptyState(
                  icon: Icons.search_off_outlined,
                  message: 'No records in this period',
                  hint: 'Try a wider date range',
                ),
              )
            : Expanded(
                child: LayoutBuilder(
                  builder: (ctx, outer) {
                    final tableWidth = outer.maxWidth > 700
                        ? outer.maxWidth - 24
                        : 700.0;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Card(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildTable(context, rows, cs),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildDetailSummary(String rtype, Map<String, dynamic> sum) {
    final tiles = <Widget>[];

    void tile(String label, String value, IconData icon, Color color) =>
        tiles.add(_SummaryTile(icon: icon, value: value, label: label, color: color));

    switch (rtype) {
      case 'TRIPS':
        tile('Trips',        '${sum['tripCount'] ?? 0}',
            Icons.swap_horiz, Colors.blue);
        final brass = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        tile('Total Brass',  '${_numFm.format(brass)} Brass',
            Icons.inventory_2_outlined, Colors.green);
        tile('Entries',      '${sum['totalRows'] ?? 0}',
            Icons.list_alt_outlined, Colors.grey.shade600);

      case 'DABAR':
        tile('Entries',      '${sum['totalRows'] ?? 0}',
            Icons.list_alt_outlined, Colors.grey.shade600);
        tile('Total Trips',  '${sum['tripCount'] ?? 0}',
            Icons.swap_horiz, Colors.teal);
        final brassD = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        tile('Total Brass',  '${_numFm.format(brassD)} Brass',
            Icons.inventory_2_outlined, Colors.green);

      case 'DIESEL':
        tile('Opening Stock', '${_numFm.format(sum['openingStock'] ?? 0)} L',
            Icons.water_drop_outlined, Colors.grey.shade600);
        tile('Received',      '${_numFm.format(sum['totalReceived'] ?? 0)} L',
            Icons.add_circle_outline, Colors.green);
        tile('Used',          '${_numFm.format(sum['totalUsed'] ?? 0)} L',
            Icons.remove_circle_outline, Colors.red);
        tile('Closing Stock', '${_numFm.format(sum['closingStock'] ?? 0)} L',
            Icons.water_drop, Colors.teal);

      case 'MACHINE_WORK':
        tile('Total Hours', '${_numFm.format(sum['totalHours'] ?? 0)} hrs',
            Icons.timer_outlined, Colors.orange);
        tile('Bucket',      '${_numFm.format(sum['bucketHours'] ?? 0)} hrs',
            Icons.construction_outlined, Colors.blue);
        tile('Breaker',     '${_numFm.format(sum['breakerHours'] ?? 0)} hrs',
            Icons.hardware_outlined, Colors.deepOrange);
        tile('Entries',     '${sum['totalRows'] ?? 0}',
            Icons.list_alt_outlined, Colors.grey.shade600);

      case 'ATTENDANCE':
        tile('Present',  '${sum['presentCount'] ?? 0}',
            Icons.check_circle_outline, Colors.green);
        tile('Absent',   '${sum['absentCount'] ?? 0}',
            Icons.cancel_outlined, Colors.red);
        tile('Half Day', '${sum['halfDayCount'] ?? 0}',
            Icons.timelapse_outlined, Colors.orange);
        tile('Leave',    '${sum['leaveCount'] ?? 0}',
            Icons.event_busy_outlined, Colors.blue);
        tile('Records',  '${sum['totalRows'] ?? 0}',
            Icons.people_outline, Colors.grey.shade600);

      case 'MATERIALS':
        tile('Entries', '${sum['totalRows'] ?? 0}',
            Icons.list_alt_outlined, Colors.grey.shade600);
        final brassM = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        final tonM   = (sum['totalTon']   as num?)?.toDouble() ?? 0;
        final amtM   = (sum['totalAmount'] as num?)?.toDouble() ?? 0;
        if (brassM > 0)
          tile('Total Brass',  '${_numFm.format(brassM)} Brass',
              Icons.inventory_2_outlined, Colors.green);
        if (tonM > 0)
          tile('Total TON',    '${_numFm.format(tonM)} TON',
              Icons.inventory_2_outlined, Colors.teal);
        if (amtM > 0)
          tile('Total Amount', fmtCurr(amtM),
              Icons.currency_rupee, Colors.orange);
    }

    return Wrap(spacing: 20, runSpacing: 10, children: tiles);
  }

  Widget _buildTable(BuildContext context, List<Map<String, dynamic>> rows,
      ColorScheme cs) {
    final rtype       = data['reportType'] as String? ?? '';
    final sum         = _summary;
    final usedHeaders = headers.where((h) => h.isNotEmpty).toList();
    final totalsRow   = _buildTotalsRow(rtype, sum, usedHeaders);

    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200),
      ),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        TableRow(
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08)),
          children: [const _TH('Date'), ...usedHeaders.map((h) => _TH(h))],
        ),
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final date = r['date'] != null
              ? _dfmt.format(DateTime.parse(r['date'] as String))
              : '—';
          final cols = [
            r['col1'] as String? ?? '—',
            r['col2'] as String? ?? '—',
            r['col3'] as String? ?? '—',
            r['col4'] as String? ?? '—',
            r['col5'] as String? ?? '—',
            r['col6'] as String? ?? '—',
            r['col7'] as String? ?? '—',
          ].take(usedHeaders.length).toList();

          return TableRow(
            decoration: i % 2 == 1
                ? BoxDecoration(color: Colors.grey.shade50) : null,
            children: [_TD(date), ...cols.map((c) => _TD(c))],
          );
        }),
        if (totalsRow != null) totalsRow,
      ],
    );
  }

  // ── Totals row at the bottom of the table ────────────────────────────────────
  // cells[0] = Date column; cells[1..n] map to usedHeaders[0..n-1]
  TableRow? _buildTotalsRow(
      String rtype, Map<String, dynamic> sum, List<String> usedHeaders) {
    if (sum.isEmpty || usedHeaders.isEmpty) return null;

    final numCols = usedHeaders.length + 1; // +1 for date
    final cells   = List<String>.filled(numCols, '');
    cells[0] = 'TOTAL';

    Widget tc(String text, {bool accent = false}) => Container(
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFBBDEFB), width: 1.5))),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text.isEmpty
                  ? Colors.transparent
                  : accent
                      ? Colors.blue.shade800
                      : Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );

    switch (rtype) {
      // Trips: Qty(Brass) in col3 (cells[3]), trip count in cells[4]
      case 'TRIPS':
        if (numCols > 3) cells[3] = '${_numFm.format(sum['totalBrass'] ?? 0)} Brass';
        if (numCols > 4) cells[4] = '${sum['tripCount'] ?? 0} trips';

      // Dabar: Trips in col3 (cells[3]), Brass in col4 (cells[4])
      case 'DABAR':
        if (numCols > 3) cells[3] = '${sum['tripCount'] ?? 0} trips';
        if (numCols > 4) cells[4] = '${_numFm.format(sum['totalBrass'] ?? 0)} Brass';

      // Diesel: Quantity col3 (cells[3]) = received/used; Running Stock col6 (cells[6]) = closing
      case 'DIESEL':
        if (numCols > 3)
          cells[3] = 'Rcvd: ${_numFm.format(sum['totalReceived'] ?? 0)} L  '
              'Used: ${_numFm.format(sum['totalUsed'] ?? 0)} L';
        if (numCols > 6)
          cells[6] = 'Closing: ${_numFm.format(sum['closingStock'] ?? 0)} L';

      // Machine Work: Hours in col6 (cells[6])
      case 'MACHINE_WORK':
        if (numCols > 1) cells[1] = '${sum['totalRows'] ?? 0} entries';
        if (numCols > 6)
          cells[6] = '${_numFm.format(sum['totalHours'] ?? 0)} hrs  '
              '(Bucket ${_numFm.format(sum['bucketHours'] ?? 0)}'
              ' · Breaker ${_numFm.format(sum['breakerHours'] ?? 0)})';

      // Attendance: show breakdown in Status col (cells[2])
      case 'ATTENDANCE':
        if (numCols > 1) cells[1] = '${sum['totalRows'] ?? 0} records';
        if (numCols > 2)
          cells[2] = 'P: ${sum['presentCount'] ?? 0}  '
              'A: ${sum['absentCount'] ?? 0}  '
              'H: ${sum['halfDayCount'] ?? 0}  '
              'L: ${sum['leaveCount'] ?? 0}';

      // Materials: Qty Brass → cells[3], Qty TON → cells[4], Amount → cells[5]
      case 'MATERIALS':
        if (numCols > 1) cells[1] = '${sum['totalRows'] ?? 0} entries';
        final brassM = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        final tonM   = (sum['totalTon']   as num?)?.toDouble() ?? 0;
        final amtM   = (sum['totalAmount'] as num?)?.toDouble() ?? 0;
        if (numCols > 3 && brassM > 0)
          cells[3] = '${_numFm.format(brassM)} Brass';
        if (numCols > 4 && tonM > 0)
          cells[4] = '${_numFm.format(tonM)} TON';
        if (numCols > 5 && amtM > 0)
          cells[5] = fmtCurr(amtM);

      default:
        return null;
    }

    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFE3F2FD)), // blue.shade50
      children: cells.asMap().entries.map((e) => tc(e.value, accent: e.value.isNotEmpty && e.key > 0)).toList(),
    );
  }

  void _exportPdf(BuildContext context) async {
    final rows        = _rows;
    final sum         = _summary;
    final rtype       = data['reportType'] as String? ?? '';
    final usedHeaders = headers.where((h) => h.isNotEmpty).toList();

    final regular     = await PdfGoogleFonts.notoSansRegular();
    final bold        = await PdfGoogleFonts.notoSansBold();
    final companyName = await AuthStorage.getTenantName() ?? 'Your Company';
    final generated   = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());

    // Build summary rows for the Report Summary block
    final sumRows = _buildPdfSummaryRows(rtype, sum);

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      // ── Page header (repeated on every page) ────────────────────────────────
      header: (ctx) {
        final isFirst = ctx.pageNumber == 1;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company + Report title
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            font: bold, fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800)),
                    pw.SizedBox(height: 2),
                    pw.Text(reportTitle,
                        style: pw.TextStyle(
                            font: bold, fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Period: ${DateFormat('d MMM yyyy').format(_from)} — ${DateFormat('d MMM yyyy').format(_to)}',
                        style: pw.TextStyle(font: bold, fontSize: 8)),
                    if (ctx.pageNumber > 1)
                      pw.Text('(continued)',
                          style: pw.TextStyle(
                              font: regular, fontSize: 7,
                              color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            // Applied filters block (first page only; non-empty filters)
            if (isFirst && filterDetails.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.blueGrey300, width: 2),
                  ),
                ),
                child: pw.Wrap(
                  spacing: 24,
                  runSpacing: 3,
                  children: filterDetails.entries.map((e) =>
                    pw.RichText(
                      text: pw.TextSpan(children: [
                        pw.TextSpan(
                            text: '${e.key}: ',
                            style: pw.TextStyle(
                                font: regular, fontSize: 7.5,
                                color: PdfColors.grey600)),
                        pw.TextSpan(
                            text: e.value,
                            style: pw.TextStyle(
                                font: bold, fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold)),
                      ]),
                    ),
                  ).toList(),
                ),
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.8, color: PdfColors.blueGrey200),
          ],
        );
      },
      // ── Page footer ──────────────────────────────────────────────────────────
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: $generated',
              style: pw.TextStyle(font: regular, fontSize: 7,
                  color: PdfColors.grey500)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: regular, fontSize: 7,
                  color: PdfColors.grey500)),
        ],
      ),
      // ── Page content ─────────────────────────────────────────────────────────
      build: (ctx) => [
        // Data table
        pw.TableHelper.fromTextArray(
          headers: ['Date', ...usedHeaders],
          headerStyle: pw.TextStyle(font: bold, fontWeight: pw.FontWeight.bold, fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          cellStyle: pw.TextStyle(font: regular, fontSize: 7),
          data: rows.map((r) {
            final date = r['date'] != null
                ? _dfmt.format(DateTime.parse(r['date'] as String)) : '-';
            final cols = [
              r['col1'] ?? '-', r['col2'] ?? '-', r['col3'] ?? '-',
              r['col4'] ?? '-', r['col5'] ?? '-', r['col6'] ?? '-',
              r['col7'] ?? '-',
            ].take(usedHeaders.length).toList();
            return [date, ...cols];
          }).toList(),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
        ),
        pw.SizedBox(height: 12),
        // ── Report Summary block ─────────────────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header bar
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(3),
                    topRight: pw.Radius.circular(3),
                  ),
                ),
                child: pw.Text('Report Summary',
                    style: pw.TextStyle(
                        font: bold, fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey700)),
              ),
              // Summary rows — two per printed row for compact layout
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: pw.Wrap(
                  spacing: 32,
                  runSpacing: 6,
                  children: sumRows.map((row) => pw.SizedBox(
                    width: 160,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(row[0],
                              style: pw.TextStyle(
                                  font: regular, fontSize: 8,
                                  color: PdfColors.grey700)),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(row[1],
                              style: pw.TextStyle(
                                  font: bold, fontSize: 8,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    ));

    final bytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: '${reportTitle.replaceAll(' ', '_')}_$_period.pdf',
    );
  }

  // Builds label→value pairs for the PDF Report Summary block
  List<List<String>> _buildPdfSummaryRows(
      String rtype, Map<String, dynamic> sum) {
    final rows = <List<String>>[];
    void add(String label, String value) => rows.add([label, value]);

    n(dynamic v) => _numFm.format((v as num?)?.toDouble() ?? 0);
    c(dynamic v) => '₹${n(v)}';

    switch (rtype) {
      case 'TRIPS':
        add('Total Trips',      '${sum['tripCount'] ?? 0}');
        add('Total Entries',    '${sum['totalRows'] ?? 0}');
        final brass = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        final ton   = (sum['totalTon']   as num?)?.toDouble() ?? 0;
        if (brass > 0) add('Total Brass',   '${n(brass)} Brass');
        if (ton   > 0) add('Total TON',     '${n(ton)} TON');
        final amt  = (sum['totalAmount']    as num?)?.toDouble() ?? 0;
        final trsp = (sum['totalTransport'] as num?)?.toDouble() ?? 0;
        if (amt  > 0) add('Total Amount',   c(amt));
        if (trsp > 0) add('Total Transport', c(trsp));

      case 'DABAR':
        add('Total Entries',   '${sum['totalRows'] ?? 0}');
        add('Total Trips',     '${sum['tripCount'] ?? 0}');
        final brassD = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        final tonD   = (sum['totalTon']   as num?)?.toDouble() ?? 0;
        if (brassD > 0) add('Total Brass', '${n(brassD)} Brass');
        if (tonD   > 0) add('Total TON',   '${n(tonD)} TON');
        final amtD = (sum['totalAmount'] as num?)?.toDouble() ?? 0;
        if (amtD > 0) add('Total Amount', c(amtD));

      case 'DIESEL':
        add('Opening Stock',  '${n(sum['openingStock'])} L');
        add('Total Received', '${n(sum['totalReceived'])} L');
        add('Total Used',     '${n(sum['totalUsed'])} L');
        add('Closing Stock',  '${n(sum['closingStock'])} L');
        final amtDsl = (sum['totalAmount'] as num?)?.toDouble() ?? 0;
        if (amtDsl > 0) add('Purchase Amount', c(amtDsl));

      case 'MACHINE_WORK':
        add('Total Entries',  '${sum['totalRows'] ?? 0}');
        add('Total Hours',    '${n(sum['totalHours'])} hrs');
        add('Bucket Hours',   '${n(sum['bucketHours'])} hrs');
        add('Breaker Hours',  '${n(sum['breakerHours'])} hrs');
        final billed = (sum['totalBilledAmount'] as num?)?.toDouble() ?? 0;
        if (billed > 0) add('Total Billed', c(billed));

      case 'ATTENDANCE':
        add('Total Records', '${sum['totalRows'] ?? 0}');
        add('Present',       '${sum['presentCount'] ?? 0}');
        add('Absent',        '${sum['absentCount'] ?? 0}');
        add('Half Day',      '${sum['halfDayCount'] ?? 0}');
        add('Leave',         '${sum['leaveCount'] ?? 0}');

      case 'MATERIALS':
        add('Total Entries', '${sum['totalRows'] ?? 0}');
        final brassM = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        final tonM   = (sum['totalTon']   as num?)?.toDouble() ?? 0;
        final amtM   = (sum['totalAmount'] as num?)?.toDouble() ?? 0;
        if (brassM > 0) add('Total Brass',  '${n(brassM)} Brass');
        if (tonM   > 0) add('Total TON',    '${n(tonM)} TON');
        if (amtM   > 0) add('Total Amount', c(amtM));
    }
    return rows;
  }

  void _exportExcel(BuildContext context) async {
    final rows        = _rows;
    final sum         = _summary;
    final rtype       = data['reportType'] as String? ?? '';
    final usedHeaders = headers.where((h) => h.isNotEmpty).toList();
    final companyName = await AuthStorage.getTenantName() ?? 'Your Company';

    final wb    = xl.Excel.createExcel();
    final sheet = wb['Report'];
    wb.delete('Sheet1');

    void cell(int r, int c, dynamic v) {
      final ce = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      ce.value = v is double
          ? xl.DoubleCellValue(v) : xl.TextCellValue(v.toString());
    }

    cell(0, 0, '$companyName - $reportTitle');
    cell(1, 0, 'Filter: $filterLabel');
    cell(2, 0, 'Period: $_period');
    cell(3, 0, 'Summary: ${_summaryText(rtype, sum)}');
    cell(4, 0, 'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}');

    int col = 0;
    cell(6, col++, 'Date');
    for (final h in usedHeaders) cell(6, col++, h);

    int row = 7;
    for (final r in rows) {
      col = 0;
      final date = r['date'] != null
          ? _dfmt.format(DateTime.parse(r['date'] as String)) : '—';
      cell(row, col++, date);
      final vals = [
        r['col1'] ?? '—', r['col2'] ?? '—', r['col3'] ?? '—',
        r['col4'] ?? '—', r['col5'] ?? '—', r['col6'] ?? '—',
        r['col7'] ?? '—',
      ].take(usedHeaders.length);
      for (final v in vals) cell(row, col++, v);
      row++;
    }

    // ── Totals row (bold, blue-tinted) ───────────────────────────────────────
    final totStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#E3F2FD'),
    );
    final numCols = usedHeaders.length + 1;
    final totCells = List<String>.filled(numCols, '');
    totCells[0] = 'TOTAL';

    switch (rtype) {
      case 'TRIPS':
        if (numCols > 3) totCells[3] = '${_numFm.format(sum['totalBrass'] ?? 0)} Brass';
        if (numCols > 4) totCells[4] = '${sum['tripCount'] ?? 0} trips';
      case 'DABAR':
        if (numCols > 3) totCells[3] = '${sum['tripCount'] ?? 0} trips';
        if (numCols > 4) totCells[4] = '${_numFm.format(sum['totalBrass'] ?? 0)} Brass';
      case 'DIESEL':
        if (numCols > 3)
          totCells[3] = 'Rcvd: ${_numFm.format(sum['totalReceived'] ?? 0)} L  '
              'Used: ${_numFm.format(sum['totalUsed'] ?? 0)} L';
        if (numCols > 6)
          totCells[6] = 'Closing: ${_numFm.format(sum['closingStock'] ?? 0)} L';
      case 'MACHINE_WORK':
        if (numCols > 1) totCells[1] = '${sum['totalRows'] ?? 0} entries';
        if (numCols > 6) {
          final wtHours = sum['workTypeHours'] as Map? ?? {};
          final wtParts = wtHours.entries
              .map((e) => '${e.key} ${_numFm.format((e.value as num?) ?? 0)}h')
              .join(' · ');
          final wtSuffix = wtParts.isNotEmpty ? '  ($wtParts)' : '';
          totCells[6] = '${_numFm.format(sum['totalHours'] ?? 0)} hrs$wtSuffix';
        }
      case 'ATTENDANCE':
        if (numCols > 1) totCells[1] = '${sum['totalRows'] ?? 0} records';
        if (numCols > 2)
          totCells[2] = 'P: ${sum['presentCount'] ?? 0}  '
              'A: ${sum['absentCount'] ?? 0}  '
              'H: ${sum['halfDayCount'] ?? 0}  '
              'L: ${sum['leaveCount'] ?? 0}';
      case 'MATERIALS':
        if (numCols > 1) totCells[1] = '${sum['totalRows'] ?? 0} entries';
        final brassX = (sum['totalBrass'] as num?)?.toDouble() ?? 0;
        final tonX   = (sum['totalTon']   as num?)?.toDouble() ?? 0;
        final amtX   = (sum['totalAmount'] as num?)?.toDouble() ?? 0;
        if (numCols > 3 && brassX > 0) totCells[3] = '${_numFm.format(brassX)} Brass';
        if (numCols > 4 && tonX > 0)   totCells[4] = '${_numFm.format(tonX)} TON';
        if (numCols > 5 && amtX > 0)   totCells[5] = fmtCurr(amtX);
    }
    for (var c = 0; c < totCells.length; c++) {
      cell(row, c, totCells[c]);
      final ce = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      ce.cellStyle = totStyle;
    }

    // encode() serialises to bytes without triggering any browser download.
    // save() also triggers a download (naming it 'FlutterExcel.xlsx') which caused the double-download bug.
    final bytes = wb.encode();
    if (bytes == null) return;

    // Single download via dart:html with the correct report filename
    final filename = '${reportTitle.replaceAll(' ', '_')}.xlsx';
    final blob = html.Blob(
      [Uint8List.fromList(bytes)],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body!.children.add(anchor);
    anchor.click();
    Future.delayed(const Duration(milliseconds: 200), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
  }

  String _summaryText(String rtype, Map<String, dynamic> sum) {
    return switch (rtype) {
      'TRIPS'        => 'Trips: ${sum['tripCount'] ?? 0} | Total Brass: ${_numFm.format(sum['totalBrass'] ?? 0)} Brass | Entries: ${sum['totalRows'] ?? 0}',
      'DABAR'        => 'Entries: ${sum['totalRows'] ?? 0} | Trips: ${sum['tripCount'] ?? 0} | Total Brass: ${_numFm.format(sum['totalBrass'] ?? 0)} Brass',
      'DIESEL'       => 'Opening: ${_numFm.format(sum['openingStock'] ?? 0)} L | Received: ${_numFm.format(sum['totalReceived'] ?? 0)} L | Used: ${_numFm.format(sum['totalUsed'] ?? 0)} L | Closing: ${_numFm.format(sum['closingStock'] ?? 0)} L',
      'MACHINE_WORK' => () {
          final wtHours = sum['workTypeHours'] as Map? ?? {};
          final wtParts = wtHours.entries
              .map((e) => '${e.key}: ${_numFm.format((e.value as num?) ?? 0)} hrs')
              .join(' | ');
          final suffix = wtParts.isNotEmpty ? ' | $wtParts' : '';
          return 'Total: ${_numFm.format(sum['totalHours'] ?? 0)} hrs | Entries: ${sum['totalRows'] ?? 0}$suffix';
        }(),
      'ATTENDANCE'   => 'Present: ${sum['presentCount'] ?? 0} | Absent: ${sum['absentCount'] ?? 0} | Half Day: ${sum['halfDayCount'] ?? 0} | Leave: ${sum['leaveCount'] ?? 0} | Records: ${sum['totalRows'] ?? 0}',
      'MATERIALS'    => 'Entries: ${sum['totalRows'] ?? 0} | Brass: ${_numFm.format(sum['totalBrass'] ?? 0)} | TON: ${_numFm.format(sum['totalTon'] ?? 0)} | Amount: ${fmtCurr((sum['totalAmount'] as num?)?.toDouble() ?? 0)}',
      _              => '',
    };
  }
}

// ── Table cells ───────────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _TD extends StatelessWidget {
  final String text;
  const _TD(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(text,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis),
      );
}

// ── Date bar (stateless) ──────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final _Preset preset;
  final DateTime from, to;
  final void Function(_Preset) onPreset;
  final VoidCallback? onPickFrom, onPickTo;

  static const _presets = [
    ('Today',      _Preset.today),
    ('This Week',  _Preset.thisWeek),
    ('This Month', _Preset.thisMonth),
    ('Last Month', _Preset.lastMonth),
    ('This FY',    _Preset.thisYear),
    ('Prev FY',    _Preset.prevYear),
  ];

  const _DateBar({
    required this.preset,
    required this.from,
    required this.to,
    required this.onPreset,
    this.onPickFrom,
    this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM yy');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, p) in _presets) ...[
            ChoiceChip(
              label: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: preset == p ? cs.onPrimary : null)),
              selected: preset == p,
              selectedColor: cs.primary,
              onSelected: (_) => onPreset(p),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 4),
          _pill(context, Icons.calendar_today, fmt.format(from), onPickFrom),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('→',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ),
          _pill(context, Icons.calendar_today, fmt.format(to), onPickTo),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label, VoidCallback? onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );
}

// ── Active filter chip ────────────────────────────────────────────────────────

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close, size: 12, color: color),
        ),
      ]),
    );
  }
}

// ── Filter area (responsive) ──────────────────────────────────────────────────

class _FilterArea extends StatelessWidget {
  final bool isMobile;
  final _Preset preset;
  final DateTime from, to;
  final void Function(_Preset) onPreset;
  final VoidCallback? onPickFrom, onPickTo;
  final List<Widget> entityPickers;
  final int activeCount;
  final List<Widget> activeChips;
  final VoidCallback onClearAll;
  final VoidCallback onLoad;

  const _FilterArea({
    required this.isMobile,
    required this.preset,
    required this.from,
    required this.to,
    required this.onPreset,
    this.onPickFrom,
    this.onPickTo,
    required this.entityPickers,
    required this.activeCount,
    required this.activeChips,
    required this.onClearAll,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final dateBar = _DateBar(
      preset: preset, from: from, to: to,
      onPreset: onPreset, onPickFrom: onPickFrom, onPickTo: onPickTo,
    );

    final loadBtn = FilledButton.icon(
      onPressed: onLoad,
      icon: const Icon(Icons.bar_chart_outlined, size: 16),
      label: const Text('Load Report'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          dateBar,
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => _showSheet(context),
              icon: Icon(Icons.tune, size: 16,
                  color: activeCount > 0 ? cs.primary : null),
              label: Text(
                activeCount > 0 ? 'Filters ($activeCount)' : 'Filters',
                style: TextStyle(
                    color: activeCount > 0 ? cs.primary : null,
                    fontWeight: activeCount > 0 ? FontWeight.w600 : null),
              ),
              style: activeCount > 0
                  ? OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.primary.withValues(alpha: 0.5)))
                  : null,
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final chip in activeChips) ...[
                        chip, const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          loadBtn,
        ],
      );
    }

    // Desktop: date bar then filter row + load button
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        dateBar,
        if (entityPickers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final picker in entityPickers) ...[
                Expanded(child: picker),
                const SizedBox(width: 8),
              ],
              if (activeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: onClearAll,
                    child: const Text('Clear All'),
                  ),
                ),
              loadBtn,
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: loadBtn),
        ],
      ],
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Filters',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  if (activeCount > 0)
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); onClearAll(); },
                      child: const Text('Clear All'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
                const Divider(height: 16),
                for (final picker in entityPickers) ...[
                  picker,
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: () { Navigator.pop(ctx); onLoad(); },
                  icon: const Icon(Icons.bar_chart_outlined, size: 16),
                  label: const Text('Load Report'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shared per-tab date/filter mixin helpers ──────────────────────────────────
// (Each tab state calls these helpers inline — no mixin needed for brevity)

String? _findLabel(
    AsyncValue<List<Map<String, dynamic>>> async,
    int? id,
    String Function(Map<String, dynamic>) label) {
  if (id == null) return null;
  return async.valueOrNull
      ?.where((m) => m['id'] == id)
      .map(label)
      .firstOrNull;
}

// ── Trips tab ─────────────────────────────────────────────────────────────────

class _TripsReportTab extends ConsumerStatefulWidget {
  final String? role;
  const _TripsReportTab({this.role});

  @override
  ConsumerState<_TripsReportTab> createState() => _TripsReportTabState();
}

class _TripsReportTabState extends ConsumerState<_TripsReportTab> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from, _to;

  int? _vehicleId; String? _vehicleName;
  int? _materialId; String? _materialName;
  int? _vendorId;  String? _vendorName;
  int? _siteId;   String? _siteName;

  _ReportKey? _key;

  @override
  void initState() {
    super.initState();
    final r = _range(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  bool get _showSite => widget.role != 'SITE_STAFF';

  int get _activeCount => [
    _vehicleId, _materialId, _vendorId,
    if (_showSite) _siteId,
  ].where((v) => v != null).length;

  void _clearAll() => setState(() {
    _vehicleId = null; _vehicleName = null;
    _materialId = null; _materialName = null;
    _vendorId = null; _vendorName = null;
    _siteId = null; _siteName = null;
  });

  void _applyPreset(_Preset p) {
    final r = _range(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(context: context, initialDate: _to,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_vehicleId != null)  params['vehicleId']  = '$_vehicleId';
    if (_materialId != null) params['materialId'] = '$_materialId';
    if (_vendorId != null)   params['vendorId']   = '$_vendorId';
    if (_siteId != null)     params['siteId']     = '$_siteId';
    setState(() => _key = _ReportKey('/api/reports/trips', params));
  }

  String get _filterLabel {
    final parts = [
      if (_vehicleName != null) _vehicleName!,
      if (_materialName != null) _materialName!,
      if (_vendorName != null) _vendorName!,
      if (_siteName != null) _siteName!,
    ];
    return parts.isEmpty ? 'All Trips' : parts.join(', ');
  }

  List<Widget> _buildChips() => [
    if (_vehicleName != null) _ActiveChip(
      label: _vehicleName!,
      onRemove: () => setState(() { _vehicleId = null; _vehicleName = null; }),
    ),
    if (_materialName != null) _ActiveChip(
      label: _materialName!,
      onRemove: () => setState(() { _materialId = null; _materialName = null; }),
    ),
    if (_vendorName != null) _ActiveChip(
      label: _vendorName!,
      onRemove: () => setState(() { _vendorId = null; _vendorName = null; }),
    ),
    if (_showSite && _siteName != null) _ActiveChip(
      label: _siteName!,
      onRemove: () => setState(() { _siteId = null; _siteName = null; }),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final vehicles  = ref.watch(_vehiclesProvider);
    final materials = ref.watch(_materialsProvider);
    final vendors   = ref.watch(_vendorsProvider);
    final sites     = ref.watch(_sitesProvider);
    final isMobile  = MediaQuery.of(context).size.width < 700;

    Widget vehiclePicker() => vehicles.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((v) => v['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active,
          itemLabel: (v) => '${v['displayName'] ?? v['plateNumber']}',
          fieldLabel: 'Vehicle',
          value: _vehicleId, clearable: true, clearLabel: 'All Vehicles',
          onChanged: (id) => setState(() {
            _vehicleId = id;
            _vehicleName = _findLabel(
                vehicles, id, (v) => '${v['displayName'] ?? v['plateNumber']}');
          }),
        );
      },
    );

    Widget materialPicker() => materials.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => SearchablePicker(
        items: list, itemLabel: (m) => m['name'] as String,
        fieldLabel: 'Material', value: _materialId,
        clearable: true, clearLabel: 'All Materials',
        onChanged: (id) => setState(() {
          _materialId = id;
          _materialName = _findLabel(materials, id, (m) => m['name'] as String);
        }),
      ),
    );

    Widget vendorPicker() => vendors.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((v) => v['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active, itemLabel: (v) => v['name'] as String,
          fieldLabel: 'Party', value: _vendorId,
          clearable: true, clearLabel: 'All Parties',
          onChanged: (id) => setState(() {
            _vendorId = id;
            _vendorName = _findLabel(vendors, id, (v) => v['name'] as String);
          }),
        );
      },
    );

    Widget sitePicker() => sites.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => SearchablePicker(
        items: list,
        itemLabel: (s) => s['name'] as String? ?? 'Site ${s['id']}',
        fieldLabel: 'Site', value: _siteId,
        clearable: true, clearLabel: 'All Sites',
        onChanged: (id) => setState(() {
          _siteId = id;
          _siteName = _findLabel(
              sites, id, (s) => s['name'] as String? ?? 'Site ${s['id']}');
        }),
      ),
    );

    final pickers = <Widget>[
      vehiclePicker(), materialPicker(), vendorPicker(),
      if (_showSite) sitePicker(),
    ];

    return _ReportShell(
      reportKey: _key,
      headers: const ['Vehicle', 'Material', 'Qty (Brass)', 'Party', 'Challan', 'Channel', 'Loading Location'],
      reportTitle: 'Trips Report',
      filterLabel: _filterLabel,
      filterDetails: {
        if (_vehicleName  != null) 'Vehicle':  _vehicleName!,
        if (_materialName != null) 'Material': _materialName!,
        if (_vendorName   != null) 'Party':    _vendorName!,
        if (_showSite && _siteName != null) 'Site': _siteName!,
      },
      filterArea: _FilterArea(
        isMobile: isMobile, preset: _preset, from: _from, to: _to,
        onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo,
        entityPickers: pickers, activeCount: _activeCount,
        activeChips: _buildChips(), onClearAll: _clearAll, onLoad: _load,
      ),
    );
  }
}

// ── Dabar tab ─────────────────────────────────────────────────────────────────

class _DabarReportTab extends ConsumerStatefulWidget {
  final String? role;
  const _DabarReportTab({this.role});

  @override
  ConsumerState<_DabarReportTab> createState() => _DabarReportTabState();
}

class _DabarReportTabState extends ConsumerState<_DabarReportTab> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from, _to;

  int? _vehicleId; String? _vehicleName;
  int? _vendorId;  String? _vendorName;
  int? _siteId;   String? _siteName;

  _ReportKey? _key;

  @override
  void initState() {
    super.initState();
    final r = _range(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  bool get _showSite => widget.role != 'SITE_STAFF';
  int get _activeCount => [
    _vehicleId, _vendorId, if (_showSite) _siteId,
  ].where((v) => v != null).length;

  void _clearAll() => setState(() {
    _vehicleId = null; _vehicleName = null;
    _vendorId = null; _vendorName = null;
    _siteId = null; _siteName = null;
  });

  void _applyPreset(_Preset p) {
    final r = _range(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(context: context, initialDate: _to,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_vehicleId != null) params['vehicleId'] = '$_vehicleId';
    if (_vendorId != null)  params['vendorId']  = '$_vendorId';
    if (_siteId != null)    params['siteId']    = '$_siteId';
    setState(() => _key = _ReportKey('/api/reports/dabar', params));
  }

  String get _filterLabel {
    final parts = [
      if (_vehicleName != null) _vehicleName!,
      if (_vendorName != null) _vendorName!,
      if (_siteName != null) _siteName!,
    ];
    return parts.isEmpty ? 'All Dabar' : parts.join(', ');
  }

  List<Widget> _buildChips() => [
    if (_vehicleName != null) _ActiveChip(
      label: _vehicleName!,
      onRemove: () => setState(() { _vehicleId = null; _vehicleName = null; }),
    ),
    if (_vendorName != null) _ActiveChip(
      label: _vendorName!,
      onRemove: () => setState(() { _vendorId = null; _vendorName = null; }),
    ),
    if (_showSite && _siteName != null) _ActiveChip(
      label: _siteName!,
      onRemove: () => setState(() { _siteId = null; _siteName = null; }),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(_vehiclesProvider);
    final vendors  = ref.watch(_vendorsProvider);
    final sites    = ref.watch(_sitesProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;

    Widget vehiclePicker() => vehicles.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((v) => v['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active,
          itemLabel: (v) => '${v['displayName'] ?? v['plateNumber']}',
          fieldLabel: 'Vehicle', value: _vehicleId,
          clearable: true, clearLabel: 'All Vehicles',
          onChanged: (id) => setState(() {
            _vehicleId = id;
            _vehicleName = _findLabel(
                vehicles, id, (v) => '${v['displayName'] ?? v['plateNumber']}');
          }),
        );
      },
    );

    Widget vendorPicker() => vendors.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((v) => v['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active, itemLabel: (v) => v['name'] as String,
          fieldLabel: 'Party', value: _vendorId,
          clearable: true, clearLabel: 'All Parties',
          onChanged: (id) => setState(() {
            _vendorId = id;
            _vendorName = _findLabel(vendors, id, (v) => v['name'] as String);
          }),
        );
      },
    );

    Widget sitePicker() => sites.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => SearchablePicker(
        items: list,
        itemLabel: (s) => s['name'] as String? ?? 'Site ${s['id']}',
        fieldLabel: 'Site', value: _siteId,
        clearable: true, clearLabel: 'All Sites',
        onChanged: (id) => setState(() {
          _siteId = id;
          _siteName = _findLabel(
              sites, id, (s) => s['name'] as String? ?? 'Site ${s['id']}');
        }),
      ),
    );

    final pickers = <Widget>[
      vehiclePicker(), vendorPicker(),
      if (_showSite) sitePicker(),
    ];

    return _ReportShell(
      reportKey: _key,
      headers: const ['Vehicle', 'Party', 'Trips', 'Brass', 'Notes', '', ''],
      reportTitle: 'Dabar Report',
      filterLabel: _filterLabel,
      filterDetails: {
        if (_vehicleName != null) 'Vehicle': _vehicleName!,
        if (_vendorName  != null) 'Party':   _vendorName!,
        if (_showSite && _siteName != null) 'Site': _siteName!,
      },
      filterArea: _FilterArea(
        isMobile: isMobile, preset: _preset, from: _from, to: _to,
        onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo,
        entityPickers: pickers, activeCount: _activeCount,
        activeChips: _buildChips(), onClearAll: _clearAll, onLoad: _load,
      ),
    );
  }
}

// ── Diesel tab ────────────────────────────────────────────────────────────────

class _DieselReportTab extends ConsumerStatefulWidget {
  final String? role;
  const _DieselReportTab({this.role});

  @override
  ConsumerState<_DieselReportTab> createState() => _DieselReportTabState();
}

class _DieselReportTabState extends ConsumerState<_DieselReportTab> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from, _to;

  int? _siteId;    String? _siteName;
  int? _vehicleId; String? _vehicleName;
  int? _machineId; String? _machineName;

  _ReportKey? _key;

  @override
  void initState() {
    super.initState();
    final r = _range(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  bool get _showSite => widget.role != 'SITE_STAFF';

  int get _activeCount => [
    if (_showSite) _siteId,
    _vehicleId, _machineId,
  ].where((v) => v != null).length;

  void _clearAll() => setState(() {
    _siteId = null; _siteName = null;
    _vehicleId = null; _vehicleName = null;
    _machineId = null; _machineName = null;
  });

  void _applyPreset(_Preset p) {
    final r = _range(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(context: context, initialDate: _to,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_siteId    != null) params['siteId']    = '$_siteId';
    if (_vehicleId != null) params['vehicleId'] = '$_vehicleId';
    if (_machineId != null) params['machineId'] = '$_machineId';
    setState(() => _key = _ReportKey('/api/reports/diesel', params));
  }

  String get _consumerName => _vehicleName ?? _machineName ?? '';

  List<Widget> _buildChips() => [
    if (_showSite && _siteName != null) _ActiveChip(
      label: _siteName!,
      onRemove: () => setState(() { _siteId = null; _siteName = null; }),
    ),
    if (_vehicleName != null) _ActiveChip(
      label: _vehicleName!,
      onRemove: () => setState(() { _vehicleId = null; _vehicleName = null; }),
    ),
    if (_machineName != null) _ActiveChip(
      label: _machineName!,
      onRemove: () => setState(() { _machineId = null; _machineName = null; }),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sites    = ref.watch(_sitesProvider);
    final vehicles = ref.watch(_vehiclesProvider);
    final machines = ref.watch(_machinesProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;

    Widget sitePicker() => sites.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => SearchablePicker(
        items: list,
        itemLabel: (s) => s['name'] as String? ?? 'Site ${s['id']}',
        fieldLabel: 'Site', value: _siteId,
        clearable: true, clearLabel: 'All Sites',
        onChanged: (id) => setState(() {
          _siteId = id;
          _siteName = _findLabel(
              sites, id, (s) => s['name'] as String? ?? 'Site ${s['id']}');
        }),
      ),
    );

    Widget vehiclePicker() => vehicles.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((v) => v['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active,
          itemLabel: (v) => '${v['displayName'] ?? v['plateNumber']}',
          fieldLabel: 'Vehicle', value: _vehicleId,
          clearable: true, clearLabel: 'All Vehicles',
          onChanged: (id) => setState(() {
            _vehicleId = id;
            _vehicleName = _findLabel(
                vehicles, id, (v) => '${v['displayName'] ?? v['plateNumber']}');
            if (id != null) { _machineId = null; _machineName = null; }
          }),
        );
      },
    );

    Widget machinePicker() => machines.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((m) => m['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active, itemLabel: (m) => m['name'] as String,
          fieldLabel: 'Machine', value: _machineId,
          clearable: true, clearLabel: 'All Machines',
          onChanged: (id) => setState(() {
            _machineId = id;
            _machineName = _findLabel(machines, id, (m) => m['name'] as String);
            if (id != null) { _vehicleId = null; _vehicleName = null; }
          }),
        );
      },
    );

    final pickers = <Widget>[
      if (_showSite) sitePicker(),
      vehiclePicker(),
      machinePicker(),
    ];

    final filterLabel = [
      if (_siteName != null) _siteName!,
      if (_consumerName.isNotEmpty) _consumerName,
    ].join(', ');

    return _ReportShell(
      reportKey: _key,
      headers: const ['Type', 'Source / Used By', 'Quantity', 'Vendor / Machine', 'Amount', 'Running Stock', 'Notes'],
      reportTitle: 'Diesel Ledger Report',
      filterLabel: filterLabel.isEmpty ? 'All Sites' : filterLabel,
      filterDetails: {
        if (_showSite && _siteName != null) 'Site': _siteName!,
        if (_vehicleName != null) 'Vehicle': _vehicleName!,
        if (_machineName != null) 'Machine': _machineName!,
      },
      filterArea: _FilterArea(
        isMobile: isMobile, preset: _preset, from: _from, to: _to,
        onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo,
        entityPickers: pickers, activeCount: _activeCount,
        activeChips: _buildChips(), onClearAll: _clearAll, onLoad: _load,
      ),
    );
  }
}

// ── Machine Work tab ──────────────────────────────────────────────────────────

class _MachineWorkReportTab extends ConsumerStatefulWidget {
  final String? role;
  const _MachineWorkReportTab({this.role});

  @override
  ConsumerState<_MachineWorkReportTab> createState() =>
      _MachineWorkReportTabState();
}

class _MachineWorkReportTabState extends ConsumerState<_MachineWorkReportTab> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from, _to;

  int? _machineId;  String? _machineName;
  int? _customerId; String? _customerName;
  int? _siteId;     String? _siteName;

  _ReportKey? _key;

  @override
  void initState() {
    super.initState();
    final r = _range(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  bool get _showSite => widget.role != 'SITE_STAFF';
  int get _activeCount => [
    _machineId, _customerId, if (_showSite) _siteId,
  ].where((v) => v != null).length;

  void _clearAll() => setState(() {
    _machineId = null; _machineName = null;
    _customerId = null; _customerName = null;
    _siteId = null; _siteName = null;
  });

  void _applyPreset(_Preset p) {
    final r = _range(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(context: context, initialDate: _to,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_machineId  != null) params['machineId']  = '$_machineId';
    if (_customerId != null) params['customerId'] = '$_customerId';
    if (_siteId     != null) params['siteId']     = '$_siteId';
    setState(() => _key = _ReportKey('/api/reports/machine-work', params));
  }

  String get _filterLabel {
    final parts = [
      if (_machineName  != null) _machineName!,
      if (_customerName != null) _customerName!,
      if (_siteName     != null) _siteName!,
    ];
    return parts.isEmpty ? 'All Machines' : parts.join(', ');
  }

  List<Widget> _buildChips() => [
    if (_machineName != null) _ActiveChip(
      label: _machineName!,
      onRemove: () => setState(() { _machineId = null; _machineName = null; }),
    ),
    if (_customerName != null) _ActiveChip(
      label: _customerName!,
      onRemove: () => setState(() { _customerId = null; _customerName = null; }),
    ),
    if (_showSite && _siteName != null) _ActiveChip(
      label: _siteName!,
      onRemove: () => setState(() { _siteId = null; _siteName = null; }),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(_machinesProvider);
    final vendors  = ref.watch(_vendorsProvider);
    final sites    = ref.watch(_sitesProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;

    Widget machinePicker() => machines.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((m) => m['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active, itemLabel: (m) => m['name'] as String,
          fieldLabel: 'Machine', value: _machineId,
          clearable: true, clearLabel: 'All Machines',
          onChanged: (id) => setState(() {
            _machineId = id;
            _machineName = _findLabel(machines, id, (m) => m['name'] as String);
          }),
        );
      },
    );

    Widget customerPicker() => vendors.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((v) => v['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active, itemLabel: (v) => v['name'] as String,
          fieldLabel: 'Party / Customer', value: _customerId,
          clearable: true, clearLabel: 'All Parties',
          onChanged: (id) => setState(() {
            _customerId = id;
            _customerName = _findLabel(vendors, id, (v) => v['name'] as String);
          }),
        );
      },
    );

    Widget sitePicker() => sites.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => SearchablePicker(
        items: list,
        itemLabel: (s) => s['name'] as String? ?? 'Site ${s['id']}',
        fieldLabel: 'Site', value: _siteId,
        clearable: true, clearLabel: 'All Sites',
        onChanged: (id) => setState(() {
          _siteId = id;
          _siteName = _findLabel(
              sites, id, (s) => s['name'] as String? ?? 'Site ${s['id']}');
        }),
      ),
    );

    final pickers = <Widget>[
      machinePicker(), customerPicker(),
      if (_showSite) sitePicker(),
    ];

    return _ReportShell(
      reportKey: _key,
      headers: const ['Machine', 'Mode', 'Description', 'Opening', 'Closing', 'Hours', 'Party / Notes'],
      reportTitle: 'Machine Work Report',
      filterLabel: _filterLabel,
      filterDetails: {
        if (_machineName  != null) 'Machine': _machineName!,
        if (_customerName != null) 'Party':   _customerName!,
        if (_showSite && _siteName != null) 'Site': _siteName!,
      },
      filterArea: _FilterArea(
        isMobile: isMobile, preset: _preset, from: _from, to: _to,
        onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo,
        entityPickers: pickers, activeCount: _activeCount,
        activeChips: _buildChips(), onClearAll: _clearAll, onLoad: _load,
      ),
    );
  }
}

// ── Attendance tab ────────────────────────────────────────────────────────────

class _AttendanceReportTab extends ConsumerStatefulWidget {
  final String? role;
  const _AttendanceReportTab({this.role});

  @override
  ConsumerState<_AttendanceReportTab> createState() => _AttendanceReportTabState();
}

class _AttendanceReportTabState extends ConsumerState<_AttendanceReportTab> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from, _to;

  int? _employeeId; String? _employeeName;

  _ReportKey? _key;

  @override
  void initState() {
    super.initState();
    final r = _range(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  int get _activeCount => _employeeId != null ? 1 : 0;

  void _clearAll() => setState(() { _employeeId = null; _employeeName = null; });

  void _applyPreset(_Preset p) {
    final r = _range(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(context: context, initialDate: _to,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_employeeId != null) params['employeeId'] = '$_employeeId';
    setState(() => _key = _ReportKey('/api/reports/attendance', params));
  }

  String get _filterLabel =>
      _employeeName != null ? _employeeName! : 'All Employees';

  List<Widget> _buildChips() => [
    if (_employeeName != null) _ActiveChip(
      label: _employeeName!,
      onRemove: () => setState(() { _employeeId = null; _employeeName = null; }),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(_employeesProvider);
    final isMobile  = MediaQuery.of(context).size.width < 700;

    Widget employeePicker() => employees.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((e) => e['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active, itemLabel: (e) => e['name'] as String,
          fieldLabel: 'Employee', value: _employeeId,
          clearable: true, clearLabel: 'All Employees',
          onChanged: (id) => setState(() {
            _employeeId = id;
            _employeeName = _findLabel(employees, id, (e) => e['name'] as String);
          }),
        );
      },
    );

    final pickers = <Widget>[employeePicker()];

    return _ReportShell(
      reportKey: _key,
      headers: const ['Employee', 'Status', 'Notes', '', '', '', ''],
      reportTitle: 'Attendance Report',
      filterLabel: _filterLabel,
      filterDetails: {
        if (_employeeName != null) 'Employee': _employeeName!,
      },
      filterArea: _FilterArea(
        isMobile: isMobile, preset: _preset, from: _from, to: _to,
        onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo,
        entityPickers: pickers, activeCount: _activeCount,
        activeChips: _buildChips(), onClearAll: _clearAll, onLoad: _load,
      ),
    );
  }
}

// ── Summary tile widget ───────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryTile({
    required this.icon, required this.value,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
        ],
      );
}

// ── Materials tab ─────────────────────────────────────────────────────────────

class _MaterialsReportTab extends ConsumerStatefulWidget {
  final String? role;
  const _MaterialsReportTab({this.role});

  @override
  ConsumerState<_MaterialsReportTab> createState() =>
      _MaterialsReportTabState();
}

class _MaterialsReportTabState extends ConsumerState<_MaterialsReportTab> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from, _to;

  int? _materialId; String? _materialName;
  int? _vendorId;   String? _vendorName;
  int? _siteId;     String? _siteName;

  _ReportKey? _key;

  @override
  void initState() {
    super.initState();
    final r = _range(_Preset.thisMonth);
    _from = r.from; _to = r.to;
  }

  bool get _showSite => widget.role != 'SITE_STAFF';
  int  get _activeCount => [
    _materialId, _vendorId, if (_showSite) _siteId,
  ].where((v) => v != null).length;

  void _clearAll() => setState(() {
    _materialId = null; _materialName = null;
    _vendorId   = null; _vendorName   = null;
    _siteId     = null; _siteName     = null;
  });

  void _applyPreset(_Preset p) {
    final r = _range(p);
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
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_materialId != null) params['materialId'] = '$_materialId';
    if (_vendorId   != null) params['vendorId']   = '$_vendorId';
    if (_siteId     != null) params['siteId']     = '$_siteId';
    setState(() => _key = _ReportKey('/api/reports/materials', params));
  }

  String get _filterLabel {
    final parts = [
      if (_materialName != null) _materialName!,
      if (_vendorName   != null) _vendorName!,
      if (_siteName     != null) _siteName!,
    ];
    return parts.isEmpty ? 'All Materials' : parts.join(', ');
  }

  List<Widget> _buildChips() => [
    if (_materialName != null) _ActiveChip(
      label: _materialName!,
      onRemove: () => setState(() { _materialId = null; _materialName = null; }),
    ),
    if (_vendorName != null) _ActiveChip(
      label: _vendorName!,
      onRemove: () => setState(() { _vendorId = null; _vendorName = null; }),
    ),
    if (_showSite && _siteName != null) _ActiveChip(
      label: _siteName!,
      onRemove: () => setState(() { _siteId = null; _siteName = null; }),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(_materialsProvider);
    final vendors   = ref.watch(_vendorsProvider);
    final sites     = ref.watch(_sitesProvider);
    final isMobile  = MediaQuery.of(context).size.width < 700;

    Widget materialPicker() => materials.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => SearchablePicker(
        items: list,
        itemLabel: (m) => m['name'] as String,
        fieldLabel: 'Material',
        value: _materialId, clearable: true, clearLabel: 'All Materials',
        onChanged: (id) => setState(() {
          _materialId   = id;
          _materialName = _findLabel(materials, id, (m) => m['name'] as String);
        }),
      ),
    );

    Widget vendorPicker() => vendors.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) {
        final active = list.where((v) => v['status'] == 'ACTIVE').toList();
        return SearchablePicker(
          items: active,
          itemLabel: (v) => v['name'] as String,
          fieldLabel: 'Party / Customer',
          value: _vendorId, clearable: true, clearLabel: 'All Parties',
          onChanged: (id) => setState(() {
            _vendorId   = id;
            _vendorName = _findLabel(vendors, id, (v) => v['name'] as String);
          }),
        );
      },
    );

    Widget sitePicker() => sites.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => SearchablePicker(
        items: list,
        itemLabel: (s) => s['name'] as String? ?? 'Site ${s['id']}',
        fieldLabel: 'Site',
        value: _siteId, clearable: true, clearLabel: 'All Sites',
        onChanged: (id) => setState(() {
          _siteId   = id;
          _siteName = _findLabel(
              sites, id, (s) => s['name'] as String? ?? 'Site ${s['id']}');
        }),
      ),
    );

    final pickers = <Widget>[
      materialPicker(), vendorPicker(),
      if (_showSite) sitePicker(),
    ];

    return _ReportShell(
      reportKey: _key,
      headers: const [
        'Material', 'Party', 'Qty (Brass)', 'Qty (TON)',
        'Amount', 'Vehicle', 'Notes',
      ],
      reportTitle: 'Materials Report',
      filterLabel: _filterLabel,
      filterDetails: {
        if (_materialName != null) 'Material': _materialName!,
        if (_vendorName   != null) 'Party':    _vendorName!,
        if (_showSite && _siteName != null) 'Site': _siteName!,
      },
      filterArea: _FilterArea(
        isMobile: isMobile, preset: _preset, from: _from, to: _to,
        onPreset: _applyPreset, onPickFrom: _pickFrom, onPickTo: _pickTo,
        entityPickers: pickers, activeCount: _activeCount,
        activeChips: _buildChips(), onClearAll: _clearAll, onLoad: _load,
      ),
    );
  }
}
