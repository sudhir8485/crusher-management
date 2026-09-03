import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/app_widgets.dart';
import '../ledger/ledger_screen.dart';
import '../vendor_payments/vendor_payments_screen.dart' show showRecordPaymentDialog;

// ── Date range presets (mirrored from LedgerScreen) ──────────────────────────

enum _Preset { thisMonth, lastMonth, thisYear, prevYear, custom }

class _Range {
  final DateTime from;
  final DateTime to;
  const _Range(this.from, this.to);
}

_Range _presetRange(_Preset p) {
  final now = DateTime.now();
  switch (p) {
    case _Preset.thisMonth:
      return _Range(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
    case _Preset.lastMonth:
      final m = now.month == 1 ? 12 : now.month - 1;
      final y = now.month == 1 ? now.year - 1 : now.year;
      return _Range(DateTime(y, m, 1), DateTime(y, m + 1, 0));
    case _Preset.thisYear:
      return _Range(DateTime(now.year, 4, 1), DateTime(now.year + 1, 3, 31));
    case _Preset.prevYear:
      return _Range(DateTime(now.year - 1, 4, 1), DateTime(now.year, 3, 31));
    case _Preset.custom:
      return _Range(now, now);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _statementProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, key) async {
  // key format: "vendorId|from|to"
  final parts = key.split('|');
  final res = await ref.read(apiClientProvider).get(
    '/api/parties/${parts[0]}/statement',
    params: {'from': parts[1], 'to': parts[2]},
  );
  return Map<String, dynamic>.from(res.data as Map);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PartyDetailScreen extends ConsumerStatefulWidget {
  final int vendorId;
  final String vendorName;

  const PartyDetailScreen({
    super.key,
    required this.vendorId,
    required this.vendorName,
  });

  @override
  ConsumerState<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends ConsumerState<PartyDetailScreen> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from;
  late DateTime _to;

  static final _dateLong = DateFormat('d MMM yyyy');
  static final _dateShort = DateFormat('d MMM yyyy');
  static final _dateKey = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final r = _presetRange(_Preset.thisMonth);
    _from = r.from;
    _to   = r.to;
  }

  String get _key => '${widget.vendorId}|${_dateKey.format(_from)}|${_dateKey.format(_to)}';

  void _applyPreset(_Preset p) {
    if (p == _Preset.custom) return; // handled by date pickers
    final r = _presetRange(p);
    setState(() { _preset = p; _from = r.from; _to = r.to; });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
        context: context, initialDate: _from,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() { _from = d; _preset = _Preset.custom; });
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
        context: context, initialDate: _to,
        firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { _to = d; _preset = _Preset.custom; });
  }

  @override
  Widget build(BuildContext context) {
    final statement = ref.watch(_statementProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendorName),
        actions: [
          statement.maybeWhen(
            data: (data) {
              final contact = data['vendorContact'] as String? ?? '';
              if (contact.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.phone_outlined),
                tooltip: contact,
                onPressed: () {},
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_statementProvider(_key)),
          ),
        ],
      ),
      body: Column(children: [
        // ── Date-range filter bar ───────────────────────────────────────────
        _DateFilterBar(
          preset: _preset,
          from: _from,
          to: _to,
          onPreset: _applyPreset,
          onPickFrom: _pickFrom,
          onPickTo: _pickTo,
        ),

        // ── Content ────────────────────────────────────────────────────────
        Expanded(
          child: statement.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _StatementBody(
              data: data,
              vendorId: widget.vendorId,
              vendorName: widget.vendorName,
              from: _from,
              to: _to,
              onRefresh: () => ref.invalidate(_statementProvider(_key)),
              onPrintStatement: () => _printStatement(data),
              onRecordPayment: () => showRecordPaymentDialog(
                context, ref,
                initialVendorId:   widget.vendorId,
                initialVendorName: widget.vendorName,
                onSaved: () => ref.invalidate(_statementProvider(_key)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _printStatement(Map<String, dynamic> data) {
    // Open the full GST-style ledger screen for this party as Print Statement
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LedgerScreen(initialVendorId: widget.vendorId),
    ));
  }
}

// ── Date filter bar ───────────────────────────────────────────────────────────

class _DateFilterBar extends StatelessWidget {
  final _Preset preset;
  final DateTime from;
  final DateTime to;
  final ValueChanged<_Preset> onPreset;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  static final _fmt = DateFormat('d MMM yy');

  const _DateFilterBar({
    required this.preset, required this.from, required this.to,
    required this.onPreset, required this.onPickFrom, required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (label, p) in [
              ('This Month', _Preset.thisMonth), ('Last Month', _Preset.lastMonth),
              ('This FY', _Preset.thisYear), ('Prev FY', _Preset.prevYear),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  selected: preset == p,
                  onSelected: (_) => onPreset(p),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          InkWell(onTap: onPickFrom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(6)),
              child: Text(_fmt.format(from), style: const TextStyle(fontSize: 12)))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: TextStyle(fontSize: 12))),
          InkWell(onTap: onPickTo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(6)),
              child: Text(_fmt.format(to), style: const TextStyle(fontSize: 12)))),
        ]),
      ]),
    );
  }
}

