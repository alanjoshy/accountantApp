// Lent / borrowed entry (web Debt).

enum DebtKind { lend, borrow }

enum DebtStatus { open, collected }

class Debt {
  const Debt({
    required this.id,
    required this.personName,
    required this.amount,
    this.amountPaid = 0,
    required this.lentDate,
    required this.dueDate,
    this.kind = DebtKind.lend,
    this.status = DebtStatus.open,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String personName;
  final double amount;
  final double amountPaid;
  final String lentDate;
  final String dueDate;
  final DebtKind kind;
  final DebtStatus status;
  final String? note;
  final String createdAt;
  final String updatedAt;

  Debt copyWith({
    String? personName,
    double? amount,
    double? amountPaid,
    String? lentDate,
    String? dueDate,
    DebtKind? kind,
    DebtStatus? status,
    String? note,
    bool clearNote = false,
    String? updatedAt,
  }) {
    return Debt(
      id: id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      amountPaid: amountPaid ?? this.amountPaid,
      lentDate: lentDate ?? this.lentDate,
      dueDate: dueDate ?? this.dueDate,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personName': personName,
        'amount': amount,
        'amountPaid': amountPaid,
        'lentDate': lentDate,
        'dueDate': dueDate,
        'kind': kind == DebtKind.borrow ? 'borrow' : 'lend',
        'status': status == DebtStatus.collected ? 'collected' : 'open',
        if (note != null && note!.isNotEmpty) 'note': note,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Debt.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'] as String?;
    final statusRaw = json['status'] as String?;
    return Debt(
      id: json['id'] as String? ?? '',
      personName: json['personName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
      lentDate: json['lentDate'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      kind: kindRaw == 'borrow' ? DebtKind.borrow : DebtKind.lend,
      status: statusRaw == 'collected' ? DebtStatus.collected : DebtStatus.open,
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
