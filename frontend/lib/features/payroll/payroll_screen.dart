import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/widgets/app_widgets.dart';

// ── Period model ──────────────────────────────────────────────────────────────

class _Period {
  final DateTime from;
  final DateTime to;
  const _Period(this.from, this.to);

  static _Period thisMonth() {
    final n = DateTime.now();
    return _Period(DateTime(n.year, n.month, 1), DateTime(n.year, n.month + 1, 0));
  }

  String get fromKey => DateFormat('yyyy-MM-dd').format(from);
  String get toKey   => DateFormat('yyyy-MM-dd').format(to);

  // Always show explicit date range
  String get label => '${_sfmt.format(from)} – ${_sfmt.format(to)}';

  // Month name for picker display
  bool get isFullMonth =>
      from.day == 1 && to == DateTime(from.year, from.month + 1, 0);
}

// ── Formatting ────────────────────────────────────────────────────────────────

final _dfmt = DateFormat('d MMM yyyy');
final _sfmt = DateFormat('d MMM yy');

// ── Position helpers — Pending / Advance / Settled ────────────────────────────

enum _Position { pending, advance, settled }

_Position _position(double closing) {
  if (closing > 0.005)  return _Position.pending;
  if (closing < -0.005) return _Position.advance;
  return _Position.settled;
}

String _positionLabel(_Position p, double closing) => switch (p) {
      _Position.pending  => '${fmtCurr(closing)} Pending',
      _Position.advance  => '${fmtCurr(closing.abs())} Advance',
      _Position.settled  => 'Settled',
    };

Color _positionColor(_Position p) => switch (p) {
      _Position.pending  => Colors.green[700]!,
      _Position.advance  => Colors.orange[800]!,
      _Position.settled  => Colors.grey,
    };

String _positionExplanation(_Position p, double closing) => switch (p) {
      _Position.pending  => '${fmtCurr(closing)} is still payable to this employee.',
      _Position.advance  => 'Employee has received ${fmtCurr(closing.abs())} more than earned wages.',
      _Position.settled  => 'Nothing is pending. Account is settled.',
    };

// ── Payment method helpers ────────────────────────────────────────────────────

const _paymentMethods = ['CASH', 'BANK_TRANSFER', 'UPI', 'OTHER'];
const _methodLabels   = {
  'CASH':          'Cash',
  'BANK_TRANSFER': 'Bank Transfer',
  'UPI':           'UPI',
  'OTHER':         'Other',
};
String _methodLabel(String? m) => _methodLabels[m] ?? 'Cash';

// ── Providers ─────────────────────────────────────────────────────────────────

final _periodProvider = StateProvider<_Period>((ref) => _Period.thisMonth());

final _payrollListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _Period>((ref, period) async {
  final res = await ref.read(apiClientProvider).get('/api/payroll', params: {
    'from': period.fromKey, 'to': period.toKey,
  });
  return List<Map<String, dynamic>>.from(res.data as List);
});

final _employeePayrollProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int id, _Period period})>((ref, key) async {
  final res = await ref.read(apiClientProvider)
      .get('/api/payroll/${key.id}', params: {
    'from': key.period.fromKey, 'to': key.period.toKey,
  });
  return Map<String, dynamic>.from(res.data as Map);
});

