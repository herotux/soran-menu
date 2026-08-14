import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_settings.dart';

class GitHubDiscovery {
  final String owner;
  final String repo;
  final String branch;
  final String menuPath;

  const GitHubDiscovery({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.menuPath,
  });
}

class GitHubService {
  static const String apiBase = 'https://api.github.com';

  static Map<String, String> _headers(String token) {
    return {
      'Accept': 'application/vnd.github+json',
      'Authorization': 'Bearer $token',
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
    };
  }

  static Uri _uri(String value) {
    return Uri.parse(value);
  }

  static String? _ownerFromSiteUrl(String siteUrl) {
    final uri = Uri.tryParse(siteUrl.trim());

    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final host = uri.host.toLowerCase();

    // https://username.github.io/...
    if (host.endsWith('.github.io')) {
      final owner = host.substring(
        0,
        host.length - '.github.io'.length,
      );

      if (owner.isNotEmpty) {
        return owner;
      }
    }

    return null;
  }

  static String? _repoFromSiteUrl(String siteUrl) {
    final uri = Uri.tryParse(siteUrl.trim());

    if (uri == null) {
      return null;
    }

    final host = uri.host.toLowerCase();

    if (!host.endsWith('.github.io')) {
      return null;
    }

    final segments = uri.pathSegments
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return null;
    }

