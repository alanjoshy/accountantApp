// Money movement record (web Transaction subset).

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

  MoneyTransaction copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    String? date,
    String? note,
    List<String>? tags,
    bool clearNote = false,
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
      };

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'expense';
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => TransactionType.expense,
    );
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    return MoneyTransaction(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      type: type,
      category: json['category'] as String? ?? '',
      date: json['date'] as String,
      createdAt: json['createdAt'] as String? ?? json['date'] as String,
      note: json['note'] as String?,
      tags: [for (final t in rawTags) t.toString()],
    );
  }
}
