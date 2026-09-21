import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/site_provider.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final _roleProvider = FutureProvider.autoDispose<String?>((ref) async {
  return AuthStorage.getRole();
});

final _dashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(selectedSiteIdProvider);
  final res = await ref.read(apiClientProvider).get('/api/dashboard');
  return Map<String, dynamic>.from(res.data as Map);
});

final _siteStaffDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(selectedSiteIdProvider);
  final res =
      await ref.read(apiClientProvider).get('/api/dashboard/site-staff');
  return Map<String, dynamic>.from(res.data as Map);
});

// ── screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(_roleProvider);

    return roleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (role) {
        // null means role not stored yet (pre-login state shouldn't reach
        // here due to router redirect, but guard defensively).
        if (role == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return role == 'SITE_STAFF'
            ? const _SiteStaffDashboardScreen()
            : const _AdminDashboardScreen();
      },
    );
  }
}

// ── admin / accountant dashboard (unchanged full version) ─────────────────────

class _AdminDashboardScreen extends ConsumerWidget {
  const _AdminDashboardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardProvider);
    final now = DateTime.now();
    final today = DateFormat('d MMM yyyy').format(now);
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
        error: (e, _) {
          // 403 means the stored token is for a role that can't reach
          // /api/dashboard (e.g. SITE_STAFF after a frontend cache hit
          // against a newly-deployed backend). Clear storage and re-login.
          final is403 = e.toString().contains('403');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  is403 ? Icons.lock_outline : Icons.error_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  is403
                      ? 'Session outdated — please log in again.'
                      : 'Could not load dashboard.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Back to Login'),
                  onPressed: () async {
                    await AuthStorage.clear();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          );
        },
        data: (d) =>
            _DashboardBody(data: d, today: today, monthName: monthName),
      ),
    );
  }
}

// ── site staff dashboard ──────────────────────────────────────────────────────

class _SiteStaffDashboardScreen extends ConsumerWidget {
  const _SiteStaffDashboardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_siteStaffDashboardProvider);
    final today = DateFormat('d MMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_siteStaffDashboardProvider),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => _SiteStaffBody(data: d, today: today),
      ),
    );
  }
}

