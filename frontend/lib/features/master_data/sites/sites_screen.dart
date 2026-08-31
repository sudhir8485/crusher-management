import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../widgets/master_list_screen.dart';

final sitesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/sites');
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
      itemBuilder: (s) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.location_on)),
        title: Text(s['name']),
        subtitle: Text(s['location'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(context, ref, s)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, s['id'])),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _SiteForm(existing: existing, onSaved: () => ref.invalidate(sitesProvider)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate site?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
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
  final _formKey = GlobalKey<FormState>();
  late final _name     = TextEditingController(text: widget.existing?['name']);
  late final _location = TextEditingController(text: widget.existing?['location']);
  bool _saving = false;

  @override
  void dispose() { _name.dispose(); _location.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {'name': _name.text, 'location': _location.text};
    final api = ref.read(apiClientProvider);
    if (widget.existing == null) {
      await api.post('/api/sites', data: data);
    } else {
      await api.put('/api/sites/${widget.existing!['id']}', data: data);
    }
    if (mounted) { Navigator.pop(context); widget.onSaved(); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Site' : 'Edit Site'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Site Name *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location'),
                  maxLines: 2),
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
