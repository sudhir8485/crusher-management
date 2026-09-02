import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'user_role';
  static const _nameKey = 'user_name';
  static const _tenantKey = 'tenant_id';
  static const _siteKey = 'site_id';

  static Future<void> save({
    required String token,
    required String role,
    required String name,
    required int tenantId,
    int? siteId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, role);
    await prefs.setString(_nameKey, name);
    await prefs.setInt(_tenantKey, tenantId);
    if (siteId != null) {
      await prefs.setInt(_siteKey, siteId);
    } else {
      await prefs.remove(_siteKey);
    }
  }

  static Future<int?> getSiteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_siteKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
