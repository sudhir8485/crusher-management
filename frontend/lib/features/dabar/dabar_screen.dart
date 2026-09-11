import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ────────────────────────────────────────────────────────────────

final _dabarDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _dabarModeProvider = StateProvider<String>((ref) => 'day');
final _dabarCustomRangeProvider =
    StateProvider<List<DateTime>>((ref) => [DateTime.now(), DateTime.now()]);

List<DateTime> _resolveDabarRange(String mode, DateTime anchor, List<DateTime> custom) {
  switch (mode) {
    case 'week':
      final mon = anchor.subtract(Duration(days: anchor.weekday - 1));
      return [mon, mon.add(const Duration(days: 6))];
    case 'month':
      return [DateTime(anchor.year, anchor.month, 1),
              DateTime(anchor.year, anchor.month + 1, 0)];
    case 'year':
      return [DateTime(anchor.year, 1, 1), DateTime(anchor.year, 12, 31)];
    case 'custom':
      return custom;
    default: // day
      return [anchor, anchor];
  }
}

String _dabarPeriodLabel(String mode, DateTime anchor, List<DateTime> custom) {
  switch (mode) {
    case 'week':   return 'this week';
    case 'month':  return 'this month';
    case 'year':   return 'this year';
    case 'custom':
      final r = _resolveDabarRange('custom', anchor, custom);
      return '${DateFormat('d MMM').format(r[0])} – ${DateFormat('d MMM yyyy').format(r[1])}';
    default:       return 'today';
  }
}

// key = "fromDate|toDate|siteId" (same pattern as Diesel)
final _dabarProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, rangeKey) async {
  final parts = rangeKey.split('|');
  final params = <String, dynamic>{'from': parts[0], 'to': parts[1]};
  if (parts[2].isNotEmpty) params['siteId'] = parts[2];
  final res = await ref.read(apiClientProvider).get('/api/dabar', params: params);
  return List<Map<String, dynamic>>.from(res.data);
});

final _vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/vehicles');
  return List<Map<String, dynamic>>.from(res.data);
});

final _vendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ───────────────────────────────────────────────────────────────────

class DabarScreen extends ConsumerStatefulWidget {
  const DabarScreen({super.key});

  @override
  ConsumerState<DabarScreen> createState() => _DabarScreenState();
}

