import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

// ── paginated invoices state + notifier ───────────────────────────────────────

class _InvoicesState {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final bool loadingMore;
  final int nextPage;
  final int totalElements;
  const _InvoicesState({
    required this.items,
    required this.hasMore,
    required this.loadingMore,
    required this.nextPage,
    required this.totalElements,
  });
  _InvoicesState copyWith({bool? loadingMore}) => _InvoicesState(
        items: items, hasMore: hasMore, nextPage: nextPage,
        totalElements: totalElements,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class _InvoicesNotifier
    extends StateNotifier<AsyncValue<_InvoicesState>> {
  final ApiClient _api;
  static const _pageSize = 25;

  _InvoicesNotifier(this._api) : super(const AsyncValue.loading()) {
    _load(0, []);
  }

  Future<void> _load(int page, List<Map<String, dynamic>> existing) async {
    try {
      final res = await _api.get('/api/invoices',
          params: {'page': '$page', 'size': '$_pageSize'});
      final d = res.data as Map<String, dynamic>;
      final content =
          List<Map<String, dynamic>>.from(d['content'] as List);
      final last = d['last'] as bool;
      final total = (d['totalElements'] as num).toInt();
      state = AsyncValue.data(_InvoicesState(
        items: [...existing, ...content],
        hasMore: !last,
        loadingMore: false,
        nextPage: page + 1,
        totalElements: total,
      ));
    } catch (e, st) {
      if (page == 0) state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncValue.data(s.copyWith(loadingMore: true));
    await _load(s.nextPage, s.items);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _load(0, []);
  }
}

final _invoicesNotifierProvider = StateNotifierProvider.autoDispose<
    _InvoicesNotifier, AsyncValue<_InvoicesState>>(
  (ref) => _InvoicesNotifier(ref.read(apiClientProvider)),
);

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

final _invoicePaymentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>(
        (ref, invoiceId) async {
  final res = await ref.read(apiClientProvider)
      .get('/api/invoices/$invoiceId/payments');
  return List<Map<String, dynamic>>.from(res.data);
});

final _dateFmt = DateFormat('d MMM yyyy');

// ── payment status config ─────────────────────────────────────────────────────

Color _statusColor(String? s) => switch (s) {
      'PAID'    => Colors.green,
      'PARTIAL' => Colors.orange,
      _         => Colors.red,
    };

String _statusLabel(String? s) => switch (s) {
      'PAID'    => 'PAID',
      'PARTIAL' => 'PARTIAL',
      _         => 'UNPAID',
    };

// ── screen ───────────────────────────────────────────────────────────────────

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(_invoicesNotifierProvider);
    final notifier = ref.read(_invoicesNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: notifier.refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (state) {
          if (state.items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No invoices yet',
              hint: 'Tap + to create your first GST invoice',
            );
          }
          final unpaid  = state.items.where((i) => i['paymentStatus'] == 'UNPAID').length;
          final partial = state.items.where((i) => i['paymentStatus'] == 'PARTIAL').length;
          final paid    = state.items.where((i) => i['paymentStatus'] == 'PAID').length;

          return Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _SummaryPill('Unpaid', unpaid, Colors.red),
                    const SizedBox(width: 12),
                    _SummaryPill('Partial', partial, Colors.orange),
                    const SizedBox(width: 12),
                    _SummaryPill('Paid', paid, Colors.green),
                    const Spacer(),
                    Text(
                      state.totalElements == state.items.length
                          ? '${state.items.length} invoices'
                          : '${state.items.length} of ${state.totalElements}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == state.items.length) {
                      return _LoadMoreButton(
                        loading: state.loadingMore,
                        onTap: notifier.loadMore,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InvoiceCard(
                        invoice: state.items[i],
                        onTap: () => _showDetail(context, ref, state.items[i]),
                        onEdit: () => _showForm(context, ref, state.items[i]),
                        onDelete: () => _confirmDelete(context, ref, state.items[i]),
                        onRecordPayment: () =>
                            _showPaymentForm(context, ref, state.items[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? inv) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _InvoiceForm(
        existing: inv,
        onSaved: () => ref.read(_invoicesNotifierProvider.notifier).refresh(),
      ),
    );
  }

  void _showDetail(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => _InvoiceDetailDialog(invoice: inv),
    );
  }

  void _showPaymentForm(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _QuickPaymentDialog(
        invoice: inv,
        onSaved: () {
          ref.read(_invoicesNotifierProvider.notifier).refresh();
          ref.invalidate(_invoicePaymentsProvider(inv['id'] as int));
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: Text(
            'Cancel ${inv['invoiceNo']} for ${inv['vendorName']}?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(apiClientProvider).delete('/api/invoices/${inv['id']}');
              ref.read(_invoicesNotifierProvider.notifier).refresh();
            },
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }
}

// ── load more button ──────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoadMoreButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : OutlinedButton(
                  onPressed: onTap,
                  child: const Text('Load more'),
                ),
        ),
      );
}

// ── summary pill ──────────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text('$count $label',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── invoice card ─────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRecordPayment;
  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final cs           = Theme.of(context).colorScheme;
    final grandTotal   = invoice['grandTotal'] as num? ?? 0;
    final totalPaid    = invoice['totalPaid'] as num? ?? 0;
    final outstanding  = invoice['outstandingAmount'] as num? ?? 0;
    final status       = invoice['paymentStatus'] as String? ?? 'UNPAID';
    final statusColor  = _statusColor(status);
    final invoiceDate  = DateTime.parse(invoice['invoiceDate'] as String);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Left: icon + status
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_long, color: cs.primary, size: 22),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_statusLabel(status),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Middle: invoice info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice['invoiceNo'] as String? ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(invoice['vendorName'] as String? ?? '—',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    Text(_dateFmt.format(invoiceDate),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: amounts
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtCurr(grandTotal),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.primary)),
                  if (totalPaid > 0) ...[
                    Text('Paid: ${fmtCurr(totalPaid)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.green.shade700)),
                  ],
                  if (status != 'PAID')
                    Text('Due: ${fmtCurr(outstanding)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                ],
              ),
              // Menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'pay')  onRecordPayment();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (invoice['paymentStatus'] != 'PAID')
                    const PopupMenuItem(
                        value: 'pay',
                        child: Text('Record Payment',
                            style: TextStyle(color: Colors.green))),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Cancel Invoice',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── invoice detail dialog ─────────────────────────────────────────────────────

class _InvoiceDetailDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceDetailDialog({required this.invoice});

  @override
  ConsumerState<_InvoiceDetailDialog> createState() =>
      _InvoiceDetailDialogState();
}

class _InvoiceDetailDialogState
    extends ConsumerState<_InvoiceDetailDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv       = widget.invoice;
    final invoiceId = inv['id'] as int;
    final items     = List<Map<String, dynamic>>.from(inv['items'] as List? ?? []);
    final cgstRate  = inv['cgstRate'] as num? ?? 9;
    final sgstRate  = inv['sgstRate'] as num? ?? 9;
    final subtotal  = inv['subtotal'] as num? ?? 0;
    final cgstAmt   = inv['cgstAmount'] as num? ?? 0;
    final sgstAmt   = inv['sgstAmount'] as num? ?? 0;
    final grandTotal = inv['grandTotal'] as num? ?? 0;
    final totalPaid  = inv['totalPaid'] as num? ?? 0;
    final outstanding = inv['outstandingAmount'] as num? ?? 0;
    final status     = inv['paymentStatus'] as String? ?? 'UNPAID';
    final statusColor = _statusColor(status);

