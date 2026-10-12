// Savings jar model (web JarGoal).

class JarUpdate {
  const JarUpdate({required this.amount, required this.at});

  final double amount;
  final String at;

  Map<String, dynamic> toJson() => {'amount': amount, 'at': at};

  factory JarUpdate.fromJson(Map<String, dynamic> json) {
    return JarUpdate(
      amount: (json['amount'] as num).toDouble(),
      at: json['at'] as String,
    );
  }
}

class JarGoal {
  const JarGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.color,
    this.icon = 'jar',
    required this.createdAt,
    required this.updatedAt,
    this.updates = const [],
  });

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String color;
  final String icon;
  final String createdAt;
  final String updatedAt;
  final List<JarUpdate> updates;

  double get progressPct {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount) * 100;
  }

  JarGoal copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? color,
    String? icon,
    String? updatedAt,
    List<JarUpdate>? updates,
  }) {
    return JarGoal(
      id: id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updates: updates ?? this.updates,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'color': color,
        'icon': icon,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'updates': updates.map((u) => u.toJson()).toList(),
      };

  factory JarGoal.fromJson(Map<String, dynamic> json) {
    final rawUpdates = json['updates'] as List<dynamic>? ?? const [];
    return JarGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      color: json['color'] as String? ?? '#22c55e',
      icon: json['icon'] as String? ?? 'jar',
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      updates: [
        for (final u in rawUpdates)
          JarUpdate.fromJson(Map<String, dynamic>.from(u as Map)),
      ],
    );
  }
}
