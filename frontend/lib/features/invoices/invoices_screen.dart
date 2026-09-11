import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

// ── Combined state: both GST invoices and Job-Work invoices merged ─────────────

final _allInvoicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final results = await Future.wait([
    api.get('/api/invoices', params: {'page': '0', 'size': '500'}),
    api.get('/api/job-work-invoices', params: {'page': '0', 'size': '500'}),
  ]);

  final gst = List<Map<String, dynamic>>.from(results[0].data['content'] as List)
      .map((m) => {...m, '_src': 'gst'}).toList();
  final jw = List<Map<String, dynamic>>.from(results[1].data['content'] as List)
      .map((m) => {...m, '_src': 'jw'}).toList();

  final all = [...gst, ...jw];
  all.sort((a, b) {
    final d = (b['invoiceDate'] as String).compareTo(a['invoiceDate'] as String);
    return d != 0 ? d : (b['id'] as int).compareTo(a['id'] as int);
  });
  return all;
});

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

final _invoiceMaterialsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/materials');
  return (res.data as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((m) => m['status'] == 'ACTIVE')
      .toList();
});

final _invoiceServicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/services');
  return (res.data as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((s) => s['status'] == 'ACTIVE')
      .toList();
});

final _invoiceSitesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/sites');
  return List<Map<String, dynamic>>.from(res.data);
});

final _invoicePaymentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>(
        (ref, invoiceId) async {
  final res =
      await ref.read(apiClientProvider).get('/api/invoices/$invoiceId/payments');
  return List<Map<String, dynamic>>.from(res.data);
});

final _dateFmt = DateFormat('d MMM yyyy');

// ── Status helpers ─────────────────────────────────────────────────────────────

Color _payStatusColor(String? s) => switch (s) {
      'PAID'    => Colors.green,
      'PARTIAL' => Colors.orange,
      _         => Colors.red,
    };

String _payStatusLabel(String? s) => switch (s) {
      'PAID'    => 'PAID',
      'PARTIAL' => 'PARTIAL',
      _         => 'UNPAID',
    };

