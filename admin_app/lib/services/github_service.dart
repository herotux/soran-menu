import 'package:http/http.dart' as http;


class GitHubService {
  static const String apiBase = 'https://api.github.com';

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
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer ${token.trim()}',
        'X-GitHub-Api-Version': '2022-11-28',
      },
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
}
