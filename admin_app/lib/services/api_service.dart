import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'app_settings.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'api_access_token';

  Future<String> get baseUrl async {
    final configured = (await AppSettings.getApiBaseUrl()).trim();
    return configured.isEmpty ? 'http://10.0.2.2:8000' : configured.replaceFirst(RegExp(r'/$'), '');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: _tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('${await baseUrl}$path'), headers: await _headers(), body: jsonEncode(body));
    return _decode(response);
  }

  Future<dynamic> get(String path) async {
    final response = await http.get(Uri.parse('${await baseUrl}$path'), headers: await _headers());
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final data = response.body.isEmpty ? {} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data is Map ? data['detail'] : null;
      throw Exception(detail?.toString() ?? 'خطا در ارتباط با سرور');
    }
    return data;
  }

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
  Future<bool> hasToken() async => (await _storage.read(key: _tokenKey))?.isNotEmpty ?? false;
}
