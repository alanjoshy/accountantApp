import 'package:accountant/features/budgets/data/budget.dart';
import 'package:accountant/features/budgets/domain/budget_logic.dart';
import 'package:accountant/features/transactions/presentation/widgets/category_option_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveCategoryStyle uses matching budget icon and color', () {
    final style = resolveCategoryStyle(
      'Food',
      budgets: const [
        Budget(
          id: '1',
          category: 'Food',
          limit: 1000,
          createdAt: '',
          icon: 'coffee',
          color: '#ec4899',
        ),
      ],
    );
    expect(style.icon, Icons.coffee_rounded);
    expect(style.color, const Color(0xFFEC4899));
  });

  test('resolveCategoryStyle falls back to category defaults', () {
    final style = resolveCategoryStyle('Food');
    expect(style.icon, Icons.restaurant_rounded);
    expect(style.color, const Color(0xFF3B82F6));
  });

  testWidgets('category name chip shows tinted icon next to the label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryNameChip(category: 'Food'),
        ),
      ),
    );

    expect(find.text('Food'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
  });

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
