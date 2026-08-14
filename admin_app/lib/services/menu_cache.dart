import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/menu_models.dart';

class MenuCache {
  static const _menuKey = 'cached_menu_json';

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

  static Future<void> save(MenuData menu) async {
    final prefs = await SharedPreferences.getInstance();

    final json = const JsonEncoder().convert(menu.toJson());

    await prefs.setString(_menuKey, json);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_menuKey);
  }
}
