import '../lib/services/interest_calculator.dart';
import '../lib/services/repayment_allocator.dart';
import '../lib/services/chit_service.dart';
import '../lib/models/chit_details.dart';
import '../lib/models/transaction_model.dart';

void main() {
  print('=============================================');
  print('   RUNNING MY MONEY DIARY VERIFICATIONS      ');
  print('=============================================');

  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      print(' [PASS] $name');
      passed++;
    } catch (e, stack) {
      print(' [FAIL] $name: $e\n$stack');
      failed++;
    }
  }

  // 1. Interest Calculator Tests
  print('\n--- 1. Interest Calculator ---');
  test('Daily rate for per_month (₹2 per ₹100/mo)', () {
    final rate = InterestCalculator.getDailyRate(rate: 2.0, rateType: 'per_month');
    final expected = (2.0 / 100.0) / 30.0;
    assert((rate - expected).abs() < 0.000001, 'Expected $expected, got $rate');
  });

  test('Daily rate for per_annum (12% p.a.)', () {
    final rate = InterestCalculator.getDailyRate(rate: 12.0, rateType: 'per_annum');
    final expected = (12.0 / 100.0) / 365.0;
    assert((rate - expected).abs() < 0.000001, 'Expected $expected, got $rate');
  });

  test('Monthly interest amount (₹1,00,000 @ 2% pm)', () {
    final amt = InterestCalculator.calculateMonthlyInterestAmount(
      principal: 100000.0,
      rate: 2.0,
      rateType: 'per_month',
    );
    assert(amt == 2000.0, 'Expected 2000, got $amt');
  });

  test('Accrued simple interest for 60 days @ 2% pm', () {
    final from = DateTime(2026, 1, 1);
    final to = DateTime(2026, 3, 2); // 60 days
    final accrued = InterestCalculator.calculateAccruedInterest(
      principal: 50000.0,
      rate: 2.0,
      rateType: 'per_month',
      isCompound: false,
      fromDate: from,
      toDate: to,
    );
    assert((accrued - 2000.0).abs() < 1.0, 'Expected ~2000, got $accrued');
  });

  test('Accrued compound interest for 60 days (2 months) @ 2% pm', () {
    final from = DateTime(2026, 1, 1);
    final to = DateTime(2026, 3, 2); // 60 days
    final accrued = InterestCalculator.calculateAccruedInterest(
      principal: 50000.0,
      rate: 2.0,
      rateType: 'per_month',
      isCompound: true,
      fromDate: from,
      toDate: to,
    );
    // Month 1: 50,000 * 0.02 = 1,000 => 51,000
    // Month 2: 51,000 * 0.02 = 1,020 => Total Interest = 2,020
    assert((accrued - 2020.0).abs() < 1.0, 'Expected ~2020, got $accrued');
  });

  // 2. Repayment Allocator Tests
  print('\n--- 2. Repayment Allocator ---');
  test('Interest first rule (payment < interest)', () {
    final split = RepaymentAllocator.calculateSplit(
      paymentAmount: 500.0,
      currentPrincipal: 10000.0,
      accruedInterest: 1000.0,
      allocationRule: 'interest_first',
    );
    assert(split.interestPortion == 500.0, 'Expected interest 500');
    assert(split.principalPortion == 0.0, 'Expected principal 0');
  });

  test('Interest first rule (payment > interest)', () {
    final split = RepaymentAllocator.calculateSplit(
      paymentAmount: 2500.0,
      currentPrincipal: 10000.0,
      accruedInterest: 1000.0,
      allocationRule: 'interest_first',
    );
    assert(split.interestPortion == 1000.0, 'Expected interest 1000');
    assert(split.principalPortion == 1500.0, 'Expected principal 1500');
  });

  test('Principal first rule (payment < principal)', () {
    final split = RepaymentAllocator.calculateSplit(
      paymentAmount: 5000.0,
      currentPrincipal: 10000.0,
      accruedInterest: 1000.0,
      allocationRule: 'principal_first',
    );
    assert(split.principalPortion == 5000.0, 'Expected principal 500');
    assert(split.interestPortion == 0.0, 'Expected interest 0');
  });

  test('Principal first rule (payment > principal)', () {
    final split = RepaymentAllocator.calculateSplit(
      paymentAmount: 10500.0,
      currentPrincipal: 10000.0,
      accruedInterest: 1000.0,
      allocationRule: 'principal_first',
    );
    assert(split.principalPortion == 10000.0, 'Expected principal 10000');
    assert(split.interestPortion == 500.0, 'Expected interest 500');
  });

  test('Manual split validation', () {
    assert(RepaymentAllocator.isValidSplit(
      paymentAmount: 2000.0,
      userInterestPortion: 600.0,
      userPrincipalPortion: 1400.0,
    ));
    assert(!RepaymentAllocator.isValidSplit(
      paymentAmount: 2000.0,
      userInterestPortion: 600.0,
      userPrincipalPortion: 1200.0,
    ));
  });

  // 3. Chit Fund Service Tests
  print('\n--- 3. Chit Fund Service ---');
  test('Net installment after dividend deduction', () {
    final net = ChitService.calculateNetInstallment(
      nominalInstallment: 10000.0,
      dividend: 1500.0,
    );
    assert(net == 8500.0, 'Expected 8500, got $net');
  });

  test('Chit summary for running chit with dividends', () {
    final details = ChitDetails(
      accountId: 1,
      totalValue: 200000.0,
      durationMonths: 20,
      nominalInstallment: 10000.0,
      currentMonth: 5,
      isLifted: false,
    );

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

    assert(summary.totalAmountPaid == 42500.0, 'Expected 42500, got ${summary.totalAmountPaid}');
    assert(summary.monthsPaid == 5, 'Expected 5 months');
    assert(summary.totalDividendsEarned == 7500.0, 'Expected 7500 dividends, got ${summary.totalDividendsEarned}');
    assert(!summary.isLifted, 'Expected not lifted');
  });

  test('Chit summary for lifted chit with prize money', () {
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

    assert(summary.isLifted, 'Expected lifted');
    assert(summary.prizeMoneyReceived == 165000.0, 'Expected 165000 prize');
    assert(summary.netGainLoss == 114000.0, 'Expected 114000 net gain, got ${summary.netGainLoss}');
  });

  print('\n=============================================');
  print('   RESULTS: $passed PASSED, $failed FAILED   ');
  print('=============================================');
}
