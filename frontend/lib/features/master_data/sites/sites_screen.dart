import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../widgets/master_list_screen.dart';
import '../../../core/widgets/app_widgets.dart';

final sitesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/sites');
  return List<Map<String, dynamic>>.from(res.data);
});

final _partiesForSiteProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/parties');
  return List<Map<String, dynamic>>.from(res.data);
});

class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    return MasterListScreen(
      title: 'Sites',
      items: sites,
      onRefresh: () => ref.invalidate(sitesProvider),
      onAdd: () => _showForm(context, ref, null),
      itemBuilder: (s) {
        final siteType       = s['siteType'] as String? ?? 'OWN';
        final isClient       = siteType == 'CLIENT_SITE';
        final linkedPartyName = s['linkedPartyName'] as String?;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isClient
                ? Colors.purple.withValues(alpha: 0.12)
                : Colors.green.withValues(alpha: 0.12),
            child: Icon(
              isClient ? Icons.business_outlined : Icons.location_on_outlined,
              color: isClient ? Colors.purple : Colors.green,
            ),
          ),
          title: Row(children: [
            Expanded(child: Text(s['name'])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isClient
                    ? Colors.purple.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: isClient
                        ? Colors.purple.withValues(alpha: 0.4)
                        : Colors.green.withValues(alpha: 0.4)),
              ),
              child: Text(
                isClient ? 'Client Site' : 'Own Site',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: isClient ? Colors.purple : Colors.green),
              ),
            ),
          ]),
          subtitle: Text([
            if (s['location'] != null && (s['location'] as String).isNotEmpty)
              s['location'] as String,
            if (isClient && linkedPartyName != null) 'Party: $linkedPartyName',
          ].join('  ·  ')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showForm(context, ref, s)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref, s['id'] as int, s['name'] as String)),
            ],
          ),
        );
      },
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _SiteForm(existing: existing, onSaved: () => ref.invalidate(sitesProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate site?'),
        content: Text('Deactivate "$name"? It will be hidden from new entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).delete('/api/sites/$id');
              ref.invalidate(sitesProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _SiteForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _SiteForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_SiteForm> createState() => _SiteFormState();
}

class _SiteFormState extends ConsumerState<_SiteForm> {
  final _formKey     = GlobalKey<FormState>();
  late final _name     = TextEditingController(text: widget.existing?['name']);
  late final _location = TextEditingController(text: widget.existing?['location']);
  String _siteType = 'OWN';
  int?   _linkedPartyId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _siteType      = widget.existing?['siteType'] ?? 'OWN';
    _linkedPartyId = widget.existing?['linkedPartyId'] as int?;
  }

  @override
  void dispose() { _name.dispose(); _location.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_siteType == 'CLIENT_SITE' && _linkedPartyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A Client Site must have a linked party'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    final data = {
      'name':          _name.text.trim(),
      'location':      _location.text.trim(),
      'siteType':      _siteType,
      'linkedPartyId': _siteType == 'CLIENT_SITE' ? _linkedPartyId : null,
    };
    final api = ref.read(apiClientProvider);
    try {
      if (widget.existing == null) {
        await api.post('/api/sites', data: data);
      } else {
        await api.put('/api/sites/${widget.existing!['id']}', data: data);
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
    final partiesAsync = ref.watch(_partiesForSiteProvider);

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Site' : 'Edit Site'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _name,
                decoration: const InputDecoration(labelText: 'Site Name *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
                maxLines: 2),
            const SizedBox(height: 12),
            const Text('Site Type', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'OWN',         label: Text('Own Site'),    icon: Icon(Icons.location_on_outlined)),
                ButtonSegment(value: 'CLIENT_SITE',  label: Text('Client Site'), icon: Icon(Icons.business_outlined)),
              ],
              selected: {_siteType},
              onSelectionChanged: (s) => setState(() {
                _siteType = s.first;
                if (_siteType == 'OWN') _linkedPartyId = null;
              }),
            ),
            if (_siteType == 'CLIENT_SITE') ...[
              const SizedBox(height: 12),
              partiesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load parties: $e'),
                data: (parties) {
                  final active = parties.where((p) => p['status'] == 'ACTIVE').toList();
                  return SearchablePicker(
                    items: active,
                    itemLabel: (p) => p['name'] as String,
                    fieldLabel: 'Linked Party *',
                    value: _linkedPartyId,
                    onChanged: (v) => setState(() => _linkedPartyId = v),
                    validator: (v) => v == null ? 'Required for Client Site' : null,
                  );
                },
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
