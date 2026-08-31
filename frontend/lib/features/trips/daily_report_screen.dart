import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

final _reportDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _dailyReportProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, date) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/trips/daily-report', params: {'date': date});
  return Map<String, dynamic>.from(res.data);
});

class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_reportDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final report = ref.watch(_dailyReportProvider(dateKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_dailyReportProvider(dateKey)),
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(
            selectedDate: selectedDate,
            onPick: (d) => ref.read(_reportDateProvider.notifier).state = d,
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) => _ReportBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onPick;
  const _DateBar({required this.selectedDate, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onPick(selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) onPick(picked);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    if (isToday)
                      const Text('Today', style: TextStyle(fontSize: 11, color: Colors.blue)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onPick(selectedDate.add(const Duration(days: 1))),
          ),
          if (!isToday)
            TextButton(
              onPressed: () => onPick(DateTime.now()),
              child: const Text('Today'),
            ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final trips = List<Map<String, dynamic>>.from(data['trips'] ?? []);
    final summaries = List<Map<String, dynamic>>.from(data['materialSummaries'] ?? []);
    final grandTotal = data['grandTotalBrass'];

    if (trips.isEmpty) {
      return const Center(child: Text('No trips recorded for this date.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card at top
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Summary — ${trips.length} trip${trips.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...summaries.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(s['materialName'] ?? '', style: const TextStyle(fontSize: 14))),
                      Text('${s['totalBrass']} Brass',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  children: [
                    const Expanded(child: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                    Text('$grandTotal Brass',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Trip-by-trip table
        const Text('All Trips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.hardEdge,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Vehicle')),
                DataColumn(label: Text('Material')),
                DataColumn(label: Text('Brass'), numeric: true),
                DataColumn(label: Text('Unloading / Ch')),
                DataColumn(label: Text('DSP Challan')),
                DataColumn(label: Text('Vdr Challan')),
              ],
              rows: trips.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final t = entry.value;
                final unloading = [
                  if ((t['unloadingLocation'] ?? '').isNotEmpty) t['unloadingLocation'],
                  if ((t['channelNo'] ?? '').isNotEmpty) 'Ch: ${t['channelNo']}',
                ].join(' / ');
                return DataRow(cells: [
                  DataCell(Text('$i')),
                  DataCell(Text(t['vehicleDisplayName'] ?? t['vehiclePlateNumber'] ?? '-')),
                  DataCell(Text(t['materialName'] ?? '-')),
                  DataCell(Text(t['quantityBrass']?.toString() ?? '-')),
                  DataCell(Text(unloading.isEmpty ? '-' : unloading)),
                  DataCell(Text(t['dspChallanNo'] ?? '-')),
                  DataCell(Text(t['vendorChallanNo'] ?? '-')),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
