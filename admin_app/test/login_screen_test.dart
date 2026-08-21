import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soransib/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders registration controls', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('ورود به SoranSib'), findsOneWidget);
    expect(find.text('حساب کاربری ندارم'), findsOneWidget);
  });
}
