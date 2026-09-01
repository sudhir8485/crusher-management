import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';

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
            return const AppEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No invoices yet',
              hint: 'Tap + to create your first GST invoice',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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

  void _showDetail(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => _InvoiceDetailDialog(invoice: inv),
    );
  }

  void _confirmDelete(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> inv) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: Text(
            'Cancel invoice ${inv['invoiceNo']} for ${inv['vendorName']}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(apiClientProvider)
                  .delete('/api/invoices/${inv['id']}');
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
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    Text(_dateFmt.format(invoiceDate),
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtCurr(grandTotal),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.primary)),
                  Text('incl. GST',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
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

// ── invoice detail dialog ─────────────────────────────────────────────────────

class _InvoiceDetailDialog extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceDetailDialog({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(
        invoice['items'] as List? ?? []);
    final cgstRate = invoice['cgstRate'] as num? ?? 9;
    final sgstRate = invoice['sgstRate'] as num? ?? 9;
    final subtotal = invoice['subtotal'] as num? ?? 0;
    final cgstAmt = invoice['cgstAmount'] as num? ?? 0;
    final sgstAmt = invoice['sgstAmount'] as num? ?? 0;
    final grandTotal = invoice['grandTotal'] as num? ?? 0;

    return AppDialog(
      title: invoice['invoiceNo'] as String? ?? 'Invoice',
      maxWidth: 580,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice['vendorName'] as String? ?? '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Invoice Date: ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(
                        _dateFmt.format(DateTime.parse(
                            invoice['invoiceDate'] as String)),
                        style: const TextStyle(fontSize: 12)),
                    if (invoice['poNo'] != null) ...[
                      const SizedBox(width: 16),
                      Text('PO: ${invoice['poNo']}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Line Items',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),

          // Items table — responsive
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
          const Divider(height: 24),

          // Totals
          _TotalRow('Subtotal', subtotal),
          _TotalRow('CGST ($cgstRate%)', cgstAmt),
          _TotalRow('SGST ($sgstRate%)', sgstAmt),
          const Divider(),
          _TotalRow('Grand Total', grandTotal, bold: true),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                        ? Theme.of(context).colorScheme.primary
                        : null)),
          ],
        ),
      );
}

// ── line item data ────────────────────────────────────────────────────────────

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
        'hsn':
            hsnCtrl.text.trim().isEmpty ? null : hsnCtrl.text.trim(),
        'quantityBrass': double.tryParse(qtyCtrl.text),
        'rate': double.tryParse(rateCtrl.text),
        'amount': double.tryParse(amtCtrl.text) ?? 0.0,
      };
}

// ── invoice form ──────────────────────────────────────────────────────────────

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
    _invoiceDate =
        e != null ? DateTime.parse(e['invoiceDate'] as String) : DateTime.now();
    if (e != null) {
      _vendorId = e['vendorId'] as int?;
      if (e['supplyDate'] != null) {
        _supplyDate = DateTime.parse(e['supplyDate'] as String);
      }
      _poCtrl.text = e['poNo'] as String? ?? '';
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
    final qty = double.tryParse(row.qtyCtrl.text);
    final rate = double.tryParse(row.rateCtrl.text);
    if (qty != null && rate != null) {
      final formatted = (qty * rate).toStringAsFixed(2);
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
    row.qtyCtrl.addListener(() => _autoCalc(row));
    row.rateCtrl.addListener(() => _autoCalc(row));
    setState(() => _items.add(row));
  }

  void _removeItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  double get _subtotal => _items.fold(
      0, (s, r) => s + (double.tryParse(r.amtCtrl.text) ?? 0));

  Future<void> _pickDate(bool isInvoice) async {
    final initial = isInvoice ? _invoiceDate : (_supplyDate ?? _invoiceDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isInvoice) {
          _invoiceDate = picked;
        } else {
          _supplyDate = picked;
        }
      });
    }
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
      'notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'items': _items.map((r) => r.toJson()).toList(),
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    try {
      if (e == null) {
        await api.post('/api/invoices', data: body);
      } else {
        await api.put('/api/invoices/${e['id']}', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $err'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(_vendorsProvider);
    final sub = _subtotal;
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
                  width: 18,
                  height: 18,
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
            // Vendor
            const SectionLabel('Invoice Details'),
            vendors.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                final active =
                    list.where((v) => v['status'] == 'ACTIVE').toList();
                return DropdownButtonFormField<int>(
                  decoration:
                      const InputDecoration(labelText: 'Vendor *'),
                  value: _vendorId,
                  isExpanded: true,
                  items: active
                      .map((v) => DropdownMenuItem<int>(
                            value: v['id'] as int,
                            child: Text(v['name'] as String,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _vendorId = v),
                  validator: (v) => v == null ? 'Select vendor' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DateField(
                    label: 'Invoice Date',
                    date: _invoiceDate,
                    onTap: () => _pickDate(true),
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateField(
                    label: 'Supply Date',
                    date: _supplyDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _poCtrl,
              decoration: const InputDecoration(labelText: 'PO No.'),
            ),

            // Line items
            const SectionLabel('Line Items'),
            ..._items.asMap().entries.map((e) => _ItemRowWidget(
                  row: e.value,
                  index: e.key,
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

            // Totals preview
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
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
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
  const _ItemRowWidget(
      {required this.row,
      required this.index,
      required this.canRemove,
      required this.onRemove,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Row(
            children: [
              Text('Item ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.close,
                      size: 18, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: row.descCtrl,
            decoration: const InputDecoration(
                labelText: 'Description *', isDense: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          // HSN + Qty on one row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.hsnCtrl,
                  decoration: const InputDecoration(
                      labelText: 'HSN Code', isDense: true),
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
            ],
          ),
          const SizedBox(height: 8),
          // Rate + Amount on one row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.rateCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Rate', isDense: true, prefixText: '₹'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.amtCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Amount *', isDense: true, prefixText: '₹'),
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
                        ? Theme.of(context).colorScheme.primary
                        : null)),
          ],
        ),
      );
}
