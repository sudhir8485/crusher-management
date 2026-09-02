import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

// Currently selected site ID for the UI.
// null = "All Sites" (visible only to OWNER_ADMIN / OFFICE_ACCOUNTANT).
// SITE_STAFF always has a fixed siteId from their JWT — set on login.
final selectedSiteIdProvider = StateProvider<int?>((ref) => null);

// List of all active sites for the site switcher dropdown.
final sitesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/api/sites');
  return List<Map<String, dynamic>>.from(res.data);
});