// ══════════════════════════════════════════════════════════════════════════════
// Payroll List Screen
// ══════════════════════════════════════════════════════════════════════════════

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_periodProvider);
    final data   = ref.watch(_payrollListProvider(period));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: [
          TextButton.icon(
            onPressed: () => _pickPeriod(context, ref, period),
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(period.label, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              icon: Icons.people_outline,
              message: 'No active employees',
              hint: 'Add employees in the Employees section',
            );
          }

          double sumOpening = 0, sumEarned = 0, sumPaid = 0, sumClosing = 0;
          for (final r in rows) {
            sumOpening += (r['openingBalance'] as num?)?.toDouble() ?? 0;
            sumEarned  += (r['earnedAmount']   as num?)?.toDouble() ?? 0;
            sumPaid    += (r['advancesPaid']   as num?)?.toDouble() ?? 0;
            sumClosing += (r['closingBalance'] as num?)?.toDouble()
                       ?? (r['balanceOwed']   as num?)?.toDouble() ?? 0;
          }

          return Column(
            children: [
              _SummaryBar(
                opening: sumOpening,
                earned:  sumEarned,
                paid:    sumPaid,
                closing: sumClosing,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) => _PayrollCard(
                    row: rows[i],
                    onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                      builder: (_) => EmployeePayrollScreen(
                        employeeId:   (rows[i]['employeeId'] as num).toInt(),
                        employeeName: rows[i]['employeeName'] as String? ?? '—',
                        period:       period,
                      ),
                    )),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickPeriod(BuildContext context, WidgetRef ref, _Period current) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PeriodDialog(
        current: current,
        onSelected: (p) => ref.read(_periodProvider.notifier).state = p,
      ),
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double opening, earned, paid, closing;
  const _SummaryBar({
    required this.opening, required this.earned,
    required this.paid,    required this.closing,
  });

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final pos     = _position(closing);
    final posColor = _positionColor(pos);

    // Show opening only if there are non-zero values
    final hasOpening = opening.abs() > 0.005;

    return Container(
      color: cs.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Formula row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (hasOpening) ...[
                _SumTile('Opening', fmtCurr(opening.abs()),
                    opening >= 0 ? Colors.grey[600]! : Colors.orange[700]!),
                _SumOp('+'),
              ],
              _SumTile('Earned', fmtCurr(earned), Colors.blue),
              _SumOp('−'),
              _SumTile('Paid', fmtCurr(paid), Colors.grey[600]!),
              _SumOp('='),
              _SumTile(
                pos == _Position.pending  ? 'Pending'
                  : pos == _Position.advance ? 'Advance'
                  : 'Settled',
                pos == _Position.settled ? '₹0' : fmtCurr(closing.abs()),
                posColor,
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Period totals — balance reflects all months',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SumOp extends StatelessWidget {
  final String op;
  const _SumOp(this.op);
  @override
  Widget build(BuildContext context) => Text(op,
      style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w300));
}

class _SumTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _SumTile(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: bold ? 14 : 13,
                  color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
      );
}

// ── Payroll card ──────────────────────────────────────────────────────────────

class _PayrollCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _PayrollCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name        = row['employeeName'] as String? ?? '—';
    final designation = (row['designation'] as String?)?.trim() ?? '';
    final wageType    = row['wageType'] as String? ?? 'DAILY';
    final wageRate    = (row['wageRate'] as num?)?.toDouble() ?? 0;
    final present     = row['presentCount'] as int? ?? 0;
    final half        = row['halfDayCount'] as int? ?? 0;
    final absent      = row['absentCount']  as int? ?? 0;
    final leave       = row['leaveCount']   as int? ?? 0;
    final earned      = (row['earnedAmount']   as num?)?.toDouble() ?? 0;
    final paid        = (row['advancesPaid']   as num?)?.toDouble() ?? 0;
    final closing     = (row['closingBalance'] as num?)?.toDouble()
                     ?? (row['balanceOwed']   as num?)?.toDouble() ?? 0;
    final rateLabel   = wageType == 'MONTHLY'
        ? '${fmtCurr(wageRate)}/mo' : '${fmtCurr(wageRate)}/day';
    final pos      = _position(closing);
    final posColor = _positionColor(pos);
    final posLabel = _positionLabel(pos, closing);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (designation.isNotEmpty || wageRate > 0)
                        Text(
                          [if (designation.isNotEmpty) designation, rateLabel].join(' · '),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(posLabel,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: posColor)),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 5, children: [
                _Pill('P: $present', Colors.green),
                if (half   > 0) _Pill('H: $half',   Colors.orange),
                if (absent > 0) _Pill('A: $absent',  Colors.red),
                if (leave  > 0) _Pill('L: $leave',   Colors.blue),
                const SizedBox(width: 2),
                _Pill('Earned: ${fmtCurr(earned)}', Colors.blue,  outlined: true),
                if (paid > 0) _Pill('Paid: ${fmtCurr(paid)}', Colors.grey, outlined: true),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool outlined;
  const _Pill(this.text, this.color, {this.outlined = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: outlined ? Border.all(color: color.withValues(alpha: 0.35)) : null,
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── Period picker dialog ──────────────────────────────────────────────────────

class _PeriodDialog extends ConsumerStatefulWidget {
  final _Period current;
  final ValueChanged<_Period> onSelected;
  const _PeriodDialog({required this.current, required this.onSelected});

  @override
  ConsumerState<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends ConsumerState<_PeriodDialog> {
  late DateTime _from, _to;
  bool _custom = false;

  @override
  void initState() {
    super.initState();
    _from = widget.current.from;
    _to   = widget.current.to;
  }

  List<DateTime> get _months {
    final now = DateTime.now();
    return List.generate(6, (i) => DateTime(now.year, now.month - i, 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Select Period'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._months.map((m) {
              final monthEnd = DateTime(m.year, m.month + 1, 0);
              final isSel    = !_custom && _from == m && _to == monthEnd;
              return ListTile(
                dense: true,
                title: Text(DateFormat('MMMM yyyy').format(m)),
                subtitle: Text('${_sfmt.format(m)} – ${_sfmt.format(monthEnd)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                trailing: isSel ? Icon(Icons.check, color: cs.primary, size: 18) : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelected(_Period(m, monthEnd));
                },
              );
            }),
            const Divider(height: 16),
            ListTile(
              dense: true,
              title: const Text('Custom Range…'),
              leading: const Icon(Icons.date_range_outlined, size: 18),
              onTap: () => setState(() => _custom = true),
            ),
            if (_custom) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _DatePill('From', _from, (d) => setState(() => _from = d))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→', style: TextStyle(color: Colors.grey))),
                Expanded(child: _DatePill('To', _to, (d) => setState(() => _to = d))),
              ]),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSelected(_Period(_from, _to));
                },
                child: const Text('Apply'),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DatePill(this.label, this.date, this.onPick);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context, initialDate: date,
            firstDate: DateTime(2020), lastDate: DateTime.now(),
          );
          if (d != null) onPick(d);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text(_sfmt.format(date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Employee Payroll Detail Screen
// ══════════════════════════════════════════════════════════════════════════════

class EmployeePayrollScreen extends ConsumerStatefulWidget {
  final int employeeId;
  final String employeeName;
  final _Period period;
  const EmployeePayrollScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.period,
  });

  @override
  ConsumerState<EmployeePayrollScreen> createState() => _EmployeePayrollScreenState();
}

class _EmployeePayrollScreenState extends ConsumerState<EmployeePayrollScreen> {
  late _Period _period;

  @override
  void initState() {
    super.initState();
    _period = widget.period;
  }

  void _invalidate() {
    ref.invalidate(_employeePayrollProvider((id: widget.employeeId, period: _period)));
    ref.invalidate(_payrollListProvider(_period));
  }

  @override
  Widget build(BuildContext context) {
    final key  = (id: widget.employeeId, period: _period);
    final data = ref.watch(_employeePayrollProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeName),
        actions: [
          TextButton.icon(
            onPressed: () => _pickPeriod(context),
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(_period.label, style: const TextStyle(fontSize: 12)),
          ),
          if (data.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Print / PDF',
              onPressed: () => _printPdf(data.value!),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordPayment(context),
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => _EmployeeDetail(
          data: d,
          period: _period,
          onDelete: _deletePayment,
          onEdit:   (p) => _showEditPayment(context, p),
        ),
      ),
    );
  }

  Future<void> _pickPeriod(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PeriodDialog(
        current: _period,
        onSelected: (p) => setState(() => _period = p),
      ),
    );
  }

  Future<void> _showRecordPayment(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordPaymentDialog(employeeId: widget.employeeId),
    );
    if (result == true && mounted) _invalidate();
  }

  Future<void> _showEditPayment(BuildContext context, Map<String, dynamic> payment) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordPaymentDialog(
        employeeId: widget.employeeId,
        existing: payment,
      ),
    );
    if (result == true && mounted) _invalidate();
  }

  Future<void> _deletePayment(int paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('This payment will be permanently removed. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/api/payroll/advances/$paymentId');
      _invalidate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── PDF generation ──────────────────────────────────────────────────────────

  Future<void> _printPdf(Map<String, dynamic> data) async {
    final companyName = await AuthStorage.getTenantName() ?? 'Your Company';
    final generated   = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();

    final wageType  = data['wageType']      as String? ?? 'DAILY';
    final wageRate  = (data['wageRate']     as num?)?.toDouble() ?? 0;
    final present   = data['presentCount']  as int? ?? 0;
    final half      = data['halfDayCount']  as int? ?? 0;
    final absent    = data['absentCount']   as int? ?? 0;
    final leave     = data['leaveCount']    as int? ?? 0;
    final earned    = (data['earnedAmount']   as num?)?.toDouble() ?? 0;
    final paid      = (data['advancesPaid']   as num?)?.toDouble() ?? 0;
    final opening   = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final closing   = (data['closingBalance'] as num?)?.toDouble()
                   ?? (data['balanceOwed']   as num?)?.toDouble() ?? 0;
    final payments  = List<Map<String, dynamic>>.from(data['advances'] as List? ?? []);
    final designation = (data['designation'] as String?)?.trim() ?? '';
    final rateLabel   = wageType == 'MONTHLY'
        ? '${fmtCurr(wageRate)}/month' : '${fmtCurr(wageRate)}/day';

    final pos = _position(closing);
    final hasOpening = opening.abs() > 0.005;

    // ── PDF helpers ───────────────────────────────────────────────────────────

    pw.Widget ht(String t, {double sz = 8, bool b = false, PdfColor? c}) =>
        pw.Text(t, style: pw.TextStyle(
            font: b ? bold : regular, fontSize: sz,
            fontWeight: b ? pw.FontWeight.bold : null, color: c));

    pw.Widget cell(String t,
        {bool b = false,
         pw.Alignment align = pw.Alignment.centerLeft,
         double padH = 6,
         double padV = 4}) =>
        pw.Container(
          padding: pw.EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: pw.Align(
            alignment: align,
            child: pw.Text(t,
                style: pw.TextStyle(
                    font: b ? bold : regular,
                    fontSize: 7.5,
                    fontWeight: b ? pw.FontWeight.bold : null)),
          ),
        );

    pw.Widget sectionTitle(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: ht(t, sz: 7.5, b: true, c: PdfColors.blueGrey700),
        );

    pw.Widget dividerLine() =>
        pw.Divider(thickness: 0.5, color: PdfColors.blueGrey200);

    // Shared table border
    final tableBorder =
        pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5));

    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
      // ── Repeated header on every page ──────────────────────────────────────
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                ht(companyName, sz: 13, b: true, c: PdfColors.blueGrey800),
                pw.SizedBox(height: 2),
                ht('PAYROLL STATEMENT', sz: 9, b: true, c: PdfColors.blueGrey600),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                if (ctx.pageNumber > 1)
                  ht('(continued)', sz: 7, c: PdfColors.grey500),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.8, color: PdfColors.blueGrey300),
          pw.SizedBox(height: 6),
          // Employee + Period (only on first page)
          if (ctx.pageNumber == 1) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    ht(widget.employeeName, sz: 11, b: true),
                    if (designation.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      ht(designation, sz: 8, c: PdfColors.grey600),
                    ],
                    pw.SizedBox(height: 1),
                    ht('Wage: $rateLabel', sz: 8, c: PdfColors.grey700),
                  ],
                )),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  ht('Period', sz: 7, c: PdfColors.grey500),
                  pw.SizedBox(height: 2),
                  ht('${_dfmt.format(_period.from)}  –  ${_dfmt.format(_period.to)}',
                      sz: 8, b: true),
                ]),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ],
      ),
      // ── Footer on every page ───────────────────────────────────────────────
      footer: (ctx) => pw.Column(children: [
        pw.Divider(thickness: 0.3, color: PdfColors.grey300),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            ht('Generated: $generated', sz: 7, c: PdfColors.grey500),
            ht('Page ${ctx.pageNumber} of ${ctx.pagesCount}', sz: 7, c: PdfColors.grey500),
            ht(companyName, sz: 7, c: PdfColors.grey500),
          ],
        ),
      ]),
      // ── Page content ───────────────────────────────────────────────────────
      build: (ctx) => [
        // ATTENDANCE
        sectionTitle('ATTENDANCE'),
        pw.Container(
          decoration: tableBorder,
          child: pw.Table(
            border: pw.TableBorder.symmetric(
                inside: const pw.BorderSide(color: PdfColors.blueGrey100, width: 0.4)),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: ['Present', 'Half Day', 'Absent', 'Leave']
                    .map((h) => cell(h, b: true, align: pw.Alignment.center)).toList(),
              ),
              pw.TableRow(children: [
                cell('$present', align: pw.Alignment.center),
                cell('$half',    align: pw.Alignment.center),
                cell('$absent',  align: pw.Alignment.center),
                cell('$leave',   align: pw.Alignment.center),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // EARNINGS
        sectionTitle('EARNINGS'),
        pw.Container(
          decoration: tableBorder,
          child: pw.Column(children: [
            if (wageType == 'DAILY') ...[
              pw.Row(children: [
                pw.Expanded(child: cell('Basic Wage  ($present days × ${fmtCurr(wageRate)})')),
                pw.SizedBox(width: 80,
                    child: cell(fmtCurr(present * wageRate),
                        align: pw.Alignment.centerRight)),
              ]),
              if (half > 0)
                pw.Row(children: [
                  pw.Expanded(child: cell('Half Day  ($half × ${fmtCurr(wageRate * 0.5)})')),
                  pw.SizedBox(width: 80,
                      child: cell(fmtCurr(half * wageRate * 0.5),
                          align: pw.Alignment.centerRight)),
                ]),
            ] else ...[
              pw.Row(children: [
                pw.Expanded(child: cell(
                    'Monthly Wage  ($present present + $half half day'
                    '${leave > 0 ? ' + $leave paid leave' : ''})')),
                pw.SizedBox(width: 80,
                    child: cell(fmtCurr(earned), align: pw.Alignment.centerRight)),
              ]),
            ],
            dividerLine(),
            pw.Container(
              color: PdfColors.blue50,
              child: pw.Row(children: [
                pw.Expanded(child: cell('Total Earned', b: true)),
                pw.SizedBox(width: 80,
                    child: cell(fmtCurr(earned), b: true, align: pw.Alignment.centerRight)),
              ]),
            ),
          ]),
        ),
        pw.SizedBox(height: 10),

        // PAYMENTS
        sectionTitle('PAYMENTS IN THIS PERIOD'),
        if (payments.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: tableBorder,
            child: ht('No payments recorded in this period.', sz: 8, c: PdfColors.grey500),
          )
        else
          pw.Container(
            decoration: tableBorder,
            child: pw.Column(children: [
              pw.Container(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                child: pw.Row(children: [
                  pw.SizedBox(width: 72,  child: cell('Date',   b: true)),
                  pw.SizedBox(width: 80,  child: cell('Method', b: true)),
                  pw.Expanded(            child: cell('Notes',  b: true)),
                  pw.SizedBox(width: 72,
                      child: cell('Amount', b: true, align: pw.Alignment.centerRight)),
                ]),
              ),
              ...payments.map((p) {
                final date   = _dfmt.format(DateTime.parse(p['paymentDate'] as String));
                final method = _methodLabel(p['paymentMethod'] as String?);
                final notes  = (p['notes'] as String?)?.trim() ?? '';
                final amount = (p['amount'] as num?)?.toDouble() ?? 0;
                return pw.Row(children: [
                  pw.SizedBox(width: 72,  child: cell(date)),
                  pw.SizedBox(width: 80,  child: cell(method)),
                  pw.Expanded(            child: cell(notes)),
                  pw.SizedBox(width: 72,
                      child: cell(fmtCurr(amount), align: pw.Alignment.centerRight)),
                ]);
              }),
              dividerLine(),
              pw.Container(
                color: PdfColors.blueGrey50,
                child: pw.Row(children: [
                  pw.Expanded(child: cell('Total Paid', b: true)),
                  pw.SizedBox(width: 72,
                      child: cell(fmtCurr(paid), b: true, align: pw.Alignment.centerRight)),
                ]),
              ),
            ]),
          ),
        pw.SizedBox(height: 10),

        // CURRENT POSITION
        sectionTitle('CURRENT POSITION'),
        pw.Container(
          decoration: tableBorder,
          child: pw.Column(children: [
            if (hasOpening)
              pw.Row(children: [
                pw.Expanded(child: cell('Opening Balance (brought forward)')),
                pw.SizedBox(width: 90,
                    child: cell(
                      opening >= 0 ? fmtCurr(opening) : '− ${fmtCurr(opening.abs())}',
                      align: pw.Alignment.centerRight,
                    )),
              ]),
            pw.Row(children: [
              pw.Expanded(child: cell('+ Earned This Period')),
              pw.SizedBox(width: 90,
                  child: cell(fmtCurr(earned), align: pw.Alignment.centerRight)),
            ]),
            pw.Row(children: [
              pw.Expanded(child: cell('− Paid This Period')),
              pw.SizedBox(width: 90,
                  child: cell(fmtCurr(paid), align: pw.Alignment.centerRight)),
            ]),
            dividerLine(),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              color: pos == _Position.pending
                  ? PdfColors.green50
                  : pos == _Position.advance
                      ? PdfColors.orange50
                      : PdfColors.grey100,
              child: pw.Row(children: [
                pw.Expanded(
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        ht(
                          pos == _Position.pending  ? 'Pending'
                            : pos == _Position.advance ? 'Advance'
                            : 'Settled',
                          sz: 10, b: true,
                          c: pos == _Position.pending
                              ? PdfColors.green800
                              : pos == _Position.advance
                                  ? PdfColors.orange800
                                  : PdfColors.grey600,
                        ),
                        pw.SizedBox(height: 2),
                        ht(
                          pos == _Position.pending
                              ? '${fmtCurr(closing)} is still payable to this employee.'
                              : pos == _Position.advance
                                  ? 'Employee has received ${fmtCurr(closing.abs())} more than earned wages.'
                                  : 'Account is settled. Nothing is pending.',
                          sz: 7.5,
                          c: PdfColors.grey600,
                        ),
                      ]),
                ),
                ht(
                  pos == _Position.settled ? '₹0' : fmtCurr(closing.abs()),
                  sz: 13, b: true,
                  c: pos == _Position.pending
                      ? PdfColors.green800
                      : pos == _Position.advance
                          ? PdfColors.orange800
                          : PdfColors.grey600,
                ),
              ]),
            ),
          ]),
        ),

        pw.SizedBox(height: 8),
        pw.Text(
          'Note: Leave days are not deducted from monthly wages (paid leave).',
          style: pw.TextStyle(font: regular, fontSize: 7, color: PdfColors.grey400),
        ),
      ],
    ));

    final bytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'Payroll_${widget.employeeName.replaceAll(' ', '_')}_${_period.label.replaceAll(' ', '_').replaceAll('–', '-')}.pdf',
    );
  }
}

