import 'package:accountant/features/budgets/domain/budget_logic.dart';
import 'package:accountant/features/transactions/presentation/widgets/category_option_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category chip shows this-cycle remaining and a progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryOptionChip(
            label: 'Food',
            selected: false,
            usage: const CategoryCycleUsage(spent: 200, limit: 1000),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Food'), findsOneWidget);
    expect(find.textContaining('% used'), findsNothing);
    expect(find.textContaining('left'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('category chip marks overspent allocation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryOptionChip(
            label: 'Food',
            selected: false,
            usage: const CategoryCycleUsage(spent: 1200, limit: 1000),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Over'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
