// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import 'invoice_pdf.dart';

/// Standalone full-page print screen — no sidebar, no app chrome.
/// Fetches the invoice, generates the PDF, and replaces the current tab
/// with the blob URL so the browser's native PDF viewer takes over.
/// The user then prints or downloads using browser controls.
class InvoicePrintScreen extends ConsumerStatefulWidget {
  final String type; // 'gst' or 'jw'
  final int id;
  const InvoicePrintScreen({required this.type, required this.id, super.key});

  @override
  ConsumerState<InvoicePrintScreen> createState() => _InvoicePrintScreenState();
}

class _InvoicePrintScreenState extends ConsumerState<InvoicePrintScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    try {
      final api = ref.read(apiClientProvider);
      final endpoint = widget.type == 'gst'
          ? '/api/invoices/${widget.id}'
          : '/api/job-work-invoices/${widget.id}';
      final res = await api.get(endpoint);
      final inv = Map<String, dynamic>.from(res.data as Map)
        ..['_src'] = widget.type;
      final profile = await fetchTenantProfile(api);
      final doc     = await buildInvoicePdf(inv, profile);
      final bytes   = await doc.save();
      final blob    = html.Blob([bytes], 'application/pdf');
      final url     = html.Url.createObjectUrlFromBlob(blob);
      // Replace current history entry → browser Back returns to /invoices
      html.window.location.replace(url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
            SizedBox(height: 8),
            Text('Your PDF will open automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