// ── Screen ─────────────────────────────────────────────────────────────────────

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
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
    final gstId = extra['editGstId'] as int?;
    final jwId  = extra['editJwId']  as int?;
    if (gstId == null && jwId == null) return;
    _scheduleOpenInvoice(gstId: gstId, jwId: jwId);
  }

  Future<void> _scheduleOpenInvoice({int? gstId, int? jwId}) async {
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final items = ref.read(_allInvoicesProvider).valueOrNull;
      if (items != null) {
        Map<String, dynamic>? inv;
        if (gstId != null) {
          inv = items.where((it) => it['_src'] == 'gst' && (it['id'] as int?) == gstId).firstOrNull;
        } else if (jwId != null) {
          inv = items.where((it) => it['_src'] == 'jw' && (it['id'] as int?) == jwId).firstOrNull;
        }
        if (inv != null) {
          _showEdit(context, ref, inv);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice not found')),
          );
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(_allInvoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_allInvoicesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No invoices yet',
              hint: 'Tap + to create your first invoice',
            );
          }
          final gstItems = items.where((i) => i['_src'] == 'gst').toList();
          final unpaid   = gstItems.where((i) => i['paymentStatus'] == 'UNPAID').length;
          final partial  = gstItems.where((i) => i['paymentStatus'] == 'PARTIAL').length;
          final paid     = gstItems.where((i) => i['paymentStatus'] == 'PAID').length;
          final pending  = items.where((i) => i['gstStatus'] == 'PENDING').length;

          return Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _Pill('Unpaid', unpaid, Colors.red),
                    const SizedBox(width: 8),
                    _Pill('Partial', partial, Colors.orange),
                    const SizedBox(width: 8),
                    _Pill('Paid', paid, Colors.green),
                    if (pending > 0) ...[
                      const SizedBox(width: 8),
                      _Pill('GST Pending', pending, Colors.amber.shade800),
                    ],
                    const Spacer(),
                    Text('${items.length} invoices',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final inv = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InvoiceCard(
                        invoice: inv,
                        onTap: () => _showDetail(context, ref, inv),
                        onEdit: () => _showEdit(context, ref, inv),
                        onDelete: () => _confirmDelete(context, ref, inv),
                        onRecordPayment: inv['_src'] == 'gst'
                            ? () => _showPaymentForm(context, ref, inv)
                            : null,
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

  void _showNewForm(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('New Invoice Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Material Invoice (GST)'),
              subtitle: const Text('Sale of materials — standard tax invoice'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (_) => _UnifiedInvoiceForm(
                    existing: null,
                    onSaved: () => ref.invalidate(_allInvoicesProvider),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.build_circle_outlined),
              title: const Text('Job-Work Invoice'),
              subtitle: const Text('Crushing / loading services at a Client Site'),
              onTap: () {
                final services     = ref.read(_invoiceServicesProvider).valueOrNull ?? const [];
                final activeSiteId = ref.read(selectedSiteIdProvider);
                Navigator.pop(ctx);
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (_) => _JwForm(
                    existing: null,
                    services: services,
                    initialSiteId: activeSiteId,
                    onSaved: () => ref.invalidate(_allInvoicesProvider),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showDetail(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    if (inv['_src'] == 'gst') {
      showDialog(
        context: ctx,
        builder: (_) => _InvoiceDetailDialog(
          invoice: inv,
          onRefresh: () => ref.invalidate(_allInvoicesProvider),
        ),
      );
    } else {
      showDialog(
        context: ctx,
        builder: (_) => _JwDetailDialog(
          invoice: inv,
          onRefresh: () => ref.invalidate(_allInvoicesProvider),
        ),
      );
    }
  }

  void _showEdit(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    if (inv['_src'] == 'gst') {
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => _UnifiedInvoiceForm(
          existing: inv,
          onSaved: () => ref.invalidate(_allInvoicesProvider),
        ),
      );
    } else {
      final services = ref.read(_invoiceServicesProvider).valueOrNull ?? const [];
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => _JwForm(
          existing: inv,
          services: services,
          onSaved: () => ref.invalidate(_allInvoicesProvider),
        ),
      );
    }
  }

  void _showPaymentForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _QuickPaymentDialog(
        invoice: inv,
        onSaved: () {
          ref.invalidate(_allInvoicesProvider);
          ref.invalidate(_invoicePaymentsProvider(inv['id'] as int));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    final isJw = inv['_src'] == 'jw';
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: Text(
            'Cancel ${inv['invoiceNo']} for ${inv['vendorName']}?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final endpoint = isJw
                  ? '/api/job-work-invoices/${inv['id']}'
                  : '/api/invoices/${inv['id']}';
              try {
                await ref.read(apiClientProvider).delete(endpoint);
              } catch (_) {
                return;
              }
              if (!ctx.mounted) return;
              ref.invalidate(_allInvoicesProvider);
            },
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }
}

// ── Pill (summary bar) ────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Pill(this.label, this.count, this.color);

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

// ── Invoice card (handles both GST and JW invoices) ───────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRecordPayment; // null for JW invoices
  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final isJw       = invoice['_src'] == 'jw';
    final grandTotal = invoice['grandTotal'] as num? ?? 0;
    final gstStatus  = invoice['gstStatus'] as String? ?? 'SET';
    final isPending  = gstStatus == 'PENDING';
    final date       = DateTime.parse(invoice['invoiceDate'] as String);

    // Payment info (GST invoices only)
    final payStatus = invoice['paymentStatus'] as String?;
    final totalPaid = invoice['totalPaid'] as num? ?? 0;
    final outstanding = invoice['outstandingAmount'] as num? ?? 0;

    return Card(
      color: isPending ? Colors.amber.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon + status badge
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPending
                          ? Colors.orange.withValues(alpha: 0.12)
                          : cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isJw ? Icons.build_circle_outlined : Icons.receipt_long,
                      color: isPending ? Colors.orange : cs.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!isJw && payStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _payStatusColor(payStatus).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_payStatusLabel(payStatus),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _payStatusColor(payStatus))),
                    ),
                  if (isPending)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Text('GST Pending',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900)),
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
                    Text(
                      [
                        if (isJw && invoice['siteName'] != null)
                          invoice['siteName'] as String,
                        _dateFmt.format(date),
                      ].join('  ·  '),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
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
                  if (!isJw && totalPaid > 0)
                    Text('Paid: ${fmtCurr(totalPaid)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.green.shade700)),
                  if (!isJw && payStatus != 'PAID')
                    Text('Due: ${fmtCurr(outstanding)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _payStatusColor(payStatus))),
                ],
              ),
              // Menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'pay') onRecordPayment?.call();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (onRecordPayment != null && invoice['paymentStatus'] != 'PAID')
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

// ── GST Invoice detail dialog ─────────────────────────────────────────────────

class _InvoiceDetailDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onRefresh;
  const _InvoiceDetailDialog({required this.invoice, required this.onRefresh});

  @override
  ConsumerState<_InvoiceDetailDialog> createState() =>
      _InvoiceDetailDialogState();
}

class _InvoiceDetailDialogState extends ConsumerState<_InvoiceDetailDialog>
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
    final grandTotal    = inv['grandTotal'] as num? ?? 0;
    final totalPaid     = inv['totalPaid'] as num? ?? 0;
    final outstanding   = inv['outstandingAmount'] as num? ?? 0;
    final status        = inv['paymentStatus'] as String? ?? 'UNPAID';
    final statusColor   = _payStatusColor(status);
    final gstStatus     = inv['gstStatus'] as String? ?? 'SET';
    final isPending     = gstStatus == 'PENDING';
    final prevSgst      = inv['gstPrevSgstRate'] as num?;
    final recalcBy      = inv['gstRecalculatedBy'] as String?;

    final payments = ref.watch(_invoicePaymentsProvider(invoiceId));

    return AppDialog(
      title: inv['invoiceNo'] as String? ?? 'Invoice',
      maxWidth: 600,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
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
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      if (inv['poNo'] != null)
                        Text('PO: ${inv['poNo']}',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(_payStatusLabel(status),
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
          // GST Pending banner + Recalculate
          if (isPending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GST: Pending',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.orange.shade900)),
                        Text('GST rate was not configured when this invoice was raised. '
                            'Set the rate in the master, then tap Recalculate.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange.shade800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                        foregroundColor: Colors.orange.shade900),
                    onPressed: () async {
                      final api = ref.read(apiClientProvider);
                      try {
                        final res = await api.post('/api/invoices/$invoiceId/recalculate-gst');
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        widget.onRefresh();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('GST recalculated — '
                              'SGST ${res.data['sgstRate']}% / '
                              'CGST ${res.data['cgstRate']}% applied.'),
                          backgroundColor: Colors.green,
                        ));
                      } catch (err) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $err'),
                            backgroundColor: Colors.red));
                      }
                    },
                    child: const Text('Recalculate GST'),
                  ),
                ],
              ),
            ),
          ],
          // Audit log after recalculation
          if (!isPending && prevSgst != null && recalcBy != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'GST recalculated by $recalcBy — '
                      'prev ${prevSgst}% SGST → ${sgstRate}% SGST (locked)',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Tabs
          TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Line Items'), Tab(text: 'Payments')],
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
                              _TH('Qty'),
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
                      if (!isPending) ...[
                        _TotalRow('CGST ($cgstRate%)', cgstAmt),
                        _TotalRow('SGST ($sgstRate%)', sgstAmt),
                      ] else
                        _TotalRow('GST (Pending)', 0, dim: true),
                      const Divider(),
                      _TotalRow('Grand Total', grandTotal, bold: true),
                      if ((inv['createdByName'] as String?) != null ||
                          (inv['createdAt'] as String?) != null) ...[
                        const Divider(height: 20),
                        const Text('RECORD INFO',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        _InvoAuditRow('Entered by',
                            _invAuditLabel(inv['createdByName'] as String?, inv['createdAt'] as String?)),
                        if ((inv['updatedByName'] as String?) != null)
                          _InvoAuditRow('Last edited by', inv['updatedByName'] as String),
                      ],
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
                          message: 'No payments recorded',
                          hint: 'Use "Record Payment" from the invoice menu',
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

// ── Job-Work invoice detail dialog (for historical JW invoices) ───────────────

class _JwDetailDialog extends ConsumerWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onRefresh;
  const _JwDetailDialog({required this.invoice, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv        = invoice;
    final invoiceId  = inv['id'] as int;
    final items      = List<Map<String, dynamic>>.from(inv['items'] as List? ?? []);
    final cgstRate   = inv['cgstRate'] as num? ?? 0;
    final sgstRate   = inv['sgstRate'] as num? ?? 0;
    final subtotal   = inv['subtotal'] as num? ?? 0;
    final cgstAmt    = inv['cgstAmount'] as num? ?? 0;
    final sgstAmt    = inv['sgstAmount'] as num? ?? 0;
    final grandTotal = inv['grandTotal'] as num? ?? 0;
    final gstStatus  = inv['gstStatus'] as String? ?? 'SET';
    final isPending  = gstStatus == 'PENDING';
    final prevSgst   = inv['gstPrevSgstRate'] as num?;
    final recalcBy   = inv['gstRecalculatedBy'] as String?;

    return AppDialog(
      title: inv['invoiceNo'] as String? ?? 'Invoice',
      maxWidth: 560,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv['vendorName'] as String? ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (inv['siteName'] != null)
                Text('Site: ${inv['siteName']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text('Date: ${_dateFmt.format(DateTime.parse(inv['invoiceDate'] as String))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Text(fmtCurr(grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),

        if (isPending) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GST: Pending',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                        color: Colors.orange.shade900)),
                Text('Set the rate in Service Master, then tap Recalculate.',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
              ])),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade100,
                    foregroundColor: Colors.orange.shade900),
                onPressed: () async {
                  final api = ref.read(apiClientProvider);
                  try {
                    final res = await api.post('/api/job-work-invoices/$invoiceId/recalculate-gst');
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    onRefresh();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('GST recalculated — SGST ${res.data['sgstRate']}% / CGST ${res.data['cgstRate']}% applied.'),
                      backgroundColor: Colors.green,
                    ));
                  } catch (err) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $err'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Recalculate GST'),
              ),
            ]),
          ),
        ],

        if (!isPending && prevSgst != null && recalcBy != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50, borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'GST recalculated by $recalcBy — prev ${prevSgst}% SGST → ${sgstRate}% SGST (locked)',
                style: TextStyle(fontSize: 11, color: Colors.green.shade800),
              )),
            ]),
          ),
        ],

        const SizedBox(height: 12),

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
              children: const [_TH('Description'), _TH('Qty'), _TH('Rate'), _TH('Amount')],
            ),
            ...items.map((item) => TableRow(children: [
              _TD(item['description'] as String? ?? '—'),
              _TD(item['quantity'] != null ? (item['quantity'] as num).toStringAsFixed(2) : '—'),
              _TD(item['rate'] != null ? fmtCurr(item['rate']) : '—'),
              _TD(fmtCurr(item['amount'] as num? ?? 0)),
            ])),
          ],
        ),
        const Divider(height: 20),
        _TotalRow('Subtotal', subtotal),
        if (!isPending) ...[
          _TotalRow('CGST ($cgstRate%)', cgstAmt),
          _TotalRow('SGST ($sgstRate%)', sgstAmt),
        ] else
          _TotalRow('GST (Pending)', 0, dim: true),
        const Divider(),
        _TotalRow('Grand Total', grandTotal, bold: true),
        if ((inv['createdByName'] as String?) != null ||
            (inv['createdAt'] as String?) != null) ...[
          const Divider(height: 20),
          const Text('RECORD INFO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          _InvoAuditRow('Entered by',
              _invAuditLabel(inv['createdByName'] as String?, inv['createdAt'] as String?)),
          if ((inv['updatedByName'] as String?) != null)
            _InvoAuditRow('Last edited by', inv['updatedByName'] as String),
        ],
      ]),
    );
  }
}

