import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

// ── providers ────────────────────────────────────────────────────────────────

final _invoicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/invoices');
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

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(_invoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_invoicesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: invoices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No invoices yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            separatorBuilder: (_, idx) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _InvoiceCard(
              invoice: data[i],
              onTap: () => _showDetail(context, ref, data[i]),
              onEdit: () => _showForm(context, ref, data[i]),
              onDelete: () => _confirmDelete(context, ref, data[i]),
            ),
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
        onSaved: () => ref.invalidate(_invoicesProvider),
      ),
    );
  }

  void _showDetail(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => _InvoiceDetailDialog(invoice: inv),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: Text('Cancel invoice ${inv['invoiceNo']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(apiClientProvider).delete('/api/invoices/${inv['id']}');
              ref.invalidate(_invoicesProvider);
            },
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }
}

// ── invoice card ─────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _InvoiceCard(
      {required this.invoice,
      required this.onTap,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grandTotal = invoice['grandTotal'] as num? ?? 0;
    final invoiceDate = DateTime.parse(invoice['invoiceDate'] as String);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice['invoiceNo'] as String? ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(invoice['vendorName'] as String? ?? '—',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(_dateFmt.format(invoiceDate),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${_fmt.format(grandTotal)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: cs.primary)),
                  Text('incl. GST',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
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

// ── invoice detail dialog ────────────────────────────────────────────────────

class _InvoiceDetailDialog extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceDetailDialog({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(invoice['items'] as List? ?? []);
    final cgstRate = invoice['cgstRate'] as num? ?? 9;
    final sgstRate = invoice['sgstRate'] as num? ?? 9;
    final subtotal = invoice['subtotal'] as num? ?? 0;
    final cgstAmt = invoice['cgstAmount'] as num? ?? 0;
    final sgstAmt = invoice['sgstAmount'] as num? ?? 0;
    final grandTotal = invoice['grandTotal'] as num? ?? 0;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice['invoiceNo'] as String? ?? '—',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(invoice['vendorName'] as String? ?? '—',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(
                    _dateFmt.format(
                        DateTime.parse(invoice['invoiceDate'] as String)),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Items
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Line Items',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                              color: Colors.grey[100]),
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
                                  ? '₹${_fmt.format(item['rate'])}'
                                  : '—'),
                              _TD('₹${_fmt.format(item['amount'] as num? ?? 0)}'),
                            ])),
                      ],
                    ),
                    const Divider(height: 24),
                    // Totals
                    _TotalRow('Subtotal', subtotal),
                    _TotalRow('CGST ($cgstRate%)', cgstAmt),
                    _TotalRow('SGST ($sgstRate%)', sgstAmt),
                    const Divider(),
                    _TotalRow('Grand Total', grandTotal, bold: true),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(text, style: const TextStyle(fontSize: 12)),
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
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 15 : 13)),
            Text('₹${_fmt.format(value)}',
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 15 : 13,
                    color: bold ? Theme.of(context).colorScheme.primary : null)),
          ],
        ),
      );
}

// ── invoice form ──────────────────────────────────────────────────────────────

class _ItemRow {
  final descCtrl = TextEditingController();
  final hsnCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final amtCtrl = TextEditingController();

  _ItemRow({Map<String, dynamic>? data}) {
    if (data != null) {
      descCtrl.text = data['description'] as String? ?? '';
      hsnCtrl.text = data['hsn'] as String? ?? '';
      final qty = data['quantityBrass'];
      if (qty != null) qtyCtrl.text = qty.toString();
      final rate = data['rate'];
      if (rate != null) rateCtrl.text = rate.toString();
      amtCtrl.text = (data['amount'] as num? ?? 0).toString();
    }
  }

