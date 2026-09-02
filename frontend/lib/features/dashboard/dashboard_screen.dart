import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final _dashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(selectedSiteIdProvider); // re-fetch when site changes
  final res = await ref.read(apiClientProvider).get('/api/dashboard');
  return Map<String, dynamic>.from(res.data as Map);
});


// ── screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardProvider);
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final today = DateFormat('d MMM yyyy').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_dashboardProvider),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => _DashboardBody(data: d, monthName: monthName, today: today),
      ),
    );
  }
}

// ── body ──────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String monthName;
  final String today;
  const _DashboardBody({required this.data, required this.monthName, required this.today});

  @override
  Widget build(BuildContext context) {
    // Today
    final todayTrips     = data['todayTripCount'] as int? ?? 0;
    final todayBrass     = (data['todayTotalBrass'] as num?)?.toDouble() ?? 0;
    final attPresent     = data['todayAttendancePresent'] as int? ?? 0;
    final attTotal       = data['todayAttendanceTotal'] as int? ?? 0;
    final todayMachine   = (data['todayMachineHours'] as num?)?.toDouble() ?? 0;
    final todayDabar     = (data['todayDabarBrass'] as num?)?.toDouble() ?? 0;

    // Today's financial
    final todayInvTotal  = (data['todayInvoiceTotal'] as num?)?.toDouble() ?? 0;
    final todayInvCount  = data['todayInvoiceCount'] as int? ?? 0;
    final todayColTotal  = (data['todayCollectionsTotal'] as num?)?.toDouble() ?? 0;
    final todayColCount  = data['todayCollectionsCount'] as int? ?? 0;

    // Diesel
    final dieselBalance  = (data['dieselBalanceLiters'] as num?)?.toDouble() ?? 0;
    final dieselReceived = (data['dieselTotalReceived'] as num?)?.toDouble() ?? 0;
    final dieselUsed     = (data['dieselTotalUsed'] as num?)?.toDouble() ?? 0;

    // Financial position
    final totalInv       = (data['totalInvoiced'] as num?)?.toDouble() ?? 0;
    final totalPaid      = (data['totalPaymentsLinked'] as num?)?.toDouble() ?? 0;
    final outstanding    = (data['totalOutstanding'] as num?)?.toDouble() ?? 0;

    // This month
    final monthMachine   = (data['monthlyMachineHours'] as num?)?.toDouble() ?? 0;
    final monthInvTotal  = (data['monthlyInvoiceTotal'] as num?)?.toDouble() ?? 0;
    final monthInvCount  = data['monthlyInvoiceCount'] as int? ?? 0;
    final monthPayTotal  = (data['monthlyPaymentsTotal'] as num?)?.toDouble() ?? 0;

    // Receivable parties
    final receivables = List<Map<String, dynamic>>.from(
        data['receivableParties'] as List? ?? []);

    // Material summary
    final tripSummary = List<Map<String, dynamic>>.from(
        data['monthlyTripSummary'] as List? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Quick Actions ───────────────────────────────────────────────────
          _QuickActions(),
          const SizedBox(height: 16),

          // ── Today ──────────────────────────────────────────────────────────
          _SectionLabel('Today — $today'),
          const SizedBox(height: 8),
          // Row 1: Trips + Attendance
          Row(
            children: [
              Expanded(
                child: _ClickCard(
                  icon: Icons.swap_horiz,
                  label: 'Trips Today',
                  value: '$todayTrips',
                  sub: todayBrass > 0
                      ? '${numFmt.format(todayBrass)} Brass'
                      : 'No brass recorded',
                  color: Colors.blue,
                  route: '/trips',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClickCard(
                  icon: Icons.people,
                  label: 'Attendance',
                  value: '$attPresent / $attTotal',
                  sub: attTotal == 0
                      ? 'No employees'
                      : attPresent == attTotal
                          ? 'All present'
                          : '${attTotal - attPresent} absent/unmarked',
                  color: attPresent == attTotal && attTotal > 0
                      ? Colors.green
                      : Colors.orange,
                  route: '/attendance',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Diesel + Machine hours + Dabar
          Row(
            children: [
              Expanded(child: _DieselCard(
                balance: dieselBalance,
                received: dieselReceived,
                used: dieselUsed,
              )),
              const SizedBox(width: 12),
              Expanded(
                child: _ClickCard(
                  icon: Icons.construction,
                  label: 'Machine Hrs',
                  value: '${numFmt.format(todayMachine)} hrs',
                  sub: todayMachine > 0 ? 'Today' : 'None today',
                  color: Colors.orange,
                  route: '/machine-work',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClickCard(
                  icon: Icons.landscape,
                  label: 'Dabar Brass',
                  value: numFmt.format(todayDabar),
                  sub: todayDabar > 0 ? 'Brass today' : 'None today',
                  color: Colors.brown,
                  route: '/dabar',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          // Row 3: Today's Invoices + Today's Collections
          Row(
            children: [
              Expanded(
                child: _ClickCard(
                  icon: Icons.receipt_long,
                  label: "Today's Sales",
                  value: fmtCurr(todayInvTotal),
                  sub: '$todayInvCount invoice${todayInvCount == 1 ? '' : 's'} today',
                  color: Colors.purple,
                  route: '/invoices',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClickCard(
                  icon: Icons.payments,
                  label: "Today's Collections",
                  value: fmtCurr(todayColTotal),
                  sub: '$todayColCount payment${todayColCount == 1 ? '' : 's'} today',
                  color: Colors.green,
                  route: '/party-payments',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Financial Position ──────────────────────────────────────────────
          _SectionLabel('Financial Position'),
          const SizedBox(height: 8),
          _FinancialCard(
            totalInvoiced: totalInv,
            totalPaid: totalPaid,
            outstanding: outstanding,
            onInvoices: () => context.go('/invoices'),
            onPayments: () => context.go('/party-payments'),
          ),

          // ── Receivables ─────────────────────────────────────────────────────
          if (receivables.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('Outstanding Receivables'),
            const SizedBox(height: 8),
            _ReceivablesWidget(rows: receivables),
          ],

          const SizedBox(height: 20),

          // ── This Month ─────────────────────────────────────────────────────
          _SectionLabel(monthName),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ClickCard(
                  icon: Icons.construction,
                  label: 'Machine Hours',
                  value: '${numFmt.format(monthMachine)} hrs',
                  sub: 'This month',
                  color: Colors.orange,
                  route: '/machine-work',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClickCard(
                  icon: Icons.receipt_long,
                  label: 'Invoices',
                  value: fmtCurr(monthInvTotal),
                  sub: '$monthInvCount invoice${monthInvCount == 1 ? '' : 's'}',
                  color: Colors.purple,
                  route: '/invoices',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClickCard(
                  icon: Icons.payments,
                  label: 'Payments',
                  value: fmtCurr(monthPayTotal),
                  sub: 'Received this month',
                  color: Colors.green,
                  route: '/party-payments',
                ),
              ),
            ],
          ),

          // ── Material Summary ───────────────────────────────────────────────
          if (tripSummary.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('Material Summary — $monthName'),
            const SizedBox(height: 8),
            _TripSummaryTable(rows: tripSummary),
          ],
        ],
      ),
    );
  }
}

// ── quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QBtn(icon: Icons.receipt_long, label: '+ Invoice', route: '/invoices'),
                _QBtn(icon: Icons.swap_horiz, label: '+ Trip', route: '/trips'),
                _QBtn(icon: Icons.local_gas_station, label: '+ Diesel', route: '/diesel'),
                _QBtn(icon: Icons.payments, label: '+ Payment', route: '/party-payments'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _QBtn({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go(route),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ── receivables widget ────────────────────────────────────────────────────────

class _ReceivablesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _ReceivablesWidget({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _TH('Party Name')),
                Expanded(flex: 2, child: _TH('Outstanding', right: true)),
                SizedBox(width: 80, child: _TH('', right: true)),
              ],
            ),
          ),
          ...rows.map((r) {
            final name = r['vendorName'] as String? ?? '—';
            final amt = (r['outstandingBalance'] as num?)?.toDouble() ?? 0;
            return Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(name, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        fmtCurr(amt),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: () => context.go('/ledger'),
                        child: const Text('Ledger', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold));
}

// ── clickable metric card ─────────────────────────────────────────────────────

class _ClickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final String route;
  const _ClickCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}

// ── diesel card ───────────────────────────────────────────────────────────────

class _DieselCard extends StatelessWidget {
  final double balance;
  final double received;
  final double used;
  const _DieselCard(
      {required this.balance, required this.received, required this.used});

  @override
  Widget build(BuildContext context) {
    final isLow = balance < 100;
    final color = balance <= 0
        ? Colors.red
        : isLow
            ? Colors.orange
            : Colors.teal;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/diesel'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.local_gas_station, color: color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text('Diesel Stock',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 10),
              Text('${numFmt.format(balance)} L',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.arrow_downward, size: 11, color: Colors.green[700]),
                  Text(' ${numFmt.format(received)} in',
                      style: TextStyle(fontSize: 11, color: Colors.green[700])),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_upward, size: 11, color: Colors.red[700]),
                  Text(' ${numFmt.format(used)} out',
                      style: TextStyle(fontSize: 11, color: Colors.red[700])),
                ],
              ),
              if (isLow && balance > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Low — refill soon',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── financial position card ───────────────────────────────────────────────────

class _FinancialCard extends StatelessWidget {
  final double totalInvoiced;
  final double totalPaid;
  final double outstanding;
  final VoidCallback onInvoices;
  final VoidCallback onPayments;
  const _FinancialCard({
    required this.totalInvoiced,
    required this.totalPaid,
    required this.outstanding,
    required this.onInvoices,
    required this.onPayments,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final outColor = outstanding > 0 ? Colors.red[700]! : Colors.green[700]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outstanding — prominent
            Center(
              child: Column(
                children: [
                  Text('Outstanding Balance',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(fmtCurr(outstanding),
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: outColor)),
                  if (outstanding <= 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('All invoices paid',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Total invoiced + paid row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onInvoices,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Invoiced',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text(fmtCurr(totalInvoiced),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onPayments,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Paid',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text(fmtCurr(totalPaid),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── trip summary table ────────────────────────────────────────────────────────

class _TripSummaryTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _TripSummaryTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double grandTotal = 0;
    for (final r in rows) {
      grandTotal += (r['totalBrass'] as num?)?.toDouble() ?? 0;
    }

    return Card(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _TH('Material')),
                Expanded(child: _TH('Trips', right: true)),
                Expanded(child: _TH('Brass', right: true)),
              ],
            ),
          ),
          ...rows.map((r) {
            final name = r['materialName'] as String? ?? '—';
            final size = r['sizeLabel'] as String? ?? '';
            final trips = r['tripCount'] as int? ?? 0;
            final brass = (r['totalBrass'] as num?)?.toDouble() ?? 0;
            return _TR(
              label: size.isNotEmpty ? '$name ($size)' : name,
              trips: '$trips',
              brass: numFmt.format(brass),
            );
          }),
          Container(
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: _TR(
              label: 'Grand Total',
              trips: '',
              brass: numFmt.format(grandTotal),
              bold: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _TR extends StatelessWidget {
  final String label;
  final String trips;
  final String brass;
  final bool bold;
  const _TR(
      {required this.label,
      required this.trips,
      required this.brass,
      this.bold = false});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              flex: 3,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(label,
                    style: TextStyle(
                        fontWeight:
                            bold ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
              )),
          Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(trips,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight:
                            bold ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
              )),
          Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(brass,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight:
                            bold ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        color: bold
                            ? Theme.of(context).colorScheme.primary
                            : null)),
              )),
        ],
      );
}
