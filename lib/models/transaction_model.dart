enum TransactionType {
  debit,
  credit,
  transfer,
}

extension TransactionTypeExtension on TransactionType {
  String get key {
    switch (this) {
      case TransactionType.debit:
        return 'debit';
      case TransactionType.credit:
        return 'credit';
      case TransactionType.transfer:
        return 'transfer';
    }
  }

  String get displayName {
    switch (this) {
      case TransactionType.debit:
        return 'Debit (-)';
      case TransactionType.credit:
        return 'Credit (+)';
      case TransactionType.transfer:
        return 'Transfer (⇄)';
    }
  }

  static TransactionType fromKey(String key) {
    switch (key) {
      case 'debit':
        return TransactionType.debit;
      case 'credit':
        return TransactionType.credit;
      case 'transfer':
        return TransactionType.transfer;
      default:
        return TransactionType.debit;
    }
  }
}

class TransactionModel {
  final int? id;
  final int accountId;
  final int? toAccountId;
  final TransactionType type;
  final double amount;
  final double principalPortion;
  final double interestPortion;
  final String category;
  final String note;
  final DateTime date;
  final bool isAutoInterest;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.accountId,
    this.toAccountId,
    required this.type,
    required this.amount,
    this.principalPortion = 0.0,
    this.interestPortion = 0.0,
    this.category = 'General',
    this.note = '',
    required this.date,
    this.isAutoInterest = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TransactionModel copyWith({
    int? id,
    int? accountId,
    int? toAccountId,
    TransactionType? type,
    double? amount,
    double? principalPortion,
    double? interestPortion,
    String? category,
    String? note,
    DateTime? date,
    bool? isAutoInterest,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      principalPortion: principalPortion ?? this.principalPortion,
      interestPortion: interestPortion ?? this.interestPortion,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      isAutoInterest: isAutoInterest ?? this.isAutoInterest,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'type': type.key,
      'amount': amount,
      'principal_portion': principalPortion,
      'interest_portion': interestPortion,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'is_auto_interest': isAutoInterest ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      toAccountId: map['to_account_id'] as int?,
      type: TransactionTypeExtension.fromKey(map['type'] as String),
      amount: (map['amount'] as num).toDouble(),
      principalPortion: (map['principal_portion'] as num?)?.toDouble() ?? 0.0,
      interestPortion: (map['interest_portion'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'General',
      note: map['note'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      isAutoInterest: (map['is_auto_interest'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
