import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/menu_models.dart';

class MenuCache {
  static const _menuKey = 'cached_menu_json';
  static const _shaKey = 'cached_menu_sha';

  static Future<MenuData?> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_menuKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw);

      if (json is! Map<String, dynamic>) {
        return null;
      }

      return MenuData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<String> getSha() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shaKey) ?? '';
  }

  static Future<void> save(
    MenuData menu, {
    String sha = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final json = const JsonEncoder().convert(
      menu.toJson(),
    );

    await prefs.setString(_menuKey, json);

    if (sha.trim().isNotEmpty) {
      await prefs.setString(
        _shaKey,
        sha.trim(),
      );
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_menuKey);
    await prefs.remove(_shaKey);
  }
}
