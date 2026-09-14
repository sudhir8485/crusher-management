import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import 'invoice_pdf.dart';

/// Standalone full-page invoice print/preview screen — no sidebar.
/// Uses PdfPreview widget which works on Android, iOS, and web.
class InvoicePrintScreen extends ConsumerStatefulWidget {
  final String type; // 'gst' or 'jw'
  final int id;
  const InvoicePrintScreen({required this.type, required this.id, super.key});

  @override
  ConsumerState<InvoicePrintScreen> createState() => _InvoicePrintScreenState();
}

class _InvoicePrintScreenState extends ConsumerState<InvoicePrintScreen> {
  String? _error;
  bool _loading = true;
  Map<String, dynamic>? _inv;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api      = ref.read(apiClientProvider);
      final endpoint = widget.type == 'gst'
          ? '/api/invoices/${widget.id}'
          : '/api/job-work-invoices/${widget.id}';
      final res      = await api.get(endpoint);
      final inv      = Map<String, dynamic>.from(res.data as Map)
        ..['_src'] = widget.type;
      final profile  = await fetchTenantProfile(api);
      if (mounted) setState(() { _inv = inv; _profile = profile; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Preparing invoice…',
                  style: TextStyle(fontSize: 15, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error generating invoice',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Invoices'),
                  onPressed: () => context.go('/invoices'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final inv     = _inv!;
    final profile = _profile!;

    return Scaffold(
      appBar: AppBar(
        title: Text(inv['invoiceNo'] as String? ?? 'Invoice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/invoices'),
        ),
      ),
      body: PdfPreview(
        build: (format) async {
          final doc = await buildInvoicePdf(inv, profile);
          return doc.save();
        },
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: '${(inv['invoiceNo'] as String? ?? 'invoice').replaceAll('/', '_')}.pdf',
      ),
    );
  }
}
