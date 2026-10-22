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
  final String? externalRefId;
  final String source;
  final String paymentMode; // 'UPI', 'Cash', 'Credit Card', 'Debit Card', 'Net Banking', 'Cheque', 'Others'
  final String? otherPaymentModeDetails;
  final String? receiptPath;
  final String? debitAccountName;
  final String? creditAccountName;
  final int? linkedTxId;
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
    this.externalRefId,
    this.source = 'manual',
    this.paymentMode = 'UPI',
    this.otherPaymentModeDetails,
    this.receiptPath,
    this.debitAccountName,
    this.creditAccountName,
    this.linkedTxId,
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
    String? externalRefId,
    String? source,
    String? paymentMode,
    String? otherPaymentModeDetails,
    String? receiptPath,
    String? debitAccountName,
    String? creditAccountName,
    int? linkedTxId,
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
      externalRefId: externalRefId ?? this.externalRefId,
      source: source ?? this.source,
      paymentMode: paymentMode ?? this.paymentMode,
      otherPaymentModeDetails: otherPaymentModeDetails ?? this.otherPaymentModeDetails,
      receiptPath: receiptPath ?? this.receiptPath,
      debitAccountName: debitAccountName ?? this.debitAccountName,
      creditAccountName: creditAccountName ?? this.creditAccountName,
      linkedTxId: linkedTxId ?? this.linkedTxId,
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
      'external_ref_id': externalRefId,
      'source': source,
      'payment_mode': paymentMode,
      'other_payment_mode_details': otherPaymentModeDetails,
      'receipt_path': receiptPath,
      'debit_account_name': debitAccountName,
      'credit_account_name': creditAccountName,
      'linked_tx_id': linkedTxId,
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
      externalRefId: map['external_ref_id'] as String?,
      source: map['source'] as String? ?? 'manual',
      paymentMode: map['payment_mode'] as String? ?? 'UPI',
      otherPaymentModeDetails: map['other_payment_mode_details'] as String?,
      receiptPath: map['receipt_path'] as String?,
      debitAccountName: map['debit_account_name'] as String?,
      creditAccountName: map['credit_account_name'] as String?,
      linkedTxId: map['linked_tx_id'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