    final payments = ref.watch(_invoicePaymentsProvider(invoiceId));

    return AppDialog(
      title: inv['invoiceNo'] as String? ?? 'Invoice',
      maxWidth: 600,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header info block
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv['vendorName'] as String? ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                          'Date: ${_dateFmt.format(DateTime.parse(inv['invoiceDate'] as String))}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      if (inv['poNo'] != null)
                        Text('PO: ${inv['poNo']}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(_statusLabel(status),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ),
                    const SizedBox(height: 4),
                    Text(fmtCurr(grandTotal),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (totalPaid > 0)
                      Text('Paid: ${fmtCurr(totalPaid)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.green.shade700)),
                    if (status != 'PAID')
                      Text('Due: ${fmtCurr(outstanding)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tabs
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Line Items'),
              Tab(text: 'Payments'),
            ],
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabs,
              children: [
                // Line items tab
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.8),
                        },
                        border: TableBorder.all(color: Colors.grey.shade200),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[100]),
                            children: const [
                              _TH('Description'),
                              _TH('Qty (B)'),
                              _TH('Rate'),
                              _TH('Amount'),
                            ],
                          ),
                          ...items.map((item) => TableRow(children: [
                                _TD(item['description'] as String? ?? '—'),
                                _TD(item['quantityBrass'] != null
                                    ? (item['quantityBrass'] as num)
                                        .toStringAsFixed(2)
                                    : '—'),
                                _TD(item['rate'] != null
                                    ? fmtCurr(item['rate'])
                                    : '—'),
                                _TD(fmtCurr(item['amount'] as num? ?? 0)),
                              ])),
                        ],
                      ),
                      const Divider(height: 20),
                      _TotalRow('Subtotal', subtotal),
                      _TotalRow('CGST ($cgstRate%)', cgstAmt),
                      _TotalRow('SGST ($sgstRate%)', sgstAmt),
                      const Divider(),
                      _TotalRow('Grand Total', grandTotal, bold: true),
                    ],
                  ),
                ),
                // Payments tab
                payments.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (list) => list.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.payment_outlined,
                          message: 'No payments recorded for this invoice',
                          hint:
                              'Use "Record Payment" from the invoice menu',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) =>
                              _PaymentTile(payment: list[i]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentTile({required this.payment});

  static const _modeColors = {
    'CASH':   Colors.green,
    'BANK':   Colors.blue,
    'CHEQUE': Colors.orange,
    'UPI':    Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final mode      = payment['paymentMode'] as String? ?? 'CASH';
    final color     = _modeColors[mode] ?? Colors.grey;
    final amount    = payment['amount'] as num? ?? 0;
    final date      = DateTime.parse(payment['paymentDate'] as String);
    final ref       = (payment['referenceNo'] as String?)?.trim() ?? '';
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(mode,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ),
      title: Text(fmtCurr(amount),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
          [_dateFmt.format(date), if (ref.isNotEmpty) ref].join('  ·  '),
          style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.check_circle,
          color: Colors.green.shade600, size: 18),
    );
  }
}

