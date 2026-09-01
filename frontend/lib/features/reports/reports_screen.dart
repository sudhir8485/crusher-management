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

// ── Date range preset ─────────────────────────────────────────────────────────

enum _Preset { today, thisWeek, thisMonth, lastMonth, thisYear, custom }

class _DR {
  final DateTime from;
  final DateTime to;
  const _DR(this.from, this.to);
}

_DR _range(_Preset p) {
  final n = DateTime.now();
  return switch (p) {
    _Preset.today      => _DR(DateTime(n.year, n.month, n.day), n),
    _Preset.thisWeek   => _DR(n.subtract(Duration(days: n.weekday - 1)), n),
    _Preset.thisMonth  => _DR(DateTime(n.year, n.month, 1), n),
    _Preset.lastMonth  => _DR(DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0)),
    _Preset.thisYear   => _DR(n.month >= 4 ? DateTime(n.year, 4, 1) : DateTime(n.year - 1, 4, 1), n),
    _Preset.custom     => _DR(DateTime(n.year, n.month, 1), n),
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
  final res = await ref.read(apiClientProvider).get('/api/vendors');
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static const _tabLabels = [
    ('Vehicles', Icons.directions_car_outlined),
    ('Machines', Icons.construction_outlined),
    ('Diesel',   Icons.local_gas_station_outlined),
    ('Trips',    Icons.swap_horiz_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabs,
          tabs: _tabLabels
              .map((t) => Tab(icon: Icon(t.$2, size: 18), text: t.$1))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _VehicleReportTab(),
          _MachineReportTab(),
          _DieselReportTab(),
          _TripsReportTab(),
        ],
      ),
    );
  }
}

// ── Shared filter + report layout ─────────────────────────────────────────────

class _ReportShell extends StatefulWidget {
  final Widget filterRow;
  final _ReportKey? reportKey;
  final List<String> headers;
  final String reportTitle;
  final String filterLabel;
  const _ReportShell({
    required this.filterRow,
    required this.reportKey,
    required this.headers,
    required this.reportTitle,
    required this.filterLabel,
  });

  @override
  State<_ReportShell> createState() => _ReportShellState();
}

