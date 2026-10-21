import 'dart:async';
import 'package:flutter/services.dart';
import '../models/transaction_model.dart';
import '../models/account.dart';
import '../data/database_helper.dart';
import 'sms_parser_service.dart';

class AutoSyncResult {
  final int totalScanned;
  final int financialFound;
  final int newAdded;
  final int duplicatesSkipped;
  final List<ParsedTransaction> newTransactions;

  AutoSyncResult({
    required this.totalScanned,
    required this.financialFound,
    required this.newAdded,
    required this.duplicatesSkipped,
    required this.newTransactions,
  });
}

class AutoTrackerService {
  static const MethodChannel _channel = MethodChannel('com.mymoneydiary.app/auto_tracker');
  static final AutoTrackerService instance = AutoTrackerService._init();

  AutoTrackerService._init() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Function()? onNewTransactionDetected;

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onLiveTransactionDetected') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      await processSingleRawMessage(
        sender: data['sender'] as String? ?? 'Notification',
        body: data['body'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        source: data['source'] as String? ?? 'notification',
      );
      onNewTransactionDetected?.call();
    }
  }

  /// Check if SMS permission is granted
  Future<bool> hasSmsPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('hasSmsPermission') ?? false;
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Request SMS permission from Android OS
  Future<bool> requestSmsPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestSmsPermission') ?? false;
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Check if user has enabled Notification Access in Android Settings
  Future<bool> isNotificationListenerEnabled() async {
    try {
      final bool enabled = await _channel.invokeMethod('isNotificationListenerEnabled') ?? false;
      return enabled;
    } catch (_) {
      return false;
    }
  }

  /// Open Android Notification Access Settings for the user
  Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
  }

  /// Read SMS from Android inbox and parse all financial transactions with strict duplicate prevention
  Future<AutoSyncResult> syncSmsInbox({int limit = 200, required int defaultAccountId}) async {
    int totalScanned = 0;
    int financialFound = 0;
    int newAdded = 0;
    int duplicatesSkipped = 0;
    final List<ParsedTransaction> newlyAddedList = [];

    try {
      final List<dynamic>? rawMessages = await _channel.invokeMethod('readRecentSms', {'limit': limit});
      if (rawMessages == null || rawMessages.isEmpty) {
        return AutoSyncResult(
          totalScanned: 0,
          financialFound: 0,
          newAdded: 0,
          duplicatesSkipped: 0,
          newTransactions: [],
        );
      }

      totalScanned = rawMessages.length;

      for (final raw in rawMessages) {
        final map = Map<String, dynamic>.from(raw as Map);
        final sender = map['address'] as String? ?? '';
        final body = map['body'] as String? ?? '';
        final timestampMs = map['date'] as int?;
        final date = timestampMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
            : DateTime.now();

        final parsed = SmsParserService.parse(
          sender: sender,
          body: body,
          timestamp: date,
          source: 'sms',
        );

        if (parsed != null) {
          financialFound++;

          // Check if already in database (duplicate check)
          final exists = await DatabaseHelper.instance.transactionExistsByExternalRef(parsed.referenceId);
          if (exists) {
            duplicatesSkipped++;
            continue;
          }

          // Insert new non-duplicate transaction
          final tx = parsed.toTransactionModel(accountId: defaultAccountId);
          final id = await DatabaseHelper.instance.insertTransaction(tx);
          if (id > 0) {
            newAdded++;
            newlyAddedList.add(parsed);
          } else {
            duplicatesSkipped++;
          }
        }
      }
    } catch (e) {
      // Return whatever was successfully processed before exception
    }

    return AutoSyncResult(
      totalScanned: totalScanned,
      financialFound: financialFound,
      newAdded: newAdded,
      duplicatesSkipped: duplicatesSkipped,
      newTransactions: newlyAddedList,
    );
  }

  /// Process an individual incoming raw message from live SMS receiver or notification
  Future<bool> processSingleRawMessage({
    required String sender,
    required String body,
    required DateTime timestamp,
    required String source,
    int? accountId,
  }) async {
    final parsed = SmsParserService.parse(
      sender: sender,
      body: body,
      timestamp: timestamp,
      source: source,
    );
    if (parsed == null) return false;

    // Check duplicate
    final exists = await DatabaseHelper.instance.transactionExistsByExternalRef(parsed.referenceId);
    if (exists) return false;

    // Determine target account (default to Pool Account or first account)
    int targetId = accountId ?? 1;
    if (accountId == null) {
      final accounts = await DatabaseHelper.instance.getAccounts();
      final pool = accounts.firstWhere(
        (a) => a.type == AccountType.pool,
        orElse: () => accounts.isNotEmpty ? accounts.first : throw Exception('No account found'),
      );
      targetId = pool.id!;
    }

    final tx = parsed.toTransactionModel(accountId: targetId);
    final id = await DatabaseHelper.instance.insertTransaction(tx);
    return id > 0;
  }
}
