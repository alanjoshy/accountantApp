// Static demo rows for Home Budget balance (presentation-only).

import 'package:flutter/material.dart';

class StaticBudgetRow {
  const StaticBudgetRow({
    required this.category,
    required this.spent,
    required this.limit,
    required this.color,
  });

  final String category;
  final double spent;
  final double limit;
  final Color color;
}

const staticBudgetBalanceRows = <StaticBudgetRow>[
  StaticBudgetRow(
    category: 'Food',
    spent: 4200,
    limit: 6000,
    color: Color(0xFF3B82F6),
  ),
  StaticBudgetRow(
    category: 'Rent',
    spent: 15000,
    limit: 15000,
    color: Color(0xFF22C55E),
  ),
  StaticBudgetRow(
    category: 'Travel',
    spent: 3100,
    limit: 4000,
    color: Color(0xFFF59E0B),
  ),
  StaticBudgetRow(
    category: 'Bills',
    spent: 2450,
    limit: 3000,
    color: Color(0xFFEF4444),
  ),
  StaticBudgetRow(
    category: 'Fun',
    spent: 2200,
    limit: 2000,
    color: Color(0xFFA855F7),
  ),
  StaticBudgetRow(
    category: 'Health',
    spent: 800,
    limit: 2500,
    color: Color(0xFF06B6D4),
  ),
];