    return segments.first.trim();
  }

  static Future<Map<String, dynamic>> _getRepo({
    required String owner,
    required String repo,
    required String token,
  }) async {
    final response = await http.get(
      _uri(
        '$apiBase/repos/'
        '${Uri.encodeComponent(owner)}/'
        '${Uri.encodeComponent(repo)}',
      ),
      headers: _headers(token),
    );

    if (response.statusCode == 401) {
      throw Exception('GitHub Token نامعتبر است');
    }

    if (response.statusCode == 403) {
      throw Exception(
        'دسترسی GitHub کافی نیست یا درخواست‌ها محدود شده‌اند',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Repository پیدا نشد: '
        '$owner/$repo '
        '(HTTP ${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('پاسخ GitHub معتبر نیست');
    }

    return data;
  }

  static Future<String?> _findMenuInTree({
    required String owner,
    required String repo,
    required String branch,
    required String token,
  }) async {
    final response = await http.get(
      _uri(
        '$apiBase/repos/'
        '${Uri.encodeComponent(owner)}/'
        '${Uri.encodeComponent(repo)}/'
        'git/trees/'
        '${Uri.encodeComponent(branch)}'
        '?recursive=1',
      ),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      return null;
    }

    final tree = data['tree'];

    if (tree is! List) {
      return null;
    }

    final candidates = <String>[];

    for (final item in tree) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      if (item['type']?.toString() != 'blob') {
        continue;
      }

      final path = item['path']?.toString() ?? '';

      if (path.isEmpty) {
        continue;
      }

      final name = path.split('/').last.toLowerCase();

      if (name == 'menu.json') {
        candidates.add(path);
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    // مسیرهای رایج را ترجیح می‌دهیم.
    const preferred = [
      'menu.json',
      'src/data/menu.json',
      'data/menu.json',
      'public/menu.json',
      'website/public/menu.json',
      'assets/menu.json',
    ];

    for (final preferredPath in preferred) {
      for (final candidate in candidates) {
        if (candidate == preferredPath) {
          return candidate;
        }
      }
    }

    return candidates.first;
  }

  static Future<GitHubDiscovery> discover({
    required String siteUrl,
    required String token,
  }) async {
    final cleanToken = token.trim();

    if (siteUrl.trim().isEmpty) {
      throw Exception('آدرس سایت را وارد کنید');
    }

    if (cleanToken.isEmpty) {
      throw Exception('GitHub Token را وارد کنید');
    }

    final owner = _ownerFromSiteUrl(siteUrl);

    if (owner == null) {
      throw Exception(
        'از این آدرس سایت نمی‌توان صاحب GitHub را تشخیص داد.\n'
        'فعلاً آدرس GitHub Pages مثل username.github.io وارد کنید.',
      );
    }

    final urlRepo = _repoFromSiteUrl(siteUrl);

    final repositories = <Map<String, dynamic>>[];

    // اگر Repository از URL قابل تشخیص باشد،
    // اول همان را امتحان می‌کنیم.
    if (urlRepo != null && urlRepo.isNotEmpty) {
      try {
        final data = await _getRepo(
          owner: owner,
          repo: urlRepo,
          token: cleanToken,
        );

        repositories.add(data);
      } catch (_) {
        // بعداً Repositoryهای دیگر بررسی می‌شوند.
      }
    }

    // Repositoryهای کاربر را می‌گیریم.
    var page = 1;

    while (page <= 10) {
      final response = await http.get(
        _uri(
          '$apiBase/user/repos'
          '?per_page=100'
          '&page=$page'
          '&sort=updated'
          '&direction=desc',
        ),
        headers: _headers(cleanToken),
      );

      if (response.statusCode == 401) {
        throw Exception('GitHub Token نامعتبر است');
      }

      if (response.statusCode != 200) {
        break;
      }

      final data = jsonDecode(response.body);

      if (data is! List || data.isEmpty) {
        break;
      }

      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final itemOwner =
            (item['owner'] as Map?)?['login']?.toString();

        if (itemOwner?.toLowerCase() != owner.toLowerCase()) {
          continue;
        }

        final fullName = item['full_name']?.toString() ?? '';

        if (!repositories.any(
          (repo) => repo['full_name']?.toString() == fullName,
        )) {
          repositories.add(item);
        }
      }

      if (data.length < 100) {
        break;
      }

      page++;
    }

    // اگر user/repos به هر دلیل Repositoryها را نداد،
    // Repositoryای که از URL پیدا کرده بودیم را بررسی می‌کنیم.
    if (repositories.isEmpty && urlRepo != null) {
      final data = await _getRepo(
        owner: owner,
        repo: urlRepo,
        token: cleanToken,
      );

      repositories.add(data);
    }

    if (repositories.isEmpty) {
      throw Exception(
        'هیچ Repository قابل دسترسی برای $owner پیدا نشد',
      );
    }

    // Repositoryهای کاندید را بررسی می‌کنیم.
    for (final repository in repositories) {
      final repoName =
          repository['name']?.toString() ?? '';

      if (repoName.isEmpty) {
        continue;
      }

      final defaultBranch =
          repository['default_branch']?.toString() ?? 'main';

      final branches = <String>[
        defaultBranch,
        if (defaultBranch != 'main') 'main',
        if (defaultBranch != 'master') 'master',
      ];

      for (final branch in branches) {
        final menuPath = await _findMenuInTree(
          owner: owner,
          repo: repoName,
          branch: branch,
          token: cleanToken,
        );

        if (menuPath != null) {
          return GitHubDiscovery(
            owner: owner,
            repo: repoName,
            branch: branch,
            menuPath: menuPath,
          );
        }
      }
    }

    throw Exception(
      'فایل menu.json در Repositoryهای $owner پیدا نشد.',
    );
  }

  static Future<void> testConnection({
    required String owner,
    required String repo,
    required String branch,
    required String path,
    required String token,
  }) async {
    if (owner.trim().isEmpty ||
        repo.trim().isEmpty ||
        branch.trim().isEmpty ||
        path.trim().isEmpty ||
        token.trim().isEmpty) {
      throw Exception('اطلاعات GitHub کامل نیست');
    }

    final uri = _uri(
      '$apiBase/repos/'
      '${Uri.encodeComponent(owner.trim())}/'
      '${Uri.encodeComponent(repo.trim())}/'
      'contents/${path.trim()}'
      '?ref=${Uri.encodeQueryComponent(branch.trim())}',
    );

    final response = await http.get(
      uri,
      headers: _headers(token.trim()),
    );

    if (response.statusCode == 401) {
      throw Exception('GitHub Token نامعتبر است');
    }

    if (response.statusCode == 403) {
      throw Exception(
        'دسترسی GitHub کافی نیست یا درخواست‌ها محدود شده‌اند',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'Repository یا menu.json پیدا نشد',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'خطای GitHub: HTTP ${response.statusCode}',
      );
    }
  }

  static Future<String> uploadImage({
    required String fileName,
    required List<int> bytes,
  }) async {
    final owner = await AppSettings.getOwner();
    final repo = await AppSettings.getRepo();
    final branch = await AppSettings.getBranch();
    final token = await AppSettings.getToken();

    if (owner.isEmpty ||
        repo.isEmpty ||
        branch.isEmpty ||
        token.isEmpty) {
      throw Exception('تنظیمات GitHub کامل نیست');
    }

    final safeFileName = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final path = 'website/public/images/$safeFileName';

    final uri = _uri(
      '$apiBase/repos/'
      '${Uri.encodeComponent(owner)}/'
      '${Uri.encodeComponent(repo)}/'
      'contents/$path',
    );

    String? sha;

    final existing = await http.get(
      uri,
      headers: _headers(token),
    );

    if (existing.statusCode == 200) {
      final data = jsonDecode(existing.body);

      if (data is Map<String, dynamic>) {
        sha = data['sha']?.toString();
      }
    } else if (existing.statusCode != 404) {
      throw Exception(
        'خطا در بررسی فایل عکس: '
        'HTTP ${existing.statusCode} ${existing.body}',
      );
    }

    final encoded = base64Encode(bytes);

    final body = <String, dynamic>{
      'message': 'Upload menu image: $safeFileName',
      'content': encoded,
      'branch': branch,
    };

    if (sha != null && sha.isNotEmpty) {
      body['sha'] = sha;
    }

    final response = await http.put(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201 &&
        response.statusCode != 200) {
      throw Exception(
        'خطا در آپلود عکس: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }

    return '/images/$safeFileName';
  }

  static Future<void> deleteImage({
    required String fileName,
  }) async {
    final owner = await AppSettings.getOwner();
    final repo = await AppSettings.getRepo();
    final branch = await AppSettings.getBranch();
    final token = await AppSettings.getToken();

    if (owner.isEmpty ||
        repo.isEmpty ||
        branch.isEmpty ||
        token.isEmpty) {
      throw Exception('تنظیمات GitHub کامل نیست');
    }

    final normalizedFileName = fileName
        .trim()
        .replaceFirst(RegExp(r'^/images/'), '')
        .replaceFirst(RegExp(r'^images/'), '');

    final safeFileName = normalizedFileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final path = 'website/public/images/$safeFileName';

    final uri = _uri(
      '$apiBase/repos/'
      '${Uri.encodeComponent(owner)}/'
      '${Uri.encodeComponent(repo)}/'
      'contents/$path',
    );

    final existing = await http.get(
      uri,
      headers: _headers(token),
    );

    if (existing.statusCode == 404) {
      return;
    }

    if (existing.statusCode != 200) {
      throw Exception(
        'خطا در بررسی عکس برای حذف: '
        'HTTP ${existing.statusCode} ${existing.body}',
      );
    }

    final data = jsonDecode(existing.body);

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'پاسخ GitHub برای فایل عکس معتبر نیست',
      );
    }

    final sha = data['sha']?.toString();

    if (sha == null || sha.isEmpty) {
      throw Exception('SHA عکس از GitHub دریافت نشد');
    }

    final body = <String, dynamic>{
      'message': 'Delete menu image: $safeFileName',
      'sha': sha,
      'branch': branch,
    };

    final response = await http.delete(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در حذف عکس: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }
  }
}
