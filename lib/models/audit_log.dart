class AuditLog {
  final int? id;
  final int? transactionId;
  final int? accountId;
  final String action; // 'create', 'update', 'archive', 'reversal', 'delete_attempt'
  final String reason;
  final String changesJson;
  final DateTime timestamp;

  AuditLog({
    this.id,
    this.transactionId,
    this.accountId,
    required this.action,
    required this.reason,
    required this.changesJson,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'account_id': accountId,
      'action': action,
      'reason': reason,
      'changes_json': changesJson,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      accountId: map['account_id'] as int?,
      action: map['action'] as String? ?? 'create',
      reason: map['reason'] as String? ?? '',
      changesJson: map['changes_json'] as String? ?? '{}',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
