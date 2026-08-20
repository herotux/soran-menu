import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/menu_models.dart';
import 'menu_repository.dart';
import '../services/app_settings.dart';

class GitHubFile {
  final String content;
  final String sha;

  GitHubFile({
    required this.content,
    required this.sha,
  });
}

class GitHubMenuRepository implements MenuRepository {
  static const String apiBase = 'https://api.github.com';

  Future<Map<String, String>> _settings() async {
    final owner = await AppSettings.getOwner();
    final repo = await AppSettings.getRepo();
    final branch = await AppSettings.getBranch();
    final path = await AppSettings.getMenuPath();
    final token = await AppSettings.getToken();

    if (owner.isEmpty ||
        repo.isEmpty ||
        branch.isEmpty ||
        path.isEmpty) {
      throw Exception('تنظیمات GitHub کامل نیست');
    }

    if (token.isEmpty) {
      throw Exception('GitHub Token وارد نشده است');
    }

    return {
      'owner': owner,
      'repo': repo,
      'branch': branch,
      'path': path,
      'token': token,
    };
  }

  Map<String, String> _headers(String token) {
    return {
      'Accept': 'application/vnd.github+json',
      'Authorization': 'Bearer $token',
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
    };
  }

  Future<GitHubFile> _getFile({
    required String owner,
    required String repo,
    required String path,
    required String branch,
    required String token,
  }) async {
    final uri = Uri.parse(
      '$apiBase/repos/$owner/$repo/contents/$path?ref=$branch',
    );

    final response = await http.get(
      uri,
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در دریافت menu.json: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    final encodedContent =
        data['content']?.toString() ?? '';

    final sha =
        data['sha']?.toString() ?? '';

    if (encodedContent.isEmpty || sha.isEmpty) {
      throw Exception('اطلاعات فایل menu.json ناقص است');
    }

    final normalizedContent =
        encodedContent.replaceAll('\n', '');

    final content = utf8.decode(
      base64.decode(normalizedContent),
    );

    return GitHubFile(
      content: content,
      sha: sha,
    );
  }

  @override
  Future<String> getVersion() async {
    final settings = await _settings();

    final path = Uri.encodeQueryComponent(
      settings['path']!,
    );

    final uri = Uri.parse(
      '$apiBase/repos/'
      '${settings['owner']!}/'
      '${settings['repo']!}/'
      'commits?path=$path'
      '&sha=${Uri.encodeQueryComponent(settings['branch']!)}'
      '&per_page=1',
    );

    final response = await http.get(
      uri,
      headers: _headers(settings['token']!),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در بررسی نسخه menu.json: '
        'HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! List || data.isEmpty) {
      return '';
    }

    final first = data.first;

    if (first is! Map<String, dynamic>) {
      return '';
    }

    return first['sha']?.toString() ?? '';
  }

  @override
  Future<MenuData> load() async {
    final settings = await _settings();

    final file = await _getFile(
      owner: settings['owner']!,
      repo: settings['repo']!,
      path: settings['path']!,
      branch: settings['branch']!,
      token: settings['token']!,
    );

    final json =
        jsonDecode(file.content) as Map<String, dynamic>;

    return MenuData.fromJson(json);
  }

  @override
  Future<String> save(MenuData menu) async {
    final settings = await _settings();

    final file = await _getFile(
      owner: settings['owner']!,
      repo: settings['repo']!,
      path: settings['path']!,
      branch: settings['branch']!,
      token: settings['token']!,
    );

    final content = const JsonEncoder.withIndent('  ').convert(
      menu.toJson(),
    );

    final encoded =
        base64Encode(utf8.encode('$content\n'));

    final uri = Uri.parse(
      '$apiBase/repos/'
      '${settings['owner']!}/'
      '${settings['repo']!}/'
      'contents/${settings['path']!}',
    );

    final response = await http.put(
      uri,
      headers: _headers(settings['token']!),
      body: jsonEncode({
        'message': 'Update menu.json from Menu Admin',
        'content': encoded,
        'sha': file.sha,
        'branch': settings['branch']!,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در ذخیره menu.json: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }

    final responseData =
        jsonDecode(response.body) as Map<String, dynamic>;

    final commit = responseData['commit'];

    if (commit is Map<String, dynamic>) {
      return commit['sha']?.toString() ?? '';
    }

    return '';
  }
}
