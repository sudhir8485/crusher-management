import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Currency / number formatters ──────────────────────────────────────────────

final currFmt = NumberFormat('#,##,##0.00', 'en_IN');
final numFmt  = NumberFormat('#,##,##0.##',  'en_IN');

String fmtCurr(num? v) => '₹${currFmt.format(v ?? 0)}';
String fmtNum(num? v, {String suffix = ''}) =>
    '${numFmt.format(v ?? 0)}${suffix.isNotEmpty ? ' $suffix' : ''}';

// ── Date navigation bar ───────────────────────────────────────────────────────

class AppDateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onPick;
  const AppDateBar({super.key, required this.selectedDate, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
            )
          else
            const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ── Scrollable dialog with pinned footer ──────────────────────────────────────

class AppDialog extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final double maxWidth;

  const AppDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: screenH * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 12),
            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: body,
              ),
            ),
            const Divider(height: 1),
            // Pinned footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: w,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  const AppEmptyState({super.key, required this.icon, required this.message, this.hint});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(message,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      );
}

// ── Summary bar chip ──────────────────────────────────────────────────────────

class SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const SummaryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
        ],
      );
}

// ── Status badge ──────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge(this.label, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      );
}

// ── Date field tappable ───────────────────────────────────────────────────────

class DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool required;
  const DateField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(
            date != null
                ? DateFormat('dd/MM/yyyy').format(date!)
                : 'Select date',
            style: TextStyle(
                color: date != null ? null : Colors.grey[500]),
          ),
        ),
      );
}
