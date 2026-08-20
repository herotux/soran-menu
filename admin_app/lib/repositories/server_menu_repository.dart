import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/menu_models.dart';
import '../services/app_settings.dart';
import 'menu_repository.dart';

class ServerMenuRepository implements MenuRepository {
  Future<String> _baseUrl() async {
    final value = (await AppSettings.getApiBaseUrl()).trim();

    if (value.isEmpty) {
      throw Exception('آدرس API سرور تنظیم نشده است');
    }

    return value.replaceFirst(RegExp(r'/$'), '');
  }

  Future<Map<String, String>> _headers() async {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  @override
  Future<MenuData> load() async {
    final baseUrl = await _baseUrl();

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/menu'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در دریافت منو از سرور: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    return MenuData.fromJson(data);
  }

  @override
  Future<String> getVersion() async {
    final baseUrl = await _baseUrl();

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/menu/version'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در بررسی نسخه منو: '
        'HTTP ${response.statusCode}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    return data['version']?.toString() ?? '';
  }

  @override
  Future<String> save(MenuData menu) async {
    final baseUrl = await _baseUrl();

    final response = await http.put(
      Uri.parse('$baseUrl/api/v1/menu'),
      headers: await _headers(),
      body: jsonEncode(menu.toJson()),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        'خطا در ذخیره منو روی سرور: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    return data['version']?.toString() ?? '';
  }
}
