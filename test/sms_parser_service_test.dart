import 'package:flutter_test/flutter_test.dart';
import '../lib/services/sms_parser_service.dart';
import '../lib/models/transaction_model.dart';

void main() {
  group('SmsParserService Tests', () {
    test('Parses HDFC debit SMS with UPI Ref', () {
      final sms = 'Sent Rs.450.00 from HDFC Bank A/C **1234 to Swiggy via UPI Ref 412345678901 on 21-OCT-26.';
      final parsed = SmsParserService.parse(
        sender: 'VK-HDFCBK',
        body: sms,
        timestamp: DateTime(2026, 10, 21, 14, 30),
        source: 'sms',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 450.0);
      expect(parsed.type, TransactionType.debit);
      expect(parsed.bankName, 'HDFC');
      expect(parsed.accountLast4, '1234');
      expect(parsed.referenceId, 'REF_412345678901');
      expect(parsed.category, 'Food & Dining');
    });

    test('Parses SBI credit SMS with UPI Ref', () {
      final sms = 'Dear SBI User, your A/C ending 5678 credited by Rs 5,000.00 on 21Oct26 by transfer from Rahul via UPI Ref 987654321012.';
      final parsed = SmsParserService.parse(
        sender: 'SBIINB',
        body: sms,
        timestamp: DateTime(2026, 10, 21, 15, 0),
        source: 'sms',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 5000.0);
      expect(parsed.type, TransactionType.credit);
      expect(parsed.bankName, 'SBI');
      expect(parsed.accountLast4, '5678');
      expect(parsed.referenceId, 'REF_987654321012');
    });

    test('Parses UPI app notification', () {
      final notif = 'Paid ₹1,200 to Petrol Bunk via UPI Ref 554433221100';
      final parsed = SmsParserService.parse(
        sender: 'PhonePe',
        body: notif,
        timestamp: DateTime(2026, 10, 21, 18, 0),
        source: 'notification',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200.0);
      expect(parsed.type, TransactionType.debit);
      expect(parsed.category, 'Travel & Fuel');
      expect(parsed.referenceId, 'REF_554433221100');
    });

    test('Rejects non-financial OTP messages', () {
      final otp = '394821 is your secret OTP for NetBanking login. Do not share with anyone.';
      final parsed = SmsParserService.parse(
        sender: 'AXISBK',
        body: otp,
        timestamp: DateTime(2026, 10, 21, 12, 0),
        source: 'sms',
      );

      expect(parsed, isNull);
    });

    test('De-duplication: Guarantees identical Reference ID between SMS and Notification', () {
      final bankSms = 'A/C 1234 debited for Rs.350.00 on 21-10-26 to Chai Point (UPI Ref no 429581928374)';
      final gpayNotif = 'Paid ₹350.00 to Chai Point. UPI Ref: 429581928374';

      final parsedSms = SmsParserService.parse(sender: 'HDFCBK', body: bankSms, source: 'sms');
      final parsedNotif = SmsParserService.parse(sender: 'Google Pay', body: gpayNotif, source: 'notification');

      expect(parsedSms, isNotNull);
      expect(parsedNotif, isNotNull);
      expect(parsedSms!.referenceId, parsedNotif!.referenceId);
      expect(parsedSms.referenceId, 'REF_429581928374');
    });
  });
}
