import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// ── providers ────────────────────────────────────────────────────────────────

final _dateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Key is "date|siteId" so the provider refires when either changes.
final _logsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, key) async {
  final parts  = key.split('|');
  final date   = parts[0];
  final siteId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  final params = <String, dynamic>{'from': date, 'to': date};
  if (siteId != null) params['siteId'] = siteId;
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

class MachineWorkScreen extends ConsumerWidget {
  const MachineWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_dateProvider);
    final siteId      = ref.watch(selectedSiteIdProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final logsKey = '$dateKey|${siteId ?? ''}';
    final logs = ref.watch(_logsProvider(logsKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_logsProvider(logsKey)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, selectedDate, siteId),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          AppDateBar(
            selectedDate: selectedDate,
            onPick: (d) => ref.read(_dateProvider.notifier).state = d,
          ),
          // Remind admin users to pick a site before creating entries
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
            error: (_, s) => const SizedBox(),
            data: (data) => _SummaryBar(logs: data),
          ),
          Expanded(
            child: logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.construction_outlined,
                    message: 'No machine work entries for ${DateFormat('d MMM yyyy').format(selectedDate)}',
                    hint: 'Tap + to add an entry',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length,
                  separatorBuilder: (_, idx) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LogCard(
                    log: data[i],
                    onEdit: () => _showForm(context, ref, data[i], selectedDate, siteId),
                    onDelete: () => _confirmDelete(context, ref, data[i], logsKey),
                    onSetRate: () => _showSetRateDialog(context, ref, data[i], logsKey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? log,
      DateTime date, int? siteId) {
    final logsKey = '${DateFormat('yyyy-MM-dd').format(date)}|${siteId ?? ''}';
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _LogForm(
        existing: log,
        defaultDate: date,
        siteId: siteId,
        onSaved: () => ref.invalidate(_logsProvider(logsKey)),
      ),
    );
  }

  void _showSetRateDialog(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> log, String dateKey) {
    final totalHours = (log['totalHours'] as num?)?.toDouble();
    final isSet = (log['rateStatus'] as String?) == 'SET';
    final currentRate = isSet ? (log['rate'] as num?)?.toDouble() : null;
    final rateCtrl = TextEditingController(text: currentRate?.toString() ?? '');
    double? previewTotal = (currentRate != null && totalHours != null)
        ? currentRate * totalHours : null;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dctx, setS) {
          void updatePreview(String v) {
            final r = double.tryParse(v);
            setS(() => previewTotal =
                (r != null && totalHours != null) ? r * totalHours : null);
          }

          return AlertDialog(
            title: Text('${isSet ? 'Edit' : 'Set'} Rate — ${log['machineName'] ?? 'Machine Work'}'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              if (totalHours != null)
                Text('${totalHours.toStringAsFixed(2)} hrs of work recorded',
                    style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Rate ₹/hr',
                  prefixText: '₹',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: updatePreview,
              ),
              if (previewTotal != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total amount:'),
                        Text(
                          '₹${_numFmt.format(previewTotal)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 15),
                        ),
                      ]),
                ),
              ],
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: rateCtrl.text.isNotEmpty
                    ? () async {
                        Navigator.pop(dctx);
                        try {
                          await ref.read(apiClientProvider).post(
                            '/api/machine-work/${log['id']}/set-rate',
                            data: null,
                            params: {'rate': rateCtrl.text},
                          );
                          ref.invalidate(_logsProvider(dateKey));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(isSet
                                  ? 'Rate updated to ₹${rateCtrl.text}/hr'
                                  : 'Rate set to ₹${rateCtrl.text}/hr — entry locked'),
                              backgroundColor: Colors.green,
                            ));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('Failed: ${_apiError(e)}'),
                              backgroundColor: Colors.red,
                            ));
                          }
                        }
                      }
                    : null,
                child: Text(isSet ? 'Update' : 'Apply & Lock'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> log, String dateKey) {
    final machineName = log['machineName'] ?? 'this entry';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete work log for $machineName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(apiClientProvider)
                  .delete('/api/machine-work/${log['id']}');
              ref.invalidate(_logsProvider(dateKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── summary bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _SummaryBar({required this.logs});

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
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.construction, size: 18),
          const SizedBox(width: 8),
          Text('${logs.length} ${logs.length == 1 ? 'entry' : 'entries'}',
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetRate;
  const _LogCard({
    required this.log,
    required this.onEdit,
    required this.onDelete,
    required this.onSetRate,
  });

  @override
  Widget build(BuildContext context) {
    final mode = (log['mode'] ?? 'BUCKET') as String;
    final modeColor = mode == 'BREAKER' ? Colors.orange : Colors.blue;
    final machineName = log['machineName'] ?? '—';
    final machineType = log['machineType'] ?? '';
    final desc = (log['workDescription'] as String?)?.trim() ?? '';
    final opening = log['openingReading'];
    final closing = log['closingReading'];
    final totalHours = log['totalHours'];
    final notes = (log['notes'] as String?)?.trim() ?? '';

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
                // Mode badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(mode,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: modeColor)),
                ),
                if (isBillable) ...[
                  const SizedBox(width: 6),
                  _BillableBadge(
                    isPendingRate: isPendingRate,
                    isGstPending: isGstPending,
                    isGstSet: isGstSet,
                  ),
                ],
                const SizedBox(width: 8),
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
                // Right side: hours or billable total
                if (isBillable && totalAmount != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    if (v == 'set_rate') onSetRate();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isBillable)
                      PopupMenuItem(
                          value: 'set_rate',
                          child: Text(isPendingRate ? 'Set Rate' : 'Edit Rate')),
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
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                if (rate != null && rateStatus == 'SET') ...[
                  const SizedBox(width: 8),
                  Text('· ₹${_numFmt.format((rate as num).toDouble())}/hr',
                      style: TextStyle(
                          fontSize: 12, color: Colors.purple.shade600)),
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
                    _Reading(
                        label: 'Hours',
                        value: (totalHours as num).toDouble()),
                  ],
                ],
              ),
            ],
            if (isPendingRate) ...[
              const SizedBox(height: 6),
              Text('Tap ⋮ → Set Rate to lock this entry',
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
  String _mode = 'BUCKET';
  final _descCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _saving = false;
  double? _previewHours;
  double? _previewTotal;

  // Customer Billable
  String _workPurpose = 'INTERNAL';
  int? _customerId;
  bool _rateIsLocked = false;  // true when editing a SET entry

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null
        ? DateTime.parse(e['logDate'] as String)
        : widget.defaultDate;
    if (e != null) {
      _machineId = e['machineId'] as int?;
      _mode = (e['mode'] as String?) ?? 'BUCKET';
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
      _rateIsLocked = (e['rateStatus'] as String?) == 'SET';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // For new entries, a site must be selected — SITE_STAFF get it from JWT,
    // but OWNER_ADMIN/OFFICE_ACCOUNTANT must choose one in the sidebar first.
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
      'workDescription':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'mode': _mode,
      'openingReading': double.tryParse(_openCtrl.text),
      'closingReading': double.tryParse(_closeCtrl.text),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'workPurpose': _workPurpose,
      'customerId':
          _workPurpose == 'CUSTOMER_BILLABLE' ? _customerId : null,
      'rate': (_workPurpose == 'CUSTOMER_BILLABLE' &&
              _rateCtrl.text.isNotEmpty &&
              !_rateIsLocked)
          ? double.tryParse(_rateCtrl.text)
          : null,
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    try {
      if (e == null) {
        // Pass siteId so the backend can assign the entry to the correct site.
        // Required for OWNER_ADMIN/OFFICE_ACCOUNTANT — SITE_STAFF gets it from JWT.
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
                  width: 18,
                  height: 18,
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
            // Work Purpose toggle
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

            // Customer picker (billable only)
            if (isBillable) ...[
              vendors.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading customers: $e'),
                data: (list) {
                  final active =
                      list.where((v) => v['status'] == 'ACTIVE').toList();
                  return SearchablePicker(
                    items: active,
                    itemLabel: (v) => v['name'] as String,
                    fieldLabel: 'Customer *',
                    value: _customerId,
                    onChanged: (v) => setState(() => _customerId = v),
                    validator: (v) =>
                        v == null ? 'Select a customer' : null,
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
                final active =
                    list.where((m) => m['status'] == 'ACTIVE').toList();
                return SearchablePicker(
                  items: active,
                  itemLabel: (m) => m['name'] as String,
                  fieldLabel: 'Machine *',
                  value: _machineId,
                  onChanged: (v) => setState(() => _machineId = v),
                  validator: (v) => v == null ? 'Select a machine' : null,
                );
              },
            ),
            const SectionLabel('Mode'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'BUCKET',
                    label: Text('Bucket'),
                    icon: Icon(Icons.crop_square)),
                ButtonSegment(
                    value: 'BREAKER',
                    label: Text('Breaker'),
                    icon: Icon(Icons.hardware)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) =>
                  setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
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
                  decoration:
                      const InputDecoration(labelText: 'Opening Reading'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _closeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Closing Reading'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    const Text('·  Total: ',
                        style: TextStyle(color: Colors.green)),
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

            // Rate field (billable only, hidden if rate is locked)
            if (isBillable) ...[
              const SectionLabel('Rate'),
              if (_rateIsLocked)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outline, size: 16,
                        color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                        'Rate locked: ₹${_rateCtrl.text}/hr',
                        style: const TextStyle(color: Colors.grey)),
                  ]),
                )
              else
                TextFormField(
                  controller: _rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rate ₹/hr (leave blank to decide later)',
                    prefixText: '₹',
                    helperText:
                        'If left blank, entry is saved as Rate: Pending',
                  ),
                ),
            ],

            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
