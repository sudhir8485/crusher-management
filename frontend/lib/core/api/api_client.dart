import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Priority order:
//   1. --dart-define=BASE_URL=<url>   (start.sh dev, start-mobile.sh ADB, start-apk.sh network)
//   2. kIsWeb → Uri.base.origin       (start-server.sh: nginx proxies /api/ to backend)
//   3. Native fallback                 (shouldn't normally be reached)
const _dartDefineUrl = String.fromEnvironment('BASE_URL');

String get _baseUrl {
  if (_dartDefineUrl.isNotEmpty) return _dartDefineUrl;
  if (kIsWeb) return Uri.base.origin;
  return 'http://localhost:8080';
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Stale or invalid token — clear stored credentials so the
          // router's redirect guard sends the user to /login on next navigation
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        }
        handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? params}) =>
      _dio.post(path, data: data, queryParameters: params);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}
