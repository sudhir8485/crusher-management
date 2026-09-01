import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ────────────────────────────────────────────────────────────────

final _dateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _logsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, date) async {
  final res = await ref
      .read(apiClientProvider)
      .get('/api/machine-work', params: {'from': date, 'to': date});
  return List<Map<String, dynamic>>.from(res.data);
});

final _machinesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/machines');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ───────────────────────────────────────────────────────────────────

class MachineWorkScreen extends ConsumerWidget {
  const MachineWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_dateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final logs = ref.watch(_logsProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_logsProvider(dateKey)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          AppDateBar(
            selectedDate: selectedDate,
            onPick: (d) => ref.read(_dateProvider.notifier).state = d,
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
                    onEdit: () =>
                        _showForm(context, ref, data[i], selectedDate),
                    onDelete: () => _confirmDelete(context, ref, data[i], dateKey),
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
      DateTime date) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _LogForm(
        existing: log,
        defaultDate: date,
        onSaved: () {
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          ref.invalidate(_logsProvider(dateKey));
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
    for (final l in logs) {
      final h = l['totalHours'];
      if (h != null) totalHours += (h as num).toDouble();
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
            Text('${totalHours.toStringAsFixed(2)} hrs total',
                style: const TextStyle(fontWeight: FontWeight.w600)),
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
  const _LogCard(
      {required this.log, required this.onEdit, required this.onDelete});

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (totalHours != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(totalHours as num).toStringAsFixed(2)} hrs',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 15),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
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
                  const Icon(Icons.arrow_forward,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 16),
                  _Reading(label: 'Closing', value: closing),
                ],
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(notes,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
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
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
  final VoidCallback onSaved;
  const _LogForm(
      {required this.existing,
      required this.defaultDate,
      required this.onSaved});

  @override
  ConsumerState<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends ConsumerState<_LogForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  Long? _machineId;
  String _mode = 'BUCKET';
  final _descCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  double? _previewHours;

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
    }
    _openCtrl.addListener(_updatePreview);
    _closeCtrl.addListener(_updatePreview);
  }

  void _updatePreview() {
    final o = double.tryParse(_openCtrl.text);
    final c = double.tryParse(_closeCtrl.text);
    setState(() {
      _previewHours = (o != null && c != null && c >= o) ? c - o : null;
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'logDate': DateFormat('yyyy-MM-dd').format(_date),
      'machineId': _machineId,
      'workDescription': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'mode': _mode,
      'openingReading': double.tryParse(_openCtrl.text),
      'closingReading': double.tryParse(_closeCtrl.text),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    if (e == null) {
      await api.post('/api/machine-work', data: body);
    } else {
      await api.put('/api/machine-work/${e['id']}', data: body);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(_machinesProvider);
    final isEdit = widget.existing != null;

    return AppDialog(
      title: isEdit ? 'Edit Machine Work Entry' : 'Add Machine Work',
      maxWidth: 460,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update' : 'Save'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateField(label: 'Date', date: _date, required: true,
              onTap: () async {
                final d = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2030),
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
                return DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Machine *'),
                  value: _machineId,
                  isExpanded: true,
                  items: active.map((m) => DropdownMenuItem<int>(
                    value: m['id'] as int,
                    child: Text(m['name'] as String, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setState(() => _machineId = v),
                  validator: (v) => v == null ? 'Select a machine' : null,
                );
              },
            ),
            const SectionLabel('Mode'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'BUCKET', label: Text('Bucket'), icon: Icon(Icons.crop_square)),
                ButtonSegment(value: 'BREAKER', label: Text('Breaker'), icon: Icon(Icons.hardware)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
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
                  Text('Total: ${_previewHours!.toStringAsFixed(2)} hours',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ]),
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

typedef Long = int;
