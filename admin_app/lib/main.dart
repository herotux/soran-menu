import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F7F7),
          foregroundColor: Color(0xFF202124),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: Color(0xFFE0E0E0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: accentColor,
              width: 2,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE8E8E8),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}
