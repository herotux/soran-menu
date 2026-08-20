import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/github_service.dart';
import '../repositories/github_menu_repository.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final formKey = GlobalKey<FormState>();

  final siteUrl = TextEditingController();
  final token = TextEditingController();

  bool obscureToken = true;
  bool connecting = false;

  @override
  void dispose() {
    siteUrl.dispose();
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
    if (!formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      connecting = true;
    });

    try {
      final discovery = await GitHubService.discover(
        siteUrl: siteUrl.text.trim(),
        token: token.text.trim(),
      );

      await AppSettings.save(
        owner: discovery.owner,
        repo: discovery.repo,
        branch: discovery.branch,
        menuPath: discovery.menuPath,
        siteUrl: siteUrl.text.trim(),
        token: token.text.trim(),
      );

      final repository = GitHubMenuRepository();

      await repository.load();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'منو پیدا شد: '
            '${discovery.owner}/${discovery.repo}'
            ' → ${discovery.menuPath}',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'اتصال برقرار نشد:\n$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          connecting = false;
        });
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
              padding: const EdgeInsets.fromLTRB(
                24,
                48,
                24,
                32,
              ),
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

                const Text(
                  'فقط آدرس سایت و GitHub Token را وارد کنید. '
                  'اپ Repository، Branch و menu.json را '
                  'به‌صورت خودکار پیدا می‌کند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF80868B),
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 36),

                const Text(
                  'اطلاعات اتصال',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: siteUrl,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  decoration: input(
                    'آدرس سایت',
                    hint: 'https://username.github.io/',
                  ),
                  validator: (value) {
                    final valueTrimmed =
                        value?.trim() ?? '';

                    if (valueTrimmed.isEmpty) {
                      return 'آدرس سایت را وارد کنید';
                    }

                    final uri =
                        Uri.tryParse(valueTrimmed);

                    if (uri == null ||
                        uri.scheme != 'https' ||
                        uri.host.isEmpty) {
                      return 'آدرس سایت معتبر نیست';
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
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'GitHub Token را وارد کنید';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                const Text(
                  'Token فقط به‌صورت امن روی دستگاه ذخیره می‌شود '
                  'و داخل سورس برنامه قرار نمی‌گیرد.',
                  style: TextStyle(
                    color: Color(0xFF5F6368),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 28),

                FilledButton.icon(
                  onPressed:
                      connecting ? null : _connect,
                  icon: connecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Text(
                      connecting
                          ? 'در حال پیدا کردن منو...'
                          : 'اتصال و دریافت منو',
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'اپ به‌صورت خودکار موارد زیر را پیدا می‌کند:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5F6368),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  '✓ GitHub Owner\n'
                  '✓ Repository\n'
                  '✓ Branch\n'
                  '✓ menu.json',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.8,
                    color: Color(0xFF5F6368),
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