// ── Employee detail body ──────────────────────────────────────────────────────

class _EmployeeDetail extends StatelessWidget {
  final Map<String, dynamic> data;
  final _Period period;
  final void Function(int id) onDelete;
  final void Function(Map<String, dynamic> payment) onEdit;
  const _EmployeeDetail({
    required this.data, required this.period,
    required this.onDelete, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final wageType  = data['wageType']      as String? ?? 'DAILY';
    final wageRate  = (data['wageRate']     as num?)?.toDouble() ?? 0;
    final present   = data['presentCount']  as int? ?? 0;
    final half      = data['halfDayCount']  as int? ?? 0;
    final absent    = data['absentCount']   as int? ?? 0;
    final leave     = data['leaveCount']    as int? ?? 0;
    final earned    = (data['earnedAmount']   as num?)?.toDouble() ?? 0;
    final paid      = (data['advancesPaid']   as num?)?.toDouble() ?? 0;
    final opening   = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final closing   = (data['closingBalance'] as num?)?.toDouble()
                   ?? (data['balanceOwed']   as num?)?.toDouble() ?? 0;
    final payments  = List<Map<String, dynamic>>.from(data['advances'] as List? ?? []);
    final rateLabel = wageType == 'MONTHLY'
        ? '${fmtCurr(wageRate)}/month' : '${fmtCurr(wageRate)}/day';
    final pos       = _position(closing);
    final posColor  = _positionColor(pos);
    final hasOpening = opening.abs() > 0.005;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        // ── Attendance ────────────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Wage Rate', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Text(rateLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Text('Period: ${period.label}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
                const SizedBox(height: 10),
                const Text('Attendance This Period',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  _AttTile('Present',  '$present', Colors.green),
                  _AttTile('Half Day', '$half',    Colors.orange),
                  _AttTile('Absent',   '$absent',  Colors.red),
                  _AttTile('Leave',    '$leave',   Colors.blue),
                ]),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Current Position (bank statement) ─────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Position',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                if (hasOpening)
                  _StmtRow('Opening Balance', fmtCurr(opening.abs()),
                      opening >= 0 ? Colors.grey[700]! : Colors.orange[700]!,
                      sign: opening < 0 ? '−' : null),
                _StmtRow('+ Earned This Period', fmtCurr(earned), Colors.blue),
                if (paid > 0)
                  _StmtRow('− Paid This Period', fmtCurr(paid), Colors.grey[600]!),
                const Divider(height: 14),
                // Final status row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: posColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: posColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pos == _Position.settled
                              ? 'Settled'
                              : pos == _Position.pending
                                  ? '${fmtCurr(closing)} Pending'
                                  : '${fmtCurr(closing.abs())} Advance',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15, color: posColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _positionExplanation(pos, closing),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    )),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(
                  'Balance carries across all months, not just this period.',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Payments ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text('Payments This Period',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.grey[600], letterSpacing: 0.4)),
        ),

        if (payments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text('No payments recorded this period.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
            ),
          )
        else
          ...payments.map((p) {
            final id     = (p['id'] as num).toInt();
            final date   = _dfmt.format(DateTime.parse(p['paymentDate'] as String));
            final amount = (p['amount'] as num?)?.toDouble() ?? 0;
            final method = _methodLabel(p['paymentMethod'] as String?);
            final notes  = (p['notes'] as String?)?.trim() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.currency_rupee, size: 18, color: Colors.green),
                ),
                title: Row(children: [
                  Text(fmtCurr(amount),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.25))),
                    child: Text(method,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ),
                ]),
                subtitle: Text(
                  [date, if (notes.isNotEmpty) notes].join(' · '),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                    onPressed: () => onEdit(p),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => onDelete(id),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete',
                  ),
                ]),
              ),
            );
          }),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _AttTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AttTile(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]);
}