// ── Payment tile ──────────────────────────────────────────────────────────────

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
    final mode   = payment['paymentMode'] as String? ?? 'CASH';
    final color  = _modeColors[mode] ?? Colors.grey;
    final amount = payment['amount'] as num? ?? 0;
    final date   = DateTime.parse(payment['paymentDate'] as String);
    final ref2   = (payment['referenceNo'] as String?)?.trim() ?? '';
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
          [_dateFmt.format(date), if (ref2.isNotEmpty) ref2].join('  ·  '),
          style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
    );
  }
}

// ── Quick payment dialog ──────────────────────────────────────────────────────

class _QuickPaymentDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onSaved;
  const _QuickPaymentDialog({required this.invoice, required this.onSaved});

  @override
  ConsumerState<_QuickPaymentDialog> createState() =>
      _QuickPaymentDialogState();
}

class _QuickPaymentDialogState extends ConsumerState<_QuickPaymentDialog> {
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
    final outstanding = widget.invoice['outstandingAmount'] as num? ?? 0;
    if (outstanding > 0) _amtCtrl.text = outstanding.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amtCtrl.dispose(); _refCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'vendorId':    widget.invoice['vendorId'],
      'invoiceId':   widget.invoice['id'],
      'paymentDate': DateFormat('yyyy-MM-dd').format(_date),
      'amount':      double.parse(_amtCtrl.text.trim()),
      'paymentMode': _mode,
      'referenceNo': _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      'notes':       _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv['invoiceNo'] as String? ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(inv['vendorName'] as String? ?? '—',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Total: ${fmtCurr(grandTotal)}',
                        style: const TextStyle(fontSize: 12)),
                    if (totalPaid > 0)
                      Text('Paid: ${fmtCurr(totalPaid)}',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                    Text('Due: ${fmtCurr(outstanding)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800)),
                  ]),
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
                    context: context, initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)));
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amtCtrl,
              decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              decoration: const InputDecoration(labelText: 'Reference No. / Cheque No.'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// UNIFIED INVOICE FORM — handles Material + Service lines, optional Client Site
// ══════════════════════════════════════════════════════════════════════════════

class _UnifiedItemRow {
  bool isService = false;

  // Material
  int?    materialId;
  String? materialName;
  bool    materialGstConfigured = true;

  // Service
  int?    serviceId;
  String? serviceName;
  bool    serviceGstConfigured = true;

  // Common
  final descCtrl = TextEditingController();
  final codeCtrl = TextEditingController(); // HSN for material, SAC for service
  final qtyCtrl  = TextEditingController();
  final rateCtrl = TextEditingController();
  final amtCtrl  = TextEditingController();

  _UnifiedItemRow({Map<String, dynamic>? data}) {
    if (data != null) {
      isService = (data['serviceId'] != null);
      descCtrl.text = data['description'] as String? ?? '';
      codeCtrl.text = data['hsn'] as String? ?? '';
      final qty  = data['quantityBrass'];
      if (qty  != null) qtyCtrl.text  = qty.toString();
      final rate = data['rate'];
      if (rate != null) rateCtrl.text = rate.toString();
      amtCtrl.text  = (data['amount'] as num? ?? 0).toString();
      materialId    = data['materialId'] as int?;
      serviceId     = data['serviceId']  as int?;
    }
  }

  bool get gstPending =>
      isService ? (serviceId != null && !serviceGstConfigured)
                : (materialId != null && !materialGstConfigured);

  void dispose() {
    descCtrl.dispose(); codeCtrl.dispose(); qtyCtrl.dispose();
    rateCtrl.dispose(); amtCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        if (!isService && materialId != null) 'materialId': materialId,
        if (isService  && serviceId  != null) 'serviceId':  serviceId,
        'description':  descCtrl.text.trim(),
        'hsn': codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
        'quantityBrass': double.tryParse(qtyCtrl.text),
        'rate':          double.tryParse(rateCtrl.text),
        'amount':        double.tryParse(amtCtrl.text) ?? 0.0,
      };
}

class _UnifiedInvoiceForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _UnifiedInvoiceForm({required this.existing, required this.onSaved});

  @override
  ConsumerState<_UnifiedInvoiceForm> createState() => _UnifiedInvoiceFormState();
}