class _ReportShellState extends State<_ReportShell> {
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter section
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: widget.filterRow,
          ),
          // Data
          Expanded(
            child: widget.reportKey == null
                ? const AppEmptyState(
                    icon: Icons.bar_chart_outlined,
                    message: 'Configure filters above and tap Load Report',
                    hint: 'Select date range and optionally filter by entity',
                  )
                : _ReportData(
                    reportKey: widget.reportKey!,
                    headers: widget.headers,
                    reportTitle: widget.reportTitle,
                    filterLabel: widget.filterLabel,
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
  const _ReportData({
    required this.reportKey,
    required this.headers,
    required this.reportTitle,
    required this.filterLabel,
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

  static final _dfmt  = DateFormat('d MMM yyyy');
  static final _sfmt  = DateFormat('d MMM yy');
  static final _numFm = NumberFormat('#,##,##0.##', 'en_IN');

  const _ReportTable({
    required this.data,
    required this.headers,
    required this.reportTitle,
    required this.filterLabel,
  });

  List<Map<String, dynamic>> get _rows =>
      List<Map<String, dynamic>>.from(data['rows'] as List? ?? []);

  Map<String, dynamic> get _summary =>
      Map<String, dynamic>.from(data['summary'] as Map? ?? {});

  DateTime get _from => DateTime.parse(data['fromDate'] as String);
  DateTime get _to   => DateTime.parse(data['toDate'] as String);

  String get _period => '${_sfmt.format(_from)} – ${_sfmt.format(_to)}';

  @override
  Widget build(BuildContext context) {
    final rows  = _rows;
    final sum   = _summary;
    final rtype = data['reportType'] as String? ?? '';
    final cs    = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Summary + export bar
        Container(
          color: cs.primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(child: _summaryChips(rtype, sum)),
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
        // Table
        rows.isEmpty
            ? const Expanded(
                child: AppEmptyState(
                  icon: Icons.search_off_outlined,
                  message: 'No records in this period',
                  hint: 'Try a wider date range',
                ),
              )
            : Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildTable(context, rows, cs),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _summaryChips(String rtype, Map<String, dynamic> sum) {
    final chips = <Widget>[];
    void add(String label, String value, Color color) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ));
    }

    switch (rtype) {
      case 'VEHICLE_LOG':
        add('Total KM',    '${_numFm.format(sum['totalKm'] ?? 0)} km', Colors.teal);
        add('Total Trips', '${sum['totalTrips'] ?? 0}', Colors.blue);
        add('Entries',     '${sum['totalRows'] ?? 0}', Colors.grey);
      case 'MACHINE_WORK':
        add('Total Hours',   '${_numFm.format(sum['totalHours'] ?? 0)} hrs', Colors.orange);
        add('Bucket',        '${_numFm.format(sum['bucketHours'] ?? 0)} hrs', Colors.blue);
        add('Breaker',       '${_numFm.format(sum['breakerHours'] ?? 0)} hrs', Colors.orange);
        add('Entries',       '${sum['totalRows'] ?? 0}', Colors.grey);
      case 'DIESEL':
        add('Opening Stock', '${_numFm.format(sum['openingStock'] ?? 0)} L', Colors.grey);
        add('Received',      '${_numFm.format(sum['totalReceived'] ?? 0)} L', Colors.green);
        add('Used',          '${_numFm.format(sum['totalUsed'] ?? 0)} L', Colors.red);
        add('Closing Stock', '${_numFm.format(sum['closingStock'] ?? 0)} L', Colors.teal);
      case 'TRIPS':
        add('Trips',     '${sum['tripCount'] ?? 0}', Colors.blue);
        add('Total Brass', '${_numFm.format(sum['totalBrass'] ?? 0)} Brass', Colors.green);
    }

    return Wrap(children: chips);
  }

  Widget _buildTable(BuildContext context, List<Map<String, dynamic>> rows,
      ColorScheme cs) {
    final usedHeaders = headers.where((h) => h.isNotEmpty).toList();
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200),
      ),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        // Header
        TableRow(
          decoration:
              BoxDecoration(color: cs.primary.withValues(alpha: 0.08)),
          children: [
            const _TH('Date'),
            ...usedHeaders.map((h) => _TH(h)),
          ],
        ),
        // Data rows
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
                ? BoxDecoration(color: Colors.grey.shade50)
                : null,
            children: [
              _TD(date),
              ...cols.map((c) => _TD(c)),
            ],
          );
        }),
      ],
    );
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  void _exportPdf(BuildContext context) async {
    final rows       = _rows;
    final sum        = _summary;
    final rtype      = data['reportType'] as String? ?? '';
    final usedHeaders = headers.where((h) => h.isNotEmpty).toList();

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DSP Construction',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('$reportTitle — $filterLabel',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: $_period',
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(_summaryText(rtype, sum),
              style: const pw.TextStyle(fontSize: 9)),
          pw.Divider(),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', ...usedHeaders],
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 7),
          data: rows.map((r) {
            final date = r['date'] != null
                ? _dfmt.format(DateTime.parse(r['date'] as String))
                : '—';
            final cols = [
              r['col1'] ?? '—', r['col2'] ?? '—', r['col3'] ?? '—',
              r['col4'] ?? '—', r['col5'] ?? '—', r['col6'] ?? '—',
              r['col7'] ?? '—',
            ].take(usedHeaders.length).toList();
            return [date, ...cols];
          }).toList(),
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColors.grey50),
        ),
      ],
    ));

    final bytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name:
          '${reportTitle}_${filterLabel.replaceAll(' ', '_')}_$_period.pdf',
    );
  }

  // ── Excel ─────────────────────────────────────────────────────────────────

  void _exportExcel(BuildContext context) async {
    final rows        = _rows;
    final sum         = _summary;
    final rtype       = data['reportType'] as String? ?? '';
    final usedHeaders = headers.where((h) => h.isNotEmpty).toList();

    final wb    = xl.Excel.createExcel();
    final sheet = wb['Report'];
    wb.delete('Sheet1');

    void cell(int r, int c, dynamic v) {
      final ce = sheet.cell(xl.CellIndex.indexByColumnRow(
          columnIndex: c, rowIndex: r));
      ce.value = v is double
          ? xl.DoubleCellValue(v)
          : xl.TextCellValue(v.toString());
    }

    cell(0, 0, 'DSP Construction — $reportTitle');
    cell(1, 0, 'Filter: $filterLabel');
    cell(2, 0, 'Period: $_period');
    cell(3, 0, 'Summary: ${_summaryText(rtype, sum)}');
    cell(4, 0,
        'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}');

    // Header row
    int col = 0;
    cell(6, col++, 'Date');
    for (final h in usedHeaders) {
      cell(6, col++, h);
    }

    // Data
    int row = 7;
    for (final r in rows) {
      col = 0;
      final date = r['date'] != null
          ? _dfmt.format(DateTime.parse(r['date'] as String))
          : '—';
      cell(row, col++, date);
      final vals = [
        r['col1'] ?? '—', r['col2'] ?? '—', r['col3'] ?? '—',
        r['col4'] ?? '—', r['col5'] ?? '—', r['col6'] ?? '—',
        r['col7'] ?? '—',
      ].take(usedHeaders.length);
      for (final v in vals) {
        cell(row, col++, v);
      }
      row++;
    }

    final bytes = wb.save();
    if (bytes == null) return;
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: '${reportTitle.replaceAll(' ', '_')}.xlsx',
    );
  }

  String _summaryText(String rtype, Map<String, dynamic> sum) {
    return switch (rtype) {
      'VEHICLE_LOG'  => 'Total KM: ${_numFm.format(sum['totalKm'] ?? 0)} km | Trips: ${sum['totalTrips'] ?? 0}',
      'MACHINE_WORK' => 'Total: ${_numFm.format(sum['totalHours'] ?? 0)} hrs | Bucket: ${_numFm.format(sum['bucketHours'] ?? 0)} | Breaker: ${_numFm.format(sum['breakerHours'] ?? 0)}',
      'DIESEL'       => 'Opening: ${_numFm.format(sum['openingStock'] ?? 0)} L | Received: ${_numFm.format(sum['totalReceived'] ?? 0)} L | Used: ${_numFm.format(sum['totalUsed'] ?? 0)} L | Closing: ${_numFm.format(sum['closingStock'] ?? 0)} L',
      'TRIPS'        => 'Trips: ${sum['tripCount'] ?? 0} | Total Brass: ${_numFm.format(sum['totalBrass'] ?? 0)} Brass',
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
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold)),
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

