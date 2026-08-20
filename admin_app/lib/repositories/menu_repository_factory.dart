import '../services/app_settings.dart';
import 'github_menu_repository.dart';
import 'menu_repository.dart';
import 'server_menu_repository.dart';

class MenuRepositoryFactory {
  static Future<MenuRepository> create() async {
    final backend = await AppSettings.getBackend();

    switch (backend) {
      case 'server':
        return ServerMenuRepository();

      case 'github':
      default:
        return GitHubMenuRepository();
    }
  }
}
