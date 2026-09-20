import 'package:test/test.dart';
import '../lib/models/chit_details.dart';
import '../lib/models/transaction_model.dart';
import '../lib/services/chit_service.dart';

void main() {
  group('ChitService Tests', () {
    test('calculateNetInstallment subtracts dividend from nominal', () {
      final net = ChitService.calculateNetInstallment(
        nominalInstallment: 10000.0,
        dividend: 1500.0,
      );
      expect(net, equals(8500.0));
    });

    test('computeSummary calculates dividends and gain/loss accurately', () {
      final details = ChitDetails(
        accountId: 1,
        totalValue: 200000.0,
        durationMonths: 20,
        nominalInstallment: 10000.0,
        currentMonth: 5,
        isLifted: false,
      );

      // 5 months of payments with dividend of 1500 each => 8500 * 5 = 42,500 paid
      final transactions = List.generate(
        5,
        (index) => TransactionModel(
          accountId: 1,
          type: TransactionType.debit,
          amount: 8500.0,
          date: DateTime(2026, 1 + index, 1),
        ),
      );

      final summary = ChitService.computeSummary(
        details: details,
        chitTransactions: transactions,
      );

      expect(summary.totalAmountPaid, equals(42500.0));
      expect(summary.monthsPaid, equals(5));
      // Nominal = 50,000, Paid = 42,500 => Dividends = 7,500
      expect(summary.totalDividendsEarned, equals(7500.0));
      expect(summary.isLifted, isFalse);
    });

    test('computeSummary for lifted chit calculates net gain correctly', () {
      final details = ChitDetails(
        accountId: 1,
        totalValue: 200000.0,
        durationMonths: 20,
        nominalInstallment: 10000.0,
        currentMonth: 6,
        isLifted: true,
        liftedMonth: 5,
        prizeMoneyReceived: 165000.0,
        bidDiscount: 35000.0,
      );

      final transactions = List.generate(
        6,
        (index) => TransactionModel(
          accountId: 1,
          type: TransactionType.debit,
          amount: 8500.0,
          date: DateTime(2026, 1 + index, 1),
        ),
      );

      final summary = ChitService.computeSummary(
        details: details,
        chitTransactions: transactions,
      );

      expect(summary.isLifted, isTrue);
      expect(summary.prizeMoneyReceived, equals(165000.0));
      // Total paid = 8500 * 6 = 51000
      // Net gain so far = 165000 - 51000 = 114000
      expect(summary.netGainLoss, equals(114000.0));
    });
  });
}
