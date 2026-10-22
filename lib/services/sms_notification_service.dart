import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class SmsNotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.mymoneydiary.app/auto_tracker');
  static final NumberFormat _numFormat = NumberFormat('#,##,###.##');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  /// Generates standard transaction text message content based on account type and transaction details
  static String generateTransactionMessage({
    required Account account,
    required TransactionModel tx,
    String? customRecipientPhone,
  }) {
    final amtStr = '₹${_numFormat.format(tx.amount)}';
    final dateStr = '${_dateFormat.format(tx.date)} at ${_timeFormat.format(tx.date)}';
    final modeStr = tx.paymentMode == 'Others' && (tx.otherPaymentModeDetails ?? '').isNotEmpty
        ? 'Others (${tx.otherPaymentModeDetails})'
        : tx.paymentMode;
    final notePart = tx.note.isNotEmpty ? ' Remarks: ${tx.note}.' : '';

    if (account.type == AccountType.debt) {
      if (tx.type == TransactionType.debit) {
        // Repaying borrowed debt
        final princStr = '₹${_numFormat.format(account.principalBalance)}';
        final intStr = '₹${_numFormat.format(account.accruedInterest)}';
        final totalStr = '₹${_numFormat.format(account.totalOutstanding)}';
        return 'Dear ${account.name}, a payment of $amtStr has been recorded towards loan on $dateStr via $modeStr.$notePart Remaining Principal: $princStr, Accrued Interest: $intStr, Total Outstanding: $totalStr. - Sent via My Money Diary';
      } else {
        // Additional borrowed amount
        return 'Dear ${account.name}, loan borrowing of $amtStr has been recorded on $dateStr via $modeStr.$notePart Total Outstanding: ₹${_numFormat.format(account.totalOutstanding)}. - Sent via My Money Diary';
      }
    } else if (account.type == AccountType.lending) {
      if (tx.type == TransactionType.credit) {
        // Borrower made a repayment
        final princStr = '₹${_numFormat.format(account.principalBalance)}';
        final intStr = '₹${_numFormat.format(account.accruedInterest)}';
        final totalStr = '₹${_numFormat.format(account.totalOutstanding)}';
        return 'Dear ${account.name}, receipt of $amtStr has been recorded towards your loan repayment on $dateStr via $modeStr.$notePart Remaining Principal: $princStr, Accrued Interest: $intStr, Total Balance: $totalStr. - Sent via My Money Diary';
      } else {
        // Additional money lent
        return 'Dear ${account.name}, loan lending of $amtStr has been recorded on $dateStr via $modeStr.$notePart Total Balance Due: ₹${_numFormat.format(account.totalOutstanding)}. - Sent via My Money Diary';
      }
    } else if (account.type == AccountType.chit) {
      return 'Dear Chit Manager, installment payment of $amtStr for Chit "${account.name}" was completed on $dateStr via $modeStr.$notePart - Sent via My Money Diary';
    } else {
      // General, Bank, Salary, Cards, etc.
      final action = tx.type == TransactionType.credit ? 'Credited' : 'Debited';
      final balStr = '₹${_numFormat.format(account.balance)}';
      return 'Transaction Alert: $amtStr $action on $dateStr for ${account.name}. Mode: $modeStr.$notePart Available Balance: $balStr. - Sent via My Money Diary';
    }
  }

  /// Sends a text message by opening the device's native SMS app with pre-filled recipient and text,
  /// falling back to Share.share if direct SMS launch fails.
  static Future<bool> sendSms({
    required String? phoneNumber,
    required String message,
  }) async {
    final cleanPhone = phoneNumber?.trim() ?? '';
    try {
      if (Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('sendSms', {
          'phone': cleanPhone,
          'message': message,
        });
        if (res == true) return true;
      }
    } catch (_) {
      // Fallback to share
    }

    try {
      await Share.share(
        cleanPhone.isNotEmpty ? '$message\n(To: $cleanPhone)' : message,
        subject: 'Transaction Update',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Interactive dialog for previewing, customizing, and sending the transaction SMS
  static Future<void> showSmsPreviewDialog(
    BuildContext context, {
    required Account account,
    required TransactionModel tx,
    String? initialPhone,
  }) async {
    final phoneToUse = initialPhone ?? account.phoneNumber ?? '';
    final phoneController = TextEditingController(text: phoneToUse);
    final initialMessage = generateTransactionMessage(
      account: account,
      tx: tx,
      customRecipientPhone: phoneToUse,
    );
    final messageController = TextEditingController(text: initialMessage);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.sms, color: AppTheme.emeraldPrimary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Send Transaction SMS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send a standard SMS update to the contact assigned to this account or payment.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Recipient Mobile Number',
                  hintText: 'e.g. +91 9876543210',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message Content',
                  border: OutlineInputBorder(),
                  helperText: 'Standard template pre-filled. You can customize before sending.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final phone = phoneController.text.trim();
              final msg = messageController.text.trim();
              final success = await sendSms(phoneNumber: phone, message: msg);
              if (context.mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open SMS app directly. Shared via system share.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
