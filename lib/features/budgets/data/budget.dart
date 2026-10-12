// Budget category limit (web Budget subset).

class Budget {
  const Budget({
    required this.id,
    required this.category,
    required this.limit,
    this.period = 'monthly',
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  final String id;
  final String category;
  final double limit;
  final String period;
  /// Inclusive YYYY-MM-DD when using a custom date window.
  final String? startDate;
  final String? endDate;
  final String createdAt;

  bool get hasCustomRange =>
      startDate != null &&
      startDate!.isNotEmpty &&
      endDate != null &&
      endDate!.isNotEmpty;

  Budget copyWith({
    String? category,
    double? limit,
    String? period,
    String? startDate,
    String? endDate,
    bool clearDates = false,
  }) {
    return Budget(
      id: id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      period: period ?? this.period,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'limit': limit,
        'period': period,
        'createdAt': createdAt,
        if (startDate != null && startDate!.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate!.isNotEmpty) 'endDate': endDate,
      };

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      category: json['category'] as String? ?? '',
      limit: (json['limit'] as num).toDouble(),
      period: json['period'] as String? ?? 'monthly',
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
