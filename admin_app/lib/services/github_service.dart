import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_settings.dart';

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
      throw Exception('همه اطلاعات GitHub را وارد کنید');
    }

    final uri = Uri.parse(
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

    if (response.statusCode != 200) {
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
          'Repository یا مسیر menu.json پیدا نشد',
        );
      }

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

    final uri = Uri.parse(
      '$apiBase/repos/'
      '${Uri.encodeComponent(owner)}/'
      '${Uri.encodeComponent(repo)}/'
      'contents/$path',
    );

    String? sha;

    // اگر فایل قبلاً وجود داشته باشد، SHA آن را می‌گیریم
    // تا GitHub اجازه آپدیت فایل را بدهد.
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

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
        'خطا در آپلود عکس: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }

    return '/images/$safeFileName';
  }
}
