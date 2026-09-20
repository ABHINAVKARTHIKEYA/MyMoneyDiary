import '../models/chit_details.dart';
import '../models/transaction_model.dart';

class ChitSummary {
  final double totalValue;
  final int totalMonths;
  final int monthsPaid;
  final double totalAmountPaid;
  final double totalDividendsEarned;
  final bool isLifted;
  final int? liftedMonth;
  final double prizeMoneyReceived;
  final double netGainLoss;

  ChitSummary({
    required this.totalValue,
    required this.totalMonths,
    required this.monthsPaid,
    required this.totalAmountPaid,
    required this.totalDividendsEarned,
    required this.isLifted,
    this.liftedMonth,
    this.prizeMoneyReceived = 0.0,
    required this.netGainLoss,
  });
}

class ChitService {
  /// Computes the net monthly installment after deducting dividend
  static double calculateNetInstallment({
    required double nominalInstallment,
    required double dividend,
  }) {
    final net = nominalInstallment - dividend;
    return net > 0 ? net : 0.0;
  }

  /// Calculates the financial summary of a Chit fund from its details and transactions
  static ChitSummary computeSummary({
    required ChitDetails details,
    required List<TransactionModel> chitTransactions,
  }) {
    double totalPaid = 0.0;
    int monthsPaid = details.currentMonth;

    // Sum debit transactions on the chit account (installments paid)
    for (final tx in chitTransactions) {
      if (tx.type == TransactionType.debit) {
        totalPaid += tx.amount;
      }
    }

    // Dividends earned = (nominalInstallment * monthsPaid) - totalPaid
    final nominalTotalForMonthsPaid =
        details.nominalInstallment * monthsPaid;
    final totalDividends = nominalTotalForMonthsPaid > totalPaid
        ? nominalTotalForMonthsPaid - totalPaid
        : 0.0;

    // If lifted, net gain/loss = prize money received - total expected or actual paid
    final prizeMoney = details.prizeMoneyReceived ?? 0.0;
    final netGainLoss = details.isLifted
        ? (prizeMoney - totalPaid)
        : totalDividends;

    return ChitSummary(
      totalValue: details.totalValue,
      totalMonths: details.durationMonths,
      monthsPaid: monthsPaid,
      totalAmountPaid: totalPaid,
      totalDividendsEarned: totalDividends,
      isLifted: details.isLifted,
      liftedMonth: details.liftedMonth,
      prizeMoneyReceived: prizeMoney,
      netGainLoss: netGainLoss,
    );
  }
}
