// Future budget reserve — does not create a transaction; only plans category limits.

class PlannedReserve {
  const PlannedReserve({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dueDate,
    this.note,
    this.appliedCycleStart,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final double amount;
  final String category;

  /// Day the expense is expected (YYYY-MM-DD).
  final String dueDate;
  final String? note;

  /// Cash-flow cycle start this reserve was folded into (next-cycle plan).
  final String? appliedCycleStart;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  bool get isActive => deletedAt == null;

  PlannedReserve copyWith({
    String? title,
    double? amount,
    String? category,
    String? dueDate,
    String? note,
    bool clearNote = false,
    String? appliedCycleStart,
    bool clearAppliedCycleStart = false,
    String? deletedAt,
    bool clearDeletedAt = false,
    String? updatedAt,
  }) {
    return PlannedReserve(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      note: clearNote ? null : (note ?? this.note),
      appliedCycleStart: clearAppliedCycleStart
          ? null
          : (appliedCycleStart ?? this.appliedCycleStart),
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
        if (note != null && note!.isNotEmpty) 'note': note,
        if (appliedCycleStart != null && appliedCycleStart!.isNotEmpty)
          'appliedCycleStart': appliedCycleStart,
        if (deletedAt != null && deletedAt!.isNotEmpty) 'deletedAt': deletedAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory PlannedReserve.fromJson(Map<String, dynamic> json) {
    return PlannedReserve(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      note: json['note'] as String?,
      appliedCycleStart: json['appliedCycleStart'] as String?,
      deletedAt: json['deletedAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
