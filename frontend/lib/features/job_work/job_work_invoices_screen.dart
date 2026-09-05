import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

// ── Paginated state + notifier ────────────────────────────────────────────────

class _JwState {
  final List<Map<String, dynamic>> items;
  final bool hasMore, loadingMore;
  final int nextPage, totalElements;
  const _JwState({required this.items, required this.hasMore,
      required this.loadingMore, required this.nextPage, required this.totalElements});
  _JwState copyWith({bool? loadingMore}) => _JwState(
      items: items, hasMore: hasMore, nextPage: nextPage,
      totalElements: totalElements, loadingMore: loadingMore ?? this.loadingMore);
}

class _JwNotifier extends StateNotifier<AsyncValue<_JwState>> {
  final ApiClient _api;
  static const _pageSize = 25;
  _JwNotifier(this._api) : super(const AsyncValue.loading()) { _load(0, []); }

  Future<void> _load(int page, List<Map<String, dynamic>> existing) async {
    try {
      final res = await _api.get('/api/job-work-invoices',
          params: {'page': '$page', 'size': '$_pageSize'});
      final d = res.data as Map<String, dynamic>;
      final content = List<Map<String, dynamic>>.from(d['content'] as List);
      state = AsyncValue.data(_JwState(
        items: [...existing, ...content],
        hasMore: !(d['last'] as bool),
        loadingMore: false,
        nextPage: page + 1,
        totalElements: (d['totalElements'] as num).toInt(),
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

final _jwNotifierProvider =
    StateNotifierProvider.autoDispose<_JwNotifier, AsyncValue<_JwState>>(
  (ref) => _JwNotifier(ref.read(apiClientProvider)),
);

// Fetches all sites — filtered to CLIENT_SITE in the form
final _jwSitesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/sites');
  return List<Map<String, dynamic>>.from(res.data);
});

// Fetches all services for line-item picker
final _jwServicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/services');
  return (res.data as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((s) => s['status'] == 'ACTIVE')
      .toList();
});

final _dateFmt = DateFormat('d MMM yyyy');

// ── Screen ────────────────────────────────────────────────────────────────────

class JobWorkInvoicesScreen extends ConsumerWidget {
  const JobWorkInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(_jwNotifierProvider);
    final notifier   = ref.read(_jwNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job-Work Invoices'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: notifier.refresh),
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
              icon: Icons.build_circle_outlined,
              message: 'No job-work invoices yet',
              hint: 'Tap + to create your first job-work invoice',
            );
          }
          final pending = state.items.where((i) => i['gstStatus'] == 'PENDING').length;
          return Column(children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                if (pending > 0) ...[
                  _Pill('GST Pending', pending, Colors.orange),
                  const SizedBox(width: 12),
                ],
                const Spacer(),
                Text(
                  state.totalElements == state.items.length
                      ? '${state.items.length} invoices'
                      : '${state.items.length} of ${state.totalElements}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: state.items.length + (state.hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == state.items.length) {
                    return _LoadMore(loading: state.loadingMore, onTap: notifier.loadMore);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _JwCard(
                      invoice: state.items[i],
                      onTap: () => _showDetail(context, ref, state.items[i]),
                      onEdit: () => _showForm(context, ref, state.items[i]),
                      onDelete: () => _confirmDelete(context, ref, state.items[i]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? inv) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _JwForm(
        existing: inv,
        onSaved: () => ref.read(_jwNotifierProvider.notifier).refresh(),
      ),
    );
  }

  void _showDetail(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => _JwDetailDialog(
        invoice: inv,
        onRefresh: () => ref.read(_jwNotifierProvider.notifier).refresh(),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: Text('Cancel ${inv['invoiceNo']} for ${inv['vendorName']}?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(apiClientProvider).delete('/api/job-work-invoices/${inv['id']}');
              ref.read(_jwNotifierProvider.notifier).refresh();
            },
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }
}

// ── Invoice card ──────────────────────────────────────────────────────────────

class _JwCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap, onEdit, onDelete;
  const _JwCard({required this.invoice, required this.onTap,
      required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final grandTotal = invoice['grandTotal'] as num? ?? 0;
    final gstStatus  = invoice['gstStatus'] as String? ?? 'SET';
    final isPending  = gstStatus == 'PENDING';
    final date       = DateTime.parse(invoice['invoiceDate'] as String);

    return Card(
      color: isPending ? Colors.amber.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPending
                    ? Colors.orange.withValues(alpha: 0.12)
                    : cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.build_circle_outlined,
                  color: isPending ? Colors.orange : cs.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invoice['invoiceNo'] as String? ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(invoice['vendorName'] as String? ?? '—',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              Text('${invoice['siteName'] ?? '—'}  ·  ${_dateFmt.format(date)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtCurr(grandTotal),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                      color: cs.primary)),
              if (isPending)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Text('GST: Pending',
                      style: TextStyle(fontSize: 10, color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete',
                    child: Text('Cancel Invoice', style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Detail dialog ─────────────────────────────────────────────────────────────

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
        // Header
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
              Text('Site: ${inv['siteName'] ?? '—'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text('Date: ${_dateFmt.format(DateTime.parse(inv['invoiceDate'] as String))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Text(fmtCurr(grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),

        // GST Pending banner
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
                Text('GST rate was not configured for a service. '
                    'Set the rate in Service Master, then tap Recalculate.',
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
                      content: Text('GST recalculated — '
                          'SGST ${res.data['sgstRate']}% / CGST ${res.data['cgstRate']}% applied.'),
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

        // Audit log after recalculation
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

        // Line items table
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
      ]),
    );
  }
}

// ── Service row model ─────────────────────────────────────────────────────────

class _ServiceRow {
  final descCtrl = TextEditingController();
  final sacCtrl  = TextEditingController();
  final qtyCtrl  = TextEditingController();
  final rateCtrl = TextEditingController();
  final amtCtrl  = TextEditingController();

  int?    serviceId;
  String? serviceName;
  bool    serviceGstConfigured = true;

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

// ── Invoice form ──────────────────────────────────────────────────────────────

class _JwForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _JwForm({required this.existing, required this.onSaved});

  @override
  ConsumerState<_JwForm> createState() => _JwFormState();
}

class _JwFormState extends ConsumerState<_JwForm> {
  final _formKey     = GlobalKey<FormState>();
  int?   _siteId;
  String? _partyName;
  late DateTime _date;
  final _notesCtrl   = TextEditingController();
  final List<_ServiceRow> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null ? DateTime.parse(e['invoiceDate'] as String) : DateTime.now();
    if (e != null) {
      _siteId    = e['siteId'] as int?;
      _partyName = e['vendorName'] as String?;
      _notesCtrl.text = e['notes'] as String? ?? '';
      for (final item in (e['items'] as List? ?? [])) {
        _items.add(_ServiceRow(data: item as Map<String, dynamic>));
      }
    }
    if (_items.isEmpty) _items.add(_ServiceRow());
    for (final row in _items) {
      row.qtyCtrl.addListener(() => _autoCalc(row));
      row.rateCtrl.addListener(() => _autoCalc(row));
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

  void _addItem() {
    final row = _ServiceRow();
    row.qtyCtrl.addListener(() => _autoCalc(row));
    row.rateCtrl.addListener(() => _autoCalc(row));
    setState(() => _items.add(row));
  }

  void _removeItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  void _onSiteSelected(Map<String, dynamic> site) {
    final partyId = site['linkedPartyId'] as int?;
    setState(() {
      _siteId    = site['id'] as int?;
      _partyName = site['linkedPartyName'] as String? ?? 'Party #$partyId';
    });
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
      'invoiceDate': DateFormat('yyyy-MM-dd').format(_date),
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
    final sitesAsync    = ref.watch(_jwSitesProvider);
    final sub   = _subtotal;
    final cgst  = sub * 0.0; // shown as preview only; server computes actual GST
    final grand = sub + cgst;
    final isEdit = widget.existing != null;

    return AppDialog(
      title: isEdit ? 'Edit Job-Work Invoice' : 'New Job-Work Invoice',
      maxWidth: 560,
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
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
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const SectionLabel('Invoice Details'),

          // Site picker — CLIENT_SITE only
          sitesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (allSites) {
              final clientSites = allSites
                  .where((s) => s['siteType'] == 'CLIENT_SITE')
                  .toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SearchablePicker(
                  items: clientSites,
                  itemLabel: (s) => s['name'] as String,
                  fieldLabel: 'Client Site *',
                  value: _siteId,
                  onChanged: (id) {
                    if (id == null) {
                      setState(() { _siteId = null; _partyName = null; });
                      return;
                    }
                    final site = clientSites.firstWhere((s) => s['id'] == id,
                        orElse: () => <String, dynamic>{});
                    if (site.isNotEmpty) _onSiteSelected(site);
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
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Party (auto-filled)',
                            style: TextStyle(fontSize: 10, color: Colors.blue.shade600)),
                        Text(_partyName!,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800)),
                      ])),
                      Icon(Icons.lock_outline, size: 14, color: Colors.blue.shade400),
                    ]),
                  ),
                ],
              ]);
            },
          ),

          const SizedBox(height: 12),
          DateField(
            label: 'Invoice Date',
            date: _date,
            required: true,
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (d != null) setState(() => _date = d);
            },
          ),

          const SectionLabel('Line Items'),
          ..._items.asMap().entries.map((e) => _ServiceRowWidget(
            row: e.value, index: e.key,
            canRemove: _items.length > 1,
            onRemove: () => _removeItem(e.key),
            onChanged: () => setState(() {}),
          )),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Line Item'),
          ),

          if (sub > 0) ...[
            const Divider(height: 20),
            _PreviewRow('Subtotal', sub),
            _PreviewRow('GST', cgst, note: 'computed on save based on Service GST rate'),
            const Divider(height: 8),
            _PreviewRow('Grand Total (approx.)', grand, bold: true),
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

// ── Service row widget ────────────────────────────────────────────────────────

class _ServiceRowWidget extends ConsumerStatefulWidget {
  final _ServiceRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove, onChanged;
  const _ServiceRowWidget({
    required this.row, required this.index, required this.canRemove,
    required this.onRemove, required this.onChanged,
  });

  @override
  ConsumerState<_ServiceRowWidget> createState() => _ServiceRowWidgetState();
}

class _ServiceRowWidgetState extends ConsumerState<_ServiceRowWidget> {
  Future<void> _pickService(List<Map<String, dynamic>> services) async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ServicePickerDialog(services: services),
    );
    if (picked == null) return;
    setState(() {
      widget.row.serviceId            = picked['id'] as int?;
      widget.row.serviceName          = picked['name'] as String?;
      widget.row.serviceGstConfigured = picked['gstRateConfigured'] as bool? ?? false;
      // Auto-fill SAC code
      final sac = picked['sacCode'] as String?;
      if (sac != null && sac.isNotEmpty) widget.row.sacCtrl.text = sac;
      // Auto-fill description if blank
      if (widget.row.descCtrl.text.trim().isEmpty) {
        widget.row.descCtrl.text = picked['name'] as String? ?? '';
      }
      // Auto-fill rate from service default
      final defaultRate = picked['defaultRate'];
      if (defaultRate != null && widget.row.rateCtrl.text.trim().isEmpty) {
        widget.row.rateCtrl.text = defaultRate.toString();
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(_jwServicesProvider);
    final row           = widget.row;
    final hasService    = row.serviceId != null;
    final gstPending    = hasService && !row.serviceGstConfigured;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: gstPending ? Colors.amber.shade50 : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gstPending ? Colors.amber.shade300 : Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Text('Item ${widget.index + 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          // Service picker button
          servicesAsync.when(
            loading: () => const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const SizedBox.shrink(),
            data: (svcs) => InkWell(
              onTap: () => _pickService(svcs),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasService
                      ? (gstPending ? Colors.amber.shade100 : Colors.blue.shade50)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: hasService
                      ? (gstPending ? Colors.amber.shade400 : Colors.blue.shade300)
                      : Colors.grey.shade300),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.handyman_outlined, size: 14,
                      color: hasService
                          ? (gstPending ? Colors.orange.shade700 : Colors.blue.shade700)
                          : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(hasService ? row.serviceName! : 'Select Service',
                      style: TextStyle(fontSize: 11,
                          color: hasService
                              ? (gstPending ? Colors.orange.shade800 : Colors.blue.shade700)
                              : Colors.grey.shade600)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.canRemove)
            GestureDetector(onTap: widget.onRemove,
                child: const Icon(Icons.close, size: 18, color: Colors.red)),
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
            decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          )),
        ]),
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
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search…',
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
                final s = filtered[i];
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
                          : gstRate > 0
                              ? 'GST $gstRate%'
                              : 'GST 0%',
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

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Pill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text('$count $label',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );
}

class _LoadMore extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoadMore({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(child: loading
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
        : OutlinedButton(onPressed: onTap, child: const Text('Load more'))),
  );
}

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
