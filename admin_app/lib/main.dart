import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MenuAdminApp());
}

class MenuAdminApp extends StatelessWidget {
  const MenuAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مدیریت منو',
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazir',
        colorSchemeSeed: const Color(0xFF62FF00),
        scaffoldBackgroundColor: const Color(0xFF101010),
        brightness: Brightness.light,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}