// ── quick payment dialog ──────────────────────────────────────────────────────

class _QuickPaymentDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onSaved;
  const _QuickPaymentDialog(
      {required this.invoice, required this.onSaved});

  @override
  ConsumerState<_QuickPaymentDialog> createState() =>
      _QuickPaymentDialogState();
}

class _QuickPaymentDialogState
    extends ConsumerState<_QuickPaymentDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _amtCtrl  = TextEditingController();
  final _refCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _mode    = 'CASH';
  late DateTime _date;
  bool _saving    = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    // Pre-fill with outstanding amount
    final outstanding = widget.invoice['outstandingAmount'] as num? ?? 0;
    if (outstanding > 0) {
      _amtCtrl.text = outstanding.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'vendorId':   widget.invoice['vendorId'],
      'invoiceId':  widget.invoice['id'],
      'paymentDate': DateFormat('yyyy-MM-dd').format(_date),
      'amount':     double.parse(_amtCtrl.text.trim()),
      'paymentMode': _mode,
      'referenceNo': _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      'notes':      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    };
    try {
      await ref.read(apiClientProvider).post('/api/party-payments', data: body);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv         = widget.invoice;
    final grandTotal  = inv['grandTotal'] as num? ?? 0;
    final totalPaid   = inv['totalPaid'] as num? ?? 0;
    final outstanding = inv['outstandingAmount'] as num? ?? 0;

    return AppDialog(
      title: 'Record Payment',
      maxWidth: 420,
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Payment'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice summary
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv['invoiceNo'] as String? ?? '—',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(inv['vendorName'] as String? ?? '—',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total: ${fmtCurr(grandTotal)}',
                          style: const TextStyle(fontSize: 12)),
                      if (totalPaid > 0)
                        Text('Paid: ${fmtCurr(totalPaid)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade700)),
                      Text('Due: ${fmtCurr(outstanding)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DateField(
              label: 'Payment Date',
              date: _date,
              required: true,
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)));
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amtCtrl,
              decoration: const InputDecoration(
                  labelText: 'Amount *', prefixText: '₹ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
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
              decoration: const InputDecoration(
                  labelText: 'Reference No. / Cheque No.'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
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

// ── invoice form ──────────────────────────────────────────────────────────────

class _ItemRow {
  final descCtrl = TextEditingController();
  final hsnCtrl  = TextEditingController();
  final qtyCtrl  = TextEditingController();
  final rateCtrl = TextEditingController();
  final amtCtrl  = TextEditingController();

  _ItemRow({Map<String, dynamic>? data}) {
    if (data != null) {
      descCtrl.text = data['description'] as String? ?? '';
      hsnCtrl.text  = data['hsn'] as String? ?? '';
      final qty  = data['quantityBrass'];
      if (qty != null)  qtyCtrl.text  = qty.toString();
      final rate = data['rate'];
      if (rate != null) rateCtrl.text = rate.toString();
      amtCtrl.text = (data['amount'] as num? ?? 0).toString();
    }
  }

  void dispose() {
    descCtrl.dispose(); hsnCtrl.dispose(); qtyCtrl.dispose();
    rateCtrl.dispose(); amtCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        'description':   descCtrl.text.trim(),
        'hsn':           hsnCtrl.text.trim().isEmpty ? null : hsnCtrl.text.trim(),
        'quantityBrass': double.tryParse(qtyCtrl.text),
        'rate':          double.tryParse(rateCtrl.text),
        'amount':        double.tryParse(amtCtrl.text) ?? 0.0,
      };
}

class _InvoiceForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _InvoiceForm({required this.existing, required this.onSaved});

  @override
  ConsumerState<_InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends ConsumerState<_InvoiceForm> {
  final _formKey  = GlobalKey<FormState>();
  int? _vendorId;
  late DateTime _invoiceDate;
  DateTime? _supplyDate;
  final _poCtrl    = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_ItemRow> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _invoiceDate = e != null
        ? DateTime.parse(e['invoiceDate'] as String) : DateTime.now();
    if (e != null) {
      _vendorId = e['vendorId'] as int?;
      if (e['supplyDate'] != null) {
        _supplyDate = DateTime.parse(e['supplyDate'] as String);
      }
      _poCtrl.text    = e['poNo'] as String? ?? '';
      _notesCtrl.text = e['notes'] as String? ?? '';
      for (final item in (e['items'] as List? ?? [])) {
        _items.add(_ItemRow(data: item as Map<String, dynamic>));
      }
    }
    if (_items.isEmpty) _items.add(_ItemRow());
    for (final row in _items) {
      row.qtyCtrl.addListener(() => _autoCalc(row));
      row.rateCtrl.addListener(() => _autoCalc(row));
    }
  }

  void _autoCalc(_ItemRow row) {
    final qty  = double.tryParse(row.qtyCtrl.text);
    final rate = double.tryParse(row.rateCtrl.text);
    if (qty != null && rate != null) {
      final formatted = (qty * rate).toStringAsFixed(2);
      if (row.amtCtrl.text != formatted) row.amtCtrl.text = formatted;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final r in _items) r.dispose();
    _poCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final row = _ItemRow();
    row.qtyCtrl.addListener(() => _autoCalc(row));
    row.rateCtrl.addListener(() => _autoCalc(row));
    setState(() => _items.add(row));
  }

  void _removeItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  double get _subtotal =>
      _items.fold(0, (s, r) => s + (double.tryParse(r.amtCtrl.text) ?? 0));

  Future<void> _pickDate(bool isInvoice) async {
    final init = isInvoice ? _invoiceDate : (_supplyDate ?? _invoiceDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => isInvoice ? _invoiceDate = picked : _supplyDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    final body = {
      'vendorId':   _vendorId,
      'invoiceDate': DateFormat('yyyy-MM-dd').format(_invoiceDate),
      'supplyDate': _supplyDate != null
          ? DateFormat('yyyy-MM-dd').format(_supplyDate!) : null,
      'poNo':   _poCtrl.text.trim().isEmpty ? null : _poCtrl.text.trim(),
      'notes':  _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'items':  _items.map((r) => r.toJson()).toList(),
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/invoices', data: body);
      } else {
        await api.put('/api/invoices/${widget.existing!['id']}', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors  = ref.watch(_vendorsProvider);
    final sub  = _subtotal;
    final cgst = sub * 0.09;
    final sgst = sub * 0.09;
    final grand = sub + cgst + sgst;
    final isEdit = widget.existing != null;

    return AppDialog(
      title: isEdit ? 'Edit Invoice' : 'New GST Invoice',
      maxWidth: 560,
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update' : 'Save Invoice'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Invoice Details'),
            vendors.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                final active =
                    list.where((v) => v['status'] == 'ACTIVE').toList();
                return SearchablePicker(
                  items: active,
                  itemLabel: (v) => v['name'] as String,
                  fieldLabel: 'Party *',
                  value: _vendorId,
                  onChanged: (v) => setState(() => _vendorId = v),
                  validator: (v) => v == null ? 'Select party' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DateField(
                  label: 'Invoice Date', date: _invoiceDate, required: true,
                  onTap: () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(child: DateField(
                  label: 'Supply Date', date: _supplyDate,
                  onTap: () => _pickDate(false))),
            ]),
            const SizedBox(height: 12),
            TextFormField(
                controller: _poCtrl,
                decoration: const InputDecoration(labelText: 'PO No.')),
            const SectionLabel('Line Items'),
            ..._items.asMap().entries.map((e) => _ItemRowWidget(
                  row: e.value, index: e.key,
                  canRemove: _items.length > 1,
                  onRemove: () => _removeItem(e.key),
                  onChanged: () => setState(() {}),
                )),
            const SizedBox(height: 4),
            TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Line Item')),
            if (sub > 0) ...[
              const Divider(height: 20),
              _PreviewRow('Subtotal', sub),
              _PreviewRow('CGST 9%', cgst),
              _PreviewRow('SGST 9%', sgst),
              const Divider(height: 8),
              _PreviewRow('Grand Total', grand, bold: true),
            ],
            const SectionLabel('Notes'),
            TextFormField(
                controller: _notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

// ── item row widget ───────────────────────────────────────────────────────────

class _ItemRowWidget extends StatelessWidget {
  final _ItemRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ItemRowWidget({
    required this.row, required this.index, required this.canRemove,
    required this.onRemove, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Item ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                    onTap: onRemove,
                    child: const Icon(Icons.close, size: 18, color: Colors.red)),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              controller: row.descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description *', isDense: true),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(
                controller: row.hsnCtrl,
                decoration: const InputDecoration(
                    labelText: 'HSN Code', isDense: true),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: row.qtyCtrl,
                decoration: const InputDecoration(
                    labelText: 'Qty (Brass)', isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(
                controller: row.rateCtrl,
                decoration: const InputDecoration(
                    labelText: 'Rate', isDense: true, prefixText: '₹'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: row.amtCtrl,
                decoration: const InputDecoration(
                    labelText: 'Amount *', isDense: true, prefixText: '₹'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (v == null || double.tryParse(v) == null) ? 'Required' : null,
              )),
            ]),
          ],
        ),
      );
}

// ── shared table cells ────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _TD extends StatelessWidget {
  final String text;
  const _TD(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis),
      );
}

class _TotalRow extends StatelessWidget {
  final String label;
  final num value;
  final bool bold;
  const _TotalRow(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 15 : 13)),
            Text(fmtCurr(value),
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 15 : 13,
                    color: bold
                        ? Theme.of(context).colorScheme.primary : null)),
          ],
        ),
      );
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _PreviewRow(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 14 : 13)),
            Text(fmtCurr(value),
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 14 : 13,
                    color: bold
                        ? Theme.of(context).colorScheme.primary : null)),
          ],
        ),
      );
}
