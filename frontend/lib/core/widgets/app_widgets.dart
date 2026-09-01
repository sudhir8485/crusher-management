import 'dart:async';
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

// ── Searchable entity picker ──────────────────────────────────────────────────

Map<String, dynamic>? _findItem(List<Map<String, dynamic>> items, int? id) {
  if (id == null) return null;
  for (final m in items) {
    if (m['id'] == id) return m;
  }
  return null;
}

/// Drop-in replacement for [DropdownButtonFormField<int>] that opens a search
/// dialog instead of a flat list. [items] must have an 'id' (int) key.
/// Set [clearable] to show a "None" option that sets the value to null.
class SearchablePicker extends FormField<int> {
  SearchablePicker({
    super.key,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) itemLabel,
    required String fieldLabel,
    int? value,
    void Function(int?)? onChanged,
    FormFieldValidator<int>? validator,
    bool clearable = false,
    String clearLabel = '— None —',
  }) : super(
          initialValue: value,
          validator: validator,
          builder: (state) {
            final selected = _findItem(items, state.value);
            return GestureDetector(
              onTap: () async {
                final result = await showDialog<(bool, int?)>(
                  context: state.context,
                  builder: (_) => _SearchPickerDialog(
                    items: items,
                    itemLabel: itemLabel,
                    title: fieldLabel,
                    currentId: state.value,
                    clearable: clearable,
                    clearLabel: clearLabel,
                  ),
                );
                if (result == null) return;
                final (cleared, id) = result;
                final newVal = cleared ? null : id;
                state.didChange(newVal);
                onChanged?.call(newVal);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: fieldLabel,
                  errorText: state.errorText,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                isEmpty: selected == null,
                child: selected != null
                    ? Text(itemLabel(selected),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16))
                    : const SizedBox.shrink(),
              ),
            );
          },
        );
}

class _SearchPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) itemLabel;
  final String title;
  final int? currentId;
  final bool clearable;
  final String clearLabel;

  const _SearchPickerDialog({
    required this.items,
    required this.itemLabel,
    required this.title,
    required this.currentId,
    required this.clearable,
    required this.clearLabel,
  });

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = q.toLowerCase().trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
            .where((m) => widget.itemLabel(m).toLowerCase().contains(_query))
            .toList();
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: _onSearch,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No results',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final id = item['id'] as int?;
                      final isSelected = id == widget.currentId;
                      return ListTile(
                        dense: true,
                        title: Text(widget.itemLabel(item)),
                        trailing: isSelected
                            ? Icon(Icons.check, color: cs.primary, size: 20)
                            : null,
                        tileColor: isSelected
                            ? cs.primary.withValues(alpha: 0.06)
                            : null,
                        onTap: () => Navigator.pop(context, (false, id)),
                      );
                    },
                  ),
          ),
          if (widget.clearable) ...[
            const Divider(height: 1),
            ListTile(
              dense: true,
              title: Text(widget.clearLabel,
                  style: const TextStyle(color: Colors.grey)),
              onTap: () => Navigator.pop(context, (true, null)),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
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