class _UnifiedInvoiceFormState extends ConsumerState<_UnifiedInvoiceForm> {
  final _formKey    = GlobalKey<FormState>();
  int?    _vendorId;
  int?    _siteId;
  String? _sitePartyName;
  late DateTime _invoiceDate;
  DateTime? _supplyDate;
  final _poCtrl    = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_UnifiedItemRow> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _invoiceDate = e != null
        ? DateTime.parse(e['invoiceDate'] as String)
        : DateTime.now();
    if (e != null) {
      _vendorId = e['vendorId'] as int?;
      if (e['supplyDate'] != null) {
        _supplyDate = DateTime.parse(e['supplyDate'] as String);
      }
      _poCtrl.text    = e['poNo'] as String? ?? '';
      _notesCtrl.text = e['notes'] as String? ?? '';
      for (final item in (e['items'] as List? ?? [])) {
        _items.add(_UnifiedItemRow(data: item as Map<String, dynamic>));
      }
    }
    if (_items.isEmpty) _items.add(_UnifiedItemRow());
    for (final row in _items) _attachListeners(row);
  }

  void _attachListeners(_UnifiedItemRow row) {
    row.qtyCtrl.addListener(() => _autoCalc(row));
    row.rateCtrl.addListener(() => _autoCalc(row));
  }

  void _autoCalc(_UnifiedItemRow row) {
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
    final row = _UnifiedItemRow();
    _attachListeners(row);
    setState(() => _items.add(row));
  }

  void _removeItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  void _onSiteSelected(Map<String, dynamic>? site) {
    if (site == null) {
      setState(() { _siteId = null; _sitePartyName = null; _vendorId = null; });
      return;
    }
    final partyId   = site['linkedPartyId'] as int?;
    final partyName = site['linkedPartyName'] as String? ?? 'Party #$partyId';
    setState(() {
      _siteId       = site['id'] as int?;
      _sitePartyName = partyName;
      _vendorId     = partyId;
    });
  }

  double get _subtotal =>
      _items.fold(0, (s, r) => s + (double.tryParse(r.amtCtrl.text) ?? 0));

  Future<void> _pickDate(bool isInvoice) async {
    final init   = isInvoice ? _invoiceDate : (_supplyDate ?? _invoiceDate);
    final picked = await showDatePicker(
      context: context, initialDate: init,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => isInvoice ? _invoiceDate = picked : _supplyDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a party'),
              backgroundColor: Colors.red));
      return;
    }
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    final body = {
      'vendorId':    _vendorId,
      'invoiceDate': DateFormat('yyyy-MM-dd').format(_invoiceDate),
      'supplyDate':  _supplyDate != null
          ? DateFormat('yyyy-MM-dd').format(_supplyDate!)
          : null,
      'poNo':  _poCtrl.text.trim().isEmpty  ? null : _poCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'items': _items.map((r) => r.toJson()).toList(),
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
    final vendors    = ref.watch(_vendorsProvider);
    final sites      = ref.watch(_invoiceSitesProvider);
    final sub   = _subtotal;
    final cgst  = sub * 0.09;
    final sgst  = sub * 0.09;
    final grand = sub + cgst + sgst;
    final isEdit = widget.existing != null;
    final hasSite = _siteId != null;

    return AppDialog(
      title: isEdit ? 'Edit Invoice' : 'New Invoice',
      maxWidth: 580,
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
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

            // Optional Client Site picker → auto-locks party
            sites.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (allSites) {
                final clientSites = allSites
                    .where((s) => s['siteType'] == 'CLIENT_SITE')
                    .toList();
                if (clientSites.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SearchablePicker(
                    items: clientSites,
                    itemLabel: (s) => s['name'] as String,
                    fieldLabel: 'Client Site (optional)',
                    value: _siteId,
                    onChanged: (id) {
                      if (id == null) { _onSiteSelected(null); return; }
                      final site = clientSites.firstWhere(
                          (s) => s['id'] == id, orElse: () => <String, dynamic>{});
                      if (site.isNotEmpty) _onSiteSelected(site);
                    },
                  ),
                  const SizedBox(height: 10),
                ]);
              },
            ),

            // Party — auto-locked when site selected, free picker otherwise
            if (hasSite && _sitePartyName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.person_outlined, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Party (auto-filled from site)',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade600)),
                    Text(_sitePartyName!,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800)),
                  ])),
                  Icon(Icons.lock_outline, size: 14, color: Colors.blue.shade400),
                ]),
              )
            else
              vendors.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) {
                  final active = list.where((v) => v['status'] == 'ACTIVE').toList();
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
            ..._items.asMap().entries.map((e) => _UnifiedItemRowWidget(
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
              _PreviewRow('Grand Total (approx.)', grand, bold: true),
              const SizedBox(height: 4),
              Text('Final GST computed from master rates on save',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],

            const SectionLabel('Notes'),
            TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

// ── Unified item row widget ───────────────────────────────────────────────────

class _UnifiedItemRowWidget extends ConsumerStatefulWidget {
  final _UnifiedItemRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _UnifiedItemRowWidget({
    required this.row, required this.index, required this.canRemove,
    required this.onRemove, required this.onChanged,
  });

  @override
  ConsumerState<_UnifiedItemRowWidget> createState() =>
      _UnifiedItemRowWidgetState();
}

class _UnifiedItemRowWidgetState extends ConsumerState<_UnifiedItemRowWidget> {
  Future<void> _pickMaterial(List<Map<String, dynamic>> materials) async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MaterialPickerDialog(materials: materials),
    );
    if (picked == null) return;
    setState(() {
      widget.row.isService             = false;
      widget.row.materialId            = picked['id'] as int?;
      widget.row.materialName          = picked['name'] as String?;
      widget.row.materialGstConfigured = picked['gstRateConfigured'] as bool? ?? true;
      widget.row.serviceId             = null;
      widget.row.serviceName           = null;
      final hsn = picked['hsnCode'] as String?;
      if (hsn != null && hsn.isNotEmpty) widget.row.codeCtrl.text = hsn;
      if (widget.row.descCtrl.text.trim().isEmpty) {
        widget.row.descCtrl.text = 'Trip — ${picked['name']}';
      }
    });
    widget.onChanged();
  }

  Future<void> _pickService(List<Map<String, dynamic>> services) async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ServicePickerDialog(services: services),
    );
    if (picked == null) return;
    setState(() {
      widget.row.isService             = true;
      widget.row.serviceId             = picked['id'] as int?;
      widget.row.serviceName           = picked['name'] as String?;
      widget.row.serviceGstConfigured  = picked['gstRateConfigured'] as bool? ?? false;
      widget.row.materialId            = null;
      widget.row.materialName          = null;
      final sac = picked['sacCode'] as String?;
      if (sac != null && sac.isNotEmpty) widget.row.codeCtrl.text = sac;
      if (widget.row.descCtrl.text.trim().isEmpty) {
        widget.row.descCtrl.text = picked['name'] as String? ?? '';
      }
      final defaultRate = picked['defaultRate'];
      if (defaultRate != null && widget.row.rateCtrl.text.trim().isEmpty) {
        widget.row.rateCtrl.text = defaultRate.toString();
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(_invoiceMaterialsProvider);
    final servicesAsync  = ref.watch(_invoiceServicesProvider);
    final row            = widget.row;
    final gstPending     = row.gstPending;
    final hasPicked      = row.materialId != null || row.serviceId != null;
    final pickedLabel    = row.isService ? row.serviceName : row.materialName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: gstPending ? Colors.amber.shade50 : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: gstPending ? Colors.amber.shade300 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: item label + pickers + remove
          Row(children: [
            Text('Item ${widget.index + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Material picker button
            materialsAsync.when(
              loading: () => const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox.shrink(),
              data: (mats) {
                final active = !row.isService && hasPicked;
                return InkWell(
                  onTap: () => _pickMaterial(mats),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? (gstPending ? Colors.amber.shade100 : Colors.blue.shade50)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: active
                          ? (gstPending ? Colors.amber.shade400 : Colors.blue.shade300)
                          : Colors.grey.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.category_outlined, size: 14,
                          color: active
                              ? (gstPending ? Colors.orange.shade700 : Colors.blue.shade700)
                              : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(!row.isService && hasPicked
                          ? (pickedLabel ?? 'Material #${row.materialId}')
                          : 'Select Material',
                          style: TextStyle(fontSize: 11,
                              color: active
                                  ? (gstPending ? Colors.orange.shade800 : Colors.blue.shade700)
                                  : Colors.grey.shade600)),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            // Service picker button
            servicesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (svcs) {
                final active = row.isService && hasPicked;
                return InkWell(
                  onTap: () => _pickService(svcs),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? (gstPending ? Colors.amber.shade100 : Colors.teal.shade50)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: active
                          ? (gstPending ? Colors.amber.shade400 : Colors.teal.shade300)
                          : Colors.grey.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.handyman_outlined, size: 14,
                          color: active
                              ? (gstPending ? Colors.orange.shade700 : Colors.teal.shade700)
                              : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(row.isService && hasPicked
                          ? (pickedLabel ?? 'Service #${row.serviceId}')
                          : 'Select Service',
                          style: TextStyle(fontSize: 11,
                              color: active
                                  ? (gstPending ? Colors.orange.shade800 : Colors.teal.shade700)
                                  : Colors.grey.shade600)),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            if (widget.canRemove)
              GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(Icons.close, size: 18, color: Colors.red)),
          ]),

          // GST-pending warning
          if (gstPending) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Flexible(child: Text(
                'GST rate not set for ${pickedLabel ?? 'this item'} — invoice will be PENDING',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
              )),
            ]),
          ],

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
              controller: row.codeCtrl,
              decoration: InputDecoration(
                  labelText: row.isService ? 'SAC Code' : 'HSN Code',
                  isDense: true),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: row.qtyCtrl,
              decoration: InputDecoration(
                  labelText: row.isService ? 'Quantity' : 'Qty (Brass)',
                  isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(
              controller: row.rateCtrl,
              decoration: const InputDecoration(
                  labelText: 'Rate', isDense: true, prefixText: '₹'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: row.amtCtrl,
              decoration: const InputDecoration(
                  labelText: 'Amount *', isDense: true, prefixText: '₹'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  (v == null || double.tryParse(v) == null) ? 'Required' : null,
            )),
          ]),
        ],
      ),
    );
  }
}

// ── Material picker dialog ────────────────────────────────────────────────────

class _MaterialPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  const _MaterialPickerDialog({required this.materials});

  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.materials.where((m) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      final code = (m['code'] as String? ?? '').toLowerCase();
      return _q.isEmpty || name.contains(_q) || code.contains(_q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Expanded(child: Text('Select Material',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search, autofocus: true,
              decoration: InputDecoration(
                isDense: true, hintText: 'Search by name or code…',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) {
                final m           = filtered[i];
                final gstRate     = m['gstRate'] as num? ?? 0;
                final configured  = m['gstRateConfigured'] as bool? ?? false;
                final isPending   = gstRate == 0 && !configured;
                return ListTile(
                  dense: true,
                  title: Text(m['name'] as String? ?? '—'),
                  subtitle: Text(
                    isPending
                        ? 'GST: not configured — invoice will be PENDING'
                        : gstRate > 0
                            ? 'GST ${gstRate}%  ·  HSN ${m['hsnCode'] ?? '—'}'
                            : 'GST 0% (zero-rated)  ·  HSN ${m['hsnCode'] ?? '—'}',
                    style: TextStyle(fontSize: 11,
                        color: isPending ? Colors.orange.shade700 : Colors.grey.shade600),
                  ),
                  trailing: isPending
                      ? Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade600)
                      : null,
                  onTap: () => Navigator.pop(context, m),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Service picker dialog ─────────────────────────────────────────────────────

class _ServicePickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  const _ServicePickerDialog({required this.services});

  @override
  State<_ServicePickerDialog> createState() => _ServicePickerDialogState();
}

class _ServicePickerDialogState extends State<_ServicePickerDialog> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.services.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      final code = (s['code'] as String? ?? '').toLowerCase();
      return _q.isEmpty || name.contains(_q) || code.contains(_q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Expanded(child: Text('Select Service',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search, autofocus: true,
              decoration: InputDecoration(
                isDense: true, hintText: 'Search…',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) {
                final s          = filtered[i];
                final configured = s['gstRateConfigured'] as bool? ?? false;
                final gstRate    = s['gstRate'] as num? ?? 0;
                final isPending  = !configured;
                final unit       = s['defaultUnit'] as String? ?? 'TON';
                final rate       = s['defaultRate'];
                return ListTile(
                  dense: true,
                  title: Text(s['name'] as String? ?? '—'),
                  subtitle: Text(
                    [
                      if (rate != null) '₹$rate/$unit',
                      isPending
                          ? 'GST: not configured — invoice will be PENDING'
                          : gstRate > 0 ? 'GST $gstRate%' : 'GST 0%',
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 11,
                        color: isPending ? Colors.orange.shade700 : Colors.grey.shade600),
                  ),
                  trailing: isPending
                      ? Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade600)
                      : null,
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// JW FORM — kept for editing historical Job-Work invoices only
// ══════════════════════════════════════════════════════════════════════════════

class _ServiceRow {
  final descCtrl = TextEditingController();
  final sacCtrl  = TextEditingController();
  final qtyCtrl  = TextEditingController();
  final rateCtrl = TextEditingController();
  final amtCtrl  = TextEditingController();
  int?    serviceId;
  String? serviceName;
  bool    serviceGstConfigured = true;
  String  autoCalcSource       = 'NONE';
  double?                     autoCalcQty;
  String?                     autoCalcUnit;
  int?                        autoCalcCount;
  List<Map<String, dynamic>>? autoCalcRecords;
  bool                        qtyOverridden = false;
  // Billed-record info from auto-qty response
  int                         billedCount = 0;
  double                      billedQty   = 0.0;
  String?                     billedByInvoiceNo;
  // Period-overlap warning from auto-qty response (per row)
  Map<String, dynamic>?       overlapWarning;

  _ServiceRow({Map<String, dynamic>? data}) {
    if (data != null) {
      descCtrl.text = data['description'] as String? ?? '';
      sacCtrl.text  = data['sacCode']     as String? ?? '';
      final qty  = data['quantity'];
      if (qty  != null) qtyCtrl.text  = qty.toString();
      final rate = data['rate'];
      if (rate != null) rateCtrl.text = rate.toString();
      amtCtrl.text = (data['amount'] as num? ?? 0).toString();
      serviceId    = data['serviceId'] as int?;
    }
  }

  void dispose() {
    descCtrl.dispose(); sacCtrl.dispose(); qtyCtrl.dispose();
    rateCtrl.dispose(); amtCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
    'serviceId':   serviceId,
    'description': descCtrl.text.trim(),
    'sacCode':     sacCtrl.text.trim().isEmpty ? null : sacCtrl.text.trim(),
    'quantity':    double.tryParse(qtyCtrl.text),
    'rate':        double.tryParse(rateCtrl.text),
    'amount':      double.tryParse(amtCtrl.text) ?? 0.0,
  };
}

class _JwForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> services;
  final VoidCallback onSaved;
  final int? initialSiteId; // from sidebar selection — auto-filled for new invoices
  const _JwForm({
    required this.existing,
    required this.services,
    required this.onSaved,
    this.initialSiteId,
  });

  @override
  ConsumerState<_JwForm> createState() => _JwFormState();
}

class _JwFormState extends ConsumerState<_JwForm> {
  final _formKey   = GlobalKey<FormState>();
  int?    _siteId;
  String? _partyName;
  late DateTime _date;
  DateTime? _periodFrom;
  DateTime? _periodTo;
  final _notesCtrl = TextEditingController();
  final List<_ServiceRow> _items = [];
  bool _saving = false;
  bool _siteAutoFilled = false;

  static final _isoFmt = DateFormat('yyyy-MM-dd');
  static final _dispFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null ? DateTime.parse(e['invoiceDate'] as String) : DateTime.now();
    if (e != null) {
      _siteId    = e['siteId'] as int?;
      _partyName = e['vendorName'] as String?;
      _notesCtrl.text = e['notes'] as String? ?? '';
      if (e['periodFrom'] != null) _periodFrom = DateTime.parse(e['periodFrom'] as String);
      if (e['periodTo']   != null) _periodTo   = DateTime.parse(e['periodTo']   as String);
      for (final item in (e['items'] as List? ?? [])) {
        _items.add(_ServiceRow(data: item as Map<String, dynamic>));
      }
    }
    if (_items.isEmpty) _items.add(_ServiceRow());
    for (final row in _items) {
      row.qtyCtrl.addListener(() => _autoCalc(row));
      row.rateCtrl.addListener(() => _autoCalc(row));
    }
    // Schedule site auto-fill after first frame (retries until sites load)
    if (widget.existing == null && widget.initialSiteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoFillSite());
    }
  }

  void _tryAutoFillSite() {
    if (!mounted || _siteAutoFilled) return;
    final allSites    = ref.read(_invoiceSitesProvider).valueOrNull ?? const [];
    final clientSites = allSites.where((s) => s['siteType'] == 'CLIENT_SITE').toList();
    if (clientSites.isEmpty) {
      // Sites not loaded yet — retry next frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoFillSite());
      return;
    }
    _siteAutoFilled = true;
    final match = clientSites.firstWhere(
        (s) => s['id'] == widget.initialSiteId,
        orElse: () => <String, dynamic>{});
    if (match.isNotEmpty && mounted) {
      setState(() {
        _siteId    = match['id'] as int?;
        _partyName = match['linkedPartyName'] as String?;
      });
    }
  }

  void _autoCalc(_ServiceRow row) {
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
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAutoQtyForRow(int rowIndex) async {
    final row = _items[rowIndex];
    if (row.autoCalcSource == 'NONE' || row.serviceId == null) return;
    if (_siteId == null || _periodFrom == null || _periodTo == null) return;
    try {
      final params = <String, String>{
        'siteId':    '$_siteId',
        'serviceId': '${row.serviceId}',
        'from':      _isoFmt.format(_periodFrom!),
        'to':        _isoFmt.format(_periodTo!),
      };
      if (widget.existing != null) {
        params['excludeInvoiceId'] = '${widget.existing!['id']}';
      }
      final res = await ref.read(apiClientProvider).get(
        '/api/job-work-invoices/auto-qty',
        params: params,
      );
      if (!mounted) return;
      // Guard: row may have been removed while the request was in flight
      if (!_items.contains(row)) return;
      final data = res.data as Map<String, dynamic>;
      setState(() {
        row.autoCalcQty     = (data['quantity'] as num?)?.toDouble();
        row.autoCalcUnit    = data['unit'] as String?;
        row.autoCalcCount   = (data['count']    as num?)?.toInt() ?? 0;
        row.autoCalcRecords = List<Map<String, dynamic>>.from(
            (data['records'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        row.qtyOverridden      = false;
        row.billedCount        = (data['billedCount']   as num?)?.toInt() ?? 0;
        row.billedQty          = (data['billedQuantity'] as num?)?.toDouble() ?? 0.0;
        row.billedByInvoiceNo  = data['billedByInvoiceNo'] as String?;
        final ov = data['overlappingInvoice'] as Map<String, dynamic>?;
        row.overlapWarning = ov != null ? Map<String, dynamic>.from(ov) : null;
        if (row.autoCalcQty != null) {
          row.qtyCtrl.text = row.autoCalcQty!.toStringAsFixed(3);
        }
      });
    } catch (_) {}
  }

  void _refreshAutoQtyAll() {
    for (int i = 0; i < _items.length; i++) {
      _fetchAutoQtyForRow(i);
    }
  }

  Future<void> _pickPeriodDate(BuildContext context, bool isFrom) async {
    final initial = isFrom
        ? (_periodFrom ?? DateTime.now())
        : (_periodTo   ?? _periodFrom ?? DateTime.now());
    final d = await showDatePicker(
        context: context, initialDate: initial,
        firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (d == null) return;
    if (isFrom) {
      _periodFrom = d;
      if (_periodTo != null && _periodTo!.isBefore(d)) _periodTo = d;
    } else {
      _periodTo = d;
      if (_periodFrom != null && _periodFrom!.isAfter(d)) _periodFrom = d;
    }
    setState(() {});
    _refreshAutoQtyAll();
  }

  double get _subtotal =>
      _items.fold(0, (s, r) => s + (double.tryParse(r.amtCtrl.text) ?? 0));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a client site'),
              backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    final body = {
      'siteId':      _siteId,
      'invoiceDate': _isoFmt.format(_date),
      if (_periodFrom != null) 'periodFrom': _isoFmt.format(_periodFrom!),
      if (_periodTo   != null) 'periodTo':   _isoFmt.format(_periodTo!),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'items': _items.map((r) => r.toJson()).toList(),
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/job-work-invoices', data: body);
      } else {
        await api.put('/api/job-work-invoices/${widget.existing!['id']}', data: body);
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
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
    final allSites    = ref.watch(_invoiceSitesProvider).valueOrNull ?? const [];
    final clientSites = allSites.where((s) => s['siteType'] == 'CLIENT_SITE').toList();
    // Watch services internally so they're always available even if provider
    // wasn't cached when the form was opened.
    final services    = ref.watch(_invoiceServicesProvider).valueOrNull
                        ?? widget.services;
    final sub         = _subtotal;

    return AppDialog(
      title: widget.existing != null ? 'Edit Job-Work Invoice' : 'New Job-Work Invoice',
      maxWidth: 560,
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existing != null ? 'Update' : 'Save Invoice'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const SectionLabel('Invoice Details'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SearchablePicker(
              items: clientSites, itemLabel: (s) => s['name'] as String,
              fieldLabel: 'Client Site *', value: _siteId,
              onChanged: (id) {
                if (id == null) { setState(() { _siteId = null; _partyName = null; }); return; }
                final site = clientSites.firstWhere((s) => s['id'] == id,
                    orElse: () => <String, dynamic>{});
                if (site.isNotEmpty) {
                  final partyId = site['linkedPartyId'] as int?;
                  setState(() {
                    _siteId    = site['id'] as int?;
                    _partyName = site['linkedPartyName'] as String? ?? 'Party #$partyId';
                  });
                  // Re-fetch auto-qty for all rows now that we have a site
                  _refreshAutoQtyAll();
                }
              },
              validator: (v) => v == null ? 'Select a client site' : null,
            ),
            if (_partyName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                      Icon(Icons.person_outlined, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Party (auto-filled)', style: TextStyle(fontSize: 10, color: Colors.blue.shade600)),
                        Text(_partyName!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800)),
                      ])),
                      Icon(Icons.lock_outline, size: 14, color: Colors.blue.shade400),
                    ]),
                  ),
                ],
            // Hint: tell user site is required for auto-qty
            if (_siteId == null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text('Select a site to enable auto-quantity calculation',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ]),
            ],
          ]),
          const SizedBox(height: 12),
          DateField(
            label: 'Invoice Date', date: _date, required: true,
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (d != null) setState(() => _date = d);
            },
          ),

          // Billing period — used for auto-quantity calculation
          const SizedBox(height: 12),
          const SectionLabel('Billing Period (optional)'),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickPeriodDate(context, true),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Period From',
                    isDense: true,
                    suffixIcon: const Icon(Icons.calendar_today, size: 16),
                    helperText: _periodFrom == null ? 'Required for auto-qty' : null,
                  ),
                  child: Text(
                    _periodFrom != null ? _dispFmt.format(_periodFrom!) : '—',
                    style: TextStyle(color: _periodFrom != null ? null : Colors.grey[500]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pickPeriodDate(context, false),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Period To',
                    isDense: true,
                    suffixIcon: const Icon(Icons.calendar_today, size: 16),
                    helperText: _periodTo == null ? 'Required for auto-qty' : null,
                  ),
                  child: Text(
                    _periodTo != null ? _dispFmt.format(_periodTo!) : '—',
                    style: TextStyle(color: _periodTo != null ? null : Colors.grey[500]),
                  ),
                ),
              ),
            ),
          ]),
          if (_siteId != null && (_periodFrom == null || _periodTo == null))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text('Set both dates to enable auto-quantity calculation on line items',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
              ]),
            ),

          // Period overlap warning — shown when any line's auto-qty detects an existing invoice covering this period
          Builder(builder: (ctx) {
            final warnings = _items
                .where((r) => r.overlapWarning != null)
                .map((r) => r.overlapWarning!)
                .toList();
            if (warnings.isEmpty) return const SizedBox.shrink();
            final w = warnings.first;
            final invoiceNo = w['invoiceNo'] as String? ?? '';
            final pFrom = w['periodFrom'] as String? ?? '';
            final pTo   = w['periodTo']   as String? ?? '';
            final label = pFrom == pTo ? pFrom : '$pFrom – $pTo';
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Note: Invoice $invoiceNo already covers $label for this site.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  )),
                ]),
              ),
            );
          }),

          const SectionLabel('Line Items'),
          ..._items.asMap().entries.map((e) => _JwServiceRowWidget(
            key: ObjectKey(e.value),
            row: e.value, index: e.key,
            services: services,
            siteId: _siteId,
            periodFrom: _periodFrom,
            periodTo: _periodTo,
            canRemove: _items.length > 1,
            onRemove: () { _items[e.key].dispose(); setState(() => _items.removeAt(e.key)); },
            onChanged: () => setState(() {}),
            onFetchAutoQty: _fetchAutoQtyForRow,
          )),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              final row = _ServiceRow();
              row.qtyCtrl.addListener(() => _autoCalc(row));
              row.rateCtrl.addListener(() => _autoCalc(row));
              setState(() => _items.add(row));
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Line Item'),
          ),
          if (sub > 0) ...[
            const Divider(height: 20),
            _PreviewRow('Subtotal', sub),
            _PreviewRow('GST', 0, note: 'computed on save based on Service GST rate'),
            const Divider(height: 8),
            _PreviewRow('Grand Total (approx.)', sub, bold: true),
          ],
          const SectionLabel('Notes'),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
        ]),
      ),
    );
  }
}

