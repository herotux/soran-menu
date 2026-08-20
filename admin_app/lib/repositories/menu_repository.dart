import '../models/menu_models.dart';

abstract class MenuRepository {
  Future<MenuData> load();

  /// شناسه نسخه/ویرایش فعلی داده.
  /// در GitHub می‌تواند commit SHA باشد،
  /// در Server می‌تواند version باشد.
  Future<String> getVersion();

  Future<String> save(MenuData menu);
}
