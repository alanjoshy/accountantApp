// Spend / earn category lists (web categories.ts).

import '../data/transaction.dart';

const spendCategories = <String>[
  'Food',
  'Grocery',
  'Transport',
  'Shopping',
  'Bills',
  'Health',
  'Entertainment',
  'Investment',
  'Other',
];

const earnCategories = <String>[
  'Salary',
  'Freelance',
  'Investment',
  'Other',
];

List<String> categoriesForType(TransactionType type) {
  return type == TransactionType.expense
      ? List<String>.from(spendCategories)
      : List<String>.from(earnCategories);
}

List<String> expenseCategoriesWithBudgets(Iterable<String> budgetCategories) {
  final list = <String>[...spendCategories];
  final seen = {for (final c in list) c.toLowerCase()};
  for (final raw in budgetCategories) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    list.add(name);
  }
  return list;
}

List<String> sortCategoriesByUsage(
  List<String> categories,
  List<MoneyTransaction> transactions, {
  int days = 90,
}) {
  final cutoff = DateTime.now().subtract(Duration(days: days));
  final counts = <String, int>{};
  for (final t in transactions) {
    if (t.type != TransactionType.expense) continue;
    final d = DateTime.tryParse(t.date)?.toLocal();
    if (d == null || d.isBefore(cutoff)) continue;
    final key = t.category.trim();
    if (key.isEmpty) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final sorted = [...categories]
    ..sort((a, b) {
      final ca = counts[a] ?? 0;
      final cb = counts[b] ?? 0;
      if (cb != ca) return cb.compareTo(ca);
      return a.compareTo(b);
    });
  return sorted;
}

String pickDefaultExpenseCategory(
  List<String> categories,
  List<MoneyTransaction> transactions, {
  String fallback = 'Food',
  int days = 90,
}) {
  if (categories.isEmpty) return fallback;
  final sorted = sortCategoriesByUsage(categories, transactions, days: days);
  final cutoff = DateTime.now().subtract(Duration(days: days));
  final hasUsage = transactions.any((t) {
    if (t.type != TransactionType.expense) return false;
    final d = DateTime.tryParse(t.date)?.toLocal();
    if (d == null || d.isBefore(cutoff)) return false;
    return t.category.trim().isNotEmpty;
  });
  if (hasUsage && sorted.isNotEmpty) return sorted.first;
  if (categories.any((c) => c == fallback)) return fallback;
  return categories.first;
}
