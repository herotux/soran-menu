import 'package:flutter/material.dart';
import 'log_viewer_screen.dart';

import '../services/app_settings.dart';
import '../services/github_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final formKey = GlobalKey<FormState>();

  final ownerController = TextEditingController();
  final repoController = TextEditingController();
  final branchController = TextEditingController();
  final pathController = TextEditingController();
  final siteUrlController = TextEditingController();
  final tokenController = TextEditingController();

  bool loading = true;
  bool saving = false;
  bool obscureToken = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ownerController.text = await AppSettings.getOwner();
    repoController.text = await AppSettings.getRepo();
    branchController.text = await AppSettings.getBranch();
    pathController.text = await AppSettings.getMenuPath();
    siteUrlController.text = await AppSettings.getSiteUrl();

    final token = await AppSettings.getToken();
    tokenController.text = token;

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    if (!formKey.currentState!.validate()) return;

    try {
      await GitHubService.testConnection(
        owner: ownerController.text,
        repo: repoController.text,
        branch: branchController.text,
        path: pathController.text,
        token: tokenController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اتصال به GitHub با موفقیت برقرار شد ✓'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اتصال: $e'),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      saving = true;
    });

    try {
      await AppSettings.save(
        owner: ownerController.text,
        repo: repoController.text,
        branch: branchController.text,
        menuPath: pathController.text,
        siteUrl: siteUrlController.text,
        token: tokenController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تنظیمات با موفقیت ذخیره شد'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ذخیره تنظیمات: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ownerController.dispose();
    repoController.dispose();
    branchController.dispose();
    pathController.dispose();
    siteUrlController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  InputDecoration decoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات اتصال GitHub'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Repository',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'اطلاعات Repository خود را وارد کنید. '
              'این اپ برای هر GitHub Repository قابل استفاده است.',
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: ownerController,
              textDirection: TextDirection.ltr,
              decoration: decoration(
                'GitHub Owner',
                hint: 'مثلاً herotux',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'نام کاربری GitHub را وارد کنید';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: repoController,
              textDirection: TextDirection.ltr,
              decoration: decoration(
                'Repository',
                hint: 'مثلاً soran-menu',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'نام Repository را وارد کنید';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: branchController,
              textDirection: TextDirection.ltr,
              decoration: decoration(
                'Branch',
                hint: 'main',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Branch را وارد کنید';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: pathController,
              textDirection: TextDirection.ltr,
              decoration: decoration(
                'مسیر menu.json',
                hint: 'src/data/menu.json',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'مسیر فایل menu.json را وارد کنید';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: siteUrlController,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              decoration: decoration(
                'آدرس سایت',
                hint: 'https://username.github.io/repository/',
              ),
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: tokenController,
              textDirection: TextDirection.ltr,
              obscureText: obscureToken,
              decoration: decoration(
                'GitHub Token',
                hint: 'ghp_... یا github_pat_...',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscureToken = !obscureToken;
                    });
                  },
                  icon: Icon(
                    obscureToken
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Token به صورت امن روی گوشی ذخیره می‌شود و داخل سورس برنامه قرار نمی‌گیرد.',
              style: TextStyle(
                color: Color(0xFF5F6368),
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: saving ? null : _testConnection,
              icon: const Icon(Icons.cloud_done),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('تست اتصال به GitHub'),
              ),
            ),

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  saving
                      ? 'در حال ذخیره...'
                      : 'ذخیره تنظیمات',
                ),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LogViewerScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.article_outlined),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('مشاهده لاگ‌های برنامه'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