// ── Shared date range filter ──────────────────────────────────────────────────

class _DateRangeFilter extends StatefulWidget {
  final void Function(DateTime from, DateTime to) onChanged;
  const _DateRangeFilter({required this.onChanged});

  @override
  State<_DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<_DateRangeFilter> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final r = _range(_Preset.thisMonth);
    _from = r.from;
    _to = r.to;
  }

  void _apply(_Preset p) {
    final r = _range(p);
    setState(() {
      _preset = p;
      _from = r.from;
      _to = r.to;
    });
    widget.onChanged(_from, _to);
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _from,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (d != null) {
      setState(() {
        _from = d;
        _preset = _Preset.custom;
      });
      widget.onChanged(_from, _to);
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _to,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) {
      setState(() {
        _to = d;
        _preset = _Preset.custom;
      });
      widget.onChanged(_from, _to);
    }
  }

  static const _presets = [
    ('Today',      _Preset.today),
    ('This Week',  _Preset.thisWeek),
    ('This Month', _Preset.thisMonth),
    ('Last Month', _Preset.lastMonth),
    ('This FY',    _Preset.thisYear),
  ];

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yy');
    return Column(
      children: [
        // Preset chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._presets.map((p) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p.$1,
                          style: const TextStyle(fontSize: 11)),
                      selected: _preset == p.$2,
                      onSelected: (_) => _apply(p.$2),
                      visualDensity: VisualDensity.compact,
                    ),
                  )),
              const SizedBox(width: 8),
              // Custom from/to
              _datePill(fmt.format(_from), _pickFrom),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('→',
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
              _datePill(fmt.format(_to), _pickTo),
            ],
          ),
        ),
      ],
    );
  }

  Widget _datePill(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
}

