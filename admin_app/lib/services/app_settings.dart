import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _ownerKey = 'github_owner';
  static const _repoKey = 'github_repo';
  static const _branchKey = 'github_branch';
  static const _pathKey = 'github_menu_path';
  static const _siteUrlKey = 'site_url';
  static const _tokenKey = 'github_token';

  static const _secureStorage = FlutterSecureStorage();

  static Future<String> getOwner() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ownerKey) ?? '';
  }

  static Future<String> getRepo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_repoKey) ?? '';
  }

  static Future<String> getBranch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_branchKey) ?? '';
  }

  static Future<String> getMenuPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pathKey) ?? '';
  }

  static Future<String> getSiteUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_siteUrlKey) ?? '';
  }

  static Future<String> getToken() async {
    return await _secureStorage.read(key: _tokenKey) ?? '';
  }

  static Future<bool> isConfigured() async {
    final owner = await getOwner();
    final repo = await getRepo();
    final branch = await getBranch();
    final path = await getMenuPath();
    final token = await getToken();

    return owner.isNotEmpty &&
        repo.isNotEmpty &&
        branch.isNotEmpty &&
        path.isNotEmpty &&
        token.isNotEmpty;
  }

  static Future<void> save({
    required String owner,
    required String repo,
    required String branch,
    required String menuPath,
    required String siteUrl,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_ownerKey, owner.trim());
    await prefs.setString(_repoKey, repo.trim());
    await prefs.setString(_branchKey, branch.trim());
    await prefs.setString(_pathKey, menuPath.trim());
    await prefs.setString(_siteUrlKey, siteUrl.trim());

    if (token.trim().isEmpty) {
      await _secureStorage.delete(key: _tokenKey);
    } else {
      await _secureStorage.write(
        key: _tokenKey,
        value: token.trim(),
      );
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_ownerKey);
    await prefs.remove(_repoKey);
    await prefs.remove(_branchKey);
    await prefs.remove(_pathKey);
    await prefs.remove(_siteUrlKey);

    await _secureStorage.delete(key: _tokenKey);
  }
}
