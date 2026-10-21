class ReminderModel {
  final int? id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String frequency; // 'one_time', 'monthly', 'quarterly', 'yearly'
  final int? accountId;
  final String category;
  final String notes;
  final bool isPaid;
  final DateTime? paidDate;
  final DateTime createdAt;

  ReminderModel({
    this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.frequency = 'monthly',
    this.accountId,
    this.category = 'Bill',
    this.notes = '',
    this.isPaid = false,
    this.paidDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOverdue => !isPaid && dueDate.isBefore(DateTime.now());
  bool get isDueToday {
    final now = DateTime.now();
    return !isPaid &&
        dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  ReminderModel copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    String? frequency,
    int? accountId,
    String? category,
    String? notes,
    bool? isPaid,
    DateTime? paidDate,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      frequency: frequency ?? this.frequency,
      accountId: accountId ?? this.accountId,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'frequency': frequency,
      'account_id': accountId,
      'category': category,
      'notes': notes,
      'is_paid': isPaid ? 1 : 0,
      'paid_date': paidDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['due_date'] as String),
      frequency: map['frequency'] as String? ?? 'monthly',
      accountId: map['account_id'] as int?,
      category: map['category'] as String? ?? 'Bill',
      notes: map['notes'] as String? ?? '',
      isPaid: (map['is_paid'] as int?) == 1,
      paidDate: map['paid_date'] != null ? DateTime.parse(map['paid_date'] as String) : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