class _SiteStaffBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String today;
  const _SiteStaffBody({required this.data, required this.today});

  @override
  Widget build(BuildContext context) {
    final tripCount = data['todayTripCount'] as int? ?? 0;
    final totalBrass =
        (data['todayTotalBrass'] as num?)?.toDouble() ?? 0;
    final diesel =
        (data['dieselBalanceLiters'] as num?)?.toDouble() ?? 0;
    final machineHrs =
        (data['todayMachineHours'] as num?)?.toDouble() ?? 0;
    final ratePending =
        (data['ratePendingMachineWorkCount'] as num?)?.toInt() ?? 0;
    final unbilled =
        (data['unbilledTripsCount'] as num?)?.toInt() ?? 0;
    final recentTrips = List<Map<String, dynamic>>.from(
        data['recentTrips'] as List? ?? []);

    final attention =
        <({IconData icon, Color color, String text, String route})>[];
    if (unbilled > 0) {
      attention.add((
        icon: Icons.swap_horiz,
        color: Colors.blue,
        text: '$unbilled ${unbilled == 1 ? 'trip' : 'trips'} not yet invoiced',
        route: '/trips',
      ));
    }
    if (ratePending > 0) {
      attention.add((
        icon: Icons.construction,
        color: Colors.deepOrange,
        text:
            '$ratePending machine work ${ratePending == 1 ? 'entry needs' : 'entries need'} a rate set',
        route: '/machine-work',
      ));
    }
    if (diesel < 100) {
      attention.add((
        icon: Icons.local_gas_station,
        color: Colors.teal,
        text:
            'Diesel low — ${numFmt.format(diesel)} L remaining',
        route: '/diesel',
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions — operations only (no invoices/payments)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
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
                      _QBtn(
                          icon: Icons.swap_horiz,
                          label: '+ Trip',
                          route: '/trips'),
                      _QBtn(
                          icon: Icons.local_gas_station,
                          label: '+ Diesel',
                          route: '/diesel'),
                      _QBtn(
                          icon: Icons.construction,
                          label: '+ Machine Work',
                          route: '/machine-work'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Today's summary
          Text(
            'Today — $today',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TodayTile(
                  icon: Icons.swap_horiz,
                  color: Colors.blue,
                  label: 'Trips',
                  value: '$tripCount',
                  sub: totalBrass > 0
                      ? '${numFmt.format(totalBrass)} Brass'
                      : 'No brass',
                  route: '/trips',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TodayTile(
                  icon: Icons.local_gas_station,
                  color: diesel < 100 ? Colors.orange : Colors.teal,
                  label: 'Diesel',
                  value: '${numFmt.format(diesel)} L',
                  sub: diesel < 100 ? 'Low — refill soon' : 'In stock',
                  route: '/diesel',
                ),
              ),
            ],
          ),
          if (machineHrs > 0) ...[
            const SizedBox(height: 10),
            _TodayTile(
              icon: Icons.construction,
              color: Colors.orange,
              label: 'Machine Work Today',
              value: '${numFmt.format(machineHrs)} hrs',
              sub: 'recorded today',
              route: '/machine-work',
            ),
          ],

          // Needs Attention
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 20),
            _NeedsAttention(items: attention),
          ],

          // Recent trips
          if (recentTrips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              "Today's Trips",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: recentTrips.asMap().entries.map((e) {
                  final t = e.value;
                  final mat = t['materialName'] as String? ?? '—';
                  final qty =
                      (t['quantity'] as num?)?.toDouble() ?? 0;
                  final party = t['partyName'] as String? ?? '—';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.swap_horiz,
                        size: 18, color: Colors.blue),
                    title: Text(mat,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(party,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                    trailing: Text(
                      '${numFmt.format(qty)} Brass',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── body ──────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String today;
  final String monthName;
  const _DashboardBody(
      {required this.data, required this.today, required this.monthName});

  @override
  Widget build(BuildContext context) {
    final todayTrips = data['todayTripCount'] as int? ?? 0;
    final todayBrass = (data['todayTotalBrass'] as num?)?.toDouble() ?? 0;
    final attPresent = data['todayAttendancePresent'] as int? ?? 0;
    final attTotal = data['todayAttendanceTotal'] as int? ?? 0;
    final todayCol =
        (data['todayCollectionsTotal'] as num?)?.toDouble() ?? 0;
    final outstanding =
        (data['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final dieselBalance =
        (data['dieselBalanceLiters'] as num?)?.toDouble() ?? 0;
    final receivables = List<Map<String, dynamic>>.from(
        data['receivableParties'] as List? ?? []);
    final trendRaw = List<Map<String, dynamic>>.from(
        data['monthlyTrend'] as List? ?? []);

    // Billing breakdown
    final materialSales =
        (data['monthlyMaterialSales'] as num?)?.toDouble() ?? 0;
    final transportation =
        (data['monthlyTransportation'] as num?)?.toDouble() ?? 0;
    final jobWork =
        (data['monthlyJobWorkBilled'] as num?)?.toDouble() ?? 0;
    final machineWork =
        (data['monthlyMachineWorkBilled'] as num?)?.toDouble() ?? 0;

    // Needs Attention
    final gstPending =
        (data['gstPendingCount'] as num?)?.toInt() ?? 0;
    final unbilledTrips =
        (data['unbilledTripsCount'] as num?)?.toInt() ?? 0;
    final ratePending =
        (data['ratePendingMachineWorkCount'] as num?)?.toInt() ?? 0;
    final jwOverlap =
        (data['jwOverlapCount'] as num?)?.toInt() ?? 0;

    final attention =
        <({IconData icon, Color color, String text, String route})>[];
    if (receivables.isNotEmpty) {
      final n = receivables.length;
      // Single party → link directly to their account; multiple → accounts list
      final route = n == 1
          ? '/accounts/party/${receivables[0]['vendorId']}?name=${Uri.encodeComponent(receivables[0]['vendorName'] as String? ?? '')}'
          : '/accounts';
      attention.add((
        icon: Icons.receipt_long,
        color: Colors.red,
        text:
            '$n ${n == 1 ? 'party has' : 'parties have'} unpaid invoices',
        route: route,
      ));
    }
    if (gstPending > 0) {
      attention.add((
        icon: Icons.percent,
        color: Colors.orange,
        text:
            '$gstPending ${gstPending == 1 ? 'invoice needs' : 'invoices need'} GST recalculation',
        route: '/invoices',
      ));
    }
    if (unbilledTrips > 0) {
      attention.add((
        icon: Icons.swap_horiz,
        color: Colors.blue,
        text:
            '$unbilledTrips ${unbilledTrips == 1 ? 'trip' : 'trips'} not yet invoiced',
        route: '/trips',
      ));
    }
    if (ratePending > 0) {
      attention.add((
        icon: Icons.construction,
        color: Colors.deepOrange,
        text:
            '$ratePending machine work ${ratePending == 1 ? 'entry needs' : 'entries need'} a rate set',
        route: '/machine-work',
      ));
    }
    if (jwOverlap > 0) {
      attention.add((
        icon: Icons.date_range,
        color: Colors.purple,
        text:
            '$jwOverlap job-work ${jwOverlap == 1 ? 'invoice has' : 'invoices have'} overlapping billing periods',
        route: '/invoices',
      ));
    }
    if (dieselBalance < 100) {
      attention.add((
        icon: Icons.local_gas_station,
        color: Colors.teal,
        text:
            'Diesel stock low — ${numFmt.format(dieselBalance)} L remaining',
        route: '/diesel',
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Quick Actions
          _QuickActions(),
          const SizedBox(height: 20),

          // 2. Hero Outstanding Balance
          _HeroBalance(
            outstanding: outstanding,
            onViewAll: () => context.go('/accounts'),
          ),
          const SizedBox(height: 20),

          // 3. Revenue Trend (cumulative) + Billing Breakdown side note
          _TrendChart(trends: trendRaw, monthName: monthName),
          const SizedBox(height: 12),
          _BillingBreakdown(
            monthName: monthName,
            materialSales: materialSales,
            transportation: transportation,
            jobWork: jobWork,
            machineWork: machineWork,
          ),
          const SizedBox(height: 20),

          // 4. Today row
          _TodayRow(
            today: today,
            trips: todayTrips,
            brass: todayBrass,
            present: attPresent,
            total: attTotal,
            collections: todayCol,
          ),
          const SizedBox(height: 20),

          // 5. Outstanding by Party (horizontal bars)
          if (receivables.isNotEmpty)
            _OutstandingBars(parties: receivables),

          // 6. Needs Attention
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 20),
            _NeedsAttention(items: attention),
          ],
          const SizedBox(height: 16),
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
                _QBtn(
                    icon: Icons.receipt_long,
                    label: '+ Invoice',
                    route: '/invoices'),
                _QBtn(
                    icon: Icons.swap_horiz,
                    label: '+ Trip',
                    route: '/trips'),
                _QBtn(
                    icon: Icons.local_gas_station,
                    label: '+ Diesel',
                    route: '/diesel'),
                _QBtn(
                    icon: Icons.payments,
                    label: '+ Payment',
                    route: '/party-payments'),
                _QBtn(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reports',
                    route: '/reports'),
                _QBtn(
                    icon: Icons.fact_check_outlined,
                    label: 'Attendance',
                    route: '/attendance'),
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
  const _QBtn(
      {required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go(route),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ── hero balance ──────────────────────────────────────────────────────────────

class _HeroBalance extends StatelessWidget {
  final double outstanding;
  final VoidCallback onViewAll;
  const _HeroBalance(
      {required this.outstanding, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final isAllPaid = outstanding <= 0;
    final color = isAllPaid ? Colors.green[700]! : Colors.red[700]!;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Text(
              'Outstanding Balance',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              fmtCurr(outstanding),
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            if (isAllPaid) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Text(
                  'All invoices paid',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.creditColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('View All in Accounts',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── revenue trend chart ───────────────────────────────────────────────────────

String _shortCurr(double value) {
  if (value >= 100000) {
    return '₹${(value / 100000).toStringAsFixed(1)}L';
  }
  if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(0)}K';
  if (value == 0) return '₹0';
  return '₹${value.toInt()}';
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trends;
  final String monthName;
  const _TrendChart({required this.trends, required this.monthName});

  @override
  Widget build(BuildContext context) {
    final invoiceSpots = <FlSpot>[];
    final paymentSpots = <FlSpot>[];
    double cumInv = 0;
    double cumPay = 0;
    double maxY = 0;

    for (final t in trends) {
      final day = (t['day'] as num?)?.toDouble() ?? 0;
      cumInv += (t['invoiceTotal'] as num?)?.toDouble() ?? 0;
      cumPay += (t['paymentTotal'] as num?)?.toDouble() ?? 0;
      invoiceSpots.add(FlSpot(day, cumInv));
      paymentSpots.add(FlSpot(day, cumPay));
      maxY = max(maxY, cumInv);
    }

    final hasData = maxY > 0;
    final effectiveMaxY = hasData ? maxY * 1.15 : 1.0;
    final maxDay = trends.isNotEmpty
        ? (trends.last['day'] as num?)?.toDouble() ?? 1.0
        : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend — $monthName',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Cumulative invoiced vs collected',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendLine(color: Colors.blue, label: 'Invoiced'),
                const SizedBox(width: 16),
                _LegendLine(color: Colors.green, label: 'Collected'),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No transactions recorded this month yet',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppColors.borderSubtle,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final d = value.toInt();
                            if (d == 1 || d % 5 == 0) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text('$d',
                                    style: const TextStyle(
                                        fontSize: 10)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 64,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min ||
                                value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                _shortCurr(value),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        bottom: BorderSide(color: AppColors.borderDefault),
                        left: BorderSide(color: AppColors.borderDefault),
                      ),
                    ),
                    minX: 1,
                    maxX: maxDay,
                    minY: 0,
                    maxY: effectiveMaxY,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.textPrimary,
                        getTooltipItems: (spots) =>
                            spots.map((s) {
                          final label = s.barIndex == 0
                              ? 'Billed'
                              : 'Collected';
                          return LineTooltipItem(
                            '$label: ${_shortCurr(s.y)}',
                            const TextStyle(
                                color: Colors.white,
                                fontSize: 11),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: invoiceSpots,
                        isCurved: true,
                        color: AppColors.infoText,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.infoBg.withValues(alpha: 0.5),
                        ),
                      ),
                      LineChartBarData(
                        spots: paymentSpots,
                        isCurved: true,
                        color: AppColors.successText,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.successBg.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendLine({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ── billing breakdown ─────────────────────────────────────────────────────────

class _BillingBreakdown extends StatelessWidget {
  final String monthName;
  final double materialSales;
  final double transportation;
  final double jobWork;
  final double machineWork;
  const _BillingBreakdown({
    required this.monthName,
    required this.materialSales,
    required this.transportation,
    required this.jobWork,
    required this.machineWork,
  });

  @override
  Widget build(BuildContext context) {
    final total = materialSales + transportation + jobWork + machineWork;
    if (total <= 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Billing by Source — $monthName',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'net of GST',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (materialSales > 0)
              _BillingRow(
                  label: 'Material Sales',
                  amount: materialSales,
                  color: Colors.blue),
            if (transportation > 0)
              _BillingRow(
                  label: 'Transportation',
                  amount: transportation,
                  color: Colors.teal),
            if (jobWork > 0)
              _BillingRow(
                  label: 'Job Work',
                  amount: jobWork,
                  color: Colors.purple),
            if (machineWork > 0)
              _BillingRow(
                  label: 'Machine Work',
                  amount: machineWork,
                  color: Colors.orange),
            const Divider(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text('Net Billed',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
                Text(
                  fmtCurr(total),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _BillingRow(
      {required this.label,
      required this.amount,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[700])),
          ),
          Text(
            fmtCurr(amount),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── today row ─────────────────────────────────────────────────────────────────

class _TodayRow extends StatelessWidget {
  final String today;
  final int trips;
  final double brass;
  final int present;
  final int total;
  final double collections;
  const _TodayRow({
    required this.today,
    required this.trips,
    required this.brass,
    required this.present,
    required this.total,
    required this.collections,
  });

  @override
  Widget build(BuildContext context) {
    final attColor =
        present == total && total > 0 ? Colors.green : Colors.orange;
    final attSub = total == 0
        ? 'No employees'
        : present == total
            ? 'All present'
            : '${total - present} absent';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today — $today',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TodayTile(
                icon: Icons.swap_horiz,
                color: Colors.blue,
                label: 'Trips',
                value: '$trips',
                sub: brass > 0
                    ? '${numFmt.format(brass)} Brass'
                    : 'No brass',
                route: '/trips',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayTile(
                icon: Icons.people,
                color: attColor,
                label: 'Attendance',
                value: '$present/$total',
                sub: attSub,
                route: '/attendance',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayTile(
                icon: Icons.payments,
                color: Colors.green,
                label: 'Collections',
                value: fmtCurr(collections),
                sub: 'received today',
                route: '/party-payments',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final String route;
  const _TodayTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style:
                    TextStyle(fontSize: 10, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── outstanding by party — horizontal bars ────────────────────────────────────

class _OutstandingBars extends StatelessWidget {
  final List<Map<String, dynamic>> parties;
  static const _barColors = [
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFF26A69A),
  ];

  const _OutstandingBars({required this.parties});

  @override
  Widget build(BuildContext context) {
    final total = parties.fold<double>(
        0,
        (s, p) =>
            s + ((p['outstandingBalance'] as num?)?.toDouble() ?? 0));
    if (total <= 0) return const SizedBox.shrink();

    final maxAmt = parties
        .map((p) => (p['outstandingBalance'] as num?)?.toDouble() ?? 0)
        .reduce(max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outstanding by Party',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...parties.asMap().entries.map((e) {
              final name =
                  e.value['vendorName'] as String? ?? '—';
              final amt = (e.value['outstandingBalance'] as num?)
                      ?.toDouble() ??
                  0;
              final fraction = maxAmt > 0 ? amt / maxAmt : 0.0;
              final color = _barColors[e.key % _barColors.length];
              return _BarRow(
                  name: name,
                  amount: amt,
                  fraction: fraction,
                  color: color);
            }),
            const Divider(height: 16),
            Text(
              'Total outstanding: ${fmtCurr(total)}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String name;
  final double amount;
  final double fraction;
  final Color color;
  const _BarRow({
    required this.name,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                fmtCurr(amount),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Background track + filled bar
          LayoutBuilder(
            builder: (ctx, constraints) => Stack(
              children: [
                Container(
                  width: constraints.maxWidth,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: constraints.maxWidth * fraction,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── needs attention ───────────────────────────────────────────────────────────

class _NeedsAttention extends StatelessWidget {
  final List<({IconData icon, Color color, String text, String route})>
      items;
  const _NeedsAttention({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warningBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: const BorderSide(color: AppColors.warningBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Needs Attention',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warningText),
            ),
            const SizedBox(height: 6),
            ...items.map((item) => InkWell(
                  onTap: () => context.go(item.route),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 16, color: item.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800]),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
