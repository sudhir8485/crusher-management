import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final _attendanceDateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final _attendanceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, date) async {
  final res = await ref
      .read(apiClientProvider)
      .get('/api/attendance', params: {'date': date});
  return Map<String, dynamic>.from(res.data as Map);
});

// Month in "yyyy-MM" format
final _monthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return DateFormat('yyyy-MM').format(now);
});

final _monthlyProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, month) async {
  final res = await ref
      .read(apiClientProvider)
      .get('/api/attendance/monthly', params: {'month': month});
  return Map<String, dynamic>.from(res.data as Map);
});

// ── status config ─────────────────────────────────────────────────────────────

const _statuses = ['PRESENT', 'HALF_DAY', 'ABSENT', 'LEAVE'];

const _statusLabels = {
  'PRESENT': 'Present',
  'HALF_DAY': 'Half Day',
  'ABSENT': 'Absent',
  'LEAVE': 'Leave',
};

const _statusColors = {
  'PRESENT': Colors.green,
  'HALF_DAY': Colors.orange,
  'ABSENT': Colors.red,
  'LEAVE': Colors.blue,
};

const _statusShort = {
  'PRESENT': 'P',
  'HALF_DAY': 'H',
  'ABSENT': 'A',
  'LEAVE': 'L',
};

// ── screen ────────────────────────────────────────────────────────────────────

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Monthly'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DailyTab(),
            _MonthlyTab(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Daily tab
// ══════════════════════════════════════════════════════════════════════════════

class _DailyTab extends ConsumerWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_attendanceDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final data = ref.watch(_attendanceProvider(dateKey));

    return Column(
      children: [
        AppDateBar(
          selectedDate: selectedDate,
          onPick: (d) =>
              ref.read(_attendanceDateProvider.notifier).state = d,
        ),
        data.when(
          loading: () => const SizedBox(),
          error: (_, s) => const SizedBox(),
          data: (d) => _SummaryBar(data: d),
        ),
        Expanded(
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (d) {
              final employees = List<Map<String, dynamic>>.from(
                  d['employees'] as List? ?? []);
              if (employees.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.people_outline,
                  message: 'No active employees',
                  hint: 'Add employees in the Employees section',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: employees.length,
                separatorBuilder: (_, idx) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _EmployeeAttendanceTile(
                  emp: employees[i],
                  date: dateKey,
                  onMarked: () =>
                      ref.invalidate(_attendanceProvider(dateKey)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final present  = data['presentCount']  as int? ?? 0;
    final halfDay  = data['halfDayCount']  as int? ?? 0;
    final absent   = data['absentCount']   as int? ?? 0;
    final leave    = data['leaveCount']    as int? ?? 0;
    final unmarked = data['unmarkedCount'] as int? ?? 0;

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SummaryChip('Present', present, Colors.green),
          _SummaryChip('Half', halfDay, Colors.orange),
          _SummaryChip('Absent', absent, Colors.red),
          _SummaryChip('Leave', leave, Colors.blue),
          if (unmarked > 0) _SummaryChip('Unmarked', unmarked, Colors.grey),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('$count',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      );
}

// ── employee attendance tile ──────────────────────────────────────────────────

class _EmployeeAttendanceTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> emp;
  final String date;
  final VoidCallback onMarked;
  const _EmployeeAttendanceTile(
      {required this.emp, required this.date, required this.onMarked});

  @override
  ConsumerState<_EmployeeAttendanceTile> createState() =>
      _EmployeeAttendanceTileState();
}

class _EmployeeAttendanceTileState
    extends ConsumerState<_EmployeeAttendanceTile> {
  bool _saving = false;

  Future<void> _mark(String status) async {
    setState(() => _saving = true);
    await ref.read(apiClientProvider).post('/api/attendance/mark', data: {
      'date': widget.date,
      'employeeId': widget.emp['employeeId'],
      'status': status,
    });
    widget.onMarked();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.emp['employeeName'] as String? ?? '—';
    final designation = (widget.emp['designation'] as String?)?.trim() ?? '';
    final wageType = widget.emp['wageType'] as String? ?? 'DAILY';
    final currentStatus = widget.emp['attendanceStatus'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: currentStatus != null
                  ? (_statusColors[currentStatus] ?? Colors.grey)
                      .withValues(alpha: 0.15)
                  : Colors.grey[200],
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: currentStatus != null
                      ? (_statusColors[currentStatus] ?? Colors.grey)
                      : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (designation.isNotEmpty || wageType.isNotEmpty)
                    Text(
                      [
                        if (designation.isNotEmpty) designation,
                        wageType == 'MONTHLY' ? 'Monthly' : 'Daily',
                      ].join(' · '),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            if (_saving)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Wrap(
                spacing: 6,
                children: _statuses.map((s) {
                  final isSelected = currentStatus == s;
                  final color = _statusColors[s]!;
                  return GestureDetector(
                    onTap: () => _mark(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _statusLabels[s]!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Monthly tab
// ══════════════════════════════════════════════════════════════════════════════

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_monthProvider);
    final data = ref.watch(_monthlyProvider(month));

    final parsed = DateTime.parse('$month-01');
    final monthLabel = DateFormat('MMMM yyyy').format(parsed);

    return Column(
      children: [
        // Month navigator
        Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final prev = DateTime(parsed.year, parsed.month - 1);
                  ref.read(_monthProvider.notifier).state =
                      DateFormat('yyyy-MM').format(prev);
                },
              ),
              Expanded(
                child: Text(monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final next = DateTime(parsed.year, parsed.month + 1);
                  final now = DateTime.now();
                  if (next.year > now.year ||
                      (next.year == now.year && next.month > now.month)) {
                    return; // don't go into future months
                  }
                  ref.read(_monthProvider.notifier).state =
                      DateFormat('yyyy-MM').format(next);
                },
              ),
              data.whenOrNull(
                data: (d) => IconButton(
                  icon: const Icon(Icons.table_chart_outlined),
                  tooltip: 'Export Excel',
                  onPressed: () => _exportExcel(d, monthLabel),
                ),
              ) ?? const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (d) {
              final employees = List<Map<String, dynamic>>.from(
                  d['employees'] as List? ?? []);
              final daysInMonth = d['daysInMonth'] as int? ?? 30;
              if (employees.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.people_outline,
                  message: 'No active employees',
                  hint: 'Add employees in the Employees section',
                );
              }
              return _MonthGrid(
                  employees: employees,
                  daysInMonth: daysInMonth,
                  month: month);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _exportExcel(Map<String, dynamic> d, String monthLabel) async {
    final employees = List<Map<String, dynamic>>.from(
        d['employees'] as List? ?? []);
    final daysInMonth = d['daysInMonth'] as int? ?? 30;

    final wb = xl.Excel.createExcel();
    final sheet = wb['Attendance'];

    // Header row: Name | 1..N | P | H | A | L
    final headers = <String>['Employee'];
    for (int i = 1; i <= daysInMonth; i++) {
      headers.add('$i');
    }
    headers.addAll(['Present', 'Half Day', 'Absent', 'Leave']);

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = xl.TextCellValue(headers[i]);
    }

    for (var ri = 0; ri < employees.length; ri++) {
      final emp = employees[ri];
      final name = emp['employeeName'] as String? ?? '—';
      final days = List<String?>.from(emp['days'] as List? ?? []);
      final rowIndex = ri + 1;

      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: rowIndex))
          .value = xl.TextCellValue(name);

      for (var di = 0; di < days.length; di++) {
        final status = days[di];
        sheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: di + 1, rowIndex: rowIndex))
            .value = xl.TextCellValue(
                status != null ? (_statusShort[status] ?? status) : '');
      }

      final colBase = daysInMonth + 1;
      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: colBase, rowIndex: rowIndex))
          .value = xl.IntCellValue(emp['presentCount'] as int? ?? 0);
      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: colBase + 1, rowIndex: rowIndex))
          .value = xl.IntCellValue(emp['halfDayCount'] as int? ?? 0);
      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: colBase + 2, rowIndex: rowIndex))
          .value = xl.IntCellValue(emp['absentCount'] as int? ?? 0);
      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: colBase + 3, rowIndex: rowIndex))
          .value = xl.IntCellValue(emp['leaveCount'] as int? ?? 0);
    }

    final bytes = wb.save();
    if (bytes == null) return;
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'Attendance_$monthLabel.xlsx',
    );
  }
}