class _JwServiceRowWidget extends StatefulWidget {
  final _ServiceRow row;
  final int index;
  final List<Map<String, dynamic>> services;
  final int? siteId;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final bool canRemove;
  final VoidCallback onRemove, onChanged;
  final Future<void> Function(int rowIndex) onFetchAutoQty;
  const _JwServiceRowWidget({
    super.key,
    required this.row, required this.index,
    required this.services,
    required this.siteId, required this.periodFrom, required this.periodTo,
    required this.canRemove, required this.onRemove, required this.onChanged,
    required this.onFetchAutoQty,
  });
  @override
  State<_JwServiceRowWidget> createState() => _JwServiceRowWidgetState();
}

class _JwServiceRowWidgetState extends State<_JwServiceRowWidget> {
  static final _numFmt = NumberFormat('#,##,##0.###', 'en_IN');

  Future<void> _pickService(List<Map<String, dynamic>> services) async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _ServicePickerDialog(services: services),
    );
    if (picked == null) return;
    setState(() {
      widget.row.serviceId            = picked['id'] as int?;
      widget.row.serviceName          = picked['name'] as String?;
      widget.row.serviceGstConfigured = picked['gstRateConfigured'] as bool? ?? false;
      widget.row.autoCalcSource       = picked['autoCalcSource']    as String? ?? 'NONE';
      widget.row.autoCalcQty          = null;
      widget.row.autoCalcCount        = null;
      widget.row.autoCalcRecords      = null;
      widget.row.qtyOverridden        = false;
      final sac = picked['sacCode'] as String?;
      if (sac != null && sac.isNotEmpty) widget.row.sacCtrl.text = sac;
      if (widget.row.descCtrl.text.trim().isEmpty) {
        widget.row.descCtrl.text = picked['name'] as String? ?? '';
      }
      final defaultRate = picked['defaultRate'];
      if (defaultRate != null && widget.row.rateCtrl.text.trim().isEmpty) {
        widget.row.rateCtrl.text = defaultRate.toString();
      }
    });
    widget.onChanged();
    if (widget.row.autoCalcSource != 'NONE') {
      await widget.onFetchAutoQty(widget.index);
    }
  }

  void _showDrillDown(BuildContext ctx) {
    final records = widget.row.autoCalcRecords;
    if (records == null || records.isEmpty) return;
    showDialog(
      context: ctx,
      builder: (_) => _AutoQtyDrillDown(
        records: records,
        source: widget.row.autoCalcSource,
        total: widget.row.autoCalcQty ?? 0,
        count: widget.row.autoCalcCount ?? 0,
      ),
    );
  }

  String _sourceLabel(String source) {
    if (source == 'TRIP_QUANTITIES')  return 'trips';
    if (source == 'DABAR_QUANTITIES') return 'dabar entries';
    return 'records';
  }

  @override
  Widget build(BuildContext context) {
    final svcs        = widget.services;
    final row         = widget.row;
    final hasService  = row.serviceId != null;
    final gstPending  = hasService && !row.serviceGstConfigured;
    final hasAutoCalc = row.autoCalcQty != null && row.autoCalcSource != 'NONE';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: gstPending ? Colors.amber.shade50 : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gstPending ? Colors.amber.shade300 : Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Item ${widget.index + 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          InkWell(
              onTap: svcs.isEmpty ? null : () => _pickService(svcs),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasService ? (gstPending ? Colors.amber.shade100 : Colors.blue.shade50) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: hasService ? (gstPending ? Colors.amber.shade400 : Colors.blue.shade300) : Colors.grey.shade300),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.handyman_outlined, size: 14,
                      color: hasService ? (gstPending ? Colors.orange.shade700 : Colors.blue.shade700) : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(hasService ? (row.serviceName ?? 'Service #${row.serviceId}') : 'Select Service',
                      style: TextStyle(fontSize: 11,
                          color: hasService ? (gstPending ? Colors.orange.shade800 : Colors.blue.shade700) : Colors.grey.shade600)),
                ]),
              ),
            ),
          const SizedBox(width: 8),
          if (widget.canRemove)
            GestureDetector(onTap: widget.onRemove, child: const Icon(Icons.close, size: 18, color: Colors.red)),
        ]),
        if (gstPending) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text('GST rate not set for ${row.serviceName} — invoice will be PENDING',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
          ]),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: row.descCtrl,
          decoration: const InputDecoration(labelText: 'Description *', isDense: true),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(
            controller: row.sacCtrl,
            decoration: const InputDecoration(labelText: 'SAC Code', isDense: true),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(
            controller: row.qtyCtrl,
            decoration: InputDecoration(
              labelText: 'Quantity',
              isDense: true,
              suffixIcon: hasAutoCalc
                  ? Tooltip(
                      message: row.qtyOverridden ? 'Manually overridden' : 'Auto-calculated',
                      child: Icon(
                        row.qtyOverridden ? Icons.edit : Icons.auto_awesome,
                        size: 16,
                        color: row.qtyOverridden ? Colors.orange.shade600 : Colors.blue.shade600,
                      ),
                    )
                  : null,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              final parsed  = double.tryParse(row.qtyCtrl.text);
              final autoQty = row.autoCalcQty;
              if (autoQty != null && parsed != null) {
                final changed = (parsed - autoQty).abs() > 0.001;
                if (changed && !row.qtyOverridden) setState(() => row.qtyOverridden = true);
                if (!changed && row.qtyOverridden) setState(() => row.qtyOverridden = false);
              }
            },
          )),
        ]),
        // "No new trips" notice — shown when auto-calc returned 0 but there are already-billed records
        if (row.autoCalcSource != 'NONE' && row.autoCalcQty == 0.0 && row.billedCount > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(children: [
              Icon(Icons.block_outlined, size: 13, color: Colors.orange.shade700),
              const SizedBox(width: 5),
              Expanded(child: Text(
                'No new ${_sourceLabel(row.autoCalcSource)} found for this period'
                '${row.billedByInvoiceNo != null ? ' — already included in ${row.billedByInvoiceNo}' : ''}.',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
              )),
            ]),
          ),
        ],
        // Auto-calc transparency note
        if (hasAutoCalc && !(row.autoCalcQty == 0.0 && row.billedCount > 0)) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showDrillDown(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: row.qtyOverridden ? Colors.orange.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: row.qtyOverridden ? Colors.orange.shade200 : Colors.blue.shade200),
              ),
              child: Row(children: [
                Icon(
                  row.qtyOverridden ? Icons.edit_outlined : Icons.info_outline,
                  size: 13,
                  color: row.qtyOverridden ? Colors.orange.shade700 : Colors.blue.shade700,
                ),
                const SizedBox(width: 5),
                Expanded(child: Text(
                  row.qtyOverridden
                      ? 'Overriding auto-calculated ${_numFmt.format(row.autoCalcQty!)} ${row.autoCalcUnit ?? ''} '
                        'from ${row.autoCalcCount} ${_sourceLabel(row.autoCalcSource)}'
                      : 'Auto-calculated from ${row.autoCalcCount} ${_sourceLabel(row.autoCalcSource)} '
                        '(${row.autoCalcUnit ?? ''}) · tap to view',
                  style: TextStyle(
                      fontSize: 11,
                      color: row.qtyOverridden ? Colors.orange.shade800 : Colors.blue.shade700),
                )),
                if (!row.qtyOverridden)
                  Icon(Icons.chevron_right, size: 14, color: Colors.blue.shade600),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(
            controller: row.rateCtrl,
            decoration: const InputDecoration(labelText: 'Rate', isDense: true, prefixText: '₹'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(
            controller: row.amtCtrl,
            decoration: const InputDecoration(labelText: 'Amount *', isDense: true, prefixText: '₹'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
          )),
        ]),
      ]),
    );
  }
}

