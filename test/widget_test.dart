// Smoke test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accountant/app/app.dart';
import 'package:accountant/app/bootstrap.dart';
import 'package:accountant/features/shell/presentation/screens/main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await bootstrap();
  });

  testWidgets('shows lock screen', (tester) async {
    await tester.pumpWidget(const AccountantApp());
    await tester.pumpAndSettle();

    expect(find.text('Set your PIN'), findsOneWidget);
    expect(find.textContaining('4–6 digit PIN'), findsWidgets);
  });

  testWidgets('switches tabs on phone, tablet, and desktop sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(768, 1024),
      Size(1440, 900),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      expect(find.text('Accountant'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.timeline_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pumpAndSettle();
      expect(find.text('Accountant'), findsNothing);

      await tester.tap(find.byIcon(Icons.pie_chart_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Budgets'), findsWidgets);

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      expect(find.text('More'), findsWidgets);

      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Accountant'), findsOneWidget);
    }
  });
}
