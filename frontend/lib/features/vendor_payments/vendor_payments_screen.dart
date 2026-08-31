import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

// ── providers ────────────────────────────────────────────────────────────────

final _paymentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vendor-payments');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vendors');
  return List<Map<String, dynamic>>.from(res.data);
});

final _fmt = NumberFormat('#,##,##0.00', 'en_IN');
final _dateFmt = DateFormat('d MMM yyyy');

// ── screen ───────────────────────────────────────────────────────────────────

class VendorPaymentsScreen extends ConsumerWidget {
  const VendorPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(_paymentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_paymentsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No payments recorded',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Group by vendor for summary banner
          final Map<String, double> totals = {};
          for (final p in data) {
            final name = p['vendorName'] as String? ?? 'Unknown';
            totals[name] = (totals[name] ?? 0) + ((p['amount'] as num?) ?? 0);
          }

          return Column(
            children: [
              if (totals.length == 1) _SummaryBanner(totals: totals),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length,
                  separatorBuilder: (_, idx) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _PaymentCard(
                    payment: data[i],
                    onEdit: () => _showForm(context, ref, data[i]),
                    onDelete: () => _confirmDelete(context, ref, data[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? p) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _PaymentForm(
        existing: p,
        onSaved: () => ref.invalidate(_paymentsProvider),
      ),
    );
  }

  void _confirmDelete(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> p) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text(
            'Delete ₹${_fmt.format(p['amount'] as num? ?? 0)} payment to ${p['vendorName']}?'),
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
                  .delete('/api/vendor-payments/${p['id']}');
              ref.invalidate(_paymentsProvider);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final Map<String, double> totals;
  const _SummaryBanner({required this.totals});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = totals.values.fold(0.0, (a, b) => a + b);
    return Container(
      color: cs.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined),
          const SizedBox(width: 8),
          Text('Total Paid to ${totals.keys.first}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('₹${_fmt.format(total)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: cs.primary)),
        ],
      ),
    );
  }
}

// ── payment card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PaymentCard(
      {required this.payment,
      required this.onEdit,
      required this.onDelete});

  static const _modeColors = {
    'CASH': Colors.green,
    'BANK': Colors.blue,
    'CHEQUE': Colors.orange,
    'UPI': Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final mode = payment['paymentMode'] as String? ?? 'CASH';
    final modeColor = _modeColors[mode] ?? Colors.grey;
    final amount = payment['amount'] as num? ?? 0;
    final payDate = DateTime.parse(payment['paymentDate'] as String);
    final ref = (payment['referenceNo'] as String?)?.trim() ?? '';
    final notes = (payment['notes'] as String?)?.trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(mode,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: modeColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payment['vendorName'] as String? ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_dateFmt.format(payDate),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (ref.isNotEmpty)
                    Text('Ref: $ref',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  if (notes.isNotEmpty)
                    Text(notes,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Text('₹${_fmt.format(amount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green)),
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
      ),
    );
  }
}

// ── form ──────────────────────────────────────────────────────────────────────

class _PaymentForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _PaymentForm({required this.existing, required this.onSaved});

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  int? _vendorId;
  late DateTime _date;
  String _mode = 'CASH';
  final _amtCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null
        ? DateTime.parse(e['paymentDate'] as String)
        : DateTime.now();
    if (e != null) {
      _vendorId = e['vendorId'] as int?;
      _mode = e['paymentMode'] as String? ?? 'CASH';
      _amtCtrl.text = (e['amount'] as num? ?? 0).toString();
      _refCtrl.text = e['referenceNo'] as String? ?? '';
      _notesCtrl.text = e['notes'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'vendorId': _vendorId,
      'paymentDate': DateFormat('yyyy-MM-dd').format(_date),
      'amount': double.parse(_amtCtrl.text),
      'paymentMode': _mode,
      'referenceNo':
          _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    if (e == null) {
      await api.post('/api/vendor-payments', data: body);
    } else {
      await api.put('/api/vendor-payments/${e['id']}', data: body);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(_vendorsProvider);
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Payment' : 'Record Payment'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                vendors.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (list) {
                    final active =
                        list.where((v) => v['status'] == 'ACTIVE').toList();
                    return DropdownButtonFormField<int>(
                      decoration:
                          const InputDecoration(labelText: 'Vendor *'),
                      initialValue: _vendorId,
                      items: active
                          .map((v) => DropdownMenuItem<int>(
                                value: v['id'] as int,
                                child: Text(v['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _vendorId = v),
                      validator: (v) =>
                          v == null ? 'Select vendor' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_dateFmt.format(_date)),
                  subtitle: const Text('Payment Date'),
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
                const SizedBox(height: 8),
                // Amount
                TextFormField(
                  controller: _amtCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Amount (₹) *', prefixText: '₹ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Payment mode
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Payment Mode',
                        style: TextStyle(fontSize: 12, color: Colors.grey))),
                const SizedBox(height: 6),
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
                  decoration: const InputDecoration(
                      labelText: 'Reference No. / Cheque No.'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
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
    );
  }
}
