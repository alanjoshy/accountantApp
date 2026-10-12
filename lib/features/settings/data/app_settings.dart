// App settings for cash flow + tags + next-cycle draft.

import '../../budgets/data/next_cycle_budget.dart';

class AppSettings {
  const AppSettings({
    this.tags = const [],
    this.monthlyIncome = 0,
    this.cycleStartDay = 1,
    this.nextCycleBudget,
    this.activeCycleStart,
  });

  final List<String> tags;
  final double monthlyIncome;
  final int cycleStartDay;
  final NextCycleBudget? nextCycleBudget;
  final String? activeCycleStart;

  AppSettings copyWith({
    List<String>? tags,
    double? monthlyIncome,
    int? cycleStartDay,
    NextCycleBudget? nextCycleBudget,
    String? activeCycleStart,
    bool clearNextCycleBudget = false,
    bool clearActiveCycleStart = false,
  }) {
    return AppSettings(
      tags: tags ?? this.tags,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      nextCycleBudget: clearNextCycleBudget
          ? null
          : (nextCycleBudget ?? this.nextCycleBudget),
      activeCycleStart: clearActiveCycleStart
          ? null
          : (activeCycleStart ?? this.activeCycleStart),
    );
  }

  Map<String, dynamic> toJson() => {
        'tags': tags,
        'monthlyIncome': monthlyIncome,
        'cycleStartDay': cycleStartDay,
        if (nextCycleBudget != null)
          'nextCycleBudget': nextCycleBudget!.toJson(),
        if (activeCycleStart != null && activeCycleStart!.isNotEmpty)
          'activeCycleStart': activeCycleStart,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    final rawDraft = json['nextCycleBudget'];
    return AppSettings(
      tags: [for (final t in rawTags) t.toString()],
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 0,
      cycleStartDay: (json['cycleStartDay'] as num?)?.toInt() ?? 1,
      nextCycleBudget: rawDraft is Map
          ? NextCycleBudget.fromJson(Map<String, dynamic>.from(rawDraft))
          : null,
      activeCycleStart: json['activeCycleStart'] as String?,
    );
  }
}
