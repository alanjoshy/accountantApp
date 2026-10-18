// Planned outflow (web ScheduledPayment).

import '../../accounts/domain/payments.dart';

enum ScheduleRepeat { once, daily, weekly, monthly }

enum ScheduleStatus { pending, paid, skipped, cancelled }

class ScheduledPayment {
  const ScheduledPayment({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dueDate,
    required this.status,
    required this.repeat,
    required this.accountId,
    required this.paymentMode,
    this.tags = const [],
    this.note,
    this.paidAt,
    this.transactionId,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final String dueDate;
  final ScheduleStatus status;
  final ScheduleRepeat repeat;
  final String accountId;
  final PaymentMode paymentMode;
  final List<String> tags;
  final String? note;
  final String? paidAt;
  final String? transactionId;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  ScheduledPayment copyWith({
    String? title,
    double? amount,
    String? category,
    String? dueDate,
    ScheduleStatus? status,
    ScheduleRepeat? repeat,
    String? accountId,
    PaymentMode? paymentMode,
    List<String>? tags,
    String? note,
    bool clearNote = false,
    String? paidAt,
    bool clearPaidAt = false,
    String? transactionId,
    bool clearTransactionId = false,
    String? deletedAt,
    bool clearDeletedAt = false,
    String? updatedAt,
  }) {
    return ScheduledPayment(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      repeat: repeat ?? this.repeat,
      accountId: accountId ?? this.accountId,
      paymentMode: paymentMode ?? this.paymentMode,
      tags: tags ?? this.tags,
      note: clearNote ? null : (note ?? this.note),
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      transactionId:
          clearTransactionId ? null : (transactionId ?? this.transactionId),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'dueDate': dueDate,
        'status': status.name,
        'repeat': repeat.name,
        'accountId': accountId,
        'paymentMode': paymentMode.name,
        if (tags.isNotEmpty) 'tags': tags,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (paidAt != null) 'paidAt': paidAt,
        if (transactionId != null) 'transactionId': transactionId,
        if (deletedAt != null) 'deletedAt': deletedAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ScheduledPayment.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    return ScheduledPayment(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      status: _status(json['status']),
      repeat: _repeat(json['repeat']),
      accountId: json['accountId'] as String? ?? '',
      paymentMode: normalizePaymentMode(json['paymentMode']),
      tags: tagsRaw is List
          ? [for (final t in tagsRaw) t.toString()]
          : const [],
      note: json['note'] as String?,
      paidAt: json['paidAt'] as String?,
      transactionId: json['transactionId'] as String?,
      deletedAt: json['deletedAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  static ScheduleStatus _status(Object? raw) {
    final s = raw?.toString().toLowerCase();
    return switch (s) {
      'paid' => ScheduleStatus.paid,
      'skipped' => ScheduleStatus.skipped,
      'cancelled' || 'canceled' => ScheduleStatus.cancelled,
      _ => ScheduleStatus.pending,
    };
  }

  static ScheduleRepeat _repeat(Object? raw) {
    final s = raw?.toString().toLowerCase();
    return switch (s) {
      'daily' => ScheduleRepeat.daily,
      'weekly' => ScheduleRepeat.weekly,
      'monthly' => ScheduleRepeat.monthly,
      _ => ScheduleRepeat.once,
    };
  }
}
