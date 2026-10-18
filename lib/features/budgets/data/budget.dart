// Budget category limit (web Budget subset + icon/color).

class Budget {
  const Budget({
    required this.id,
    required this.category,
    required this.limit,
    this.period = 'monthly',
    this.startDate,
    this.endDate,
    // ignore: prefer_initializing_formals — keep public `icon`/`color` names
    String? icon = 'more',
    // ignore: prefer_initializing_formals
    String? color = '#3b82f6',
    required this.createdAt,
  })  : _icon = icon,
        _color = color;

  final String id;
  final String category;
  final double limit;
  final String period;
  /// Inclusive YYYY-MM-DD when using a custom date window.
  final String? startDate;
  final String? endDate;
  final String? _icon;
  final String? _color;
  final String createdAt;

  /// Hot-reload / legacy rows may leave style fields null.
  String get icon {
    final v = _icon;
    return (v == null || v.isEmpty) ? 'more' : v;
  }

  String get color {
    final v = _color;
    return (v == null || v.isEmpty) ? '#3b82f6' : v;
  }

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
    String? icon,
    String? color,
    bool clearDates = false,
  }) {
    return Budget(
      id: id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      period: period ?? this.period,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'limit': limit,
        'period': period,
        'createdAt': createdAt,
        'icon': icon,
        'color': color,
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
      icon: json['icon'] as String? ?? 'more',
      color: json['color'] as String? ?? '#3b82f6',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
