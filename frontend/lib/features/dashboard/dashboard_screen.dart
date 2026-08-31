import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final _dashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/dashboard');
  return Map<String, dynamic>.from(res.data as Map);
});

final _numFmt = NumberFormat('#,##,##0.##', 'en_IN');
final _currFmt = NumberFormat('#,##,##0.00', 'en_IN');

// ── screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardProvider);
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

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
        data: (d) => _DashboardBody(data: d, monthName: monthName),
      ),
    );
  }
}

// ── body ──────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String monthName;
  const _DashboardBody({required this.data, required this.monthName});

  @override
  Widget build(BuildContext context) {
    final todayTrips = data['todayTripCount'] as int? ?? 0;
    final todayBrass = (data['todayTotalBrass'] as num?)?.toDouble() ?? 0;
    final dieselBalance =
        (data['dieselBalanceLiters'] as num?)?.toDouble() ?? 0;
    final dieselReceived =
        (data['dieselTotalReceived'] as num?)?.toDouble() ?? 0;
    final dieselUsed = (data['dieselTotalUsed'] as num?)?.toDouble() ?? 0;
    final machineHours =
        (data['monthlyMachineHours'] as num?)?.toDouble() ?? 0;
    final invoiceTotal =
        (data['monthlyInvoiceTotal'] as num?)?.toDouble() ?? 0;
    final invoiceCount = data['monthlyInvoiceCount'] as int? ?? 0;
    final payTotal = (data['monthlyPaymentsTotal'] as num?)?.toDouble() ?? 0;
    final tripSummary =
        List<Map<String, dynamic>>.from(data['monthlyTripSummary'] as List? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Today ──────────────────────────────────────────────────────────
          Text('Today',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.swap_horiz,
                  label: 'Trips Today',
                  value: '$todayTrips',
                  sub: todayBrass > 0
                      ? '${_numFmt.format(todayBrass)} Brass'
                      : 'No brass recorded',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DieselCard(
                  balance: dieselBalance,
                  received: dieselReceived,
                  used: dieselUsed,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── This Month ─────────────────────────────────────────────────────
          Text(monthName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.construction,
                  label: 'Machine Hours',
                  value: '${_numFmt.format(machineHours)} hrs',
                  sub: 'JCB / Comosko work',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.receipt_long,
                  label: 'Invoices',
                  value: '₹${_currFmt.format(invoiceTotal)}',
                  sub: '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'} issued',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.payments,
                  label: 'Payments Received',
                  value: '₹${_currFmt.format(payTotal)}',
                  sub: 'from vendor',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          // ── Monthly Trip Summary ───────────────────────────────────────────
          if (tripSummary.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Material Summary — $monthName',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _TripSummaryTable(rows: tripSummary),
          ],
        ],
      ),
    );
  }
}

// ── metric card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(sub,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_gas_station, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text('Diesel Stock',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Text('${_numFmt.format(balance)} L',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.arrow_downward, size: 12, color: Colors.green[700]),
                Text(' ${_numFmt.format(received)} in',
                    style: TextStyle(fontSize: 11, color: Colors.green[700])),
                const SizedBox(width: 8),
                Icon(Icons.arrow_upward, size: 12, color: Colors.red[700]),
                Text(' ${_numFmt.format(used)} out',
                    style: TextStyle(fontSize: 11, color: Colors.red[700])),
              ],
            ),
            if (isLow && balance > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Low stock — refill soon',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600)),
              ),
            ],
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
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: _TableHeader('Material')),
                  Expanded(
                      child: _TableHeader('Trips', right: true)),
                  Expanded(
                      child: _TableHeader('Brass', right: true)),
                ],
              ),
            ),
            // Rows
            ...rows.map((r) {
              final name = r['materialName'] as String? ?? '—';
              final size = r['sizeLabel'] as String? ?? '';
              final trips = r['tripCount'] as int? ?? 0;
              final brass = (r['totalBrass'] as num?)?.toDouble() ?? 0;
              return _TableRow(
                label: size.isNotEmpty ? '$name ($size)' : name,
                trips: '$trips',
                brass: _numFmt.format(brass),
              );
            }),
            // Grand total
            Container(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: _TableRow(
                label: 'Grand Total',
                trips: '',
                brass: _numFmt.format(grandTotal),
                bold: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final bool right;
  const _TableHeader(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _TableRow extends StatelessWidget {
  final String label;
  final String trips;
  final String brass;
  final bool bold;
  const _TableRow(
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Text(label,
                    style: TextStyle(
                        fontWeight:
                            bold ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
              )),
          Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Text(trips,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight:
                            bold ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
              )),
          Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
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
