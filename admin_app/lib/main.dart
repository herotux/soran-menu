import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/customer_home_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MenuAdminApp());
}

class MenuAdminApp extends StatelessWidget {
  const MenuAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF62FF00);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SoranSib',
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazir',
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: accentColor, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F7F7), foregroundColor: Color(0xFF202124), elevation: 0),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      home: const Directionality(textDirection: TextDirection.rtl, child: AppGate()),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});
  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final api = ApiService();
  bool loading = true;
  Widget? destination;

  @override
  void initState() {
    super.initState();
    resolve();
  }

  Future<void> resolve() async {
    try {
      if (!await api.hasToken()) {
        destination = const LoginScreen();
      } else {
        final restaurants = await api.get('/api/auth/me/restaurants') as List;
        destination = restaurants.isNotEmpty ? const HomeScreen() : const CustomerHomeScreen();
      }
    } catch (_) {
      await api.clearToken();
      destination = const LoginScreen();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading ? const Scaffold(body: Center(child: CircularProgressIndicator())) : destination!;
}
