import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

String _apiError(dynamic err) {
  if (err is DioException) {
    final data = err.response?.data;
    if (data is Map && data.isNotEmpty) {
      final msg = data['error'] ?? data.values.first;
      return msg?.toString() ?? 'HTTP ${err.response?.statusCode}';
    }
    return 'HTTP ${err.response?.statusCode ?? '?'}';
  }
  return err.toString();
}

final _fmt = DateFormat('yyyy-MM-dd');

// ── period helpers ────────────────────────────────────────────────────────────

List<DateTime> _resolveMWRange(String mode, DateTime anchor, List<DateTime> custom) {
  switch (mode) {
    case 'week':
      final mon = anchor.subtract(Duration(days: anchor.weekday - 1));
      return [mon, mon.add(const Duration(days: 6))];
    case 'month':
      return [DateTime(anchor.year, anchor.month, 1),
              DateTime(anchor.year, anchor.month + 1, 0)];
    case 'year':
      return [DateTime(anchor.year, 1, 1), DateTime(anchor.year, 12, 31)];
    case 'custom':
      return custom;
    default: // day
      return [anchor, anchor];
  }
}

String _mwRangeKey(String mode, DateTime anchor, List<DateTime> custom, int? siteId) {
  final r = _resolveMWRange(mode, anchor, custom);
  return '${_fmt.format(r[0])}|${_fmt.format(r[1])}|${siteId ?? ''}';
}

String _mwPeriodLabel(String mode, DateTime anchor, List<DateTime> custom) {
  switch (mode) {
    case 'week':   return 'this week';
    case 'month':  return 'this month';
    case 'year':   return 'this year';
    case 'custom':
      final r = _resolveMWRange('custom', anchor, custom);
      return '${DateFormat('d MMM').format(r[0])} – ${DateFormat('d MMM yyyy').format(r[1])}';
    default:       return 'today';
  }
}

// ── providers ────────────────────────────────────────────────────────────────

final _mwDateProvider   = StateProvider<DateTime>((ref) => DateTime.now());
final _mwModeProvider   = StateProvider<String>((ref) => 'day');
final _mwCustomProvider = StateProvider<List<DateTime>>((ref) => [DateTime.now(), DateTime.now()]);

// key = "from|to|siteId"  (same pattern as Diesel / Dabar)
final _logsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, key) async {
  final parts  = key.split('|');
  final params = <String, dynamic>{'from': parts[0], 'to': parts[1]};
  if (parts[2].isNotEmpty) params['siteId'] = parts[2];
  final res = await ref.read(apiClientProvider).get('/api/machine-work', params: params);
  return List<Map<String, dynamic>>.from(res.data);
});

final _machinesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/machines');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

final _numFmt = NumberFormat('#,##,##0.##');

// ── screen ───────────────────────────────────────────────────────────────────

class MachineWorkScreen extends ConsumerStatefulWidget {
  const MachineWorkScreen({super.key});

  @override
  ConsumerState<MachineWorkScreen> createState() => _MachineWorkScreenState();
}

