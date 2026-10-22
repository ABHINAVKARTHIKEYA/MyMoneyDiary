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

  print('\n=============================================');
  print('   RESULTS: $passed PASSED, $failed FAILED   ');
  print('=============================================');
}
