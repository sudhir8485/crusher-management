import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

// Range key: 'from|to' or '' for all-time
final _paymentsRangeProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final fmt  = DateFormat('yyyy-MM-dd');
  return '${fmt.format(from)}|${fmt.format(now)}';
});

final _paymentsModeProvider = StateProvider<String>((ref) => 'month');
final _paymentsAnchorProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _paymentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, rangeKey) async {
  final parts  = rangeKey.split('|');
  final params = <String, dynamic>{'page': '0', 'size': '500'};
  if (parts.length == 2) {
    params['from'] = parts[0];
    params['to']   = parts[1];
  }
  final res = await ref.read(apiClientProvider).get('/api/party-payments', params: params);
  final d = res.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(d['content'] as List);
});

// Trip-balance for the vendor currently selected in the form
final _vendorTripBalanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, int>(
        (ref, vendorId) async {
  final res = await ref
      .read(apiClientProvider)
      .get('/api/parties/$vendorId/trip-balance');
  return Map<String, dynamic>.from(res.data as Map);
});

final _dateFmt = DateFormat('d MMM yyyy');

// ── Helpers ───────────────────────────────────────────────────────────────────

String _rangeKeyForMode(String mode, DateTime anchor) {
  final fmt = DateFormat('yyyy-MM-dd');
  switch (mode) {
    case 'day':
      return '${fmt.format(anchor)}|${fmt.format(anchor)}';
    case 'week':
      final mon = anchor.subtract(Duration(days: anchor.weekday - 1));
      final sun = mon.add(const Duration(days: 6));
      return '${fmt.format(mon)}|${fmt.format(sun)}';
    case 'month':
      final from = DateTime(anchor.year, anchor.month, 1);
      final to   = DateTime(anchor.year, anchor.month + 1, 0);
      return '${fmt.format(from)}|${fmt.format(to)}';
    default:
      return _rangeKeyForMode('month', anchor);
  }
}

String _balanceLabel(double v) => v < 0 ? 'Advance' : 'Outstanding';
Color  _balanceColor(double v)  => v < 0 ? Colors.blue.shade700 : Colors.orange.shade800;
String _fmtBalance(double v)    => fmtCurr(v.abs());

// ── Screen ────────────────────────────────────────────────────────────────────

