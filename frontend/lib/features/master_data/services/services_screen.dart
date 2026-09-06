import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../widgets/master_list_screen.dart';

final servicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/services');
  return List<Map<String, dynamic>>.from(res.data);
});

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return MasterListScreen(
      title: 'Services',
      items: services,
      onRefresh: () => ref.invalidate(servicesProvider),
      onAdd: () => _showForm(context, ref, null),
      itemBuilder: (s) {
        final rate    = s['defaultRate'];
        final unit    = s['defaultUnit'] as String? ?? 'TON';
        final code    = s['code'] as String?;
        final gstRate = s['gstRate'];
        final sac     = s['sacCode'] as String?;
        final configured = s['gstRateConfigured'] as bool? ?? false;
        final subtitleParts = <String>['Unit: $unit'];
        if (rate != null) subtitleParts.add('₹$rate/$unit');
        if (gstRate != null && configured) subtitleParts.add('GST $gstRate%');
        else subtitleParts.add('GST: not set');
        if (sac != null && sac.isNotEmpty) subtitleParts.add('SAC $sac');

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: configured
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.amber.shade100,
            child: Icon(Icons.handyman_outlined,
                color: configured ? Theme.of(context).colorScheme.primary : Colors.orange),
          ),
          title: Text(s['name'] + (code != null && code.isNotEmpty ? '  ($code)' : '')),
          subtitle: Text(subtitleParts.join('  ·  ')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!configured)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'GST rate not configured — invoices will be PENDING',
                    child: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                  ),
                ),
              IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showForm(context, ref, s)),
              IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () =>
                      _confirmDelete(context, ref, s['id'] as int, s['name'] as String)),
            ],
          ),
        );
      },
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _ServiceForm(existing: existing, onSaved: () => ref.invalidate(servicesProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Deactivate service?'),
        content: Text('Deactivate "$name"? It will be hidden from new job-work invoices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(apiClientProvider).delete('/api/services/$id');
              } catch (_) { return; }
              if (!context.mounted) return;
              ref.invalidate(servicesProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _ServiceForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name     = TextEditingController(text: widget.existing?['name']);
  late final _code     = TextEditingController(text: widget.existing?['code'] ?? '');
  late final _rate     = TextEditingController(
      text: widget.existing?['defaultRate']?.toString() ?? '');
  late final _gstRate  = TextEditingController(
      text: widget.existing?['gstRate']?.toString() ?? '0');
  late final _sacCode  = TextEditingController(
      text: widget.existing?['sacCode'] ?? '');
  String _unit = 'TON';
  String _autoCalcSource = 'NONE';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.existing?['defaultUnit'] ?? 'TON';
    _autoCalcSource = widget.existing?['autoCalcSource'] ?? 'NONE';
  }

  @override
  void dispose() {
    _name.dispose(); _code.dispose(); _rate.dispose();
    _gstRate.dispose(); _sacCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
      'defaultUnit': _unit,
      if (_rate.text.trim().isNotEmpty)
        'defaultRate': double.tryParse(_rate.text.trim()),
      'gstRate': double.tryParse(_gstRate.text.trim()) ?? 0,
      if (_sacCode.text.trim().isNotEmpty) 'sacCode': _sacCode.text.trim(),
      'autoCalcSource': _autoCalcSource,
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/services', data: data);
      } else {
        await api.put('/api/services/${widget.existing!['id']}', data: data);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Service' : 'Edit Service'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Service Name *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Service Code'),
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(value: 'TON', child: Text('Ton')),
                    DropdownMenuItem(value: 'BRASS', child: Text('Brass')),
                  ],
                  onChanged: (v) => setState(() => _unit = v!),
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rate,
                decoration: InputDecoration(
                  labelText: 'Default Rate',
                  prefixText: '₹ ',
                  suffixText: '/ $_unit',
                  helperText: 'Auto-fills rate on job-work invoice lines',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty &&
                      double.tryParse(v.trim()) == null) return 'Invalid number';
                  return null;
                },
              ),
              const Divider(height: 24),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _gstRate,
                  decoration: const InputDecoration(
                    labelText: 'GST Rate (%)',
                    suffixText: '%',
                    helperText: '0 = non-taxable  |  e.g. 18, 12, 5',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0 || n > 100) return 'Enter 0–100';
                    return null;
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _sacCode,
                  decoration: const InputDecoration(
                    labelText: 'SAC Code',
                    helperText: 'Service Accounting Code',
                  ),
                )),
              ]),
              const Divider(height: 24),
              DropdownButtonFormField<String>(
                value: _autoCalcSource,
                decoration: const InputDecoration(
                  labelText: 'Auto-Calculate Quantity From',
                  helperText: 'Used by Job-Work invoices to auto-fill line quantity',
                ),
                items: const [
                  DropdownMenuItem(value: 'NONE',             child: Text('Manual Entry (no auto-calculate)')),
                  DropdownMenuItem(value: 'TRIP_QUANTITIES',  child: Text('Sum of Trip Quantities')),
                  DropdownMenuItem(value: 'DABAR_QUANTITIES', child: Text('Sum of Dabar Quantities')),
                ],
                onChanged: (v) => setState(() => _autoCalcSource = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
