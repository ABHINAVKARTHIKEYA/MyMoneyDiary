class TransactionEditHistory {
  final int? id;
  final int transactionId;
  final DateTime editedAt;
  final String reason;
  final double oldAmount;
  final double newAmount;
  final DateTime oldDate;
  final DateTime newDate;
  final String oldMode;
  final String newMode;
  final String oldNote;
  final String newNote;

  TransactionEditHistory({
    this.id,
    required this.transactionId,
    DateTime? editedAt,
    required this.reason,
    required this.oldAmount,
    required this.newAmount,
    required this.oldDate,
    required this.newDate,
    this.oldMode = 'UPI',
    this.newMode = 'UPI',
    this.oldNote = '',
    this.newNote = '',
  }) : editedAt = editedAt ?? DateTime.now();

  String get changesSummary {
    final List<String> changes = [];
    if (oldAmount != newAmount) {
      changes.add('Amount: ₹${oldAmount.toStringAsFixed(2)} → ₹${newAmount.toStringAsFixed(2)}');
    }
    if (oldMode != newMode) {
      changes.add('Mode: $oldMode → $newMode');
    }
    if (oldDate != newDate) {
      changes.add('Date modified');
    }
    if (oldNote != newNote && newNote.isNotEmpty) {
      changes.add('Note: "$newNote"');
    }
    return changes.join(' | ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'edited_at': editedAt.toIso8601String(),
      'reason': reason,
      'old_amount': oldAmount,
      'new_amount': newAmount,
      'old_date': oldDate.toIso8601String(),
      'new_date': newDate.toIso8601String(),
      'old_mode': oldMode,
      'new_mode': newMode,
      'old_note': oldNote,
      'new_note': newNote,
    };
  }

  factory TransactionEditHistory.fromMap(Map<String, dynamic> map) {
    return TransactionEditHistory(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int,
      editedAt: DateTime.parse(map['edited_at'] as String),
      reason: map['reason'] as String? ?? 'General modification',
      oldAmount: (map['old_amount'] as num).toDouble(),
      newAmount: (map['new_amount'] as num).toDouble(),
      oldDate: DateTime.parse(map['old_date'] as String),
      newDate: DateTime.parse(map['new_date'] as String),
      oldMode: map['old_mode'] as String? ?? 'UPI',
      newMode: map['new_mode'] as String? ?? 'UPI',
      oldNote: map['old_note'] as String? ?? '',
      newNote: map['new_note'] as String? ?? '',
    );
  }
}
