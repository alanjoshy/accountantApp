// Fixed payment modes (web payments.ts).

import 'package:flutter/material.dart';

enum PaymentMode { upi, bank, card, cash }

class PaymentModeInfo {
  const PaymentModeInfo({
    required this.id,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final PaymentMode id;
  final String label;
  final String hint;
  final IconData icon;
}

const paymentModes = <PaymentModeInfo>[
  PaymentModeInfo(
    id: PaymentMode.upi,
    label: 'UPI',
    hint: 'GPay, PhonePe, BHIM and more',
    icon: Icons.qr_code_2_rounded,
  ),
  PaymentModeInfo(
    id: PaymentMode.bank,
    label: 'Bank',
    hint: 'NEFT, IMPS, net banking',
    icon: Icons.account_balance_rounded,
  ),
  PaymentModeInfo(
    id: PaymentMode.card,
    label: 'Card',
    hint: 'Debit or credit card',
    icon: Icons.credit_card_rounded,
  ),
  PaymentModeInfo(
    id: PaymentMode.cash,
    label: 'Cash',
    hint: 'Physical cash',
    icon: Icons.payments_rounded,
  ),
];

String paymentModeLabel(PaymentMode? id) {
  if (id == null) return '—';
  for (final m in paymentModes) {
    if (m.id == id) return m.label;
  }
  return '—';
}

IconData paymentModeIcon(PaymentMode id) {
  for (final m in paymentModes) {
    if (m.id == id) return m.icon;
  }
  return Icons.payments_rounded;
}

PaymentMode normalizePaymentMode(Object? value) {
  if (value is PaymentMode) return value;
  final raw = value?.toString().toLowerCase();
  return switch (raw) {
    'upi' => PaymentMode.upi,
    'bank' => PaymentMode.bank,
    'card' => PaymentMode.card,
    'cash' => PaymentMode.cash,
    _ => PaymentMode.upi,
  };
}

PaymentMode? tryParsePaymentMode(Object? value) {
  if (value == null) return null;
  final raw = value.toString().toLowerCase();
  return switch (raw) {
    'upi' => PaymentMode.upi,
    'bank' => PaymentMode.bank,
    'card' => PaymentMode.card,
    'cash' => PaymentMode.cash,
    _ => null,
  };
}