class _DabarScreenState extends ConsumerState<DabarScreen> {
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
    final dabarId = extra['editDabarId'] as int?;
    final dateStr = extra['entryDate'] as String?;
    if (dabarId == null || dateStr == null) return;
    final date = DateTime.parse(dateStr);
    ref.read(_dabarModeProvider.notifier).state = 'day';
    ref.read(_dabarDateProvider.notifier).state = date;
    _scheduleOpenDabar(dabarId, date);
  }

  Future<void> _scheduleOpenDabar(int dabarId, DateTime date) async {
    final siteId = ref.read(selectedSiteIdProvider);
    final fmt = DateFormat('yyyy-MM-dd');
    final ds = fmt.format(date);
    final key = '$ds|$ds|${siteId ?? ''}';
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final entries = ref.read(_dabarProvider(key)).valueOrNull;
      if (entries != null) {
        final entry = entries.where((e) => (e['id'] as int?) == dabarId).firstOrNull;
        if (entry != null) {
          _showForm(context, ref, entry, date, key);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry not found — check that the correct site is selected')),
          );
        }
        return;
      }
    }
  }

  String _rangeKey(String mode, DateTime anchor, List<DateTime> custom, int? siteId) {
    final fmt = DateFormat('yyyy-MM-dd');
    final range = _resolveDabarRange(mode, anchor, custom);
    return '${fmt.format(range[0])}|${fmt.format(range[1])}|${siteId ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(_dabarDateProvider);
    final mode         = ref.watch(_dabarModeProvider);
    final custom       = ref.watch(_dabarCustomRangeProvider);
    final siteId       = ref.watch(selectedSiteIdProvider);
    final rangeKey     = _rangeKey(mode, selectedDate, custom, siteId);
    final entries      = ref.watch(_dabarProvider(rangeKey));

    void invalidate() => ref.invalidate(_dabarProvider(rangeKey));

    String emptyPeriod() {
      switch (mode) {
        case 'week':   return 'this week';
        case 'month':  return 'in ${DateFormat('MMMM yyyy').format(selectedDate)}';
        case 'year':   return 'in ${DateFormat('yyyy').format(selectedDate)}';
        case 'custom': return 'for this range';
        default:       return 'for ${DateFormat('d MMM yyyy').format(selectedDate)}';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dabar (Raw Stone Intake)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: invalidate),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null, selectedDate, rangeKey),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          _DabarDateRangeBar(
            selectedDate: selectedDate,
            mode: mode,
            custom: custom,
            onDateChanged: (d) => ref.read(_dabarDateProvider.notifier).state = d,
            onModeChanged: (m) => ref.read(_dabarModeProvider.notifier).state = m,
            onCustomChanged: (r) => ref.read(_dabarCustomRangeProvider.notifier).state = r,
          ),
          if (siteId == null)
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Select a site from the sidebar to add new entries',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  )),
                ]),
              ),
            ),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.terrain_outlined,
                    message: 'No dabar entries ${emptyPeriod()}',
                    hint: 'Tap + to add an entry',
                  );
                }
                return _DabarList(
                  list: list,
                  mode: mode,
                  date: selectedDate,
                  custom: custom,
                  onEdit:   (e) => _showForm(context, ref, e, selectedDate, rangeKey),
                  onDelete: (e) => _confirmDelete(context, ref, e, rangeKey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing,
      DateTime date, String rangeKey) {
    showDialog(
      context: context,
      builder: (_) => _DabarForm(
        existing: existing,
        initialDate: date,
        onSaved: () {
          final key = _rangeKey(
            ref.read(_dabarModeProvider),
            ref.read(_dabarDateProvider),
            ref.read(_dabarCustomRangeProvider),
            ref.read(selectedSiteIdProvider),
          );
          ref.invalidate(_dabarProvider(key));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      Map<String, dynamic> entry, String rangeKey) {
    final vehicle = entry['vehicleDisplayName'] ?? entry['vehiclePlateNumber'] ?? '—';
    final vendor  = entry['vendorName'] ?? '—';
    final brass   = entry['quantityBrass'];
    final detail  = brass != null ? '$vehicle · $vendor · ${numFmt.format(brass)} Brass' : '$vehicle · $vendor';
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete dabar entry?'),
        content: Text('Delete: $detail?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(apiClientProvider).delete('/api/dabar/${entry['id']}');
              } catch (_) { return; }
              if (!context.mounted) return;
              final key = _rangeKey(
                ref.read(_dabarModeProvider),
                ref.read(_dabarDateProvider),
                ref.read(_dabarCustomRangeProvider),
                ref.read(selectedSiteIdProvider),
              );
              ref.invalidate(_dabarProvider(key));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Date Range Bar ────────────────────────────────────────────────────────────

class _DabarDateRangeBar extends StatelessWidget {
  final DateTime selectedDate;
  final String mode;
  final List<DateTime> custom;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<List<DateTime>> onCustomChanged;

  const _DabarDateRangeBar({
    required this.selectedDate,
    required this.mode,
    required this.custom,
    required this.onDateChanged,
    required this.onModeChanged,
    required this.onCustomChanged,
  });

  void _prev() {
    switch (mode) {
      case 'week':  onDateChanged(selectedDate.subtract(const Duration(days: 7))); break;
      case 'month': onDateChanged(DateTime(selectedDate.year, selectedDate.month - 1, 1)); break;
      case 'year':  onDateChanged(DateTime(selectedDate.year - 1, 1, 1)); break;
      default:      onDateChanged(selectedDate.subtract(const Duration(days: 1))); break;
    }
  }

  void _next() {
    switch (mode) {
      case 'week':  onDateChanged(selectedDate.add(const Duration(days: 7))); break;
      case 'month': onDateChanged(DateTime(selectedDate.year, selectedDate.month + 1, 1)); break;
      case 'year':  onDateChanged(DateTime(selectedDate.year + 1, 1, 1)); break;
      default:      onDateChanged(selectedDate.add(const Duration(days: 1))); break;
    }
  }

  String _label() {
    final fmt = DateFormat('d MMM yyyy');
    final range = _resolveDabarRange(mode, selectedDate, custom);
    switch (mode) {
      case 'week':
        return '${DateFormat('d MMM').format(range[0])} – ${fmt.format(range[1])}';
      case 'month':
        return DateFormat('MMMM yyyy').format(selectedDate);
      case 'year':
        return DateFormat('yyyy').format(selectedDate);
      case 'custom':
        return '${DateFormat('d MMM').format(range[0])} – ${fmt.format(range[1])}';
      default:
        return DateFormat('EEEE, d MMMM yyyy').format(selectedDate);
    }
  }

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: custom[0], end: custom[1]),
    );
    if (picked != null) {
      onCustomChanged([picked.start, picked.end]);
      onModeChanged('custom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showArrows = mode != 'custom';

    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Mode chips row
        Row(children: [
          for (final m in [('day', 'Day'), ('week', 'Week'), ('month', 'Month'), ('year', 'Year')])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(m.$2),
                selected: mode == m.$1,
                onSelected: (_) => onModeChanged(m.$1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: TextStyle(fontSize: 12,
                    color: mode == m.$1 ? cs.onPrimary : null),
                selectedColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          InkWell(
            onTap: () => _pickCustom(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mode == 'custom' ? cs.primary : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: mode == 'custom' ? cs.primary : cs.outline.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_outlined, size: 14,
                    color: mode == 'custom' ? cs.onPrimary : cs.onSurface),
                const SizedBox(width: 4),
                Text('Custom', style: TextStyle(fontSize: 12,
                    color: mode == 'custom' ? cs.onPrimary : cs.onSurface)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        // Date navigation row
        Row(children: [
          if (showArrows)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prev,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          Expanded(
            child: GestureDetector(
              onTap: mode == 'day'
                  ? () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) onDateChanged(d);
                    }
                  : mode == 'custom' ? () => _pickCustom(context) : null,
              child: Text(_label(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
          if (showArrows)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _next,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ]),
      ]),
    );
  }
}

// ── Entry list (search + filter chrome) ──────────────────────────────────────

class _DabarList extends StatefulWidget {
  final List<Map<String, dynamic>> list;
  final String mode;
  final DateTime date;
  final List<DateTime> custom;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _DabarList({
    required this.list,
    required this.mode,
    required this.date,
    required this.custom,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DabarList> createState() => _DabarListState();
}

class _DabarListState extends State<_DabarList> {
  String _search = '';
  bool _externalOnly = false;
  bool _companyOnly  = false;
  bool _payableOnly  = false;
  String? _vehicleFilter;
  final _searchCtrl  = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    var list = all;
    if (_externalOnly) list = list.where((e) => e['vehicleOwner'] == 'VENDOR').toList();
    if (_companyOnly)  list = list.where((e) => e['vehicleOwner'] == 'TENANT').toList();
    if (_payableOnly)  list = list.where((e) => e['transportPayableActive'] == true).toList();
    if (_vehicleFilter != null) {
      list = list.where((e) =>
        (e['vehicleDisplayName'] ?? e['vehiclePlateNumber']) == _vehicleFilter,
      ).toList();
    }
    if (_search.isNotEmpty) {
      list = list.where((e) {
        final plate   = (e['vehiclePlateNumber'] as String? ?? '').toLowerCase();
        final display = (e['vehicleDisplayName']  as String? ?? '').toLowerCase();
        final party   = (e['vendorName']           as String? ?? '').toLowerCase();
        return plate.contains(_search) || display.contains(_search) || party.contains(_search);
      }).toList();
    }
    return list;
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap, {Color? color}) {
    final c = color ?? Colors.blue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? c : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? c : Colors.grey[700])),
          if (active) ...[
            const SizedBox(width: 3),
            Icon(Icons.close, size: 11, color: c),
          ],
        ]),
      ),
    );
  }

  void _showDrilldown(BuildContext context, Map<String, dynamic> entry) {
    final vehicle    = entry['vehicleDisplayName'] ?? entry['vehiclePlateNumber'] ?? '—';
    final party      = entry['vendorName'] ?? '—';
    final owner      = entry['vehicleOwner'] as String?;
    final ownerParty = entry['vehicleOwnedByPartyName'] as String?;
    final hasPayable = entry['transportPayableActive'] == true;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Entry Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Vehicle', value: vehicle),
            _DetailRow(label: 'Party', value: party),
            _DetailRow(
              label: 'Vehicle Ownership',
              value: owner == 'TENANT' ? 'Company (no payable)' : (ownerParty ?? 'External'),
              valueColor: owner == 'TENANT' ? Colors.blueGrey : Colors.orange.shade800,
            ),
            if (owner == 'VENDOR' && ownerParty != null)
              _DetailRow(label: 'Owned by', value: ownerParty),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  hasPayable ? Icons.account_balance_wallet : Icons.do_not_disturb_alt_outlined,
                  size: 18,
                  color: hasPayable ? Colors.deepOrange : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPayable
                        ? 'Transport payable created — visible in party ledger'
                        : 'No transport payable',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasPayable ? Colors.deepOrange : Colors.grey,
                      fontWeight: hasPayable ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all      = widget.list;
    final filtered = _applyFilters(all);

    // Counts from unfiltered list (for chip labels)
    final externalCount = all.where((e) => e['vehicleOwner'] == 'VENDOR').length;
    final companyCount  = all.where((e) => e['vehicleOwner'] == 'TENANT').length;
    final payableCount  = all.where((e) => e['transportPayableActive'] == true).length;

    // Top vehicle labels by entry count (for vehicle chips)
    final Map<String, int> vehicleCounts = {};
    for (final e in all) {
      final label = (e['vehicleDisplayName'] ?? e['vehiclePlateNumber']) as String?;
      if (label != null) vehicleCounts[label] = (vehicleCounts[label] ?? 0) + 1;
    }
    final topVehicles = vehicleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Summary from unfiltered backend list (full period aggregates, same as Diesel)
    final totalBrass    = all.fold<double>(0, (s, e) => s + ((e['quantityBrass'] as num?)?.toDouble() ?? 0));
    final totalTrips    = all.fold<int>(0, (s, e) => s + ((e['tripsCount'] as int?) ?? 0));
    final totalPayables = all.where((e) => e['transportPayableActive'] == true).length;

    final periodLabel = _dabarPeriodLabel(widget.mode, widget.date, widget.custom);
    final hasChips = externalCount > 0 || companyCount > 0 || payableCount > 0 || topVehicles.length > 1;

    return Column(
      children: [
        // ── Summary bar ──────────────────────────────────────────────────────
        Container(
          color: Colors.brown.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Entries',     value: '${all.length}'),
                  _Stat(label: 'Total Trips', value: '$totalTrips'),
                  _Stat(label: 'Total Brass', value: totalBrass.toStringAsFixed(3)),
                  _Stat(
                    label: 'Payables',
                    value: '$totalPayables',
                    color: totalPayables > 0 ? Colors.deepOrange : Colors.brown.shade300,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Period: $periodLabel',
                style: TextStyle(fontSize: 11, color: Colors.brown.shade400),
              ),
            ],
          ),
        ),
        // ── Search bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search vehicle, party…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() {
                        _search = '';
                        _searchCtrl.clear();
                      }),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
          ),
        ),
        // ── Filter chips ─────────────────────────────────────────────────────
        if (hasChips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              if (externalCount > 0) ...[
                _filterChip('External ($externalCount)', _externalOnly,
                    () => setState(() {
                      _externalOnly = !_externalOnly;
                      if (_externalOnly) _companyOnly = false;
                    }),
                    color: Colors.orange),
                const SizedBox(width: 6),
              ],
              if (companyCount > 0) ...[
                _filterChip('Company ($companyCount)', _companyOnly,
                    () => setState(() {
                      _companyOnly = !_companyOnly;
                      if (_companyOnly) _externalOnly = false;
                    }),
                    color: Colors.blueGrey),
                const SizedBox(width: 6),
              ],
              if (payableCount > 0) ...[
                _filterChip('Payable ($payableCount)', _payableOnly,
                    () => setState(() => _payableOnly = !_payableOnly),
                    color: Colors.deepOrange),
                const SizedBox(width: 6),
              ],
              if (topVehicles.length > 1)
                for (final entry in topVehicles.take(4)) ...[
                  _filterChip(entry.key, _vehicleFilter == entry.key,
                      () => setState(() =>
                        _vehicleFilter = _vehicleFilter == entry.key ? null : entry.key),
                      color: Colors.indigo),
                  const SizedBox(width: 6),
                ],
            ]),
          ),
        // ── Entry list ───────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? AppEmptyState(
                  icon: Icons.search_off,
                  message: 'No entries match the current filter',
                  hint: 'Clear the search or remove a filter chip',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _DabarCard(
                    entry: filtered[i],
                    showDate: widget.mode != 'day',
                    onTap: () => _showDrilldown(context, filtered[i]),
                    onEdit: () => widget.onEdit(filtered[i]),
                    onDelete: () => widget.onDelete(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── drilldown detail row ──────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── summary stat ─────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.brown;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}

// ── card ─────────────────────────────────────────────────────────────────────

class _DabarCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool showDate;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DabarCard({required this.entry, this.showDate = false, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final vehicle = entry['vehicleDisplayName'] ?? entry['vehiclePlateNumber'] ?? '-';
    final vendor = entry['vendorName'] ?? '-';
    final trips = entry['tripsCount'];
    final brass = entry['quantityBrass'];
    final hasPayable = entry['transportPayableActive'] == true;
    final vehicleOwner = entry['vehicleOwner'] as String?;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.brown.shade100,
                child: Text(
                  vehicle.length > 4 ? vehicle.substring(0, 4) : vehicle,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(vehicle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        if (vehicleOwner == 'TENANT')
                          _Badge('Company', Colors.blueGrey)
                        else if (vehicleOwner == 'VENDOR')
                          _Badge('External', Colors.orange),
                        if (showDate && entry['entryDate'] != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('d MMM').format(DateTime.parse(entry['entryDate'] as String)),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Party: $vendor', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (trips != null)
                          _Badge('$trips Trips', Colors.orange.shade700),
                        if (trips != null && brass != null) const SizedBox(width: 8),
                        if (brass != null)
                          _Badge('$brass Brass', Colors.green),
                        if (hasPayable) ...[
                          const SizedBox(width: 8),
                          _Badge('Payable', Colors.deepOrange),
                        ],
                      ],
                    ),
                    if (entry['notes'] != null && (entry['notes'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(entry['notes'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Tap for details', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
    );
  }
}

// ── form ─────────────────────────────────────────────────────────────────────

class _DabarForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime initialDate;
  final VoidCallback onSaved;
  const _DabarForm({this.existing, required this.initialDate, required this.onSaved});

  @override
  ConsumerState<_DabarForm> createState() => _DabarFormState();
}

class _DabarFormState extends ConsumerState<_DabarForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _entryDate;
  late final _trips  = TextEditingController(
    text: widget.existing?['tripsCount']?.toString() ?? '1',
  );
  late final _brass  = TextEditingController(text: widget.existing?['quantityBrass']?.toString());
  late final _notes  = TextEditingController(text: widget.existing?['notes']);
  int? _vehicleId;
  int? _vendorId;
  bool _saving = false;

  // Payable state
  bool _showPayableToggle = false;
  bool _createPayable = false;
  String? _ownerPartyName;
  late final _payableAmount = TextEditingController(
    text: widget.existing?['transportPayableAmount']?.toString(),
  );
  bool get _payableSettled => widget.existing?['transportPayableSettled'] == true;

  @override
  void initState() {
    super.initState();
    _entryDate = widget.initialDate;
    _vehicleId = widget.existing?['vehicleId'];
    _vendorId  = widget.existing?['vendorId'];
    _createPayable = widget.existing?['transportPayableActive'] == true;

    if (_vehicleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onVehicleChanged(_vehicleId!));
    }
  }

  @override
  void dispose() {
    _trips.dispose(); _brass.dispose(); _notes.dispose(); _payableAmount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  Future<void> _onVehicleChanged(int vehicleId) async {
    setState(() {
      _vehicleId = vehicleId;
      _showPayableToggle = false;
      _ownerPartyName = null;
    });

    final vehicles = ref.read(_vehiclesProvider).valueOrNull;
    if (vehicles == null) return;

    final vehicle = vehicles.firstWhere(
      (v) => v['id'] == vehicleId,
      orElse: () => <String, dynamic>{},
    );
    if (vehicle.isEmpty) return;

    if (vehicle['owner'] == 'VENDOR' && vehicle['vendorId'] != null) {
      final vendorId = vehicle['vendorId'] as int;
      if (widget.existing == null || _vendorId == null) {
        setState(() => _vendorId = vendorId);
      }
    }

    final siteId = ref.read(selectedSiteIdProvider);
    if (siteId == null) return;

    try {
      final res = await ref.read(apiClientProvider).get(
        '/api/dabar/payable-eligibility',
        params: {'vehicleId': vehicleId, 'siteId': siteId},
      );
      final eligibility = res.data['eligibility'] as String;
      if (!mounted) return;

      if (eligibility == 'ELIGIBLE') {
        final ownerPartyId = vehicle['vendorId'] as int?;
        String? ownerName;
        if (ownerPartyId != null) {
          final vendors = ref.read(_vendorsProvider).valueOrNull;
          ownerName = vendors
              ?.firstWhere(
                (v) => v['id'] == ownerPartyId,
                orElse: () => <String, dynamic>{},
              )['name'] as String?;
        }
        setState(() {
          _showPayableToggle = true;
          _ownerPartyName = ownerName;
          if (widget.existing == null) _createPayable = false;
        });
      } else {
        setState(() {
          _showPayableToggle = false;
          _createPayable = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _showPayableToggle = false; _createPayable = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'entryDate': DateFormat('yyyy-MM-dd').format(_entryDate),
      'vehicleId': _vehicleId,
      'vendorId': _vendorId,
      'tripsCount': _trips.text.trim().isEmpty ? null : int.tryParse(_trips.text.trim()),
      'quantityBrass': _brass.text.trim().isEmpty ? null : double.tryParse(_brass.text.trim()),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };

    if (_showPayableToggle) {
      data['createTransportPayable'] = _createPayable;
    } else if (widget.existing != null && widget.existing!['transportPayableActive'] == true) {
      data['createTransportPayable'] = false;
    }

    // Send agreed amount when updating a payable (update only, not on create)
    if (widget.existing != null && !_payableSettled) {
      final amt = _payableAmount.text.trim();
      if (amt.isNotEmpty) {
        final parsed = double.tryParse(amt);
        if (parsed != null) data['transportPayableAmount'] = parsed;
      }
    }

    final api = ref.read(apiClientProvider);
    final siteId = ref.read(selectedSiteIdProvider);
    if (widget.existing == null && siteId == null) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a site from the sidebar before adding entries'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    final siteParams = siteId != null ? {'siteId': siteId} : null;
    try {
      if (widget.existing == null) {
        await api.post('/api/dabar', data: data, params: siteParams);
      } else {
        await api.put('/api/dabar/${widget.existing!['id']}', data: data);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(_vehiclesProvider);
    final vendors  = ref.watch(_vendorsProvider);

    return AppDialog(
      title: widget.existing == null ? 'Add Dabar Entry' : 'Edit Dabar Entry',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateField(label: 'Entry Date', date: _entryDate, onTap: _pickDate, required: true),
            const SizedBox(height: 12),
            vehicles.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => SearchablePicker(
                items: list,
                itemLabel: (v) =>
                    '${v['displayName'] ?? v['plateNumber']}  (${v['vehicleType'] ?? ''})',
                fieldLabel: 'Vehicle *',
                value: _vehicleId,
                onChanged: (v) {
                  if (v != null) _onVehicleChanged(v);
                },
                validator: (v) => v == null ? 'Select vehicle' : null,
              ),
            ),
            const SizedBox(height: 12),
            vendors.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => SearchablePicker(
                key: ValueKey(_vendorId),
                items: list,
                itemLabel: (v) => v['name'] as String,
                fieldLabel: 'Party',
                value: _vendorId,
                clearable: true,
                onChanged: (v) => setState(() => _vendorId = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _trips,
                  decoration: const InputDecoration(labelText: 'No. of Trips'),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _brass,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    suffixText: 'Brass',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            if (_showPayableToggle) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepOrange.shade200),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Arranged by DSP (creates a payable)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _ownerPartyName != null
                        ? 'Creates transport payable to $_ownerPartyName'
                        : 'Creates transport payable to vehicle\'s owner',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _createPayable,
                  onChanged: (v) => setState(() => _createPayable = v),
                  activeThumbColor: Colors.deepOrange,
                ),
              ),
            ],
            // Show amount field when editing an entry with an active payable
            if (widget.existing != null && widget.existing!['transportPayableActive'] == true) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _payableAmount,
                readOnly: _payableSettled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Agreed Transport Amount (₹)',
                  prefixText: '₹',
                  helperText: _payableSettled
                      ? 'Settled — cannot edit'
                      : 'Leave blank if amount not yet agreed',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _payableSettled
                      ? const Icon(Icons.lock_outline, size: 16)
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
