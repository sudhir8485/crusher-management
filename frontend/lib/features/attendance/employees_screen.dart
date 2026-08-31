import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final employeesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/employees?all=true');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── screen ────────────────────────────────────────────────────────────────────

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(employeesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
      body: employees.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No employees added yet',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          final active = data.where((e) => e['status'] == 'ACTIVE').toList();
          final inactive = data.where((e) => e['status'] != 'ACTIVE').toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('Active (${active.length})'),
                ...active.map((e) => _EmployeeCard(
                      emp: e,
                      onEdit: () => _showForm(context, ref, e),
                      onDeactivate: () => _confirmDeactivate(context, ref, e),
                    )),
              ],
              if (inactive.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('Inactive (${inactive.length})'),
                ...inactive.map((e) => _EmployeeCard(
                      emp: e,
                      onEdit: () => _showForm(context, ref, e),
                      onDeactivate: null,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey)),
      );

  void _showForm(BuildContext ctx, WidgetRef ref, Map<String, dynamic>? emp) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _EmployeeForm(
        existing: emp,
        onSaved: () => ref.invalidate(employeesProvider),
      ),
    );
  }

  void _confirmDeactivate(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> emp) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate Employee'),
        content:
            Text('Remove ${emp['name']} from active employees?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(apiClientProvider)
                  .delete('/api/employees/${emp['id']}');
              ref.invalidate(employeesProvider);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

// ── employee card ─────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> emp;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  const _EmployeeCard(
      {required this.emp, required this.onEdit, this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final isActive = emp['status'] == 'ACTIVE';
    final designation = (emp['designation'] as String?)?.trim() ?? '';
    final wageType = emp['wageType'] as String? ?? 'DAILY';
    final wageRate = emp['wageRate'];

    String wageLabel = wageType == 'MONTHLY' ? 'Monthly' : 'Daily';
    if (wageRate != null) {
      wageLabel += ' ₹${(wageRate as num).toStringAsFixed(0)}';
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Colors.grey[200],
          child: Text(
            (emp['name'] as String).substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
          ),
        ),
        title: Text(emp['name'] as String,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? null : Colors.grey)),
        subtitle: Text(
          [if (designation.isNotEmpty) designation, wageLabel]
              .join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'deactivate' && onDeactivate != null) onDeactivate!();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (onDeactivate != null)
              const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Deactivate',
                      style: TextStyle(color: Colors.orange))),
          ],
        ),
      ),
    );
  }
}

// ── form ──────────────────────────────────────────────────────────────────────

class _EmployeeForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _EmployeeForm({required this.existing, required this.onSaved});

  @override
  ConsumerState<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<_EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _desigCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String _wageType = 'DAILY';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] as String? ?? '';
      _desigCtrl.text = e['designation'] as String? ?? '';
      _wageType = e['wageType'] as String? ?? 'DAILY';
      final rate = e['wageRate'];
      if (rate != null) _rateCtrl.text = rate.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _desigCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'name': _nameCtrl.text.trim(),
      'designation': _desigCtrl.text.trim().isEmpty
          ? null
          : _desigCtrl.text.trim(),
      'wageType': _wageType,
      'wageRate': double.tryParse(_rateCtrl.text),
    };
    final api = ref.read(apiClientProvider);
    final e = widget.existing;
    if (e == null) {
      await api.post('/api/employees', data: body);
    } else {
      await api.put('/api/employees/${e['id']}', data: body);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Employee' : 'Add Employee'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desigCtrl,
                decoration: const InputDecoration(
                  labelText: 'Designation',
                  hintText: 'e.g. Site Supervisor, Operator, Driver',
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Wage Type',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'DAILY', label: Text('Daily')),
                  ButtonSegment(value: 'MONTHLY', label: Text('Monthly')),
                ],
                selected: {_wageType},
                onSelectionChanged: (s) =>
                    setState(() => _wageType = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rateCtrl,
                decoration: InputDecoration(
                  labelText: _wageType == 'DAILY'
                      ? 'Rate per Day (₹)'
                      : 'Monthly Salary (₹)',
                  prefixText: '₹ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
