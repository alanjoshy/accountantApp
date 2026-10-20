// Money account (web MoneyAccount + icon/color).

import '../domain/account_style.dart';

class MoneyAccount {
  const MoneyAccount({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
    // ignore: prefer_initializing_formals — keep public `icon`/`color` names
    String? icon,
    // ignore: prefer_initializing_formals
    String? color,
  })  : _icon = icon,
        _color = color;

  final String id;
  final String name;
  final AccountKind kind;
  final double balance;
  final String createdAt;
  final String updatedAt;
  final String? _icon;
  final String? _color;

  String get icon {
    final v = _icon;
    return (v == null || v.isEmpty) ? defaultIconForKind(kind) : v;
  }

  String get color {
    final v = _color;
    return (v == null || v.isEmpty) ? defaultColorForKind(kind) : v;
  }

  MoneyAccount copyWith({
    String? name,
    AccountKind? kind,
    double? balance,
    String? icon,
    String? color,
    String? updatedAt,
  }) {
    return MoneyAccount(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'balance': balance,
        'icon': icon,
        'color': color,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory MoneyAccount.fromJson(Map<String, dynamic> json) {
    return MoneyAccount(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      kind: normalizeAccountKind(json['kind']),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