class _StmtRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final String? sign;
  const _StmtRow(this.label, this.value, this.color, {this.sign});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          Text(sign != null ? '$sign $value' : value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ]),
      );
}

// ── Record / Edit Payment Dialog ──────────────────────────────────────────────

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final int employeeId;
  final Map<String, dynamic>? existing;
  const _RecordPaymentDialog({required this.employeeId, this.existing});

  @override
  ConsumerState<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  late DateTime _date;
  late String   _method;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _date   = DateTime.parse(ex['paymentDate'] as String);
      _method = (ex['paymentMethod'] as String?) ?? 'CASH';
      _amountCtrl.text = ((ex['amount'] as num?)?.toDouble() ?? 0).toString();
      _notesCtrl.text  = (ex['notes']  as String?) ?? '';
    } else {
      _date   = DateTime.now();
      _method = 'CASH';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'employeeId':    widget.employeeId,
        'date':          DateFormat('yyyy-MM-dd').format(_date),
        'amount':        amt,
        'paymentMethod': _method,
        'notes':         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };
      if (_isEdit) {
        final id = (widget.existing!['id'] as num).toInt();
        await ref.read(apiClientProvider).put('/api/payroll/advances/$id', data: body);
      } else {
        await ref.read(apiClientProvider).post('/api/payroll/advances', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Payment' : 'Record Payment'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context, initialDate: _date,
                firstDate: DateTime(2020), lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_dfmt.format(_date), style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Payment method
          DropdownButtonFormField<String>(
            value: _method,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(),
            ),
            items: _paymentMethods
                .map((m) => DropdownMenuItem(value: m, child: Text(_methodLabels[m]!)))
                .toList(),
            onChanged: (v) => setState(() => _method = v ?? 'CASH'),
          ),
          const SizedBox(height: 12),

          // Notes / reference
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference / Notes (optional)',
              hintText: 'e.g. UPI ref, cheque no.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