// ── monthly grid ──────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final List<Map<String, dynamic>> employees;
  final int daysInMonth;
  final String month;

  const _MonthGrid({
    required this.employees,
    required this.daysInMonth,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const nameWidth = 130.0;
    const dayWidth = 32.0;
    const summaryWidth = 40.0;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: nameWidth +
                (dayWidth * daysInMonth) +
                (summaryWidth * 4) +
                16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Container(
                color: cs.primary.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    SizedBox(
                      width: nameWidth,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text('Employee',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                    ...List.generate(daysInMonth, (i) {
                      final day = i + 1;
                      // Highlight today
                      final parsed = DateTime.parse('$month-01');
                      final now = DateTime.now();
                      final isToday = parsed.year == now.year &&
                          parsed.month == now.month &&
                          day == now.day;
                      return SizedBox(
                        width: dayWidth,
                        child: Center(
                          child: Text('$day',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isToday
                                      ? cs.primary
                                      : Colors.grey[700])),
                        ),
                      );
                    }),
                    SizedBox(
                      width: summaryWidth,
                      child: Center(
                        child: Text('P',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700])),
                      ),
                    ),
                    SizedBox(
                      width: summaryWidth,
                      child: Center(
                        child: Text('H',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700])),
                      ),
                    ),
                    SizedBox(
                      width: summaryWidth,
                      child: Center(
                        child: Text('A',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700])),
                      ),
                    ),
                    SizedBox(
                      width: summaryWidth,
                      child: Center(
                        child: Text('L',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700])),
                      ),
                    ),
                  ],
                ),
              ),
              // Employee rows
              ...employees.asMap().entries.map((entry) {
                final i = entry.key;
                final emp = entry.value;
                final name = emp['employeeName'] as String? ?? '—';
                final days = List<String?>.from(emp['days'] as List? ?? []);
                final p = emp['presentCount'] as int? ?? 0;
                final h = emp['halfDayCount'] as int? ?? 0;
                final a = emp['absentCount'] as int? ?? 0;
                final l = emp['leaveCount'] as int? ?? 0;

                return Container(
                  color: i.isEven ? Colors.transparent : Colors.grey[50],
                  child: Row(
                    children: [
                      SizedBox(
                        width: nameWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      ...List.generate(daysInMonth, (di) {
                        final status = di < days.length ? days[di] : null;
                        final short = status != null
                            ? (_statusShort[status] ?? '?')
                            : '·';
                        final color = status != null
                            ? (_statusColors[status] ?? Colors.grey)
                            : Colors.grey[300]!;
                        return SizedBox(
                          width: dayWidth,
                          height: 32,
                          child: Center(
                            child: Text(
                              short,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: status != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: color,
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(
                        width: summaryWidth,
                        child: Center(
                          child: Text('$p',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700])),
                        ),
                      ),
                      SizedBox(
                        width: summaryWidth,
                        child: Center(
                          child: Text('$h',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700])),
                        ),
                      ),
                      SizedBox(
                        width: summaryWidth,
                        child: Center(
                          child: Text('$a',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700])),
                        ),
                      ),
                      SizedBox(
                        width: summaryWidth,
                        child: Center(
                          child: Text('$l',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700])),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
