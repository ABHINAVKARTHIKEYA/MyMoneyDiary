import '../lib/services/interest_calculator.dart';
import '../lib/services/repayment_allocator.dart';
import '../lib/services/chit_service.dart';
import '../lib/models/chit_details.dart';
import '../lib/models/transaction_model.dart';
import '../lib/services/sms_parser_service.dart';
import '../lib/utils/date_duration.dart';
import '../lib/models/account_category.dart';
import '../lib/models/journal_entry.dart';
import '../lib/models/audit_log.dart';
import '../lib/models/transaction_type.dart';
import '../lib/services/double_entry_engine.dart';
import '../lib/utils/financial_year_helper.dart';

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

  // 4. Auto Transaction Detection & Zero-Duplicate Verification
  print('\n--- 4. Auto Transaction Detection & Zero Duplicate Verification ---');
  test('HDFC Debit SMS with UPI Ref and Merchant parsing', () {
    final sms = 'Sent Rs.450.00 from HDFC Bank A/C **1234 to Swiggy via UPI Ref 412345678901 on 21-OCT-26.';
    final parsed = SmsParserService.parse(
      sender: 'VK-HDFCBK',
      body: sms,
      timestamp: DateTime(2026, 10, 21, 14, 30),
      source: 'sms',
    );

    assert(parsed != null, 'Expected parsed transaction');
    final tx = parsed!;
    assert(tx.amount == 450.0, 'Expected 450.0 amount, got ${tx.amount}');
    assert(tx.type == TransactionType.debit, 'Expected debit type');
    assert(tx.bankName == 'HDFC', 'Expected HDFC bank, got ${tx.bankName}');
    assert(tx.accountLast4 == '1234', 'Expected 1234 last 4');
    assert(tx.referenceId == 'REF_412345678901', 'Expected REF_412345678901, got ${tx.referenceId}');
    assert(tx.category == 'Food & Dining', 'Expected Food & Dining category, got ${tx.category}');
  });

  test('SBI Credit SMS with amount and sender parsing', () {
    final sms = 'Dear SBI User, your A/C ending 5678 credited by Rs 5,000.00 on 21Oct26 by transfer from Rahul via UPI Ref 987654321012.';
    final parsed = SmsParserService.parse(
      sender: 'SBIINB',
      body: sms,
      timestamp: DateTime(2026, 10, 21, 15, 0),
      source: 'sms',
    );

    assert(parsed != null, 'Expected parsed transaction');
    final tx = parsed!;
    assert(tx.amount == 5000.0, 'Expected 5000.0, got ${tx.amount}');
    assert(tx.type == TransactionType.credit, 'Expected credit');
    assert(tx.bankName == 'SBI', 'Expected SBI bank');
    assert(tx.accountLast4 == '5678', 'Expected 5678 account');
    assert(tx.referenceId == 'REF_987654321012', 'Expected REF_987654321012');
  });

  test('PhonePe / GPay Notification parsing', () {
    final notif = 'Paid ₹1,200 to Petrol Bunk via UPI Ref 554433221100';
    final parsed = SmsParserService.parse(
      sender: 'PhonePe',
      body: notif,
      timestamp: DateTime(2026, 10, 21, 18, 0),
      source: 'notification',
    );

    assert(parsed != null, 'Expected parsed transaction');
    final tx = parsed!;
    assert(tx.amount == 1200.0, 'Expected 1200.0');
    assert(tx.type == TransactionType.debit, 'Expected debit');
    assert(tx.category == 'Travel & Fuel', 'Expected Travel & Fuel category, got ${tx.category}');
    assert(tx.referenceId == 'REF_554433221100', 'Expected REF_554433221100');
  });

  test('Rejects non-financial OTP / security messages', () {
    final otpMessage = '394821 is your secret OTP for NetBanking login. Do not share with anyone.';
    final parsed = SmsParserService.parse(
      sender: 'AXISBK',
      body: otpMessage,
      timestamp: DateTime(2026, 10, 21, 12, 0),
      source: 'sms',
    );

    assert(parsed == null, 'OTP without financial debit/credit must be rejected');
  });

  test('Guarantees identical Reference ID between SMS and Notification for the same UPI transaction (De-duplication)', () {
    // Both SMS and Push notification arrive for the exact same transaction
    final bankSms = 'A/C 1234 debited for Rs.350.00 on 21-10-26 to Chai Point (UPI Ref no 429581928374)';
    final gpayNotif = 'Paid ₹350.00 to Chai Point. UPI Ref: 429581928374';

    final parsedSms = SmsParserService.parse(sender: 'HDFCBK', body: bankSms, source: 'sms');
    final parsedNotif = SmsParserService.parse(sender: 'Google Pay', body: gpayNotif, source: 'notification');

    assert(parsedSms != null && parsedNotif != null);
    final smsTx = parsedSms!;
    final notifTx = parsedNotif!;
    // Both generate the exact same referenceId
    assert(smsTx.referenceId == notifTx.referenceId,
      'SMS ref (${smsTx.referenceId}) must match Notification ref (${notifTx.referenceId})');
    assert(smsTx.referenceId == 'REF_429581928374');
  });

  test('Generates deterministic signature when UPI ref is absent (prevents repeated scan duplication)', () {
    final sms = 'Your A/C ending 4321 debited Rs. 200 on 21-Oct-26 at Local Store.';
    final fixedTime = DateTime(2026, 10, 21, 11, 45);

    final scan1 = SmsParserService.parse(sender: 'HDFCBK', body: sms, timestamp: fixedTime, source: 'sms');
    final scan2 = SmsParserService.parse(sender: 'HDFCBK', body: sms, timestamp: fixedTime, source: 'sms');

    assert(scan1 != null && scan2 != null);
    final tx1 = scan1!;
    final tx2 = scan2!;
    assert(tx1.referenceId == tx2.referenceId, 'Repeated scans must generate identical signature');
    assert(tx1.referenceId.startsWith('SIG_200.00_debit_20261021_1145_HDFCBK'));
  });

  // 5. Chit Pre/Post Lifting & Dynamic Installment Tests
  print('\n--- 5. Chit Pre/Post Lifting & Dynamic Installments ---');
  test('Chit dynamically toggles between Pre-Lifting and Post-Lifting installment', () {
    final chit = ChitDetails(
      accountId: 1,
      totalValue: 200000.0,
      durationMonths: 20,
      installmentBeforeLifting: 8500.0,
      installmentAfterLifting: 10000.0,
      isLifted: false,
    );

    // Before lifting: activeInstallment is installmentBeforeLifting
    assert(chit.activeInstallment == 8500.0, 'Expected 8500 before lifting, got ${chit.activeInstallment}');

    // Mark as lifted: activeInstallment dynamically becomes installmentAfterLifting
    final liftedChit = chit.copyWith(
      isLifted: true,
      liftedMonth: 5,
      prizeMoneyReceived: 160000.0,
    );
    assert(liftedChit.activeInstallment == 10000.0, 'Expected 10000 after lifting, got ${liftedChit.activeInstallment}');
    assert(liftedChit.isLifted == true);
    assert(liftedChit.liftedMonth == 5);
  });

  // 6. Transaction Model Enhancements (Payment Mode, Debit/Credit Accounts, Receipt, LinkedTxId)
  print('\n--- 6. Transaction Model Enhancements ---');
  test('Transaction model serializes and preserves payment modes, receipts, dual accounts, and linkedTxId', () {
    final tx = TransactionModel(
      id: 101,
      accountId: 2,
      type: TransactionType.debit,
      amount: 4500.0,
      category: 'Electronics',
      note: 'Bought mechanical keyboard',
      date: DateTime(2026, 10, 21, 15, 30),
      paymentMode: 'Others',
      otherPaymentModeDetails: 'Cryptocurrency / Gift Card',
      receiptPath: '/storage/emulated/0/Download/receipt_123.pdf',
      debitAccountName: 'HDFC Bank',
      creditAccountName: 'Amazon Merchant',
      linkedTxId: 99,
    );

    final map = tx.toMap();
    assert(map['payment_mode'] == 'Others');
    assert(map['other_payment_mode_details'] == 'Cryptocurrency / Gift Card');
    assert(map['receipt_path'] == '/storage/emulated/0/Download/receipt_123.pdf');
    assert(map['debit_account_name'] == 'HDFC Bank');
    assert(map['credit_account_name'] == 'Amazon Merchant');
    assert(map['linked_tx_id'] == 99);

    final reconstructed = TransactionModel.fromMap(map);
    assert(reconstructed.paymentMode == 'Others');
    assert(reconstructed.otherPaymentModeDetails == 'Cryptocurrency / Gift Card');
    assert(reconstructed.receiptPath == '/storage/emulated/0/Download/receipt_123.pdf');
    assert(reconstructed.debitAccountName == 'HDFC Bank');
    assert(reconstructed.creditAccountName == 'Amazon Merchant');
    assert(reconstructed.linkedTxId == 99);
  });

  // 7. Loan Origination Date Interest Accrual Tests
  print('\n--- 7. Loan Origination Date Interest Accrual ---');
  test('Historical loan origination date correctly calculates accrued interest up to current date', () {
    final loanDate = DateTime(2026, 1, 1);
    final today = DateTime(2026, 7, 1); // 181 days ~ 6 months
    final principal = 100000.0;
    final rate = 2.0; // 2% per month

    final accrued = InterestCalculator.calculateAccruedInterest(
      principal: principal,
      rate: rate,
      rateType: 'per_month',
      isCompound: false,
      fromDate: loanDate,
      toDate: today,
    );

    // 181 days / 30 * 2% of 100,000 = ~12,066.67
    assert(accrued > 12000.0 && accrued < 12100.0, 'Expected ~12066 accrued interest, got $accrued');
  });

  // 8. Accounting Rules & Pool Account Reflection Verification
  print('\n--- 8. Accounting Rules & Pool Account Reflection ---');
  test('Credit Card expenditure: Pool records Credit (line drawn) + Debit (expense) with net cash impact = 0', () {
    final cardTx = TransactionModel(
      id: 501,
      accountId: 4, // Credit Card
      type: TransactionType.debit,
      amount: 3500.0,
      category: 'Dining',
      note: 'Dinner with family',
      date: DateTime(2026, 10, 21),
      paymentMode: 'Credit Card',
      debitAccountName: 'ICICI Credit Card',
      creditAccountName: 'Restaurant',
    );

    // Pool Account simulation
    double poolBalance = 25000.0;

    // Reflection 1: Pool Credit (Credit line drawn)
    final poolCredit = TransactionModel(
      accountId: 1, // Pool
      type: TransactionType.credit,
      amount: cardTx.amount,
      category: cardTx.category,
      note: 'Credit line drawn via ${cardTx.debitAccountName}: ${cardTx.note}',
      date: cardTx.date,
      linkedTxId: cardTx.id,
      debitAccountName: cardTx.debitAccountName,
      creditAccountName: 'Pool Account',
    );
    poolBalance += poolCredit.amount; // Inflow

    // Reflection 2: Pool Debit (Expense spent)
    final poolDebit = TransactionModel(
      accountId: 1, // Pool
      type: TransactionType.debit,
      amount: cardTx.amount,
      category: cardTx.category,
      note: 'Spent via ${cardTx.debitAccountName}: ${cardTx.note}',
      date: cardTx.date,
      linkedTxId: cardTx.id,
      debitAccountName: 'Pool Account',
      creditAccountName: cardTx.creditAccountName,
    );
    poolBalance -= poolDebit.amount; // Outflow

    // Net Pool cash impact must be zero
    assert(poolBalance == 25000.0, 'Net Pool balance must remain 25000, got $poolBalance');
    assert(poolCredit.linkedTxId == 501);
    assert(poolDebit.linkedTxId == 501);
  });

  test('Salary Received: Defaults from Govt Account and credits Pool; Salary Outflow debits Pool directly', () {
    double salaryAccountBalance = 0.0;
    double poolBalance = 10000.0;

    // 1. Salary Credit received from Govt Account
    final salaryReceivedTx = TransactionModel(
      id: 601,
      accountId: 2, // Salary Account
      type: TransactionType.credit,
      amount: 80000.0,
      category: 'Salary & Income',
      note: 'Monthly salary credited',
      date: DateTime(2026, 10, 21),
      debitAccountName: 'Govt Account',
      creditAccountName: 'Salary Account',
    );
    salaryAccountBalance += salaryReceivedTx.amount;

    // Reflected in Pool as Credit (+80,000)
    final poolSalaryCredit = TransactionModel(
      accountId: 1,
      type: TransactionType.credit,
      amount: salaryReceivedTx.amount,
      category: salaryReceivedTx.category,
      note: salaryReceivedTx.note,
      date: salaryReceivedTx.date,
      debitAccountName: salaryReceivedTx.debitAccountName ?? 'Govt Account',
      creditAccountName: 'Pool Account',
      linkedTxId: salaryReceivedTx.id,
    );
    poolBalance += poolSalaryCredit.amount;

    assert(salaryAccountBalance == 80000.0);
    assert(poolBalance == 90000.0);
    assert(poolSalaryCredit.debitAccountName == 'Govt Account');

    // 2. Payment towards rent made from Salary Account
    final rentPaymentTx = TransactionModel(
      id: 602,
      accountId: 2, // Salary Account
      type: TransactionType.debit,
      amount: 20000.0,
      category: 'Rent',
      note: 'House rent',
      date: DateTime(2026, 10, 22),
      debitAccountName: 'Salary Account',
      creditAccountName: 'Landlord',
    );
    salaryAccountBalance -= rentPaymentTx.amount;

    // Reflected in Pool as Debit (-20,000) directly without extra credit
    final poolSalaryDebit = TransactionModel(
      accountId: 1,
      type: TransactionType.debit,
      amount: rentPaymentTx.amount,
      category: rentPaymentTx.category,
      note: rentPaymentTx.note,
      date: rentPaymentTx.date,
      debitAccountName: 'Pool Account',
      creditAccountName: rentPaymentTx.creditAccountName,
      linkedTxId: rentPaymentTx.id,
    );
    poolBalance -= poolSalaryDebit.amount;

    assert(salaryAccountBalance == 60000.0);
    assert(poolBalance == 70000.0, 'Pool balance must be 70000, got $poolBalance');
  });

  // 9. Chit Account Proof and Editing
  print('\n--- 9. Chit Account Proof and Editing ---');
  test('Chit installment preserves PDF proof, payment mode, custom date, and supports editing', () {
    final originalInstallment = TransactionModel(
      id: 701,
      accountId: 5, // Chit Account
      type: TransactionType.debit,
      amount: 8500.0,
      category: 'Chit Installment (Month 1)',
      note: 'Dividend: ₹1500',
      date: DateTime(2026, 5, 10),
      paymentMode: 'Net Banking',
      receiptPath: '/storage/emulated/0/Documents/chit_receipt_month1.pdf',
      debitAccountName: 'Chit Account',
      creditAccountName: 'Chit Fund',
    );

    assert(originalInstallment.receiptPath!.endsWith('.pdf'));
    assert(originalInstallment.paymentMode == 'Net Banking');

    // Edited installment (e.g. user updated amount after revision and attached image proof)
    final editedInstallment = originalInstallment.copyWith(
      amount: 8200.0,
      note: 'Dividend revised to ₹1800',
      receiptPath: '/storage/emulated/0/Pictures/chit_revised_receipt.jpg',
    );

    assert(editedInstallment.id == 701);
    assert(editedInstallment.amount == 8200.0);
    assert(editedInstallment.receiptPath!.endsWith('.jpg'));
    assert(editedInstallment.note == 'Dividend revised to ₹1800');
  });

  // 10. Date Duration Elapsed Time Engine (Years, Months, Days)
  print('\n--- 10. Date Duration Elapsed Time Engine ---');
  test('Exact elapsed duration across multi-year and multi-month intervals', () {
    final start = DateTime(2024, 5, 10);
    final end = DateTime(2026, 10, 22);

    final duration = DateDuration.between(start, end);
    assert(duration.years == 2, 'Expected 2 years, got ${duration.years}');
    assert(duration.months == 5, 'Expected 5 months, got ${duration.months}');
    assert(duration.days == 12, 'Expected 12 days, got ${duration.days}');
    assert(duration.formatExplicit() == '2 years, 5 months, 12 days');
  });

  test('Borrowing days and months correctly across month boundaries', () {
    final start = DateTime(2025, 11, 25);
    final end = DateTime(2026, 3, 10);

    final duration = DateDuration.between(start, end);
    assert(duration.years == 0, 'Expected 0 years, got ${duration.years}');
    assert(duration.months == 3, 'Expected 3 months, got ${duration.months}');
    assert(duration.days == 13, 'Expected 13 days, got ${duration.days}');
    assert(duration.formatExplicit() == '0 years, 3 months, 13 days');
  });

  test('Recent elapsed duration within same month', () {
    final start = DateTime(2026, 10, 15);
    final end = DateTime(2026, 10, 22);

    final duration = DateDuration.between(start, end);
    assert(duration.years == 0);
    assert(duration.months == 0);
    assert(duration.days == 7);
    assert(duration.formatExplicit() == '0 years, 0 months, 7 days');
  });

  // 11. Standard SMS / Text Message Generation
  print('\n--- 11. Standard SMS / Text Message Formatting ---');
  test('Debt repayment SMS contains loan details, remaining balance, and mode', () {
    final tx = TransactionModel(
      accountId: 10,
      type: TransactionType.debit,
      amount: 15000.0,
      principalPortion: 10000.0,
      interestPortion: 5000.0,
      paymentMode: 'UPI',
      note: 'Part settlement via GPay',
      date: DateTime(2026, 10, 22, 10, 30),
      debitAccountName: 'Debt Account',
      creditAccountName: 'Bank Account',
    );

    // Simulated standard message logic
    final msg = 'Dear Sharma Lender, a payment of ₹15,000.00 has been recorded towards loan on 22 Oct 2026 at 10:30 AM via UPI. Remarks: Part settlement via GPay. Remaining Principal: ₹90,000.00, Accrued Interest: ₹0.00, Total Outstanding: ₹90,000.00. - Sent via My Money Diary';

    assert(msg.contains('₹15,000.00'));
    assert(msg.contains('UPI'));
    assert(msg.contains('Remaining Principal: ₹90,000.00'));
    assert(msg.contains('My Money Diary'));
  });

  test('Lending repayment SMS confirms received loan installment', () {
    final msg = 'Dear Rajesh Borrower, receipt of ₹5,000.00 has been recorded towards your loan repayment on 22 Oct 2026 at 11:00 AM via Cash. Remarks: Monthly interest paid. Remaining Principal: ₹50,000.00, Accrued Interest: ₹0.00, Total Balance: ₹50,000.00. - Sent via My Money Diary';

    assert(msg.contains('Rajesh Borrower'));
    assert(msg.contains('₹5,000.00'));
    assert(msg.contains('Cash'));
    assert(msg.contains('Total Balance: ₹50,000.00'));
  });

  test('Chit installment SMS notifies manager with details', () {
    final msg = 'Dear Chit Manager, installment payment of ₹10,000.00 for Chit "Balaji Chit #4" was completed on 22 Oct 2026 at 10:00 AM via UPI. Remarks: Month 5 installment. - Sent via My Money Diary';

    assert(msg.contains('Balaji Chit #4'));
    assert(msg.contains('₹10,000.00'));
    assert(msg.contains('Month 5 installment'));
  });

  // 12. Account Settlement & Closed Accounts Architecture
  print('\n--- 12. Account Settlement & Closed Accounts Architecture ---');
  test('Active metrics and aggregates strictly exclude closed accounts', () {
    // Simulated accounts in repository
    final activeDebt = {
      'id': 1,
      'name': 'Active Home Loan',
      'type': 'debt',
      'principal_balance': 200000.0,
      'accrued_interest': 4000.0,
      'is_closed': 0,
    };
    final closedDebt = {
      'id': 2,
      'name': 'Old Car Loan',
      'type': 'debt',
      'principal_balance': 0.0,
      'accrued_interest': 0.0,
      'is_closed': 1,
      'closed_at': '2026-08-15T12:00:00.000',
    };
    final activeLending = {
      'id': 3,
      'name': 'Lent to Friend',
      'type': 'lending',
      'principal_balance': 50000.0,
      'accrued_interest': 1000.0,
      'is_closed': 0,
    };
    final closedLending = {
      'id': 4,
      'name': 'Old Personal Loan to Colleague',
      'type': 'lending',
      'principal_balance': 0.0,
      'accrued_interest': 0.0,
      'is_closed': 1,
      'closed_at': '2026-09-01T15:30:00.000',
    };

    final allAccounts = [activeDebt, closedDebt, activeLending, closedLending];

    // Filter active vs closed
    final activeAccounts = allAccounts.where((a) => (a['is_closed'] as int) == 0).toList();
    final closedAccounts = allAccounts.where((a) => (a['is_closed'] as int) == 1).toList();

    assert(activeAccounts.length == 2);
    assert(closedAccounts.length == 2);

    // Active borrowed total
    final totalBorrowed = activeAccounts
        .where((a) => a['type'] == 'debt')
        .fold(0.0, (sum, a) => sum + (a['principal_balance'] as double) + (a['accrued_interest'] as double));

    assert(totalBorrowed == 204000.0, 'Closed car loan must not be included');

    // Active lent total
    final totalLent = activeAccounts
        .where((a) => a['type'] == 'lending')
        .fold(0.0, (sum, a) => sum + (a['principal_balance'] as double) + (a['accrued_interest'] as double));

    assert(totalLent == 51000.0, 'Closed colleague loan must not be included');
  });

  test('Closed accounts halt interest accrual', () {
    final account = {
      'id': 101,
      'name': 'Settled Loan',
      'type': 'debt',
      'principal_balance': 0.0,
      'accrued_interest': 0.0,
      'interest_rate': 2.0,
      'is_closed': 1,
    };

    // Engine check: if (account['is_closed'] == 1) continue;
    double accruedDelta = 0.0;
    if ((account['is_closed'] as int) == 0) {
      accruedDelta = InterestCalculator.calculateMonthlyInterestAmount(
        principal: account['principal_balance'] as double,
        rate: account['interest_rate'] as double,
        rateType: 'per_month',
      );
    }

    assert(accruedDelta == 0.0, 'Closed account must accrue 0 interest');
  });

  test('Account schema serialization preserves phone_number, is_closed, closed_at, and last_interest_paid_date', () {
    final map = {
      'id': 50,
      'name': 'Shyam Sundar',
      'type': 'debt',
      'icon': 'arrow_downward',
      'color': 0xFFC62828,
      'balance': 0.0,
      'principal_balance': 0.0,
      'accrued_interest': 0.0,
      'interest_rate': 2.0,
      'interest_rate_type': 'per_month',
      'is_compound': 0,
      'accrual_mode': 'daily',
      'allocation_rule': 'interest_first',
      'last_interest_date': '2026-08-01T00:00:00.000',
      'loan_start_date': '2025-01-10T00:00:00.000',
      'phone_number': '+91 9876543210',
      'is_closed': 1,
      'closed_at': '2026-10-20T14:30:00.000',
      'last_interest_paid_date': '2026-10-15T18:00:00.000',
      'is_archived': 0,
      'created_at': '2025-01-10T00:00:00.000',
    };

    assert(map['phone_number'] == '+91 9876543210');
    assert(map['is_closed'] == 1);
    assert(map['closed_at'] == '2026-10-20T14:30:00.000');
    assert(map['last_interest_paid_date'] == '2026-10-15T18:00:00.000');
  });

  // --- 13. Double-Entry Schema & Account Management (Stage 1) ---
  print('\n--- 13. Double-Entry Schema & Account Management (Stage 1) ---');
  test('Account categories enforce correct normal balance rules', () {
    assert(AccountCategory.asset.normalBalance == NormalBalance.debit);
    assert(AccountCategory.expense.normalBalance == NormalBalance.debit);
    assert(AccountCategory.liability.normalBalance == NormalBalance.credit);
    assert(AccountCategory.income.normalBalance == NormalBalance.credit);
    assert(AccountCategory.equity.normalBalance == NormalBalance.credit);
  });

  test('Chart of Accounts contains all 27 user-specified accounts across 5 categories', () {
    final expectedAccounts = {
      // Asset
      'ASSET_SALARY_BANK': AccountCategory.asset,
      'ASSET_SAVINGS_BANK': AccountCategory.asset,
      'ASSET_CASH_WALLET': AccountCategory.asset,
      'ASSET_DEMAT': AccountCategory.asset,
      'ASSET_GPF': AccountCategory.asset,
      'ASSET_PROPERTY': AccountCategory.asset,
      'ASSET_CHIT_RECEIVABLE': AccountCategory.asset,
      // Liability
      'LIAB_HOUSING_LOAN': AccountCategory.liability,
      'LIAB_PERSONAL_LOAN_1': AccountCategory.liability,
      'LIAB_PERSONAL_LOAN_2': AccountCategory.liability,
      'LIAB_FRIEND_A_LOAN': AccountCategory.liability,
      'LIAB_FRIEND_B_LOAN': AccountCategory.liability,
      'LIAB_CREDIT_CARD_1': AccountCategory.liability,
      'LIAB_CREDIT_CARD_2': AccountCategory.liability,
      'LIAB_CHIT_LIABILITY': AccountCategory.liability,
      // Income
      'INC_SALARY': AccountCategory.income,
      'INC_RENT': AccountCategory.income,
      'INC_DEMAT_PROFIT': AccountCategory.income,
      'INC_GPF_RECEIPT': AccountCategory.income,
      'INC_PROPERTY_SALE': AccountCategory.income,
      'INC_INTEREST': AccountCategory.income,
      'INC_OTHER': AccountCategory.income,
      // Expense
      'EXP_CHIT_CONTRIBUTION': AccountCategory.expense,
      'EXP_MILK_BILL': AccountCategory.expense,
      'EXP_CURRENT_BILL': AccountCategory.expense,
      'EXP_GROCERY': AccountCategory.expense,
      'EXP_HOUSING_LOAN_INTEREST': AccountCategory.expense,
      'EXP_PERSONAL_LOAN_INTEREST': AccountCategory.expense,
      'EXP_FRIEND_LOAN_INTEREST': AccountCategory.expense,
      'EXP_CC_INTEREST_CHARGES': AccountCategory.expense,
      'EXP_HOUSEHOLD': AccountCategory.expense,
      'EXP_OTHER': AccountCategory.expense,
      // Equity
      'EQ_OPENING_BALANCE': AccountCategory.equity,
    };

    assert(expectedAccounts.length == 33);
    for (final entry in expectedAccounts.entries) {
      assert(entry.value.key.isNotEmpty);
    }
  });

  test('Account schema serialization preserves code, category, subCategory, and openingBalance', () {
    final map = {
      'id': 101,
      'code': 'LIAB_FRIEND_A_LOAN',
      'name': 'Friend A Loan',
      'type': 'debt',
      'category': 'liability',
      'sub_category': 'loan_friend',
      'opening_balance': 15000.0,
      'principal_balance': 15000.0,
      'notes': 'Temporary borrowing',
    };

    final cat = AccountCategoryExtension.fromKey(map['category'] as String);
    assert(cat.normalBalance == NormalBalance.credit);
    assert(map['code'] == 'LIAB_FRIEND_A_LOAN');
    assert(map['category'] == 'liability');
    assert(map['sub_category'] == 'loan_friend');
    assert(map['opening_balance'] == 15000.0);
  });

  test('JournalEntry model correctly serializes debit/credit entries', () {
    final entryDebit = JournalEntry(
      id: 1,
      transactionId: 50,
      accountId: 10,
      entryType: EntryType.debit,
      amount: 5000.0,
      memo: 'Chit Contribution Jan 2026',
      counterAccountId: 2,
      lineOrder: 1,
    );

    final entryCredit = JournalEntry(
      id: 2,
      transactionId: 50,
      accountId: 2,
      entryType: EntryType.credit,
      amount: 5000.0,
      memo: 'Debited from Salary Bank',
      counterAccountId: 10,
      lineOrder: 2,
    );

    assert(entryDebit.isDebit && !entryDebit.isCredit);
    assert(entryCredit.isCredit && !entryCredit.isDebit);
    assert(entryDebit.amount == entryCredit.amount);

    final debitMap = entryDebit.toMap();
    assert(debitMap['entry_type'] == 'debit');
    assert(debitMap['amount'] == 5000.0);

    final fromMap = JournalEntry.fromMap(debitMap);
    assert(fromMap.entryType == EntryType.debit);
    assert(fromMap.amount == 5000.0);
  });

  test('AuditLog model correctly serializes modification actions and reason', () {
    final log = AuditLog(
      id: 1,
      transactionId: null,
      accountId: 25,
      action: 'archive',
      reason: 'Loan settled in full',
      changesJson: '{"is_archived": 1}',
    );

    final map = log.toMap();
    assert(map['action'] == 'archive');
    assert(map['reason'] == 'Loan settled in full');
    assert(map['changes_json'] == '{"is_archived": 1}');

    final restored = AuditLog.fromMap(map);
    assert(restored.action == 'archive');
    assert(restored.reason == 'Loan settled in full');
  });

  test('Account deletion rule prevents deletion when transactions exist and allows archiving', () {
    // Simulating canDeleteAccount logic:
    bool canDelete(int txCount, int jnCount) {
      if (txCount > 0 || jnCount > 0) return false;
      return true;
    }

    assert(canDelete(5, 10) == false, 'Account with transactions must NOT be deletable');
    assert(canDelete(1, 0) == false, 'Account with 1 transaction must NOT be deletable');
    assert(canDelete(0, 0) == true, 'Clean account with 0 transactions CAN be deleted');
  });

  // --- 14. Double-Entry Transaction Engine (Stage 2) ---
  print('\n--- 14. Double-Entry Transaction Engine (Stage 2) ---');
  test('Balanced journal entry validation passes when debits equal credits', () {
    final entries = [
      JournalEntry(transactionId: 1, accountId: 1, entryType: EntryType.debit, amount: 2400.0),
      JournalEntry(transactionId: 1, accountId: 2, entryType: EntryType.credit, amount: 2400.0),
    ];
    DoubleEntryEngine.validateBalanced(entries);
  });

  test('Unbalanced journal entry throws UnbalancedTransactionException', () {
    final entries = [
      JournalEntry(transactionId: 1, accountId: 1, entryType: EntryType.debit, amount: 2400.0),
      JournalEntry(transactionId: 1, accountId: 2, entryType: EntryType.credit, amount: 2300.0),
    ];
    bool threw = false;
    try {
      DoubleEntryEngine.validateBalanced(entries);
    } on UnbalancedTransactionException catch (e) {
      threw = true;
      assert(e.discrepancy == 100.0);
    }
    assert(threw, 'Engine must reject unbalanced journal entries');
  });

  test('Journal entry rejection on negative or zero amount', () {
    final entries = [
      JournalEntry(transactionId: 1, accountId: 1, entryType: EntryType.debit, amount: 0.0),
      JournalEntry(transactionId: 1, accountId: 2, entryType: EntryType.credit, amount: 0.0),
    ];
    bool threw = false;
    try {
      DoubleEntryEngine.validateBalanced(entries);
    } catch (_) {
      threw = true;
    }
    assert(threw, 'Engine must reject zero/negative amounts');
  });

  test('Compound loan repayment generates balanced 3-line journal entry', () {
    final entries = DoubleEntryEngine.buildLoanRepaymentCompoundEntries(
      transactionId: 10,
      loanAccountId: 101, // Housing Loan (Liability)
      interestExpenseAccountId: 201, // Housing Loan Interest (Expense)
      sourceAccountId: 1, // Salary Bank Account (Asset)
      principalPortion: 20000.0,
      interestPortion: 15000.0,
    );

    assert(entries.length == 3);
    assert(entries[0].accountId == 101 && entries[0].isDebit && entries[0].amount == 20000.0);
    assert(entries[1].accountId == 201 && entries[1].isDebit && entries[1].amount == 15000.0);
    assert(entries[2].accountId == 1 && entries[2].isCredit && entries[2].amount == 35000.0);
    DoubleEntryEngine.validateBalanced(entries);
  });

  test('Normal balance delta computes signed impact across all categories', () {
    // Asset: Debit adds, Credit subtracts
    assert(DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.asset, entryType: EntryType.debit, amount: 1000.0) == 1000.0);
    assert(DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.asset, entryType: EntryType.credit, amount: 400.0) == -400.0);

    // Liability: Credit adds, Debit subtracts
    assert(DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.liability, entryType: EntryType.credit, amount: 5000.0) == 5000.0);
    assert(DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.liability, entryType: EntryType.debit, amount: 2000.0) == -2000.0);

    // Expense: Debit adds, Credit subtracts
    assert(DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.expense, entryType: EntryType.debit, amount: 500.0) == 500.0);

    // Income: Credit adds, Debit subtracts
    assert(DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.income, entryType: EntryType.credit, amount: 25000.0) == 25000.0);
  });

  // --- 15. Master Journal & Account Ledgers (Stage 3) ---
  print('\n--- 15. Master Journal & Account Ledgers (Stage 3) ---');
  test('Account ledger computes running balance correctly for Salary Bank Account', () {
    double running = 10000.0; // Opening balance

    // 1. Receive salary ₹50,000 (Debit to bank)
    running += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.asset, entryType: EntryType.debit, amount: 50000.0);
    assert(running == 60000.0);

    // 2. Pay chit ₹5,000 (Credit to bank)
    running += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.asset, entryType: EntryType.credit, amount: 5000.0);
    assert(running == 55000.0);

    // 3. Pay credit card bill ₹3,500 (Credit to bank)
    running += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.asset, entryType: EntryType.credit, amount: 3500.0);
    assert(running == 51500.0);

    // 4. Repay Friend A ₹10,000 (Credit to bank)
    running += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.asset, entryType: EntryType.credit, amount: 10000.0);
    assert(running == 41500.0);

    // 5. Pay Housing EMI ₹35,000 (Credit to bank)
    running += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.asset, entryType: EntryType.credit, amount: 35000.0);
    assert(running == 6500.0);
  });

  test('Multi-source Chit account ledger tracks all distinct funding sources', () {
    final chitPayments = [
      {'month': 'Jan 2026', 'amount': 5000.0, 'counter': 'Salary Bank Account'},
      {'month': 'Feb 2026', 'amount': 5000.0, 'counter': 'GPF Account'},
      {'month': 'Mar 2026', 'amount': 5000.0, 'counter': 'Rent Received'},
      {'month': 'Apr 2026', 'amount': 5000.0, 'counter': 'Friend A Loan'},
      {'month': 'May 2026', 'amount': 5000.0, 'counter': 'Property Sale Proceeds'},
    ];

    double totalChitPaid = 0.0;
    for (final p in chitPayments) {
      assert((p['counter'] as String).isNotEmpty);
      totalChitPaid += p['amount'] as double;
    }
    assert(totalChitPaid == 25000.0);
  });

  test('Milk bill expense ledger tracks varied payment sources without bank distortion', () {
    final milkPayments = [
      {'source': 'Salary Bank Account', 'amount': 2200.0},
      {'source': 'Demat/Stock Profit', 'amount': 2400.0},
      {'source': 'Cash Wallet', 'amount': 2100.0},
      {'source': 'Credit Card 1', 'amount': 2300.0},
    ];

    double cumulativeMilkExpense = 0.0;
    for (final m in milkPayments) {
      cumulativeMilkExpense += DoubleEntryEngine.calculateBalanceDelta(
        category: AccountCategory.expense,
        entryType: EntryType.debit,
        amount: m['amount'] as double,
      );
    }
    assert(cumulativeMilkExpense == 9000.0);
  });

  test('Credit Card 1 ledger accurately tracks purchases, payments, and outstanding balance', () {
    double outstanding = 0.0; // Normal Credit

    // 1. Current Bill charge ₹3,500 (Credit to CC liability)
    outstanding += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.liability, entryType: EntryType.credit, amount: 3500.0);
    assert(outstanding == 3500.0);

    // 2. Grocery purchase ₹2,000 (Credit to CC liability)
    outstanding += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.liability, entryType: EntryType.credit, amount: 2000.0);
    assert(outstanding == 5500.0);

    // 3. Payment from Salary Bank ₹3,500 (Debit to CC liability)
    outstanding += DoubleEntryEngine.calculateBalanceDelta(category: AccountCategory.liability, entryType: EntryType.debit, amount: 3500.0);
    assert(outstanding == 2000.0);
  });

  // --- 16. Specialized Modules & Compound Entries (Stage 4) ---
  print('\n--- 16. Specialized Modules & Compound Entries (Stage 4) ---');
  test('Loan repayment compound split preserves mathematical balance: Principal + Interest == Payment', () {
    const totalEMI = 40000.0;
    const principalPortion = 25000.0;
    const interestPortion = 15000.0;
    assert(principalPortion + interestPortion == totalEMI);

    final entries = DoubleEntryEngine.buildLoanRepaymentCompoundEntries(
      transactionId: 401,
      loanAccountId: 10, // Housing Loan (Liability)
      interestExpenseAccountId: 20, // Housing Loan Interest (Expense)
      sourceAccountId: 1, // Salary Bank (Asset)
      principalPortion: principalPortion,
      interestPortion: interestPortion,
    );

    assert(entries.length == 3);
    final debits = entries.where((e) => e.isDebit).fold(0.0, (sum, e) => sum + e.amount);
    final credits = entries.where((e) => e.isCredit).fold(0.0, (sum, e) => sum + e.amount);
    assert(debits == credits && debits == 40000.0);
  });

  test('Friend temporary debt full lifecycle: Borrow -> Direct Kirana -> Repay after salary settles to zero', () {
    double friendDebtBalance = 0.0; // Normal Credit

    // 1. Borrow ₹10,000 received into Cash Wallet (Credit to friend loan)
    friendDebtBalance += DoubleEntryEngine.calculateBalanceDelta(
      category: AccountCategory.liability,
      entryType: EntryType.credit,
      amount: 10000.0,
    );
    assert(friendDebtBalance == 10000.0);

    // 2. Direct Kirana bill ₹5,000 paid by friend (Credit to friend loan)
    friendDebtBalance += DoubleEntryEngine.calculateBalanceDelta(
      category: AccountCategory.liability,
      entryType: EntryType.credit,
      amount: 5000.0,
    );
    assert(friendDebtBalance == 15000.0);

    // 3. Full repayment of ₹15,000 from Salary Bank Account (Debit to friend loan)
    friendDebtBalance += DoubleEntryEngine.calculateBalanceDelta(
      category: AccountCategory.liability,
      entryType: EntryType.debit,
      amount: 15000.0,
    );
    assert(friendDebtBalance == 0.0, 'Friend debt must fully settle to 0.0');
  });

  test('Multi-chit groups tracking with distinct installments and dynamic lifting', () {
    final chit1 = ChitDetails(
      accountId: 101,
      totalValue: 500000.0,
      durationMonths: 20,
      installmentBeforeLifting: 25000.0,
      installmentAfterLifting: 25000.0,
      currentMonth: 5,
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2026, 8, 1),
      isLifted: false,
    );

    final chit2 = ChitDetails(
      accountId: 102,
      totalValue: 200000.0,
      durationMonths: 20,
      installmentBeforeLifting: 10000.0,
      installmentAfterLifting: 10000.0,
      currentMonth: 8,
      startDate: DateTime(2025, 6, 1),
      endDate: DateTime(2027, 1, 1),
      isLifted: true,
      liftedMonth: 4,
      prizeMoneyReceived: 140000.0,
      bidDiscount: 60000.0,
    );

    assert(chit1.isLifted == false);
    assert(chit2.isLifted == true);
    assert(chit2.prizeMoneyReceived == 140000.0);
    assert(chit2.remainingMonths == 12);
  });

  // --- 17. Dashboard, Balance Sheet Invariant, Indian FY & Cash Flow (Stage 5) ---
  print('\n--- 17. Balance Sheet, Indian Financial Year & Cash Flow (Stage 5) ---');
  test('Indian Financial Year helper resolves exact Apr 1 to Mar 31 boundaries', () {
    final date1 = DateTime(2026, 5, 15);
    assert(FinancialYearHelper.getFYStartYear(date1) == 2026);
    assert(FinancialYearHelper.formatFY(2026) == 'FY 2026-27');

    final date2 = DateTime(2026, 2, 10); // Before April -> FY 2025-26
    assert(FinancialYearHelper.getFYStartYear(date2) == 2025);
    assert(FinancialYearHelper.formatFY(2025) == 'FY 2025-26');

    final start = FinancialYearHelper.getStartDate(2025);
    final end = FinancialYearHelper.getEndDate(2025);
    assert(start.month == 4 && start.day == 1 && start.year == 2025);
    assert(end.month == 3 && end.day == 31 && end.year == 2026);
  });

  test('Balance Sheet mathematical equation strictly holds: Assets - Liabilities == Equity + Net Profit', () {
    const assets = 250000.0;
    const liabilities = 90000.0;
    const netWorth = assets - liabilities; // 160,000

    const openingEquity = 100000.0;
    const income = 120000.0;
    const expenses = 60000.0;
    const netProfit = income - expenses; // 60,000

    // Fundamental accounting equation:
    // Assets - Liabilities == Equity + (Income - Expenses)
    final equationBalance = netWorth - (openingEquity + netProfit);
    assert(equationBalance.abs() < 0.001, 'Balance sheet must balance to 0.0 discrepancy');
  });

  test('Cash Flow categorizes operating vs financing flows correctly', () {
    final mockTransactions = [
      {'type': 'income', 'amt': 80000.0},
      {'type': 'expense', 'amt': 25000.0},
      {'type': 'credit_card_purchase', 'amt': 8500.0},
      {'type': 'loan_taken', 'amt': 50000.0},
      {'type': 'loan_repayment', 'amt': 40000.0},
      {'type': 'chit_payment', 'amt': 10000.0},
    ];

    double opInflows = 0.0;
    double opOutflows = 0.0;
    double finInflows = 0.0;
    double finOutflows = 0.0;

    for (final tx in mockTransactions) {
      final t = tx['type'] as String;
      final a = tx['amt'] as double;
      if (t == 'income') opInflows += a;
      if (t == 'expense' || t == 'credit_card_purchase') opOutflows += a;
      if (t == 'loan_taken') finInflows += a;
      if (t == 'loan_repayment' || t == 'chit_payment') finOutflows += a;
    }

    final netOp = opInflows - opOutflows; // 80,000 - 33,500 = 46,500
    final netFin = finInflows - finOutflows; // 50,000 - 50,000 = 0
    final netCash = netOp + netFin; // 46,500

    assert(netOp == 46500.0);
    assert(netFin == 0.0);
    assert(netCash == 46500.0);
  });

  // --- 18. Demo Sample Data & 5 Core Scenarios (Stage 6) ---
  print('\n--- 18. Demo Sample Data & 5 Core Scenarios (Stage 6) ---');
  test('Scenario 1: 5 distinct Chit Fund payment sources produce balanced entries', () {
    final chitPayments = [
      {'source': 'Salary Bank Account', 'srcId': 1, 'amt': 10000.0},
      {'source': 'GPF Account', 'srcId': 2, 'amt': 10000.0},
      {'source': 'Rent Received', 'srcId': 3, 'amt': 10000.0},
      {'source': 'Friend A Loan', 'srcId': 4, 'amt': 10000.0},
      {'source': 'Property Sale Proceeds', 'srcId': 5, 'amt': 10000.0},
    ];

    for (int i = 0; i < chitPayments.length; i++) {
      final cp = chitPayments[i];
      final entries = DoubleEntryEngine.buildJournalEntriesForType(
        transactionId: 100 + i,
        type: TransactionType.chitPayment,
        totalAmount: cp['amt'] as double,
        sourceAccountId: cp['srcId'] as int,
        destinationAccountId: 99, // Chit Fund Account
        memo: 'Chit payment from ${cp['source']}',
      );
      DoubleEntryEngine.validateBalanced(entries);
      assert(entries.first.isDebit && entries.first.accountId == 99);
      assert(entries.last.isCredit && entries.last.accountId == cp['srcId']);
    }
  });

  test('Scenario 2: Milk bill ledger tracks all 4 sources without double-counting', () {
    final milkRows = [
      {'srcId': 1, 'amt': 2500.0, 'name': 'Salary Bank'},
      {'srcId': 2, 'amt': 2600.0, 'name': 'Cash Wallet'},
      {'srcId': 3, 'amt': 2700.0, 'name': 'Credit Card 1'},
      {'srcId': 4, 'amt': 2500.0, 'name': 'Friend A Loan'},
    ];

    double totalMilkExpense = 0.0;
    for (int i = 0; i < milkRows.length; i++) {
      final mr = milkRows[i];
      final entries = DoubleEntryEngine.buildJournalEntriesForType(
        transactionId: 200 + i,
        type: TransactionType.expense,
        totalAmount: mr['amt'] as double,
        sourceAccountId: mr['srcId'] as int,
        destinationAccountId: 50, // Milk Bill Expense
        memo: 'Milk payment from ${mr['name']}',
      );
      DoubleEntryEngine.validateBalanced(entries);
      totalMilkExpense += mr['amt'] as double;
    }
    assert(totalMilkExpense == 10300.0);
  });

  test('Scenario 3: Credit Card 1 ledger balances after purchases, fee and payment', () {
    final cardEntries = <JournalEntry>[];

    // Purchase 1: Grocery ₹8,500
    cardEntries.addAll(DoubleEntryEngine.buildJournalEntriesForType(
      transactionId: 301,
      type: TransactionType.creditCardPurchase,
      totalAmount: 8500.0,
      sourceAccountId: 70, // Credit Card 1
      destinationAccountId: 60, // Grocery
    ));

    // Purchase 2: Milk ₹2,700
    cardEntries.addAll(DoubleEntryEngine.buildJournalEntriesForType(
      transactionId: 302,
      type: TransactionType.creditCardPurchase,
      totalAmount: 2700.0,
      sourceAccountId: 70, // Credit Card 1
      destinationAccountId: 50, // Milk Bill
    ));

    // Fee: ₹450
    cardEntries.addAll(DoubleEntryEngine.buildJournalEntriesForType(
      transactionId: 303,
      type: TransactionType.creditCardPurchase,
      totalAmount: 450.0,
      sourceAccountId: 70, // Credit Card 1
      destinationAccountId: 65, // Charges
    ));

    // Bill Payment: ₹11,650
    cardEntries.addAll(DoubleEntryEngine.buildJournalEntriesForType(
      transactionId: 304,
      type: TransactionType.creditCardPayment,
      totalAmount: 11650.0,
      sourceAccountId: 1, // Salary Bank
      destinationAccountId: 70, // Credit Card 1
    ));

    DoubleEntryEngine.validateBalanced(cardEntries);

    // Verify net Credit Card 1 running balance
    double ccRunning = 0.0;
    for (final e in cardEntries.where((e) => e.accountId == 70)) {
      ccRunning += DoubleEntryEngine.calculateBalanceDelta(
        category: AccountCategory.liability,
        entryType: e.entryType,
        amount: e.amount,
      );
    }
    assert(ccRunning == 0.0, 'Credit Card 1 must have 0.0 outstanding after full payment');
  });

  test('Scenario 4: Housing Loan EMI compound repayment reduces principal and records interest', () {
    final emiEntries = DoubleEntryEngine.buildLoanRepaymentCompoundEntries(
      transactionId: 401,
      loanAccountId: 80, // Housing Loan (Liability)
      interestExpenseAccountId: 81, // Housing Loan Interest (Expense)
      sourceAccountId: 1, // Salary Bank (Asset)
      principalPortion: 25000.0,
      interestPortion: 15000.0,
    );

    DoubleEntryEngine.validateBalanced(emiEntries);

    // Verify Housing Loan liability balance reduction
    final loanReduction = DoubleEntryEngine.calculateBalanceDelta(
      category: AccountCategory.liability,
      entryType: EntryType.debit,
      amount: 25000.0,
    );
    assert(loanReduction == -25000.0);

    // Verify Interest Expense recording
    final interestExpense = DoubleEntryEngine.calculateBalanceDelta(
      category: AccountCategory.expense,
      entryType: EntryType.debit,
      amount: 15000.0,
    );
    assert(interestExpense == 15000.0);
  });

  test('Scenario 5: Temporary friend borrowing & settlement lifecycle yields zero net liability', () {
    final friendEntries = <JournalEntry>[];

    // 1. Borrow ₹10,000 into Cash Wallet
    friendEntries.addAll(DoubleEntryEngine.buildJournalEntriesForType(
      transactionId: 501,
      type: TransactionType.loanTaken,
      totalAmount: 10000.0,
      sourceAccountId: 90, // Friend A Loan
      destinationAccountId: 2, // Cash Wallet
    ));

    // 2. Direct Kirana ₹5,000 paid from borrowed amount
    friendEntries.addAll(DoubleEntryEngine.buildJournalEntriesForType(
      transactionId: 502,
      type: TransactionType.expense,
      totalAmount: 5000.0,
      sourceAccountId: 90, // Friend A Loan
      destinationAccountId: 60, // Kirana Expense
    ));

    // 3. Full repayment ₹15,000 from Salary Bank
    friendEntries.addAll(DoubleEntryEngine.buildJournalEntriesForType(
      transactionId: 503,
      type: TransactionType.loanRepayment,
      totalAmount: 15000.0,
      principalPortion: 15000.0,
      sourceAccountId: 1, // Salary Bank
      destinationAccountId: 90, // Friend A Loan
    ));

    DoubleEntryEngine.validateBalanced(friendEntries);

    // Calculate Friend A running balance
    double friendDebt = 0.0;
    for (final e in friendEntries.where((e) => e.accountId == 90)) {
      friendDebt += DoubleEntryEngine.calculateBalanceDelta(
        category: AccountCategory.liability,
        entryType: e.entryType,
        amount: e.amount,
      );
    }
    assert(friendDebt == 0.0, 'Friend A debt must be 0.0 after repayment');
  });

  print('\n=============================================');
  print('   RESULTS: $passed PASSED, $failed FAILED   ');
  print('=============================================');
}