class VendorPaymentsScreen extends ConsumerWidget {
  const VendorPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeKey = ref.watch(_paymentsRangeProvider);
    final mode     = ref.watch(_paymentsModeProvider);
    final anchor   = ref.watch(_paymentsAnchorProvider);
    final payments = ref.watch(_paymentsProvider(rangeKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_paymentsProvider(rangeKey)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, rangeKey),
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
      body: Column(children: [
        _RangeBar(mode: mode, anchor: anchor, rangeKey: rangeKey),
        Expanded(
          child: payments.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (list) => _PaymentsList(
              list: list,
              onEdit:   (p) => _showForm(context, ref, p, rangeKey),
              onDelete: (p) => _confirmDelete(context, ref, p, rangeKey),
            ),
          ),
        ),
      ]),
    );
  }

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? p, String rangeKey) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _PaymentForm(
        existing: p,
        onSaved: () => ref.invalidate(_paymentsProvider(rangeKey)),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref, Map<String, dynamic> p, String rangeKey) {
    showDialog(
      context: ctx,
      // Use the dialog's own context (dialogCtx) for Navigator.pop — avoids
      // using the outer ctx after the overlay hierarchy has changed.
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Delete ${fmtCurr(p['amount'] as num? ?? 0)} payment to ${p['vendorName']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(apiClientProvider).delete('/api/party-payments/${p['id']}');
              // Small settle wait so any exit animations complete before the
              // list rebuilds and deactivates the old card widgets.
              await Future.delayed(const Duration(milliseconds: 150));
              ref.invalidate(_paymentsProvider(rangeKey));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Range bar ─────────────────────────────────────────────────────────────────

class _RangeBar extends ConsumerWidget {
  final String mode;
  final DateTime anchor;
  final String rangeKey;

  const _RangeBar({required this.mode, required this.anchor, required this.rangeKey});

  String _label() {
    final parts = rangeKey.split('|');
    if (parts.length != 2) return '';
    final from = DateTime.parse(parts[0]);
    final to   = DateTime.parse(parts[1]);
    if (mode == 'month') return DateFormat('MMMM yyyy').format(anchor);
    if (mode == 'week')  return '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}';
    if (mode == 'day')   return DateFormat('d MMM yyyy').format(anchor);
    return '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}';
  }

  void _move(WidgetRef ref, int direction) {
    final a = ref.read(_paymentsAnchorProvider);
    DateTime next;
    switch (mode) {
      case 'day':
        next = a.add(Duration(days: direction)); break;
      case 'week':
        next = a.add(Duration(days: 7 * direction)); break;
      default: // month
        next = DateTime(a.year, a.month + direction, 1); break;
    }
    ref.read(_paymentsAnchorProvider.notifier).state = next;
    ref.read(_paymentsRangeProvider.notifier).state = _rangeKeyForMode(mode, next);
  }

  void _setMode(WidgetRef ref, String m) {
    ref.read(_paymentsModeProvider.notifier).state = m;
    final a = ref.read(_paymentsAnchorProvider);
    ref.read(_paymentsRangeProvider.notifier).state = _rangeKeyForMode(m, a);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          for (final m in [('day', 'Day'), ('week', 'Week'), ('month', 'Month')])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(m.$2),
                selected: mode == m.$1,
                onSelected: (_) => _setMode(ref, m.$1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: TextStyle(fontSize: 12, color: mode == m.$1 ? cs.onPrimary : null),
                selectedColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _move(ref, -1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Text(_label(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _move(ref, 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
      ]),
    );
  }
}

// ── Payments list with search + summary ──────────────────────────────────────

class _PaymentsList extends StatefulWidget {
  final List<Map<String, dynamic>> list;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _PaymentsList({required this.list, required this.onEdit, required this.onDelete});

  @override
  State<_PaymentsList> createState() => _PaymentsListState();
}

class _PaymentsListState extends State<_PaymentsList> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered() {
    if (_search.isEmpty) return widget.list;
    return widget.list.where((p) {
      final name  = (p['vendorName'] as String? ?? '').toLowerCase();
      return name.contains(_search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered   = _filtered();
    final totalAmt   = filtered.fold<double>(0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));

    if (widget.list.isEmpty) {
      return const AppEmptyState(
        icon: Icons.payments_outlined,
        message: 'No payments in this period',
        hint: 'Switch date range or tap + to record a payment',
      );
    }

    return Column(children: [
      // Summary bar
      Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.blue),
          const SizedBox(width: 6),
          Text('${filtered.length} payment${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Text(fmtCurr(totalAmt),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                  color: Colors.blue.shade800)),
        ]),
      ),
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by party name…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() { _search = ''; _searchCtrl.clear(); }))
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
        ),
      ),
      Expanded(
        child: filtered.isEmpty
            ? const AppEmptyState(icon: Icons.search_off, message: 'No payments match search')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                itemCount: filtered.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentCard(
                    payment: filtered[i],
                    onEdit: () => widget.onEdit(filtered[i]),
                    onDelete: () => widget.onDelete(filtered[i]),
                  ),
                ),
              ),
      ),
    ]);
  }
}

