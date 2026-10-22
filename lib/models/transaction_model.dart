import 'transaction_type.dart';
import 'journal_entry.dart';

export 'transaction_type.dart';

class TransactionModel {
  final int? id;
  final String txNumber;
  final int accountId;
  final int? toAccountId;
  final int? sourceAccountId;
  final int? destinationAccountId;
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
  final String? billNumber;
  final String? personName;
  final String? chitGroupName;
  final String? recurrenceRule;
  final String? referenceNumber;
  final int? linkedTxId;
  final List<JournalEntry>? journalEntries;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    String? txNumber,
    required this.accountId,
    this.toAccountId,
    int? sourceAccountId,
    int? destinationAccountId,
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
    this.billNumber,
    this.personName,
    this.chitGroupName,
    this.recurrenceRule,
    this.referenceNumber,
    this.linkedTxId,
    this.journalEntries,
    DateTime? createdAt,
  })  : txNumber = txNumber ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        sourceAccountId = sourceAccountId ?? accountId,
        destinationAccountId = destinationAccountId ?? toAccountId,
        createdAt = createdAt ?? DateTime.now();

  bool get isCredit => type.isInflow;
  bool get isDebit => type.isOutflow;
  bool get isTransfer => type.isTransfer;

  TransactionModel copyWith({
    int? id,
    String? txNumber,
    int? accountId,
    int? toAccountId,
    int? sourceAccountId,
    int? destinationAccountId,
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
    String? billNumber,
    String? personName,
    String? chitGroupName,
    String? recurrenceRule,
    String? referenceNumber,
    int? linkedTxId,
    List<JournalEntry>? journalEntries,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      txNumber: txNumber ?? this.txNumber,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
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
      otherPaymentModeDetails:
          otherPaymentModeDetails ?? this.otherPaymentModeDetails,
      receiptPath: receiptPath ?? this.receiptPath,
      debitAccountName: debitAccountName ?? this.debitAccountName,
      creditAccountName: creditAccountName ?? this.creditAccountName,
      billNumber: billNumber ?? this.billNumber,
      personName: personName ?? this.personName,
      chitGroupName: chitGroupName ?? this.chitGroupName,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      linkedTxId: linkedTxId ?? this.linkedTxId,
      journalEntries: journalEntries ?? this.journalEntries,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tx_number': txNumber,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'source_account_id': sourceAccountId ?? accountId,
      'destination_account_id': destinationAccountId ?? toAccountId,
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
      'bill_number': billNumber,
      'person_name': personName,
      'chit_group_name': chitGroupName,
      'recurrence_rule': recurrenceRule,
      'reference_number': referenceNumber,
      'linked_tx_id': linkedTxId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final accId = (map['account_id'] as num?)?.toInt() ??
        (map['source_account_id'] as num?)?.toInt() ??
        0;
    final toAccId = (map['to_account_id'] as num?)?.toInt() ??
        (map['destination_account_id'] as num?)?.toInt();

    return TransactionModel(
      id: map['id'] as int?,
      txNumber: map['tx_number'] as String? ?? 'TXN-${map['id'] ?? 0}',
      accountId: accId,
      toAccountId: toAccId,
      sourceAccountId: (map['source_account_id'] as num?)?.toInt() ?? accId,
      destinationAccountId:
          (map['destination_account_id'] as num?)?.toInt() ?? toAccId,
      type: TransactionTypeExtension.fromKey(map['type'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      principalPortion: (map['principal_portion'] as num?)?.toDouble() ?? 0.0,
      interestPortion: (map['interest_portion'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'General',
      note: map['note'] as String? ?? '',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      isAutoInterest: (map['is_auto_interest'] as int?) == 1,
      externalRefId: map['external_ref_id'] as String?,
      source: map['source'] as String? ?? 'manual',
      paymentMode: map['payment_mode'] as String? ?? 'UPI',
      otherPaymentModeDetails: map['other_payment_mode_details'] as String?,
      receiptPath: map['receipt_path'] as String?,
      debitAccountName: map['debit_account_name'] as String?,
      creditAccountName: map['credit_account_name'] as String?,
      billNumber: map['bill_number'] as String?,
      personName: map['person_name'] as String?,
      chitGroupName: map['chit_group_name'] as String?,
      recurrenceRule: map['recurrence_rule'] as String?,
      referenceNumber: map['reference_number'] as String?,
      linkedTxId: map['linked_tx_id'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
