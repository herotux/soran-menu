import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'customer_home_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool register = false;
  bool loading = false;
  final api = ApiService();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final data = await api.post(register ? '/api/auth/register' : '/api/auth/login', {
        'email': _email.text.trim(),
        'password': _password.text,
        if (register) 'name': _name.text.trim(),
      });
      await api.saveToken(data['access_token'] as String);
      final restaurants = await api.get('/api/auth/me/restaurants') as List;
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => restaurants.isNotEmpty ? const HomeScreen() : const CustomerHomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/icon/logo.png', height: 100),
                    const SizedBox(height: 20),
                    Text(register ? 'ساخت حساب کاربری' : 'ورود به SoranSib', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (register) ...[
                      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل'), validator: (v) => v == null || !v.contains('@') ? 'ایمیل معتبر وارد کنید' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور'), validator: (v) => v == null || v.length < 8 ? 'حداقل ۸ کاراکتر' : null),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'لطفاً صبر کنید...' : register ? 'ثبت نام' : 'ورود')),
                    TextButton(onPressed: loading ? null : () => setState(() => register = !register), child: Text(register ? 'قبلاً حساب دارم' : 'حساب کاربری ندارم')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