class _MachineWorkScreenState extends ConsumerState<MachineWorkScreen> {
  bool _extraProcessed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processExtra());
  }

  void _processExtra() {
    if (_extraProcessed) return;
    _extraProcessed = true;
    final extra = GoRouterState.of(context).extra as Map?;
    if (extra == null) return;
    final logId = extra['editLogId'] as int?;
    final dateStr = extra['entryDate'] as String?;
    if (logId == null || dateStr == null) return;
    final date = DateTime.parse(dateStr);
    ref.read(_mwModeProvider.notifier).state = 'day';
    ref.read(_mwDateProvider.notifier).state = date;
    _scheduleOpenLog(logId, date);
  }

  Future<void> _scheduleOpenLog(int logId, DateTime date) async {
    final siteId = ref.read(selectedSiteIdProvider);
    final key = _mwRangeKey('day', date, [date, date], siteId);
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final logs = ref.read(_logsProvider(key)).valueOrNull;
      if (logs != null) {
        final log = logs.where((l) => (l['id'] as int?) == logId).firstOrNull;
        if (log != null) {
          _showForm(context, ref, log, date, siteId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry not found — check that the correct site is selected')),
          );
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date   = ref.watch(_mwDateProvider);
    final mode   = ref.watch(_mwModeProvider);
    final custom = ref.watch(_mwCustomProvider);
    final siteId = ref.watch(selectedSiteIdProvider);
    final key    = _mwRangeKey(mode, date, custom, siteId);
    final logs   = ref.watch(_logsProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_logsProvider(key)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, date, siteId),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          _MWDateRangeBar(
            selectedDate: date,
            mode: mode,
            custom: custom,
            onDateChanged: (d) => ref.read(_mwDateProvider.notifier).state = d,
            onModeChanged: (m) => ref.read(_mwModeProvider.notifier).state = m,
            onCustomChanged: (r) => ref.read(_mwCustomProvider.notifier).state = r,
          ),
          if (siteId == null)
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Select a site from the sidebar to add new entries',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  )),
                ]),
              ),
            ),
          logs.when(
            loading: () => const SizedBox(),
            error:   (_, _s) => const SizedBox(),
            data: (data) => _SummaryBar(
                logs: data, mode: mode, date: date, custom: custom),
          ),
          Expanded(
            child: logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.construction_outlined,
                    message: 'No machine work entries ${_emptyMsg(mode, date)}',
                    hint: 'Tap + to add an entry',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length,
                  separatorBuilder: (_, _i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LogCard(
                    log: data[i],
                    showDate: mode != 'day',
                    onEdit:   () => _showForm(context, ref, data[i], date, siteId),
                    onDelete: () => _confirmDelete(context, ref, data[i], key),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _emptyMsg(String mode, DateTime date) {
    switch (mode) {
      case 'week':   return 'this week';
      case 'month':  return 'in ${DateFormat('MMMM yyyy').format(date)}';
      case 'year':   return 'in ${DateFormat('yyyy').format(date)}';
      case 'custom': return 'for this range';
      default:       return 'for ${DateFormat('d MMM yyyy').format(date)}';
    }
  }

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? log,
      DateTime date, int? siteId) {
    final key = _mwRangeKey(
      ref.read(_mwModeProvider),
      ref.read(_mwDateProvider),
      ref.read(_mwCustomProvider),
      siteId,
    );
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _LogForm(
        existing: log,
        defaultDate: date,
        siteId: siteId,
        onSaved: () => ref.invalidate(_logsProvider(key)),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> log, String rangeKey) {
    final machineName = log['machineName'] ?? 'this entry';
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete work log for $machineName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(apiClientProvider).delete('/api/machine-work/${log['id']}');
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('Delete failed: ${_apiError(e)}'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              if (!ctx.mounted) return;
              ref.invalidate(_logsProvider(rangeKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── period navigation bar ─────────────────────────────────────────────────────

class _MWDateRangeBar extends StatelessWidget {
  final DateTime selectedDate;
  final String mode;
  final List<DateTime> custom;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<List<DateTime>> onCustomChanged;

  const _MWDateRangeBar({
    required this.selectedDate,
    required this.mode,
    required this.custom,
    required this.onDateChanged,
    required this.onModeChanged,
    required this.onCustomChanged,
  });

  void _prev() {
    switch (mode) {
      case 'week':  onDateChanged(selectedDate.subtract(const Duration(days: 7))); break;
      case 'month': onDateChanged(DateTime(selectedDate.year, selectedDate.month - 1, 1)); break;
      case 'year':  onDateChanged(DateTime(selectedDate.year - 1, 1, 1)); break;
      default:      onDateChanged(selectedDate.subtract(const Duration(days: 1))); break;
    }
  }

  void _next() {
    switch (mode) {
      case 'week':  onDateChanged(selectedDate.add(const Duration(days: 7))); break;
      case 'month': onDateChanged(DateTime(selectedDate.year, selectedDate.month + 1, 1)); break;
      case 'year':  onDateChanged(DateTime(selectedDate.year + 1, 1, 1)); break;
      default:      onDateChanged(selectedDate.add(const Duration(days: 1))); break;
    }
  }

  String _label() {
    final range = _resolveMWRange(mode, selectedDate, custom);
    switch (mode) {
      case 'week':
        return '${DateFormat('d MMM').format(range[0])} – ${DateFormat('d MMM yyyy').format(range[1])}';
      case 'month':
        return DateFormat('MMMM yyyy').format(selectedDate);
      case 'year':
        return DateFormat('yyyy').format(selectedDate);
      case 'custom':
        return '${DateFormat('d MMM').format(range[0])} – ${DateFormat('d MMM yyyy').format(range[1])}';
      default:
        return DateFormat('EEEE, d MMMM yyyy').format(selectedDate);
    }
  }

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: custom[0], end: custom[1]),
    );
    if (picked != null) {
      onCustomChanged([picked.start, picked.end]);
      onModeChanged('custom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showArrows = mode != 'custom';

    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Mode chips
        Row(children: [
          for (final m in [('day', 'Day'), ('week', 'Week'), ('month', 'Month'), ('year', 'Year')])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(m.$2),
                selected: mode == m.$1,
                onSelected: (_) => onModeChanged(m.$1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: TextStyle(fontSize: 12,
                    color: mode == m.$1 ? cs.onPrimary : null),
                selectedColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          InkWell(
            onTap: () => _pickCustom(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mode == 'custom' ? cs.primary : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: mode == 'custom' ? cs.primary : cs.outline.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_outlined, size: 14,
                    color: mode == 'custom' ? cs.onPrimary : cs.onSurface),
                const SizedBox(width: 4),
                Text('Custom', style: TextStyle(fontSize: 12,
                    color: mode == 'custom' ? cs.onPrimary : cs.onSurface)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          if (showArrows)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prev,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          Expanded(
            child: GestureDetector(
              onTap: mode == 'day'
                  ? () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (d != null) onDateChanged(d);
                    }
                  : mode == 'custom' ? () => _pickCustom(context) : null,
              child: Text(_label(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          if (showArrows)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _next,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ]),
      ]),
    );
  }
}

// ── summary bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final String mode;
  final DateTime date;
  final List<DateTime> custom;
  const _SummaryBar({required this.logs, required this.mode, required this.date, required this.custom});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox();
    double totalHours = 0;
    double totalBillable = 0;
    int billableCount = 0;
    for (final l in logs) {
      final h = l['totalHours'];
      if (h != null) totalHours += (h as num).toDouble();
      if (l['workPurpose'] == 'CUSTOMER_BILLABLE') {
        billableCount++;
        final amt = l['totalAmount'];
        if (amt != null) totalBillable += (amt as num).toDouble();
      }
    }
    final period = _mwPeriodLabel(mode, date, custom);
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.construction, size: 18),
          const SizedBox(width: 8),
          Text('${logs.length} ${logs.length == 1 ? 'entry' : 'entries'} $period',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (totalHours > 0) ...[
            const Icon(Icons.timer_outlined, size: 18),
            const SizedBox(width: 4),
            Text('${totalHours.toStringAsFixed(2)} hrs',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (billableCount > 0 && totalBillable > 0) ...[
            const SizedBox(width: 12),
            Text('₹${_numFmt.format(totalBillable)} billed',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700)),
          ],
        ],
      ),
    );
  }
}

// ── log card ─────────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool showDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _LogCard({
    required this.log,
    this.showDate = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final mode = (log['mode'] as String?)?.trim() ?? '';
    final machineName = log['machineName'] ?? '—';
    final machineType = log['machineType'] ?? '';
    final desc = (log['workDescription'] as String?)?.trim() ?? '';
    final opening = log['openingReading'];
    final closing = log['closingReading'];
    final totalHours = log['totalHours'];
    final notes = (log['notes'] as String?)?.trim() ?? '';
    final logDateStr = log['logDate'] as String?;

    final workPurpose = (log['workPurpose'] ?? 'INTERNAL') as String;
    final isBillable = workPurpose == 'CUSTOMER_BILLABLE';
    final customerName = log['customerName'] as String?;
    final rateStatus = log['rateStatus'] as String?;
    final rate = log['rate'];
    final totalAmount = log['totalAmount'];
    final isPendingRate = isBillable && rateStatus == 'PENDING';
    final gstInvoiceId = log['gstInvoiceId'];
    final gstInvoiceStatus = log['gstInvoiceStatus'] as String?;
    final hasGstInvoice = gstInvoiceId != null;
    final isGstPending = hasGstInvoice && gstInvoiceStatus == 'PENDING';
    final isGstSet = hasGstInvoice && gstInvoiceStatus == 'SET';

    return Card(
      color: (isPendingRate || isGstPending) ? Colors.amber.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (mode.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(mode,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                  ),
                  const SizedBox(width: 6),
                ],
                if (isBillable) ...[
                  _BillableBadge(
                    isPendingRate: isPendingRate,
                    isGstPending: isGstPending,
                    isGstSet: isGstSet,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(machineName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (machineType.isNotEmpty)
                        Text(machineType,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                // Date badge for non-day modes
                if (showDate && logDateStr != null) ...[
                  Text(
                    DateFormat('d MMM').format(DateTime.parse(logDateStr)),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isBillable && totalAmount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '₹${_numFmt.format((totalAmount as num).toDouble())}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                          fontSize: 14),
                    ),
                  )
                else if (totalHours != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(totalHours as num).toStringAsFixed(2)} hrs',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 14),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            if (isBillable && customerName != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(customerName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                if (rate != null && rateStatus == 'SET') ...[
                  const SizedBox(width: 8),
                  Text('· ₹${_numFmt.format((rate as num).toDouble())}/hr',
                      style: TextStyle(fontSize: 12, color: Colors.purple.shade600)),
                ],
              ]),
            ],
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(fontSize: 13)),
            ],
            if (opening != null || closing != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _Reading(label: 'Opening', value: opening),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  const SizedBox(width: 16),
                  _Reading(label: 'Closing', value: closing),
                  if (totalHours != null && isBillable) ...[
                    const SizedBox(width: 16),
                    _Reading(label: 'Hours', value: (totalHours as num).toDouble()),
                  ],
                ],
              ),
            ],
            if (isPendingRate) ...[
              const SizedBox(height: 6),
              Text('Tap ⋮ → Edit to set the rate for this entry',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic)),
            ] else if (isGstPending) ...[
              const SizedBox(height: 6),
              Text('GST rate not set — open party account to confirm GST',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic)),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(notes,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }
}

