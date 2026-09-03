import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../widgets/master_list_screen.dart';

final materialsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/materials');
  return List<Map<String, dynamic>>.from(res.data);
});

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsProvider);
    return MasterListScreen(
      title: 'Materials',
      items: materials,
      onRefresh: () => ref.invalidate(materialsProvider),
      onAdd: () => _showForm(context, ref, null),
      itemBuilder: (m) {
        final rateTon    = m['defaultSaleRate'];
        final rateBrass  = m['defaultSaleRateBrass'];
        final rateTrans  = m['defaultTransportRate'];
        final kpb        = m['kgPerBrass'];
        final code       = m['code'] as String?;
        final subtitleParts = <String>['Unit: ${m['unit']}'];
        if (rateTon   != null) subtitleParts.add('TON: ₹$rateTon');
        if (rateBrass != null) subtitleParts.add('BRASS: ₹$rateBrass');
        if (rateTrans != null) subtitleParts.add('Transport: ₹$rateTrans/km');
        if (kpb       != null) subtitleParts.add('$kpb kg/brass');
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.category)),
          title: Text(m['name'] + (code != null && code.isNotEmpty ? '  ($code)' : '')),
          subtitle: Text(subtitleParts.join('  ·  ')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showForm(context, ref, m)),
              IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () =>
                      _confirmDelete(context, ref, m['id'] as int, m['name'] as String)),
            ],
          ),
        );
      },
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _MaterialForm(existing: existing, onSaved: () => ref.invalidate(materialsProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate material?'),
        content: Text('Deactivate "$name"? It will be hidden from new trip entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/materials/$id');
              ref.invalidate(materialsProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _MaterialForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _MaterialForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_MaterialForm> createState() => _MaterialFormState();
}

class _MaterialFormState extends ConsumerState<_MaterialForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name          = TextEditingController(text: widget.existing?['name']);
  late final _code          = TextEditingController(text: widget.existing?['code'] ?? '');
  late final _label         = TextEditingController(text: widget.existing?['sizeLabel']);
  late final _saleRateTon     = TextEditingController(
      text: widget.existing?['defaultSaleRate']?.toString() ?? '');
  late final _saleRateBrass   = TextEditingController(
      text: widget.existing?['defaultSaleRateBrass']?.toString() ?? '');
  late final _transportRate   = TextEditingController(
      text: widget.existing?['defaultTransportRate']?.toString() ?? '');
  late final _kgPerBrass      = TextEditingController(
      text: widget.existing?['kgPerBrass']?.toString() ?? '');
  String _unit = 'BRASS';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.existing?['unit'] ?? 'BRASS';
  }

  @override
  void dispose() {
    _name.dispose(); _code.dispose(); _label.dispose();
    _saleRateTon.dispose(); _saleRateBrass.dispose();
    _transportRate.dispose(); _kgPerBrass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
      'sizeLabel': _label.text.trim().isEmpty ? null : _label.text.trim(),
      'unit': _unit,
      if (_saleRateTon.text.trim().isNotEmpty)
        'defaultSaleRate': double.tryParse(_saleRateTon.text.trim()),
      if (_saleRateBrass.text.trim().isNotEmpty)
        'defaultSaleRateBrass': double.tryParse(_saleRateBrass.text.trim()),
      if (_transportRate.text.trim().isNotEmpty)
        'defaultTransportRate': double.tryParse(_transportRate.text.trim()),
      if (_kgPerBrass.text.trim().isNotEmpty)
        'kgPerBrass': double.tryParse(_kgPerBrass.text.trim()),
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/materials', data: data);
      } else {
        await api.put('/api/materials/${widget.existing!['id']}', data: data);
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
      title: Text(widget.existing == null ? 'Add Material' : 'Edit Material'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Material Code'),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Size Label (e.g. 20 MM)'),
                )),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(labelText: 'Default Unit'),
                items: const [
                  DropdownMenuItem(value: 'BRASS', child: Text('Brass')),
                  DropdownMenuItem(value: 'TON',   child: Text('Ton')),
                ],
                onChanged: (v) => setState(() => _unit = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _saleRateTon,
                  decoration: const InputDecoration(
                    labelText: 'Default Rate (TON)',
                    prefixText: '₹ ',
                    suffixText: '/ TON',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty &&
                        double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _saleRateBrass,
                  decoration: const InputDecoration(
                    labelText: 'Default Rate (BRASS)',
                    prefixText: '₹ ',
                    suffixText: '/ BRASS',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty &&
                        double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _transportRate,
                decoration: const InputDecoration(
                  labelText: 'Default Transport Rate',
                  prefixText: '₹ ',
                  suffixText: '/ km / unit',
                  helperText: 'Auto-fills transport rate on trip form',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty &&
                      double.tryParse(v.trim()) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kgPerBrass,
                decoration: const InputDecoration(
                  labelText: 'KG per Brass',
                  suffixText: 'kg / brass',
                  helperText: 'Auto-calculates brass quantity from net weight',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Invalid number';
                    if (n <= 0) return 'Must be greater than 0';
                  }
                  return null;
                },
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
