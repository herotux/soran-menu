import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/menu_models.dart';

abstract class MenuRepository {
  Future<MenuData> load();
  Future<void> save(MenuData menu);
}

class RemoteMenuRepository implements MenuRepository {
  static const String menuUrl =
      'https://herotux.github.io/soran-menu/data/menu.json';

  @override
  Future<MenuData> load() async {
    final response = await http.get(
      Uri.parse(menuUrl),
      headers: const {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در دریافت منو: HTTP ${response.statusCode}',
      );
    }

    final json = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as Map<String, dynamic>;

    return MenuData.fromJson(json);
  }

  @override
  Future<void> save(MenuData menu) async {
    throw UnimplementedError(
      'ذخیره‌سازی GitHub هنوز پیاده‌سازی نشده است.',
    );
  }
}