// ── Payment card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PaymentCard({required this.payment, required this.onEdit, required this.onDelete});

  static const _modeColors = {
    'CASH': Colors.green, 'BANK': Colors.blue,
    'CHEQUE': Colors.orange, 'UPI': Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final mode      = payment['paymentMode'] as String? ?? 'CASH';
    final modeColor = _modeColors[mode] ?? Colors.grey;
    final amount    = payment['amount'] as num? ?? 0;
    final payDate   = DateTime.parse(payment['paymentDate'] as String);
    final ref       = (payment['referenceNo'] as String?)?.trim() ?? '';
    final notes     = (payment['notes'] as String?)?.trim() ?? '';
    final allocStr  = (payment['allocationSummary'] as String?)?.trim();

    // Determine allocation display
    final allocLines = allocStr != null && allocStr.isNotEmpty
        ? allocStr.split('\n')
        : <String>['Unallocated — Advance'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(mode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: modeColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(payment['vendorName'] as String? ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(_dateFmt.format(payDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (payment['invoiceNo'] != null)
                Text('Invoice: ${payment['invoiceNo']}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700])),
              if (ref.isNotEmpty)
                Text('Ref: $ref', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              if (notes.isNotEmpty)
                Text(notes, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              // Allocation breakdown
              ...allocLines.map((line) => Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(line,
                    style: TextStyle(fontSize: 11,
                        color: line.contains('Advance') || line.contains('Unallocated')
                            ? Colors.blue[700] : Colors.grey[600],
                        fontStyle: FontStyle.italic)),
              )),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtCurr(amount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                // Delay so the popup's exit animation completes before we show
                // another overlay — prevents lifecycle assertion crashes.
                await Future.delayed(Duration.zero);
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Party Search Dialog (same pattern as Trips) ───────────────────────────────

class _PartyPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vendors;
  final int? currentId;
  const _PartyPickerDialog({required this.vendors, this.currentId});

  @override
  State<_PartyPickerDialog> createState() => _PartyPickerDialogState();
}

class _PartyPickerDialogState extends State<_PartyPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.vendors
        : widget.vendors.where((v) {
            final name  = (v['name']    as String? ?? '').toLowerCase();
            final phone = (v['contact'] as String? ?? '').toLowerCase();
            return name.contains(_query) || phone.contains(_query);
          }).toList();
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Select Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name or phone…',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (q) => setState(() => _query = q.toLowerCase().trim()),
              ),
            ]),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No parties found', style: TextStyle(color: Colors.grey))))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = filtered[i];
                      final id      = v['id'] as int?;
                      final contact = v['contact'] as String? ?? '';
                      return ListTile(
                        dense: true,
                        title: Text(v['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: contact.isNotEmpty ? Text(contact) : null,
                        trailing: id == widget.currentId
                            ? Icon(Icons.check, color: cs.primary, size: 20) : null,
                        tileColor: id == widget.currentId
                            ? cs.primary.withValues(alpha: 0.06) : null,
                        onTap: () => Navigator.pop(context, v),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }
}

// ── Public helper — open Record Payment dialog from any screen ────────────────

/// Opens the Record Payment form as a dialog, optionally pre-filling a party.
/// Call this from the Trips screen (or any other screen) to reuse the same form.
void showRecordPaymentDialog(
  BuildContext context,
  WidgetRef ref, {
  int? initialVendorId,
  String? initialVendorName,
  VoidCallback? onSaved,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaymentForm(
      existing: null,
      initialVendorId: initialVendorId,
      initialVendorName: initialVendorName,
      onSaved: onSaved ?? () {},
    ),
  );
}

// ── Payment form ──────────────────────────────────────────────────────────────

class _PaymentForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  final int? initialVendorId;
  final String? initialVendorName;
  const _PaymentForm({
    required this.existing,
    required this.onSaved,
    this.initialVendorId,
    this.initialVendorName,
  });

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  int?    _vendorId;
  String  _vendorName = '';
  int?    _invoiceId;
  late DateTime _date;
  String  _mode = 'CASH';
  final _amtCtrl   = TextEditingController();
  final _refCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool    _saving  = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null ? DateTime.parse(e['paymentDate'] as String) : DateTime.now();
    if (e != null) {
      _vendorId   = e['vendorId']     as int?;
      _vendorName = e['vendorName']   as String? ?? '';
      _invoiceId  = e['invoiceId']    as int?;
      _mode       = e['paymentMode']  as String? ?? 'CASH';
      _amtCtrl.text  = (e['amount']      as num? ?? 0).toString();
      _refCtrl.text  = e['referenceNo']  as String? ?? '';
      _notesCtrl.text = e['notes']       as String? ?? '';
    } else if (widget.initialVendorId != null) {
      _vendorId   = widget.initialVendorId;
      _vendorName = widget.initialVendorName ?? '';
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── FIFO preview (pure frontend calculation, same logic as backend) ─────────

  List<_AllocLine> _computeFifoPreview(
      Map<String, dynamic> balance, double paymentAmount) {
    final trips = balance['trips'] as List? ?? [];
    final totalPaid = (balance['totalPaid'] as num?)?.toDouble() ?? 0;
    if (trips.isEmpty) return [];

    final List<_AllocLine> lines = [];
    double remaining = paymentAmount;
    double cumulativeBilled = 0;
    double cumulativeCovered = totalPaid;

    for (final t in trips) {
      final bill    = (t['totalBill'] as num?)?.toDouble() ?? 0;
      if (bill <= 0) continue;
      final prevCum = cumulativeBilled;
      cumulativeBilled += bill;

      final alreadySettled = (cumulativeCovered.clamp(prevCum, cumulativeBilled) - prevCum).clamp(0, bill);
      final tripDue = bill - alreadySettled;
      if (tripDue <= 0) continue;
      if (remaining <= 0) break;

      final dateStr  = _dateFmt.format(DateTime.parse(t['tripDate'] as String));
      final matName  = t['materialName'] as String? ?? '—';
      if (remaining >= tripDue) {
        lines.add(_AllocLine('$dateStr — $matName ${fmtCurr(tripDue)}', 'full'));
        remaining -= tripDue;
      } else {
        final stillDue = tripDue - remaining;
        lines.add(_AllocLine(
            '$dateStr — $matName ${fmtCurr(tripDue)}  (${fmtCurr(stillDue)} still due)', 'partial'));
        remaining = 0;
      }
    }

    if (remaining > 0.5) {
      lines.add(_AllocLine('₹${fmtCurr(remaining)} held as Advance', 'advance'));
    }
    return lines;
  }

  Future<void> _save() async {
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a party'), backgroundColor: Colors.red));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      'vendorId':    _vendorId,
      if (_invoiceId != null) 'invoiceId': _invoiceId,
      'paymentDate': DateFormat('yyyy-MM-dd').format(_date),
      'amount':      double.parse(_amtCtrl.text),
      'paymentMode': _mode,
      if (_refCtrl.text.trim().isNotEmpty)   'referenceNo': _refCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes':       _notesCtrl.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    final e   = widget.existing;
    try {
      if (e == null) {
        await api.post('/api/party-payments', data: body);
      } else {
        await api.put('/api/party-payments/${e['id']}', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (ex) {
      setState(() => _saving = false);
      if (mounted) {
        final msg = ex is DioException
            ? (ex.response?.data is Map
                ? (ex.response!.data['error'] ?? ex.response!.data.toString())
                : ex.message ?? 'Request failed')
            : ex.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors  = ref.watch(_vendorsProvider);
    final isEdit   = widget.existing != null;
    final balAsync = _vendorId != null ? ref.watch(_vendorTripBalanceProvider(_vendorId!)) : null;
    final balance  = balAsync?.valueOrNull;
    final outstanding = (balance?['outstanding'] as num?)?.toDouble() ?? 0;
    final enteredAmt  = double.tryParse(_amtCtrl.text) ?? 0;
    final preview     = (balance != null && enteredAmt > 0)
        ? _computeFifoPreview(balance, enteredAmt) : <_AllocLine>[];
    final newBalance  = outstanding - enteredAmt;

    return AppDialog(
      title: isEdit ? 'Edit Payment' : 'Record Payment',
      maxWidth: 480,
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
            // ── Party picker (dialog style, same as trips) ──────────────
            vendors.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                final active = list.where((v) => v['status'] == 'ACTIVE').toList();
                return InkWell(
                  onTap: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => _PartyPickerDialog(
                          vendors: active, currentId: _vendorId),
                    );
                    if (result != null) {
                      setState(() {
                        _vendorId   = result['id'] as int?;
                        _vendorName = result['name'] as String? ?? '';
                        _invoiceId  = null;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Party *',
                      border: const OutlineInputBorder(),
                      errorText: _vendorId == null && _saving ? 'Select party' : null,
                    ),
                    isEmpty: _vendorName.isEmpty,
                    child: _vendorName.isNotEmpty
                        ? Text(_vendorName, style: const TextStyle(fontSize: 14))
                        : Text('Tap to select party',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  ),
                );
              },
            ),

            // ── Current balance display ─────────────────────────────────
            if (_vendorId != null) ...[
              const SizedBox(height: 8),
              balAsync!.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (bal) {
                  if (bal == null) return const SizedBox.shrink();
                  final out = (bal['outstanding'] as num?)?.toDouble() ?? 0;
                  final label = _balanceLabel(out);
                  final color = _balanceColor(out);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 16, color: color),
                      const SizedBox(width: 8),
                      Text('Current $label: ', style: TextStyle(fontSize: 13, color: color)),
                      Text(_fmtBalance(out),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                    ]),
                  );
                },
              ),
            ],

            const SizedBox(height: 12),
            DateField(
              label: 'Payment Date',
              date: _date,
              required: true,
              onTap: () async {
                final d = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amtCtrl,
              decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),

            // ── Live FIFO allocation preview ────────────────────────────
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('This payment will be applied as:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  ...preview.map((line) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      Icon(
                        line.type == 'full' ? Icons.check_circle_outline
                            : line.type == 'advance' ? Icons.savings_outlined
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: line.type == 'full' ? Colors.green
                            : line.type == 'advance' ? Colors.blue
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(line.text,
                          style: TextStyle(fontSize: 12, color: Colors.grey[800]))),
                    ]),
                  )),
                  const Divider(height: 16),
                  Row(children: [
                    Text('New Balance after this payment: ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    Text(
                      newBalance.abs() < 0.5
                          ? 'Fully Paid'
                          : '${_balanceLabel(newBalance)} ${_fmtBalance(newBalance)}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: newBalance.abs() < 0.5
                              ? Colors.green : _balanceColor(newBalance)),
                    ),
                  ]),
                ]),
              ),
            ],

            const SectionLabel('Payment Mode'),
            Wrap(
              spacing: 8,
              children: ['CASH', 'BANK', 'CHEQUE', 'UPI']
                  .map((m) => ChoiceChip(
                        label: Text(m),
                        selected: _mode == m,
                        onSelected: (_) => setState(() => _mode = m),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _refCtrl,
              decoration: const InputDecoration(labelText: 'Reference No. / Cheque No.'),
            ),
            const SizedBox(height: 8),
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

class _AllocLine {
  final String text;
  final String type; // 'full' | 'partial' | 'advance'
  const _AllocLine(this.text, this.type);
}