// ── Auto-qty drill-down dialog (shared between invoices and job_work screens) ──

class _AutoQtyDrillDown extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final String source;
  final double total;
  final int count;
  const _AutoQtyDrillDown({
    required this.records, required this.source,
    required this.total, required this.count,
  });

  static final _numFmt  = NumberFormat('#,##,##0.###', 'en_IN');
  static final _dateFmt = DateFormat('d MMM yyyy');

  String get _sourceLabel => source == 'TRIP_QUANTITIES' ? 'Trips' : 'Dabar Entries';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(children: [
              Icon(Icons.list_alt_outlined, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text('Auto-Calculated from $_sourceLabel',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$count $_sourceLabel summed',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                Text('Total: ${_numFmt.format(total)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800)),
              ]),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) {
                final rec   = records[i];
                final date  = rec['date'] as String? ?? '';
                final qty   = (rec['quantity'] as num?)?.toDouble() ?? 0;
                final unit  = rec['unit'] as String? ?? '';
                final mode  = rec['vehicleMode'] as String?;
                final trips = rec['tripsCount'] as int?;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue.shade50,
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                  ),
                  title: Text(
                    date.isNotEmpty ? _dateFmt.format(DateTime.parse(date)) : '—',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: mode != null
                      ? Text(mode == 'OWN_VEHICLE' ? 'Own Vehicle' : 'Company Vehicle',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                      : (trips != null
                          ? Text('$trips trip${trips == 1 ? '' : 's'}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                          : null),
                  trailing: Text('${_numFmt.format(qty)} $unit',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Audit helpers ─────────────────────────────────────────────────────────────

String _invAuditLabel(String? name, String? ts) {
  final n = name ?? '—';
  if (ts == null) return n;
  final d = DateTime.tryParse(ts);
  return d != null ? '$n · ${DateFormat('d MMM yyyy').format(d)}' : n;
}

class _InvoAuditRow extends StatelessWidget {
  final String label;
  final String value;
  const _InvoAuditRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Shared table helpers ──────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _TD extends StatelessWidget {
  final String text;
  const _TD(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      );
}

class _TotalRow extends StatelessWidget {
  final String label;
  final num value;
  final bool bold;
  final bool dim;
  const _TotalRow(this.label, this.value, {this.bold = false, this.dim = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 15 : 13,
              color: dim ? Colors.grey[500] : null)),
          Text(dim ? '—' : fmtCurr(value), style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 15 : 13,
              color: bold ? Theme.of(context).colorScheme.primary
                  : dim ? Colors.grey[500] : null)),
        ]),
      );
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final String? note;
  const _PreviewRow(this.label, this.value, {this.bold = false, this.note});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 14 : 13)),
            if (note != null)
              Text(note!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
          Text(fmtCurr(value), style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 14 : 13,
              color: bold ? Theme.of(context).colorScheme.primary : null)),
        ]),
      );
}
