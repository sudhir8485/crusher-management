import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

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

// ── screen ────────────────────────────────────────────────────────────────────

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_attendanceDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final data = ref.watch(_attendanceProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_attendanceProvider(dateKey)),
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (d) {
                final employees = List<Map<String, dynamic>>.from(
                    d['employees'] as List? ?? []);
                if (employees.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No active employees.\nAdd employees first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
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
      ),
    );
  }
}

// ── date bar ──────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onPick;
  const _DateBar({required this.selectedDate, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEE, d MMM yyyy').format(selectedDate);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                onPick(selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) onPick(d);
              },
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                onPick(selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}

// ── summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final present = data['presentCount'] as int? ?? 0;
    final halfDay = data['halfDayCount'] as int? ?? 0;
    final absent = data['absentCount'] as int? ?? 0;
    final leave = data['leaveCount'] as int? ?? 0;
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
          if (unmarked > 0)
            _SummaryChip('Unmarked', unmarked, Colors.grey),
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
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color)),
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
    final designation =
        (widget.emp['designation'] as String?)?.trim() ?? '';
    final wageType = widget.emp['wageType'] as String? ?? 'DAILY';
    final currentStatus = widget.emp['attendanceStatus'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
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
            // Name + designation
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
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            // Status chips — tap to mark
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
