// Planned limits for the upcoming cash-flow cycle (web NextCycleBudget).

class NextCycleBudget {
  const NextCycleBudget({
    required this.cycleStart,
    required this.monthlyIncome,
    required this.limits,
    this.carryForward = true,
    required this.preparedAt,
  });

  final String cycleStart;
  final double monthlyIncome;
  final Map<String, double> limits;
  final bool carryForward;
  final String preparedAt;

  NextCycleBudget copyWith({
    String? cycleStart,
    double? monthlyIncome,
    Map<String, double>? limits,
    bool? carryForward,
    String? preparedAt,
  }) {
    return NextCycleBudget(
      cycleStart: cycleStart ?? this.cycleStart,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      limits: limits ?? this.limits,
      carryForward: carryForward ?? this.carryForward,
      preparedAt: preparedAt ?? this.preparedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'cycleStart': cycleStart,
        'monthlyIncome': monthlyIncome,
        'limits': {
          for (final e in limits.entries) e.key: e.value,
        },
        'carryForward': carryForward,
        'preparedAt': preparedAt,
      };

  factory NextCycleBudget.fromJson(Map<String, dynamic> json) {
    final rawLimits = json['limits'] as Map<String, dynamic>? ?? const {};
    return NextCycleBudget(
      cycleStart: json['cycleStart'] as String? ?? '',
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 0,
      limits: {
        for (final e in rawLimits.entries)
          e.key: (e.value as num?)?.toDouble() ?? 0,
      },
      carryForward: json['carryForward'] as bool? ?? true,
      preparedAt: json['preparedAt'] as String? ?? '',
    );
  }
}
