enum EntryType {
  debit,
  credit,
}

extension EntryTypeExtension on EntryType {
  String get key => this == EntryType.debit ? 'debit' : 'credit';
  static EntryType fromKey(String key) =>
      key.toLowerCase() == 'debit' ? EntryType.debit : EntryType.credit;
}

class JournalEntry {
  final int? id;
  final int transactionId;
  final int accountId;
  final EntryType entryType;
  final double amount;
  final String? memo;
  final int? counterAccountId;
  final int lineOrder;
  final DateTime createdAt;

  JournalEntry({
    this.id,
    required this.transactionId,
    required this.accountId,
    required this.entryType,
    required this.amount,
    this.memo,
    this.counterAccountId,
    this.lineOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isDebit => entryType == EntryType.debit;
  bool get isCredit => entryType == EntryType.credit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'account_id': accountId,
      'entry_type': entryType.key,
      'amount': amount,
      'memo': memo,
      'counter_account_id': counterAccountId,
      'line_order': lineOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int,
      accountId: map['account_id'] as int,
      entryType: EntryTypeExtension.fromKey(map['entry_type'] as String),
      amount: (map['amount'] as num).toDouble(),
      memo: map['memo'] as String?,
      counterAccountId: map['counter_account_id'] as int?,
      lineOrder: map['line_order'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
