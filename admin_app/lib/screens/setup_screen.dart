import 'package:flutter/material.dart';

import '../services/menu_repository.dart';
import '../services/app_settings.dart';
import '../services/github_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final formKey = GlobalKey<FormState>();

  final owner = TextEditingController();
  final repo = TextEditingController();
  final branch = TextEditingController();
  final path = TextEditingController();
  final token = TextEditingController();

  bool obscureToken = true;
  bool connecting = false;

  @override
  void dispose() {
    owner.dispose();
    repo.dispose();
    branch.dispose();
    path.dispose();
    token.dispose();
    super.dispose();
  }

  InputDecoration input(
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

  Future<void> _connect() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => connecting = true);

    try {
      await GitHubService.testConnection(
        owner: owner.text,
        repo: repo.text,
        branch: branch.text,
        path: path.text,
        token: token.text,
      );

      // Save GitHub settings after the direct connection test succeeds.
      await AppSettings.save(
        owner: owner.text.trim(),
        repo: repo.text.trim(),
        branch: branch.text.trim(),
        menuPath: path.text.trim(),
        siteUrl: '',
        token: token.text.trim(),
      );

      // Now load the real menu using the saved GitHub settings.
      final repository = RemoteMenuRepository();
      await repository.load();

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اتصال برقرار نشد:\n$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => connecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              children: [
                const Icon(
                  Icons.cloud_sync,
                  size: 76,
                ),

                const SizedBox(height: 24),

                const Text(
                  'اتصال به منوی رستوران',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'برای شروع، اطلاعات Repository گیت‌هاب خود را وارد کنید. '
                  'پس از اتصال، اطلاعات منو مستقیماً از menu.json خوانده می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 36),

                const Text(
                  'اطلاعات GitHub',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: owner,
                  textDirection: TextDirection.ltr,
                  decoration: input(
                    'GitHub Owner',
                    hint: 'username',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'GitHub Owner را وارد کنید';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: repo,
                  textDirection: TextDirection.ltr,
                  decoration: input(
                    'Repository',
                    hint: 'my-menu',
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
                  controller: branch,
                  textDirection: TextDirection.ltr,
                  decoration: input(
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
                  controller: path,
                  textDirection: TextDirection.ltr,
                  decoration: input(
                    'مسیر menu.json',
                    hint: 'src/data/menu.json',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'مسیر menu.json را وارد کنید';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: token,
                  textDirection: TextDirection.ltr,
                  obscureText: obscureToken,
                  decoration: input(
                    'GitHub Token',
                    hint: 'github_pat_...',
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'GitHub Token را وارد کنید';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                Text(
                  'Token فقط به صورت امن روی دستگاه ذخیره می‌شود.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 28),

                FilledButton.icon(
                  onPressed: connecting ? null : _connect,
                  icon: connecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Text(
                      connecting
                          ? 'در حال اتصال...'
                          : 'اتصال و دریافت منو',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'پس از اتصال، اطلاعات رستوران، دسته‌ها و محصولات '
                  'از Repository شما خوانده می‌شوند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