// ── billable badge ────────────────────────────────────────────────────────────

class _BillableBadge extends StatelessWidget {
  final bool isPendingRate;
  final bool isGstPending;
  final bool isGstSet;
  const _BillableBadge({
    required this.isPendingRate,
    required this.isGstPending,
    required this.isGstSet,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color text;
    final String label;

    if (isPendingRate) {
      bg = Colors.amber.shade100;
      border = Colors.amber.shade400;
      text = Colors.orange.shade900;
      label = 'Rate: Pending';
    } else if (isGstPending) {
      bg = Colors.amber.shade100;
      border = Colors.amber.shade400;
      text = Colors.orange.shade900;
      label = 'GST: Pending';
    } else if (isGstSet) {
      bg = Colors.teal.shade50;
      border = Colors.teal.shade200;
      text = Colors.teal.shade800;
      label = 'Tax Invoice';
    } else {
      bg = Colors.purple.shade50;
      border = Colors.purple.shade200;
      text = Colors.purple.shade700;
      label = 'Billable';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }
}

class _Reading extends StatelessWidget {
  final String label;
  final dynamic value;
  const _Reading({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          value != null ? (value as num).toStringAsFixed(1) : '—',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}

// ── form dialog ───────────────────────────────────────────────────────────────

class _LogForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime defaultDate;
  final int? siteId;
  final VoidCallback onSaved;
  const _LogForm({
    required this.existing,
    required this.defaultDate,
    required this.siteId,
    required this.onSaved,
  });

  @override
  ConsumerState<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends ConsumerState<_LogForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  int? _machineId;
  String? _mode;
  int? _workTypeId;
  List<Map<String, dynamic>> _currentWorkTypes = [];
  bool _workTypesInitialized = false;
  final _descCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _saving = false;
  double? _previewHours;
  double? _previewTotal;

  String _workPurpose = 'INTERNAL';
  int? _customerId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null
        ? DateTime.parse(e['logDate'] as String)
        : widget.defaultDate;
    if (e != null) {
      _machineId = e['machineId'] as int?;
      _mode = e['mode'] as String?;
      _workTypeId = e['workTypeId'] as int?;
      _descCtrl.text = (e['workDescription'] as String?) ?? '';
      final open = e['openingReading'];
      final close = e['closingReading'];
      if (open != null) _openCtrl.text = open.toString();
      if (close != null) _closeCtrl.text = close.toString();
      _notesCtrl.text = (e['notes'] as String?) ?? '';
      _workPurpose = (e['workPurpose'] as String?) ?? 'INTERNAL';
      _customerId = e['customerId'] as int?;
      final rate = e['rate'];
      if (rate != null) _rateCtrl.text = rate.toString();
    }
    _openCtrl.addListener(_updatePreview);
    _closeCtrl.addListener(_updatePreview);
    _rateCtrl.addListener(_updatePreview);
  }

  void _updatePreview() {
    final o = double.tryParse(_openCtrl.text);
    final c = double.tryParse(_closeCtrl.text);
    final r = double.tryParse(_rateCtrl.text);
    final hours = (o != null && c != null && c >= o) ? c - o : null;
    setState(() {
      _previewHours = hours;
      _previewTotal = (_workPurpose == 'CUSTOMER_BILLABLE' && hours != null && r != null)
          ? hours * r
          : null;
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _notesCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _onMachineSelected(int? machineId, List<Map<String, dynamic>> allMachines) {
    if (machineId == null) {
      setState(() {
        _machineId = null;
        _currentWorkTypes = [];
        _mode = null;
        _workTypeId = null;
      });
      return;
    }

    final machine = allMachines.firstWhere(
      (m) => m['id'] == machineId,
      orElse: () => {},
    );
    final types = (machine['workTypes'] as List<dynamic>? ?? [])
        .map((wt) => Map<String, dynamic>.from(wt as Map))
        .toList();

    setState(() {
      _machineId = machineId;
      _currentWorkTypes = types;
      if (types.isEmpty) {
        _mode = null;
        _workTypeId = null;
      } else if (types.length == 1) {
        _selectWorkType(types[0]);
      } else {
        if (_workTypeId != null && types.any((wt) => wt['id'] == _workTypeId)) {
          // keep current selection
        } else {
          _selectWorkType(types[0]);
        }
      }
    });
  }

  void _selectWorkType(Map<String, dynamic> wt, {bool userTriggered = false}) {
    _mode = wt['label'] as String?;
    _workTypeId = wt['id'] as int?;
    final defaultRate = wt['defaultRate'];
    if (userTriggered) {
      _rateCtrl.text = defaultRate != null
          ? (defaultRate as num).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')
          : '';
      _updatePreview();
    } else if (_rateCtrl.text.isEmpty && defaultRate != null) {
      _rateCtrl.text = (defaultRate as num).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      _updatePreview();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing == null && widget.siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select a site from the sidebar before adding entries'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ));
      return;
    }
    setState(() => _saving = true);
    final body = {
      'logDate': DateFormat('yyyy-MM-dd').format(_date),
      'machineId': _machineId,
      'workDescription': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'mode': _mode,
      'workTypeId': _workTypeId,
      'openingReading': double.tryParse(_openCtrl.text),
      'closingReading': double.tryParse(_closeCtrl.text),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'workPurpose': _workPurpose,
      'customerId': _workPurpose == 'CUSTOMER_BILLABLE' ? _customerId : null,
      'rate': (_workPurpose == 'CUSTOMER_BILLABLE' && _rateCtrl.text.isNotEmpty)
          ? double.tryParse(_rateCtrl.text)
          : null,
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    try {
      if (e == null) {
        final params = widget.siteId != null
            ? <String, dynamic>{'siteId': '${widget.siteId}'}
            : null;
        await api.post('/api/machine-work', data: body, params: params);
      } else {
        await api.put('/api/machine-work/${e['id']}', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${_apiError(err)}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(_machinesProvider);
    final vendors = ref.watch(_vendorsProvider);
    final isEdit = widget.existing != null;
    final isBillable = _workPurpose == 'CUSTOMER_BILLABLE';

    return AppDialog(
      title: isEdit ? 'Edit Machine Work Entry' : 'Add Machine Work',
      maxWidth: 480,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update' : 'Save'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Work Purpose'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'INTERNAL',
                    label: Text('Internal'),
                    icon: Icon(Icons.factory_outlined)),
                ButtonSegment(
                    value: 'CUSTOMER_BILLABLE',
                    label: Text('Customer Billable'),
                    icon: Icon(Icons.receipt_outlined)),
              ],
              selected: {_workPurpose},
              onSelectionChanged: (s) =>
                  setState(() { _workPurpose = s.first; _updatePreview(); }),
            ),
            const SizedBox(height: 14),

            if (isBillable) ...[
              vendors.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading customers: $e'),
                data: (list) {
                  final active = list.where((v) => v['status'] == 'ACTIVE').toList();
                  return SearchablePicker(
                    items: active,
                    itemLabel: (v) => v['name'] as String,
                    fieldLabel: 'Customer *',
                    value: _customerId,
                    onChanged: (v) => setState(() => _customerId = v),
                    validator: (v) => v == null ? 'Select a customer' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            DateField(
              label: 'Date',
              date: _date,
              required: true,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),

            machines.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) {
                final active = list.where((m) => m['status'] == 'ACTIVE').toList();
                if (!_workTypesInitialized && _machineId != null) {
                  _workTypesInitialized = true;
                  final machine = active.firstWhere(
                      (m) => m['id'] == _machineId, orElse: () => {});
                  final types = (machine['workTypes'] as List<dynamic>? ?? [])
                      .map((wt) => Map<String, dynamic>.from(wt as Map)).toList();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _currentWorkTypes = types);
                  });
                }
                return SearchablePicker(
                  items: active,
                  itemLabel: (m) => m['name'] as String,
                  fieldLabel: 'Machine *',
                  value: _machineId,
                  onChanged: (v) => _onMachineSelected(v, active),
                  validator: (v) => v == null ? 'Select a machine' : null,
                );
              },
            ),

            if (_currentWorkTypes.length >= 2) ...[
              const SectionLabel('Mode'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _currentWorkTypes.map((wt) {
                  final label = wt['label'] as String;
                  return ChoiceChip(
                    label: Text(label),
                    selected: _mode == label,
                    onSelected: (_) {
                      setState(() {
                        _selectWorkType(wt, userTriggered: true);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Work Description',
                hintText: 'e.g. Loading khadi to screen',
              ),
              maxLines: 2,
            ),
            const SectionLabel('Readings'),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _openCtrl,
                  decoration: const InputDecoration(labelText: 'Opening Reading'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _closeCtrl,
                  decoration: const InputDecoration(labelText: 'Closing Reading'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final c = double.tryParse(v);
                    final o = double.tryParse(_openCtrl.text);
                    if (c != null && o != null && c < o) {
                      return 'Must be ≥ opening reading';
                    }
                    return null;
                  },
                )),
              ],
            ),
            if (_previewHours != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                      'Hours: ${_previewHours!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                  if (_previewTotal != null) ...[
                    const SizedBox(width: 12),
                    const Text('·  Total: ', style: TextStyle(color: Colors.green)),
                    Text(
                        '₹${_numFmt.format(_previewTotal!)}',
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ]),
              ),
            ],

            if (isBillable) ...[
              const SectionLabel('Rate'),
              TextFormField(
                controller: _rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Rate ₹/hr',
                  prefixText: '₹',
                  helperText: 'Leave blank to save as Rate: Pending',
                ),
              ),
            ],

            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