// ── Vehicle tab ───────────────────────────────────────────────────────────────

class _VehicleReportTab extends ConsumerStatefulWidget {
  const _VehicleReportTab();

  @override
  ConsumerState<_VehicleReportTab> createState() => _VehicleReportTabState();
}

class _VehicleReportTabState extends ConsumerState<_VehicleReportTab> {
  int? _vehicleId;
  _ReportKey? _key;
  DateTime _from = _range(_Preset.thisMonth).from;
  DateTime _to   = _range(_Preset.thisMonth).to;

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_vehicleId != null) params['vehicleId'] = _vehicleId.toString();
    setState(() => _key = _ReportKey('/api/reports/vehicle-log', params));
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(_vehiclesProvider);
    return _ReportShell(
      reportKey: _key,
      headers: const ['Vehicle', 'From', 'To', 'KM', 'Day/Night', 'Total Trips', 'Diesel Note'],
      reportTitle: 'Vehicle Daily Log Report',
      filterLabel: _vehicleId == null ? 'All Vehicles' : 'Vehicle $_vehicleId',
      filterRow: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          vehicles.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (list) => Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    decoration: _dropDec('Vehicle'),
                    value: _vehicleId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Vehicles')),
                      ...list.where((v) => v['status'] == 'ACTIVE').map((v) =>
                          DropdownMenuItem(
                            value: v['id'] as int,
                            child: Text(
                              '${v['displayName'] ?? v['plateNumber']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (v) => setState(() => _vehicleId = v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Load'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _DateRangeFilter(
              onChanged: (f, t) => setState(() {
                    _from = f;
                    _to = t;
                  })),
        ],
      ),
    );
  }
}

// ── Machine tab ───────────────────────────────────────────────────────────────

class _MachineReportTab extends ConsumerStatefulWidget {
  const _MachineReportTab();

  @override
  ConsumerState<_MachineReportTab> createState() => _MachineReportTabState();
}

class _MachineReportTabState extends ConsumerState<_MachineReportTab> {
  int? _machineId;
  _ReportKey? _key;
  DateTime _from = _range(_Preset.thisMonth).from;
  DateTime _to   = _range(_Preset.thisMonth).to;

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_machineId != null) params['machineId'] = _machineId.toString();
    setState(() => _key = _ReportKey('/api/reports/machine-work', params));
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(_machinesProvider);
    return _ReportShell(
      reportKey: _key,
      headers: const ['Machine', 'Mode', 'Description', 'Opening', 'Closing', 'Hours', 'Notes'],
      reportTitle: 'Machine Work Report',
      filterLabel: _machineId == null ? 'All Machines' : 'Machine $_machineId',
      filterRow: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          machines.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (list) => Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    decoration: _dropDec('Machine'),
                    value: _machineId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Machines')),
                      ...list.where((m) => m['status'] == 'ACTIVE').map((m) =>
                          DropdownMenuItem(
                            value: m['id'] as int,
                            child: Text(m['name'] as String,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _machineId = v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Load'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _DateRangeFilter(
              onChanged: (f, t) => setState(() {
                    _from = f;
                    _to = t;
                  })),
        ],
      ),
    );
  }
}

// ── Diesel tab ────────────────────────────────────────────────────────────────

class _DieselReportTab extends ConsumerStatefulWidget {
  const _DieselReportTab();

  @override
  ConsumerState<_DieselReportTab> createState() => _DieselReportTabState();
}

class _DieselReportTabState extends ConsumerState<_DieselReportTab> {
  _ReportKey? _key;
  DateTime _from = _range(_Preset.thisMonth).from;
  DateTime _to   = _range(_Preset.thisMonth).to;