// ── Statement body ────────────────────────────────────────────────────────────

class _StatementBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final int vendorId;
  final String vendorName;
  final DateTime from;
  final DateTime to;
  final VoidCallback onRefresh;
  final VoidCallback onPrintStatement;
  final VoidCallback onRecordPayment;

  static final _dateFmt = DateFormat('d MMM yyyy');

  const _StatementBody({
    required this.data,
    required this.vendorId,
    required this.vendorName,
    required this.from,
    required this.to,
    required this.onRefresh,
    required this.onPrintStatement,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final closing = (data['closingBalance'] as num?)?.toDouble() ?? 0;
    final entries = data['entries'] as List? ?? [];

    final isOwed    = closing > 0.5;
    final isAdvance = closing < -0.5;

    final balLabel = isOwed    ? 'Owes ${fmtCurr(closing)}'
        : isAdvance ? 'Advance ${fmtCurr(closing.abs())}'
        : 'Settled Up';
    final balColor = isOwed    ? Colors.orange.shade800
        : isAdvance ? Colors.blue.shade700
        : Colors.green.shade700;
    final balBg    = isOwed    ? Colors.orange.shade50
        : isAdvance ? Colors.blue.shade50
        : Colors.green.shade50;

    return Column(children: [
      // ── Balance + action buttons ──────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: balBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: balColor.withValues(alpha: 0.3)),
            ),
            child: Text(balLabel,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: balColor),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrintStatement,
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print Statement'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onRecordPayment,
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: const Text('Record Payment'),
              ),
            ),
          ]),
        ]),
      ),

      const Divider(height: 1),

      // ── Transaction list ──────────────────────────────────────────────────
      Expanded(
        child: entries.isEmpty
            ? AppEmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No transactions in this period',
                hint: 'Try changing the date range',
              )
            : _EntryList(entries: entries),
      ),
    ]);
  }
}

// ── Entry list with date grouping ─────────────────────────────────────────────

class _EntryList extends StatelessWidget {
  final List entries;
  static final _groupFmt = DateFormat('d MMM yyyy');

  const _EntryList({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Group entries by date (they come sorted ASC from backend)
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final entry = Map<String, dynamic>.from(e as Map);
      final key = entry['date'] as String;
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    final dates = grouped.keys.toList(); // already in order

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date = dates[i];
        final dayEntries = grouped[date]!;
        final parsedDate = DateTime.parse(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _groupFmt.format(parsedDate),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600, letterSpacing: 0.3),
              ),
            ),
            const Divider(height: 1),
            ...dayEntries.map((e) => _EntryRow(entry: e)),
          ],
        );
      },
    );
  }
}

// ── Single entry row (khatabook style) ────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type = entry['type'] as String;
    final isBilled = type == 'BILLED';
    final desc = entry['description'] as String? ?? '—';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final balance = (entry['runningBalance'] as num?)?.toDouble() ?? 0;

    final amtColor = isBilled ? Colors.orange.shade800 : Colors.green.shade700;
    final typeLabel = isBilled ? 'Billed' : 'Received';

    final balIsOwed = balance > 0.5;
    final balIsAdv  = balance < -0.5;
    final balText   = balIsOwed  ? 'Bal. ${fmtCurr(balance)}'
        : balIsAdv   ? 'Adv. ${fmtCurr(balance.abs())}'
        : 'Settled';
    final balColor  = balIsOwed  ? Colors.orange.shade700
        : balIsAdv   ? Colors.blue.shade700
        : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Left: description + running balance
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(balText, style: TextStyle(fontSize: 11, color: balColor)),
          ],
        )),
        // Right: amount column (BILLED right, RECEIVED right but green)
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(typeLabel, style: TextStyle(fontSize: 10, color: amtColor)),
          const SizedBox(height: 2),
          Text(fmtCurr(amount),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: amtColor)),
        ]),
      ]),
    );
  }
}
