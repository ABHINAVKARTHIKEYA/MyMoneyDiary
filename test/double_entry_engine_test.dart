import 'package:flutter_test/flutter_test.dart';
import '../lib/models/account.dart';
import '../lib/models/account_category.dart';
import '../lib/models/journal_entry.dart';
import '../lib/models/transaction_model.dart';
import '../lib/models/transaction_type.dart';
import '../lib/services/double_entry_engine.dart';
import '../lib/utils/financial_year_helper.dart';

void main() {
  group('DoubleEntryEngine & Accounting Unit Tests', () {
    test('AccountCategory attributes and normal balance', () {
      expect(AccountCategory.asset.normalBalance, NormalBalance.debit);
      expect(AccountCategory.expense.normalBalance, NormalBalance.debit);
      expect(AccountCategory.liability.normalBalance, NormalBalance.credit);
      expect(AccountCategory.income.normalBalance, NormalBalance.credit);
      expect(AccountCategory.equity.normalBalance, NormalBalance.credit);

      expect(AccountCategory.asset.displayName, 'Assets');
      expect(AccountCategory.liability.displayName, 'Liabilities');
    });

    test('Validates debits equal credits in balanced journal entry', () {
      final entries = [
        JournalEntry(
          transactionId: 1,
          accountId: 10,
          entryType: JournalEntryType.debit,
          amount: 5000.0,
        ),
        JournalEntry(
          transactionId: 1,
          accountId: 20,
          entryType: JournalEntryType.credit,
          amount: 5000.0,
        ),
      ];

      expect(DoubleEntryEngine.validateDebitsEqualCredits(entries), isTrue);
      expect(DoubleEntryEngine.sumDebits(entries), 5000.0);
      expect(DoubleEntryEngine.sumCredits(entries), 5000.0);
    });

    test('Throws UnbalancedTransactionException when debits != credits', () {
      final entries = [
        JournalEntry(
          transactionId: 2,
          accountId: 10,
          entryType: JournalEntryType.debit,
          amount: 5000.0,
        ),
        JournalEntry(
          transactionId: 2,
          accountId: 20,
          entryType: JournalEntryType.credit,
          amount: 4000.0,
        ),
      ];

      expect(
        () => DoubleEntryEngine.validateJournalEntries(entries),
        throwsA(isA<UnbalancedTransactionException>()),
      );
    });

    test('Compound EMI repayment entry balances perfectly', () {
      final compoundEntries = DoubleEntryEngine.generateCompoundLoanRepayment(
        transactionId: 99,
        sourceBankAccountId: 1, // Salary Bank
        loanLiabilityAccountId: 2, // Housing Loan
        interestExpenseAccountId: 3, // Housing Loan Interest
        principalAmount: 35000.0,
        interestAmount: 15000.0,
      );

      expect(DoubleEntryEngine.validateDebitsEqualCredits(compoundEntries), isTrue);
      expect(DoubleEntryEngine.sumDebits(compoundEntries), 50000.0);
      expect(DoubleEntryEngine.sumCredits(compoundEntries), 50000.0);
    });

    test('Indian Financial Year helper resolves FY2026-27 accurately', () {
      final dateInMay2026 = DateTime(2026, 5, 15);
      final fy = FinancialYearHelper.getFinancialYear(dateInMay2026);
      expect(fy.label, 'FY 2026-27');
      expect(fy.startDate, DateTime(2026, 4, 1));
      expect(fy.endDate, DateTime(2027, 3, 31, 23, 59, 59));

      final dateInJan2026 = DateTime(2026, 1, 10);
      final fyJan = FinancialYearHelper.getFinancialYear(dateInJan2026);
      expect(fyJan.label, 'FY 2025-26');
    });
  });
}