  void dispose() {
    descCtrl.dispose();
    hsnCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    amtCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        'description': descCtrl.text.trim(),
        'hsn': hsnCtrl.text.trim().isEmpty ? null : hsnCtrl.text.trim(),
        'quantityBrass': double.tryParse(qtyCtrl.text),
        'rate': double.tryParse(rateCtrl.text),
        'amount': double.tryParse(amtCtrl.text) ?? 0.0,
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
  final _formKey = GlobalKey<FormState>();
  int? _vendorId;
  late DateTime _invoiceDate;
  DateTime? _supplyDate;
  final _poCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_ItemRow> _items = [];
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
      _poCtrl.text = e['poNo'] as String? ?? '';
      _notesCtrl.text = e['notes'] as String? ?? '';
      final rawItems = e['items'] as List? ?? [];
      for (final item in rawItems) {
        _items.add(_ItemRow(data: item as Map<String, dynamic>));
      }
    }
    if (_items.isEmpty) _items.add(_ItemRow());
    for (final row in _items) {
      row.qtyCtrl.addListener(() => _autoCalcAmount(row));
      row.rateCtrl.addListener(() => _autoCalcAmount(row));
    }
  }

  void _autoCalcAmount(_ItemRow row) {
    final qty = double.tryParse(row.qtyCtrl.text);
    final rate = double.tryParse(row.rateCtrl.text);
    if (qty != null && rate != null) {
      final amt = qty * rate;
      final formatted = amt.toStringAsFixed(2);
      if (row.amtCtrl.text != formatted) {
        row.amtCtrl.text = formatted;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final r in _items) {
      r.dispose();
    }
    _poCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final row = _ItemRow();
    row.qtyCtrl.addListener(() => _autoCalcAmount(row));
    row.rateCtrl.addListener(() => _autoCalcAmount(row));
    setState(() => _items.add(row));
  }

  void _removeItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  double get _subtotal {
    double s = 0;
    for (final r in _items) {
      s += double.tryParse(r.amtCtrl.text) ?? 0;
    }
    return s;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    final body = {
      'vendorId': _vendorId,
      'invoiceDate': DateFormat('yyyy-MM-dd').format(_invoiceDate),
      'supplyDate': _supplyDate != null
          ? DateFormat('yyyy-MM-dd').format(_supplyDate!)
          : null,
      'poNo': _poCtrl.text.trim().isEmpty ? null : _poCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'items': _items.map((r) => r.toJson()).toList(),
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    if (e == null) {
      await api.post('/api/invoices', data: body);
    } else {
      await api.put('/api/invoices/${e['id']}', data: body);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(_vendorsProvider);
    final sub = _subtotal;
    final cgst = sub * 0.09;
    final sgst = sub * 0.09;
    final grand = sub + cgst + sgst;
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Invoice' : 'New GST Invoice'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor + date row
                Row(
                  children: [
                    Expanded(
                      child: vendors.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (list) {
                          final active = list
                              .where((v) => v['status'] == 'ACTIVE')
                              .toList();
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.calendar_today, size: 20),
                        title: Text(
                            DateFormat('d MMM yyyy').format(_invoiceDate),
                            style: const TextStyle(fontSize: 13)),
                        subtitle: const Text('Invoice Date',
                            style: TextStyle(fontSize: 11)),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _invoiceDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _invoiceDate = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _poCtrl,
                        decoration: const InputDecoration(
                            labelText: 'PO No.', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading:
                            const Icon(Icons.local_shipping_outlined, size: 20),
                        title: Text(
                            _supplyDate != null
                                ? DateFormat('d MMM yyyy').format(_supplyDate!)
                                : 'Not set',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: const Text('Supply Date',
                            style: TextStyle(fontSize: 11)),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _supplyDate ?? _invoiceDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _supplyDate = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Line items header
                Row(
                  children: [
                    const Text('Line Items',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Row'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ..._items.asMap().entries.map((e) =>
                    _ItemRowWidget(
                      row: e.value,
                      index: e.key,
                      canRemove: _items.length > 1,
                      onRemove: () => _removeItem(e.key),
                      onChanged: () => setState(() {}),
                    )),
                // Totals preview
                if (sub > 0) ...[
                  const Divider(height: 24),
                  _PreviewRow('Subtotal', sub),
                  _PreviewRow('CGST 9%', cgst),
                  _PreviewRow('SGST 9%', sgst),
                  _PreviewRow('Grand Total', grand, bold: true),
                ],
                const SizedBox(height: 12),
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
              : Text(isEdit ? 'Update' : 'Save Invoice'),
        ),
      ],
    );
  }
}

class _ItemRowWidget extends StatelessWidget {
  final _ItemRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ItemRowWidget(
      {required this.row,
      required this.index,
      required this.canRemove,
      required this.onRemove,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Item ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.red,
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: row.descCtrl,
            decoration: const InputDecoration(
                labelText: 'Description *', isDense: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.hsnCtrl,
                  decoration:
                      const InputDecoration(labelText: 'HSN', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.qtyCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Qty (Brass)', isDense: true),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.rateCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Rate', isDense: true),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.amtCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Amount *', isDense: true),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || double.tryParse(v) == null)
                          ? 'Required'
                          : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _PreviewRow(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 14 : 12)),
            Text('₹${_fmt.format(value)}',
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 14 : 12,
                    color: bold
                        ? Theme.of(context).colorScheme.primary
                        : null)),
          ],
        ),
      );
}
