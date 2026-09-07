import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

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

final _receiptDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _usageDateProvider   = StateProvider<DateTime>((ref) => DateTime.now());

final _balanceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, siteId) async {
  final res = await ref.read(apiClientProvider).get('/api/diesel/balance', params: {'siteId': siteId});
  return Map<String, dynamic>.from(res.data);
});

final _receiptsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, key) async {
  // key = "date|siteId"
  final parts  = key.split('|');
  final date   = parts[0];
  final siteId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  final params = <String, dynamic>{'from': date, 'to': date};
  if (siteId != null) params['siteId'] = siteId;
  final res = await ref.read(apiClientProvider).get('/api/diesel/receipts', params: params);
  return List<Map<String, dynamic>>.from(res.data);
});

final _usagesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, key) async {
  final parts  = key.split('|');
  final date   = parts[0];
  final siteId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  final params = <String, dynamic>{'from': date, 'to': date};
  if (siteId != null) params['siteId'] = siteId;
  final res = await ref.read(apiClientProvider).get('/api/diesel/usages', params: params);
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

final _machinesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/machines');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ───────────────────────────────────────────────────────────────────

class DieselScreen extends ConsumerStatefulWidget {
  const DieselScreen({super.key});

  @override
  ConsumerState<DieselScreen> createState() => _DieselScreenState();
}

class _DieselScreenState extends ConsumerState<DieselScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refreshAll() {
    final siteId = ref.read(selectedSiteIdProvider);
    if (siteId != null) ref.invalidate(_balanceProvider(siteId));
    final rDate = DateFormat('yyyy-MM-dd').format(ref.read(_receiptDateProvider));
    final uDate = DateFormat('yyyy-MM-dd').format(ref.read(_usageDateProvider));
    final siteStr = siteId?.toString() ?? '';
    ref.invalidate(_receiptsProvider('$rDate|$siteStr'));
    ref.invalidate(_usagesProvider('$uDate|$siteStr'));
  }

  @override
  Widget build(BuildContext context) {
    final siteId = ref.watch(selectedSiteIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diesel'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.arrow_downward), text: 'Received'),
            Tab(icon: Icon(Icons.arrow_upward), text: 'Used'),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? dieselReceiptFab(context, ref, _refreshAll)
          : dieselUsageFab(context, ref, _refreshAll),
      body: Column(
        children: [
          // Require site selection — same UX pattern as Machine Work
          if (siteId == null)
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Select a site from the sidebar to view diesel stock and add entries',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  )),
                ]),
              ),
            ),
          // Per-site balance banner — only shown when site is selected
          if (siteId != null)
            ref.watch(_balanceProvider(siteId)).when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (b) => _BalanceBanner(balance: b),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ReceiptsTab(onChanged: _refreshAll),
                _UsagesTab(onChanged: _refreshAll),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── balance banner ────────────────────────────────────────────────────────────

class _BalanceBanner extends StatelessWidget {
  final Map<String, dynamic> balance;
  const _BalanceBanner({required this.balance});

  @override
  Widget build(BuildContext context) {
    final received = (balance['totalReceivedLiters'] as num?)?.toDouble() ?? 0;
    final used     = (balance['totalUsedLiters'] as num?)?.toDouble() ?? 0;
    final stock    = (balance['balanceLiters'] as num?)?.toDouble() ?? 0;
    final isLow    = stock < 100;

    return Container(
      color: isLow ? Colors.red.shade50 : Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCol('Received', '${received.toStringAsFixed(1)} L', Colors.green),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          _StatCol('Used', '${used.toStringAsFixed(1)} L', Colors.red),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          _StatCol('Stock', '${stock.toStringAsFixed(1)} L',
              isLow ? Colors.red : Colors.amber.shade800, bold: true),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _StatCol(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: bold ? 18 : 16,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── receipts tab ──────────────────────────────────────────────────────────────

class _ReceiptsTab extends ConsumerWidget {
  final VoidCallback onChanged;
  const _ReceiptsTab({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_receiptDateProvider);
    final siteId       = ref.watch(selectedSiteIdProvider);
    final dateKey      = DateFormat('yyyy-MM-dd').format(selectedDate);
    final providerKey  = '$dateKey|${siteId ?? ''}';
    final receipts     = ref.watch(_receiptsProvider(providerKey));

    return Column(
      children: [
        _DateBar(
          selectedDate: selectedDate,
          onPick: (d) => ref.read(_receiptDateProvider.notifier).state = d,
        ),
        Expanded(
          child: receipts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No diesel received on this date. Tap + to add.'));
              }
              final total = list.fold<double>(0, (s, r) => s + ((r['quantityLiters'] as num?)?.toDouble() ?? 0));
              return Column(
                children: [
                  _DayTotal('Total received today', total),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ReceiptCard(
                        r: list[i],
                        onEdit:   () => _showReceiptForm(context, ref, list[i], selectedDate, onChanged),
                        onDelete: () => _confirmDelete(context, ref, '/api/diesel/receipts/${list[i]['id']}',
                            providerKey, onChanged, label: '${(list[i]['quantityLiters'] as num?)?.toStringAsFixed(1) ?? "?"} L',
                            isReceipt: true),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── usages tab ────────────────────────────────────────────────────────────────

class _UsagesTab extends ConsumerWidget {
  final VoidCallback onChanged;
  const _UsagesTab({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_usageDateProvider);
    final siteId       = ref.watch(selectedSiteIdProvider);
    final dateKey      = DateFormat('yyyy-MM-dd').format(selectedDate);
    final providerKey  = '$dateKey|${siteId ?? ''}';
    final usages       = ref.watch(_usagesProvider(providerKey));

    return Column(
      children: [
        _DateBar(
          selectedDate: selectedDate,
          onPick: (d) => ref.read(_usageDateProvider.notifier).state = d,
        ),
        Expanded(
          child: usages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No diesel used on this date. Tap + to add.'));
              }
              final total = list.fold<double>(0, (s, u) => s + ((u['quantityLiters'] as num?)?.toDouble() ?? 0));
              return Column(
                children: [
                  _DayTotal('Total used today', total),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UsageCard(
                        u: list[i],
                        onEdit:   () => _showUsageForm(context, ref, list[i], selectedDate, onChanged),
                        onDelete: () => _confirmDelete(context, ref, '/api/diesel/usages/${list[i]['id']}',
                            providerKey, onChanged,
                            label: '${(list[i]['quantityLiters'] as num?)?.toStringAsFixed(1) ?? "?"} L'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── shared helpers ────────────────────────────────────────────────────────────

void _showReceiptForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing,
    DateTime date, VoidCallback onChanged) {
  showDialog(
    context: context,
    builder: (_) => _ReceiptForm(
      existing: existing,
      initialDate: date,
      onSaved: () {
        final siteId  = ref.read(selectedSiteIdProvider);
        final dateKey = DateFormat('yyyy-MM-dd').format(ref.read(_receiptDateProvider));
        ref.invalidate(_receiptsProvider('$dateKey|${siteId ?? ''}'));
        if (siteId != null) ref.invalidate(_balanceProvider(siteId));
        onChanged();
      },
    ),
  );
}

void _showUsageForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing,
    DateTime date, VoidCallback onChanged) {
  showDialog(
    context: context,
    builder: (_) => _UsageForm(
      existing: existing,
      initialDate: date,
      onSaved: () {
        final siteId  = ref.read(selectedSiteIdProvider);
        final dateKey = DateFormat('yyyy-MM-dd').format(ref.read(_usageDateProvider));
        ref.invalidate(_usagesProvider('$dateKey|${siteId ?? ''}'));
        if (siteId != null) ref.invalidate(_balanceProvider(siteId));
        onChanged();
      },
    ),
  );
}

void _confirmDelete(BuildContext context, WidgetRef ref, String path,
    String providerKey, VoidCallback onChanged,
    {String label = 'this entry', bool isReceipt = false}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Delete diesel entry?'),
      content: Text('Delete $label?\n\nThis cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(dialogCtx);
            try {
              await ref.read(apiClientProvider).delete(path);
            } catch (_) { return; }
            if (!context.mounted) return;
            final siteId = ref.read(selectedSiteIdProvider);
            if (siteId != null) ref.invalidate(_balanceProvider(siteId));
            if (isReceipt) {
              ref.invalidate(_receiptsProvider(providerKey));
            } else {
              ref.invalidate(_usagesProvider(providerKey));
            }
            onChanged();
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class _DayTotal extends StatelessWidget {
  final String label;
  final double liters;
  const _DayTotal(this.label, this.liters);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text('${liters.toStringAsFixed(1)} L',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── date bar ──────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onPick;
  const _DateBar({required this.selectedDate, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => onPick(selectedDate.subtract(const Duration(days: 1)))),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: selectedDate,
                  firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) onPick(picked);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  Text(DateFormat('EEEE, d MMMM yyyy').format(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                  if (isToday) const Text('Today', style: TextStyle(fontSize: 11, color: Colors.blue)),
                ]),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => onPick(selectedDate.add(const Duration(days: 1)))),
          if (!isToday) TextButton(onPressed: () => onPick(DateTime.now()), child: const Text('Today')),
        ],
      ),
    );
  }
}

// ── receipt card ──────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ReceiptCard({required this.r, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final source        = r['source'] as String? ?? '';
    final qty           = (r['quantityLiters'] as num?)?.toDouble();
    final rate          = r['ratePerLiter'];
    final amount        = r['amount'];
    final vendor        = r['vendorName'];
    final inv           = r['invoiceNo'];
    final advanceParty  = r['advancePartyName'] as String?;
    final advanceAmount = r['advanceAmount'];

    final isPump    = source == 'PUMP';
    final isAdvance = source == 'PARTY_ADVANCE';

    Color badgeColor = isPump ? Colors.blue : isAdvance ? Colors.purple : Colors.orange;
    String badgeLabel = isPump ? 'Pump' : isAdvance ? 'Party Advance' : 'Direct';
    IconData badgeIcon = isPump
        ? Icons.local_gas_station
        : isAdvance
            ? Icons.account_balance_wallet_outlined
            : Icons.inventory_2_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.15),
              child: Icon(badgeIcon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _SourceBadge(badgeLabel, badgeColor),
                    if (qty != null) ...[
                      const SizedBox(width: 8),
                      Text('${qty.toStringAsFixed(1)} L',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  if (isAdvance && advanceParty != null)
                    Text('Party: $advanceParty',
                        style: TextStyle(fontSize: 13, color: Colors.purple.shade700, fontWeight: FontWeight.w500)),
                  if (isAdvance && advanceAmount != null)
                    Text('Advance credited: ₹$advanceAmount',
                        style: const TextStyle(fontSize: 12, color: Colors.purple)),
                  if (!isAdvance) ...[
                    if (vendor != null || inv != null)
                      Text(
                        [vendor, if (inv != null) 'Invoice: $inv'].whereType<String>().join('  ·  '),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    if (rate != null || amount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [if (rate != null) '₹$rate/L', if (amount != null) 'Total: ₹$amount'].join('  ·  '),
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ),
                  ],
                  if (r['notes'] != null && (r['notes'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(r['notes'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    ),
                ],
              ),
            ),
            Column(children: [
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SourceBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── usage card ────────────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  final Map<String, dynamic> u;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _UsageCard({required this.u, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final qty           = (u['quantityLiters'] as num?)?.toDouble();
    final rate          = u['ratePerLiter'];
    final dieselValue   = u['dieselValue'];
    final machine       = u['machineName'];
    final vehicle       = u['vehicleDisplayName'] ?? u['vehiclePlateNumber'];
    final consumer      = machine ?? vehicle ?? 'Unknown';
    final owner         = u['vehicleOwner'] as String?;
    final ownerParty    = u['vehicleOwnedByPartyName'] as String?;
    final hasPayable    = u['hasDieselPayable'] == true;
    final isExternal    = owner == 'VENDOR';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.red.shade50,
              child: Icon(machine != null ? Icons.construction : Icons.local_shipping,
                  color: Colors.red.shade300, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(consumer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  if (qty != null)
                    Text('${qty.toStringAsFixed(1)} L used',
                        style: const TextStyle(fontSize: 13, color: Colors.red)),
                  if (rate != null)
                    Text('₹$rate/L${dieselValue != null ? '  ·  Value: ₹$dieselValue' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (isExternal && ownerParty != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(hasPayable ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
                          size: 14,
                          color: hasPayable ? Colors.deepOrange : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        hasPayable
                            ? 'Payable deducted from $ownerParty'
                            : 'External vehicle — $ownerParty (no rate, no deduction)',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasPayable ? Colors.deepOrange : Colors.grey,
                          fontWeight: hasPayable ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ]),
                  ],
                  if (u['notes'] != null && (u['notes'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(u['notes'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    ),
                ],
              ),
            ),
            Column(children: [
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── receipt form ──────────────────────────────────────────────────────────────

class _ReceiptForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime initialDate;
  final VoidCallback onSaved;
  const _ReceiptForm({this.existing, required this.initialDate, required this.onSaved});

  @override
  ConsumerState<_ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends ConsumerState<_ReceiptForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late String _source;
  late final _qty           = TextEditingController(text: widget.existing?['quantityLiters']?.toString());
  late final _rate          = TextEditingController(text: widget.existing?['ratePerLiter']?.toString());
  late final _invNo         = TextEditingController(text: widget.existing?['invoiceNo']);
  late final _notes         = TextEditingController(text: widget.existing?['notes']);
  late final _advanceAmount = TextEditingController(text: widget.existing?['advanceAmount']?.toString());
  int? _vendorId;
  int? _advancePartyId;
  bool _saving = false;

  double? get _computedAmount {
    final q = double.tryParse(_qty.text);
    final r = double.tryParse(_rate.text);
    if (q != null && r != null) return q * r;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _date          = widget.initialDate;
    _source        = widget.existing?['source'] ?? 'PUMP';
    _vendorId      = widget.existing?['vendorId'];
    _advancePartyId = widget.existing?['advancePartyId'];
    _qty.addListener(() => setState(() {}));
    _rate.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qty.dispose(); _rate.dispose(); _invNo.dispose(); _notes.dispose(); _advanceAmount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final siteId = ref.read(selectedSiteIdProvider);
    if (siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a site before adding entries'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'receiptDate': DateFormat('yyyy-MM-dd').format(_date),
      'source':       _source,
      'quantityLiters': double.tryParse(_qty.text.trim()),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    if (_source == 'PARTY_ADVANCE') {
      data['advancePartyId'] = _advancePartyId;
      data['advanceAmount']  = double.tryParse(_advanceAmount.text.trim());
    } else {
      data['ratePerLiter'] = _rate.text.trim().isEmpty ? null : double.tryParse(_rate.text.trim());
      data['vendorId']     = _vendorId;
      data['invoiceNo']    = _invNo.text.trim().isEmpty ? null : _invNo.text.trim();
    }
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/diesel/receipts', data: data, params: {'siteId': siteId});
      } else {
        await api.put('/api/diesel/receipts/${widget.existing!['id']}', data: data);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${_apiError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors      = ref.watch(_vendorsProvider);
    final amount       = _computedAmount;
    final isAdvance    = _source == 'PARTY_ADVANCE';

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Diesel Receipt' : 'Edit Diesel Receipt'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date *', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                    child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 16),

                // Source toggle: 3 options
                const Text('Source *', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'PUMP',          label: Text('Pump'),          icon: Icon(Icons.local_gas_station)),
                    ButtonSegment(value: 'DIRECT',        label: Text('Direct'),        icon: Icon(Icons.inventory_2_outlined)),
                    ButtonSegment(value: 'PARTY_ADVANCE', label: Text('Party Advance'), icon: Icon(Icons.account_balance_wallet_outlined)),
                  ],
                  selected: {_source},
                  onSelectionChanged: (s) => setState(() {
                    _source = s.first;
                    // Clear fields when switching modes
                    _rate.clear(); _invNo.clear(); _advanceAmount.clear();
                    _vendorId = null; _advancePartyId = null;
                  }),
                ),
                const SizedBox(height: 16),

                // Quantity (always shown)
                TextFormField(
                  controller: _qty,
                  decoration: const InputDecoration(labelText: 'Litres *', suffixText: 'L'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter quantity' : null,
                ),

                if (isAdvance) ...[
                  // Party Advance mode — show party picker + amount
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.purple.shade700),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            'Diesel funded by the party. Adds to site stock and credits the party\'s account.',
                            style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
                          )),
                        ]),
                        const SizedBox(height: 12),
                        vendors.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                          data: (list) => SearchablePicker(
                            items: list,
                            itemLabel: (v) => v['name'] as String,
                            fieldLabel: 'Party who funded diesel *',
                            value: _advancePartyId,
                            onChanged: (v) => setState(() => _advancePartyId = v),
                            validator: (v) => v == null ? 'Select party' : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _advanceAmount,
                          decoration: const InputDecoration(
                            labelText: 'Amount credited to party *',
                            prefixText: '₹',
                            helperText: 'The ₹ amount posted as advance on this party\'s account',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter amount' : null,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Pump / Direct mode — rate, supplier, invoice
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rate,
                    decoration: const InputDecoration(labelText: 'Rate / Litre', prefixText: '₹'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calculate_outlined, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Amount: ₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  vendors.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) => SearchablePicker(
                      items: list,
                      itemLabel: (v) => v['name'] as String,
                      fieldLabel: 'Supplier (optional)',
                      value: _vendorId,
                      clearable: true,
                      onChanged: (v) => setState(() => _vendorId = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _invNo, decoration: const InputDecoration(labelText: 'Invoice / Bill No (optional)')),
                ],

                const SizedBox(height: 12),
                TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}

// ── usage form ────────────────────────────────────────────────────────────────

class _UsageForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime initialDate;
  final VoidCallback onSaved;
  const _UsageForm({this.existing, required this.initialDate, required this.onSaved});

  @override
  ConsumerState<_UsageForm> createState() => _UsageFormState();
}

class _UsageFormState extends ConsumerState<_UsageForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final _qty  = TextEditingController(text: widget.existing?['quantityLiters']?.toString());
  late final _rate = TextEditingController(text: widget.existing?['ratePerLiter']?.toString());
  late final _notes = TextEditingController(text: widget.existing?['notes']);
  late String _consumerType;
  int? _machineId;
  int? _vehicleId;
  bool _saving = false;

  // Resolved from vehicle list after vehicle selection
  Map<String, dynamic>? _selectedVehicle;

  double? get _dieselValue {
    final q = double.tryParse(_qty.text);
    final r = double.tryParse(_rate.text);
    if (q != null && r != null) return q * r;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    if (widget.existing?['machineId'] != null) {
      _consumerType = 'machine';
      _machineId    = widget.existing!['machineId'];
    } else if (widget.existing?['vehicleId'] != null) {
      _consumerType = 'vehicle';
      _vehicleId    = widget.existing!['vehicleId'];
    } else {
      _consumerType = 'machine';
    }
    _qty.addListener(() => setState(() {}));
    _rate.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qty.dispose(); _rate.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final siteId = ref.read(selectedSiteIdProvider);
    if (siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a site before adding entries'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'usageDate':      DateFormat('yyyy-MM-dd').format(_date),
      'machineId':      _consumerType == 'machine' ? _machineId : null,
      'vehicleId':      _consumerType == 'vehicle' ? _vehicleId : null,
      'quantityLiters': double.tryParse(_qty.text.trim()),
      'ratePerLiter':   _rate.text.trim().isEmpty ? null : double.tryParse(_rate.text.trim()),
      'notes':          _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/diesel/usages', data: data, params: {'siteId': siteId});
      } else {
        await api.put('/api/diesel/usages/${widget.existing!['id']}', data: data);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${_apiError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final machines   = ref.watch(_machinesProvider);
    final vehicles   = ref.watch(_vehiclesProvider);
    final dieselVal  = _dieselValue;
    final isExternal = _consumerType == 'vehicle' && _selectedVehicle != null
        && _selectedVehicle!['owner'] == 'VENDOR';
    final ownerName  = _selectedVehicle?['vendorName'] as String?;

    // On first build with existing vehicle, resolve from loaded list
    if (_consumerType == 'vehicle' && _vehicleId != null && _selectedVehicle == null) {
      vehicles.whenData((list) {
        final match = list.where((v) => v['id'] == _vehicleId).firstOrNull;
        if (match != null && mounted) setState(() => _selectedVehicle = match);
      });
    }

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Diesel Usage' : 'Edit Diesel Usage'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date *', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                    child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 16),

                // Consumer type
                const Text('Used by *', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'machine', label: Text('Machine'), icon: Icon(Icons.construction)),
                    ButtonSegment(value: 'vehicle', label: Text('Vehicle'), icon: Icon(Icons.local_shipping)),
                  ],
                  selected: {_consumerType},
                  onSelectionChanged: (s) => setState(() {
                    _consumerType   = s.first;
                    _machineId      = null;
                    _vehicleId      = null;
                    _selectedVehicle = null;
                  }),
                ),
                const SizedBox(height: 16),

                // Machine or Vehicle picker
                if (_consumerType == 'machine')
                  machines.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) => SearchablePicker(
                      items: list,
                      itemLabel: (m) => '${m['name']}  (${m['machineType'] ?? ''})',
                      fieldLabel: 'Machine *',
                      value: _machineId,
                      onChanged: (v) => setState(() => _machineId = v),
                      validator: (v) => v == null ? 'Select machine' : null,
                    ),
                  )
                else
                  vehicles.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) => SearchablePicker(
                      items: list,
                      itemLabel: (v) => '${v['displayName'] ?? v['plateNumber']}',
                      fieldLabel: 'Vehicle *',
                      value: _vehicleId,
                      onChanged: (v) {
                        setState(() {
                          _vehicleId = v;
                          _selectedVehicle = v == null ? null : list.where((veh) => veh['id'] == v).firstOrNull;
                        });
                      },
                      validator: (v) => v == null ? 'Select vehicle' : null,
                    ),
                  ),
                const SizedBox(height: 12),

                // External vehicle info banner — auto-detected, no toggle needed
                if (isExternal) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepOrange.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.deepOrange.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'External vehicle${ownerName != null ? ' — owned by $ownerName' : ''}. '
                        'Rate is required — it will be used to compute the payable deduction to this party.',
                        style: TextStyle(fontSize: 12, color: Colors.deepOrange.shade800),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Quantity
                TextFormField(
                  controller: _qty,
                  decoration: const InputDecoration(labelText: 'Litres Used *', suffixText: 'L'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter quantity' : null,
                ),
                const SizedBox(height: 12),

                // Rate per litre — required for external vehicles (payable cannot be silently skipped)
                TextFormField(
                  controller: _rate,
                  decoration: InputDecoration(
                    labelText: isExternal ? 'Rate / Litre *' : 'Rate / Litre (optional)',
                    prefixText: '₹',
                    helperText: isExternal ? 'Required — deducts ₹(qty × rate) from DSP\'s payable to ${ownerName ?? 'owner'}' : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (isExternal && (v == null || v.trim().isEmpty)) {
                      return 'Rate is required for external vehicles — cannot skip payable deduction';
                    }
                    return null;
                  },
                ),

                // Live diesel value for external vehicles
                if (isExternal && dieselVal != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepOrange.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calculate_outlined, size: 16, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Text('Payable deduction: ₹${dieselVal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ]),
                  ),
                ],

                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}

// ── FAB overlay (one per tab) ─────────────────────────────────────────────────

FloatingActionButton dieselReceiptFab(BuildContext context, WidgetRef ref, VoidCallback onChanged) =>
    FloatingActionButton.extended(
      heroTag: 'diesel_receipt_fab',
      onPressed: () => _showReceiptForm(context, ref, null, ref.read(_receiptDateProvider), onChanged),
      icon: const Icon(Icons.add),
      label: const Text('Add Receipt'),
    );

FloatingActionButton dieselUsageFab(BuildContext context, WidgetRef ref, VoidCallback onChanged) =>
    FloatingActionButton.extended(
      heroTag: 'diesel_usage_fab',
      onPressed: () => _showUsageForm(context, ref, null, ref.read(_usageDateProvider), onChanged),
      icon: const Icon(Icons.add),
      label: const Text('Add Usage'),
    );
