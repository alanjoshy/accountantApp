import 'package:flutter_test/flutter_test.dart';

import 'package:accountant/app/app.dart';

void main() {
  testWidgets('Accountant app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AccountantApp());

    expect(find.text('Accountant'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}