  void _load() {
    setState(() => _key = _ReportKey('/api/reports/diesel', {
          'from': DateFormat('yyyy-MM-dd').format(_from),
          'to':   DateFormat('yyyy-MM-dd').format(_to),
        }));
  }

  @override
  Widget build(BuildContext context) {
    return _ReportShell(
      reportKey: _key,
      headers: const ['Type', 'Source / Used By', 'Quantity', 'Vendor / Machine', 'Amount', 'Running Stock', 'Notes'],
      reportTitle: 'Diesel Ledger Report',
      filterLabel: 'All',
      filterRow: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Diesel report shows all receipts and usage with running stock balance.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Load'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DateRangeFilter(
              onChanged: (f, t) => setState(() {
                    _from = f;
                    _to = t;
                  })),
        ],
      ),
    );
  }
}

// ── Trips tab ─────────────────────────────────────────────────────────────────

class _TripsReportTab extends ConsumerStatefulWidget {
  const _TripsReportTab();

  @override
  ConsumerState<_TripsReportTab> createState() => _TripsReportTabState();
}

class _TripsReportTabState extends ConsumerState<_TripsReportTab> {
  int? _vehicleId;
  int? _materialId;
  int? _vendorId;
  _ReportKey? _key;
  DateTime _from = _range(_Preset.thisMonth).from;
  DateTime _to   = _range(_Preset.thisMonth).to;

  void _load() {
    final params = <String, String>{
      'from': DateFormat('yyyy-MM-dd').format(_from),
      'to':   DateFormat('yyyy-MM-dd').format(_to),
    };
    if (_vehicleId != null)  params['vehicleId']  = _vehicleId.toString();
    if (_materialId != null) params['materialId'] = _materialId.toString();
    if (_vendorId != null)   params['vendorId']   = _vendorId.toString();
    setState(() => _key = _ReportKey('/api/reports/trips', params));
  }

  @override
  Widget build(BuildContext context) {
    final vehicles  = ref.watch(_vehiclesProvider);
    final materials = ref.watch(_materialsProvider);
    final vendors   = ref.watch(_vendorsProvider);

    return _ReportShell(
      reportKey: _key,
      headers: const ['Vehicle', 'Material', 'Qty (Brass)', 'Vendor', 'Challan', 'Channel', 'Loading Location'],
      reportTitle: 'Trips Report',
      filterLabel: _filterLabel,
      filterRow: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 dropdowns in a row
          Row(
            children: [
              Expanded(child: vehicles.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) => DropdownButtonFormField<int?>(
                  decoration: _dropDec('Vehicle'),
                  value: _vehicleId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Vehicles')),
                    ...list.where((v) => v['status'] == 'ACTIVE').map((v) =>
                        DropdownMenuItem(value: v['id'] as int,
                            child: Text('${v['displayName'] ?? v['plateNumber']}',
                                overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: materials.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) => DropdownButtonFormField<int?>(
                  decoration: _dropDec('Material'),
                  value: _materialId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Materials')),
                    ...list.map((m) => DropdownMenuItem(value: m['id'] as int,
                        child: Text(m['name'] as String, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _materialId = v),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: vendors.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) => DropdownButtonFormField<int?>(
                  decoration: _dropDec('Vendor'),
                  value: _vendorId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Vendors')),
                    ...list.where((v) => v['status'] == 'ACTIVE').map((v) =>
                        DropdownMenuItem(value: v['id'] as int,
                            child: Text(v['name'] as String, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _vendorId = v),
                ),
              )),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Load'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DateRangeFilter(
              onChanged: (f, t) => setState(() {
                    _from = f;
                    _to = t;
                  })),
        ],
      ),
    );
  }

  String get _filterLabel {
    if (_vehicleId != null)  return 'Vehicle filter';
    if (_materialId != null) return 'Material filter';
    if (_vendorId != null)   return 'Vendor filter';
    return 'All Trips';
  }
}

// ── Shared decoration ─────────────────────────────────────────────────────────

InputDecoration _dropDec(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
    );
