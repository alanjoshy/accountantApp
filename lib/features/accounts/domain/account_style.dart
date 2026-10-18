// Icon + color options for money accounts.

import 'package:flutter/material.dart';

enum AccountKind { bank, cash, wallet, other }

const accountColorOptions = <String>[
  '#3b82f6',
  '#22c55e',
  '#f59e0b',
  '#ef4444',
  '#a855f7',
  '#06b6d4',
  '#ec4899',
  '#84cc16',
  '#f97316',
  '#6366f1',
];

const accountIconOptions = <String>[
  'bank',
  'cash',
  'wallet',
  'card',
  'savings',
  'business',
  'phone',
  'more',
];

Color accountColorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return const Color(0xFF3B82F6);
  return Color(int.parse('FF$cleaned', radix: 16));
}

IconData accountIconData(String key) {
  return switch (key) {
    'bank' => Icons.account_balance_rounded,
    'cash' => Icons.payments_rounded,
    'wallet' => Icons.account_balance_wallet_rounded,
    'card' => Icons.credit_card_rounded,
    'savings' => Icons.savings_rounded,
    'business' => Icons.business_rounded,
    'phone' => Icons.phone_iphone_rounded,
    _ => Icons.account_balance_rounded,
  };
}

String defaultIconForKind(AccountKind kind) {
  return switch (kind) {
    AccountKind.bank => 'bank',
    AccountKind.cash => 'cash',
    AccountKind.wallet => 'wallet',
    AccountKind.other => 'more',
  };
}

String defaultColorForKind(AccountKind kind) {
  return switch (kind) {
    AccountKind.bank => '#3b82f6',
    AccountKind.cash => '#22c55e',
    AccountKind.wallet => '#a855f7',
    AccountKind.other => '#06b6d4',
  };
}

String accountKindLabel(AccountKind kind) {
  return switch (kind) {
    AccountKind.bank => 'Bank account',
    AccountKind.cash => 'In-hand cash',
    AccountKind.wallet => 'Wallet',
    AccountKind.other => 'Other',
  };
}

String accountKindHint(AccountKind kind) {
  return switch (kind) {
    AccountKind.bank => 'Savings or current',
    AccountKind.cash => 'Wallet / pocket cash',
    AccountKind.wallet => 'Paytm, Amazon Pay, etc.',
    AccountKind.other => 'Anything else',
  };
}

AccountKind normalizeAccountKind(Object? value) {
  final raw = value?.toString().toLowerCase();
  return switch (raw) {
    'cash' => AccountKind.cash,
    'wallet' => AccountKind.wallet,
    'other' => AccountKind.other,
    _ => AccountKind.bank,
  };
}
