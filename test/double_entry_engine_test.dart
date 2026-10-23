import 'package:flutter_test/flutter_test.dart';
import '../lib/models/account_category.dart';
import '../lib/models/journal_entry.dart';
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
          entryType: EntryType.debit,
          amount: 5000.0,
        ),
        JournalEntry(
          transactionId: 1,
          accountId: 20,
          entryType: EntryType.credit,
          amount: 5000.0,
        ),
      ];

      expect(() => DoubleEntryEngine.validateBalanced(entries), returnsNormally);
    });

    test('Throws UnbalancedTransactionException when debits != credits', () {
      final entries = [
        JournalEntry(
          transactionId: 2,
          accountId: 10,
          entryType: EntryType.debit,
          amount: 5000.0,
        ),
        JournalEntry(
          transactionId: 2,
          accountId: 20,
          entryType: EntryType.credit,
          amount: 4000.0,
        ),
      ];

      expect(
        () => DoubleEntryEngine.validateBalanced(entries),
        throwsA(isA<UnbalancedTransactionException>()),
      );
    });

    test('Compound EMI repayment entry balances perfectly', () {
      final compoundEntries = DoubleEntryEngine.buildLoanRepaymentCompoundEntries(
        transactionId: 99,
        sourceAccountId: 1, // Salary Bank
        loanAccountId: 2, // Housing Loan
        interestExpenseAccountId: 3, // Housing Loan Interest
        principalPortion: 35000.0,
        interestPortion: 15000.0,
      );

      expect(compoundEntries.length, 3);
      expect(() => DoubleEntryEngine.validateBalanced(compoundEntries), returnsNormally);
    });

    test('Indian Financial Year helper resolves FY2026-27 accurately', () {
      final dateInMay2026 = DateTime(2026, 5, 15);
      final fyStartYear = FinancialYearHelper.getFYStartYear(dateInMay2026);
      expect(fyStartYear, 2026);
      expect(FinancialYearHelper.formatFY(fyStartYear), 'FY 2026-27');
      expect(FinancialYearHelper.getStartDate(fyStartYear), DateTime(2026, 4, 1, 0, 0, 0));
      expect(FinancialYearHelper.getEndDate(fyStartYear), DateTime(2027, 3, 31, 23, 59, 59));

      final dateInJan2026 = DateTime(2026, 1, 10);
      final fyJanStartYear = FinancialYearHelper.getFYStartYear(dateInJan2026);
      expect(fyJanStartYear, 2025);
      expect(FinancialYearHelper.formatFY(fyJanStartYear), 'FY 2025-26');
    });
  });
}
