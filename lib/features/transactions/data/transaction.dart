// Money movement record (web Transaction subset).

import '../../accounts/domain/payments.dart';

enum TransactionType { income, expense, transfer }

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.createdAt,
    this.note,
    this.tags = const [],
    this.paymentMode,
    this.accountId,
    this.toAccountId,
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String date;
  final String createdAt;
  final String? note;
  final List<String> tags;
  final PaymentMode? paymentMode;
  final String? accountId;
  final String? toAccountId;

  MoneyTransaction copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    String? date,
    String? note,
    List<String>? tags,
    PaymentMode? paymentMode,
    String? accountId,
    String? toAccountId,
    bool clearNote = false,
    bool clearPaymentMode = false,
    bool clearAccountId = false,
    bool clearToAccountId = false,
  }) {
    return MoneyTransaction(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      createdAt: createdAt,
      note: clearNote ? null : (note ?? this.note),
      tags: tags ?? this.tags,
      paymentMode:
          clearPaymentMode ? null : (paymentMode ?? this.paymentMode),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      toAccountId:
          clearToAccountId ? null : (toAccountId ?? this.toAccountId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'category': category,
        'date': date,
        'createdAt': createdAt,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (tags.isNotEmpty) 'tags': tags,
        if (paymentMode != null) 'paymentMode': paymentMode!.name,
        if (accountId != null && accountId!.isNotEmpty) 'accountId': accountId,
        if (toAccountId != null && toAccountId!.isNotEmpty)
          'toAccountId': toAccountId,
      };

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'expense';
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => TransactionType.expense,
    );
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    final accountRaw = json['accountId'];
    final toRaw = json['toAccountId'];
    return MoneyTransaction(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: type,
      category: json['category'] as String? ?? '',
      date: json['date']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['date']?.toString() ?? '',
      note: json['note'] as String?,
      tags: [for (final t in rawTags) t.toString()],
      paymentMode: tryParsePaymentMode(json['paymentMode']),
      accountId: accountRaw?.toString(),
      toAccountId: toRaw?.toString(),
    );
  }
}
