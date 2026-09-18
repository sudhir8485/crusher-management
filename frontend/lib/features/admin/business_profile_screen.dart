import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// ── provider ─────────────────────────────────────────────────────────────────

final tenantProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/tenant/profile');
  return Map<String, dynamic>.from(res.data as Map);
});

// ── screen ───────────────────────────────────────────────────────────────────

class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(tenantProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tenantProfileProvider),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => _ProfileForm(
          profile: profile,
          onSaved: () => ref.invalidate(tenantProfileProvider),
        ),
      ),
    );
  }
}

// ── form ─────────────────────────────────────────────────────────────────────

class _ProfileForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onSaved;
  const _ProfileForm({required this.profile, required this.onSaved});

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _gstinCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _bankAccountNoCtrl;
  late final TextEditingController _bankIfscCtrl;
  late final TextEditingController _invoicePrefixCtrl;
  late final TextEditingController _invoiceTermsCtrl;
  String? _logoBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl         = TextEditingController(text: p['name']          as String? ?? '');
    _addressCtrl      = TextEditingController(text: p['address']        as String? ?? '');
    _phoneCtrl        = TextEditingController(text: p['phone']          as String? ?? '');
    _emailCtrl        = TextEditingController(text: p['email']          as String? ?? '');
    _gstinCtrl        = TextEditingController(text: p['gstin']          as String? ?? '');
    _bankNameCtrl     = TextEditingController(text: p['bankName']       as String? ?? '');
    _bankAccountNoCtrl= TextEditingController(text: p['bankAccountNo']  as String? ?? '');
    _bankIfscCtrl     = TextEditingController(text: p['bankIfsc']       as String? ?? '');
    _invoicePrefixCtrl= TextEditingController(text: p['invoicePrefix']  as String? ?? '');
    _invoiceTermsCtrl = TextEditingController(text: p['invoiceTerms']   as String? ?? '');
    _logoBase64       = p['logoBase64'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose(); _gstinCtrl.dispose();
    _bankNameCtrl.dispose(); _bankAccountNoCtrl.dispose(); _bankIfscCtrl.dispose();
    _invoicePrefixCtrl.dispose(); _invoiceTermsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64   = base64Encode(bytes);
    final mime  = file.mimeType ?? 'image/jpeg';
    setState(() => _logoBase64 = 'data:$mime;base64,$b64');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put('/api/tenant/profile', data: {
        'name':          _nameCtrl.text.trim(),
        'address':       _addressCtrl.text.trim(),
        'phone':         _phoneCtrl.text.trim(),
        'email':         _emailCtrl.text.trim(),
        'gstin':         _gstinCtrl.text.trim(),
        'bankName':      _bankNameCtrl.text.trim(),
        'bankAccountNo': _bankAccountNoCtrl.text.trim(),
        'bankIfsc':      _bankIfscCtrl.text.trim().toUpperCase(),
        'invoicePrefix': _invoicePrefixCtrl.text.trim().toUpperCase(),
        'invoiceTerms':  _invoiceTermsCtrl.text.trim(),
        'logoBase64':    _logoBase64,
      });
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business profile saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                _Section('Logo'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LogoPreview(logoBase64: _logoBase64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.upload, size: 18),
                            label: const Text('Upload Logo'),
                          ),
                          if (_logoBase64 != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => setState(() => _logoBase64 = null),
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              label: const Text('Remove',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text('PNG, JPG or SVG — shown on PDFs and invoices',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Company Name
                _Section('Company Details'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 27AABCD1234E1Z5',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),

                const SizedBox(height: 24),

                // Bank Details
                _Section('Bank Details'),
                const SizedBox(height: 4),
                Text('Shown on printed invoices for payment',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. State Bank of India',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankAccountNoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankIfscCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. SBIN0001234',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),

                const SizedBox(height: 24),

                // Invoice Settings
                _Section('Invoice Settings'),
                const SizedBox(height: 4),
                Text('Prefix appears in invoice numbers, e.g. ABC/2026-27/1',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _invoicePrefixCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Prefix',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. DSP, ABC, XYZ',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && v.trim().length > 20) {
                      return 'Max 20 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invoiceTermsCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Terms & Conditions',
                    border: OutlineInputBorder(),
                    hintText: 'Enter each term on a new line.\n'
                        'e.g.\n'
                        '1. Interest@24 PA if bill not paid within 4 days.\n'
                        '2. Jurisdiction: YOUR COURT only.',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
          letterSpacing: 0.5));
}

class _LogoPreview extends StatelessWidget {
  final String? logoBase64;
  const _LogoPreview({this.logoBase64});

  @override
  Widget build(BuildContext context) {
    if (logoBase64 != null && logoBase64!.startsWith('data:')) {
      final bytes = base64Decode(logoBase64!.split(',').last);
      return Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain),
        ),
      );
    }
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.business, size: 36, color: Colors.grey.shade400),
    );
  }
}
