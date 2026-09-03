import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';
import 'party_detail_screen.dart';
import '../vendor_payments/vendor_payments_screen.dart' show showRecordPaymentDialog;
import '../vendor_payments/vendor_payments_screen.dart' as payments_screen;

// ── Provider ──────────────────────────────────────────────────────────────────

final _partyBalancesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties/balances');
  return List<Map<String, dynamic>>.from(res.data as List);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_partyBalancesProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Parties'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'All Transactions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _PartiesTab(onRefresh: () => ref.invalidate(_partyBalancesProvider)),
          const payments_screen.VendorPaymentsScreen(),
        ],
      ),
    );
  }
}

// ── Parties Tab ───────────────────────────────────────────────────────────────

class _PartiesTab extends ConsumerStatefulWidget {
  final VoidCallback onRefresh;
  const _PartiesTab({required this.onRefresh});

  @override
  ConsumerState<_PartiesTab> createState() => _PartiesTabState();
}

class _PartiesTabState extends ConsumerState<_PartiesTab> {
  String _search = '';
  String _filter = 'all'; // all | outstanding | advance | settled
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> all) {
    var list = all;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) {
        final name    = (p['name']    as String? ?? '').toLowerCase();
        final contact = (p['contact'] as String? ?? '').toLowerCase();
        return name.contains(q) || contact.contains(q);
      }).toList();
    }
    if (_filter == 'outstanding') {
      list = list.where((p) => (_outstanding(p)) > 0.5).toList();
    } else if (_filter == 'advance') {
      list = list.where((p) => (_outstanding(p)) < -0.5).toList();
    } else if (_filter == 'settled') {
      list = list.where((p) => (_outstanding(p)).abs() <= 0.5).toList();
    }
    // Default sort: highest outstanding first, then advances, then settled
    list.sort((a, b) {
      final oa = _outstanding(a);
      final ob = _outstanding(b);
      // Both positive (owed): largest first
      if (oa > 0.5 && ob > 0.5) return ob.compareTo(oa);
      // Positive before advance/settled
      if (oa > 0.5) return -1;
      if (ob > 0.5) return 1;
      return a['name'].toString().compareTo(b['name'].toString());
    });
    return list;
  }

  double _outstanding(Map<String, dynamic> p) =>
      (p['outstanding'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(_partyBalancesProvider);
    return balances.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        final filtered = _applyFilter(list);

        // Summary
        double totalOwed = 0, totalAdvance = 0;
        for (final p in list) {
          final o = _outstanding(p);
          if (o > 0.5) totalOwed += o;
          if (o < -0.5) totalAdvance += o.abs();
        }

        return Column(children: [
          // ── Summary bar ─────────────────────────────────────────────────────
          _SummaryBar(totalOwed: totalOwed, totalAdvance: totalAdvance, count: list.length),

          // ── Search ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() { _search = ''; _searchCtrl.clear(); }))
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
            ),
          ),

          // ── Filter chips ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              for (final (label, value) in [
                ('All', 'all'), ('Outstanding', 'outstanding'),
                ('Advance', 'advance'), ('Settled', 'settled'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _filter == value,
                    onSelected: (_) => setState(() => _filter = value),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
          ),

          // ── Party list ───────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? AppEmptyState(
                    icon: Icons.people_outline,
                    message: _search.isNotEmpty || _filter != 'all'
                        ? 'No parties match' : 'No parties yet',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _PartyBalanceCard(
                      party: filtered[i],
                      onTap: () => _openLedger(filtered[i]),
                      onRecordPayment: () => showRecordPaymentDialog(
                        context, ref,
                        initialVendorId:   filtered[i]['vendorId'] as int?,
                        initialVendorName: filtered[i]['name'] as String?,
                        onSaved: () => ref.invalidate(_partyBalancesProvider),
                      ),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  void _openLedger(Map<String, dynamic> party) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PartyDetailScreen(
        vendorId:   party['vendorId'] as int,
        vendorName: party['name']     as String? ?? '—',
      ),
    ));
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double totalOwed;
  final double totalAdvance;
  final int count;
  const _SummaryBar({required this.totalOwed, required this.totalAdvance, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surface,
      child: Row(children: [
        Text('$count parties', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const Spacer(),
        _tile('Receivable', totalOwed, Colors.orange.shade700),
        const SizedBox(width: 12),
        _tile('Advance held', totalAdvance, Colors.blue.shade700),
      ]),
    );
  }

  Widget _tile(String label, double amount, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(fmtCurr(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ],
  );
}

// ── Party balance card ────────────────────────────────────────────────────────

class _PartyBalanceCard extends StatelessWidget {
  final Map<String, dynamic> party;
  final VoidCallback onTap;
  final VoidCallback onRecordPayment;
  const _PartyBalanceCard({required this.party, required this.onTap, required this.onRecordPayment});

  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final name     = party['name'] as String? ?? '—';
    final contact  = party['contact'] as String? ?? '';
    final gstin    = party['gstin']   as String? ?? '';
    final isGst    = party['gstRegistered'] as bool? ?? false;
    final outstanding = (party['outstanding'] as num?)?.toDouble() ?? 0;
    final lastDate = party['lastActivityDate'] as String?;

    final isOwed    = outstanding > 0.5;
    final isAdvance = outstanding < -0.5;
    final isSettled = !isOwed && !isAdvance;

    final dotColor = isOwed ? Colors.red.shade600
        : isAdvance ? Colors.green.shade600
        : Colors.grey.shade400;

    final balLabel = isOwed    ? 'Owes ${fmtCurr(outstanding)}'
        : isAdvance ? 'Advance ${fmtCurr(outstanding.abs())}'
        : 'Settled';
    final balColor = isOwed    ? Colors.orange.shade800
        : isAdvance ? Colors.blue.shade700
        : Colors.grey.shade600;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Color dot
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  if (isGst)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Text('GST', style: TextStyle(fontSize: 9,
                          color: Colors.indigo.shade700, fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  if (contact.isNotEmpty)
                    Text(contact, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (contact.isNotEmpty && gstin.isNotEmpty)
                    Text('  ·  ', style: TextStyle(color: Colors.grey[400])),
                  if (gstin.isNotEmpty)
                    Text(gstin, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
                if (lastDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last: ${_dateFmt.format(DateTime.parse(lastDate))}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(balLabel, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: balColor)),
              const SizedBox(height: 4),
              if (isOwed)
                TextButton.icon(
                  onPressed: onRecordPayment,
                  icon: const Icon(Icons.payments_outlined, size: 14),
                  label: const Text('Pay', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
