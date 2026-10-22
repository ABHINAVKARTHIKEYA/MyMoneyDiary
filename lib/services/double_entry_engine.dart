import '../models/account_category.dart';
import '../models/journal_entry.dart';
import '../models/transaction_type.dart';

class UnbalancedTransactionException implements Exception {
  final double totalDebits;
  final double totalCredits;
  final double discrepancy;

  UnbalancedTransactionException(this.totalDebits, this.totalCredits)
      : discrepancy = (totalDebits - totalCredits).abs();

  @override
  String toString() =>
      'UnbalancedTransactionException: Total Debits (₹${totalDebits.toStringAsFixed(2)}) must equal Total Credits (₹${totalCredits.toStringAsFixed(2)}). Discrepancy: ₹${discrepancy.toStringAsFixed(2)}';
}

class DoubleEntryEngine {
  /// Validates that a list of journal entry lines satisfies double-entry invariants.
  static void validateBalanced(List<JournalEntry> entries) {
    if (entries.length < 2) {
      throw ArgumentError('A double-entry transaction must have at least 2 line items.');
    }

    double totalDebits = 0.0;
    double totalCredits = 0.0;

    for (final entry in entries) {
      if (entry.amount <= 0) {
        throw ArgumentError('Journal entry amount must be strictly greater than 0. Got: ${entry.amount}');
      }
      if (entry.isDebit) {
        totalDebits += entry.amount;
      } else if (entry.isCredit) {
        totalCredits += entry.amount;
      }
    }

    // Floating-point precision threshold: 0.001 INR (0.1 paisa)
    if ((totalDebits - totalCredits).abs() > 0.001) {
      throw UnbalancedTransactionException(totalDebits, totalCredits);
    }
  }

  /// Calculates net signed balance impact of a journal entry on an account.
  /// For Assets & Expenses (Normal Debit): Debit is (+), Credit is (-)
  /// For Liabilities, Income & Equity (Normal Credit): Credit is (+), Debit is (-)
  static double calculateBalanceDelta({
    required AccountCategory category,
    required EntryType entryType,
    required double amount,
  }) {
    if (category.normalBalance == NormalBalance.debit) {
      return entryType == EntryType.debit ? amount : -amount;
    } else {
      return entryType == EntryType.credit ? amount : -amount;
    }
  }

  /// Helper to generate balanced debit/credit lines for standard two-legged transactions.
  static List<JournalEntry> buildTwoLeggedEntries({
    required int transactionId,
    required int debitAccountId,
    required int creditAccountId,
    required double amount,
    String? debitMemo,
    String? creditMemo,
  }) {
    final entries = [
      JournalEntry(
        transactionId: transactionId,
        accountId: debitAccountId,
        entryType: EntryType.debit,
        amount: amount,
        memo: debitMemo,
        counterAccountId: creditAccountId,
        lineOrder: 1,
      ),
      JournalEntry(
        transactionId: transactionId,
        accountId: creditAccountId,
        entryType: EntryType.credit,
        amount: amount,
        memo: creditMemo,
        counterAccountId: debitAccountId,
        lineOrder: 2,
      ),
    ];
    validateBalanced(entries);
    return entries;
  }

  /// Helper to build compound loan repayment journal entries (Principal + Interest).
  /// Debits Loan Liability (Principal portion)
  /// Debits Loan Interest Expense (Interest portion)
  /// Credits Source Account (Total payment)
  static List<JournalEntry> buildLoanRepaymentCompoundEntries({
    required int transactionId,
    required int loanAccountId,
    required int interestExpenseAccountId,
    required int sourceAccountId,
    required double principalPortion,
    required double interestPortion,
    String? principalMemo,
    String? interestMemo,
    String? sourceMemo,
  }) {
    final totalPayment = principalPortion + interestPortion;
    if (totalPayment <= 0) {
      throw ArgumentError('Loan repayment payment must be greater than zero.');
    }

    final entries = <JournalEntry>[];
    int order = 1;

    if (principalPortion > 0) {
      entries.add(
        JournalEntry(
          transactionId: transactionId,
          accountId: loanAccountId,
          entryType: EntryType.debit,
          amount: principalPortion,
          memo: principalMemo ?? 'Loan principal repayment',
          counterAccountId: sourceAccountId,
          lineOrder: order++,
        ),
      );
    }

    if (interestPortion > 0) {
      entries.add(
        JournalEntry(
          transactionId: transactionId,
          accountId: interestExpenseAccountId,
          entryType: EntryType.debit,
          amount: interestPortion,
          memo: interestMemo ?? 'Loan interest expense',
          counterAccountId: sourceAccountId,
          lineOrder: order++,
        ),
      );
    }

    entries.add(
      JournalEntry(
        transactionId: transactionId,
        accountId: sourceAccountId,
        entryType: EntryType.credit,
        amount: totalPayment,
        memo: sourceMemo ?? 'Repayment payment source',
        counterAccountId: loanAccountId,
        lineOrder: order++,
      ),
    );

    validateBalanced(entries);
    return entries;
  }

  /// Builds entries automatically based on TransactionType.
  static List<JournalEntry> buildJournalEntriesForType({
    required int transactionId,
    required TransactionType type,
    required double totalAmount,
    required int sourceAccountId,
    required int destinationAccountId,
    double principalPortion = 0.0,
    double interestPortion = 0.0,
    int? interestExpenseAccountId,
    String? memo,
  }) {
    switch (type) {
      case TransactionType.loanRepayment:
        if (principalPortion > 0 || interestPortion > 0) {
          final intExpenseId = interestExpenseAccountId ?? destinationAccountId;
          return buildLoanRepaymentCompoundEntries(
            transactionId: transactionId,
            loanAccountId: destinationAccountId,
            interestExpenseAccountId: intExpenseId,
            sourceAccountId: sourceAccountId,
            principalPortion: principalPortion > 0 ? principalPortion : (totalAmount - interestPortion),
            interestPortion: interestPortion,
            principalMemo: memo,
            interestMemo: memo,
            sourceMemo: memo,
          );
        }
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId,
          creditAccountId: sourceAccountId,
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );

      case TransactionType.income:
      case TransactionType.credit:
        // Money flows from Income source into Asset destination
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId, // Asset increases
          creditAccountId: sourceAccountId,     // Income increases
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );

      case TransactionType.expense:
      case TransactionType.debit:
      case TransactionType.creditCardPurchase:
      case TransactionType.chitPayment:
        // Expense destination increases (Debit), Funding source decreases/incurs liability (Credit)
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId, // Expense increases
          creditAccountId: sourceAccountId,     // Asset decreases or Card liability increases
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );

      case TransactionType.transfer:
        // Money moves from Source asset to Destination asset
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId, // Receiving asset increases
          creditAccountId: sourceAccountId,     // Sending asset decreases
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );

      case TransactionType.loanTaken:
        // Money received into Destination asset, Liability source increases
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId, // Asset increases
          creditAccountId: sourceAccountId,     // Loan liability increases
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );

      case TransactionType.creditCardPayment:
        // Card liability reduced (Debit), Bank source reduced (Credit)
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId, // Card liability decreases
          creditAccountId: sourceAccountId,     // Bank asset decreases
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );

      case TransactionType.chitReceipt:
        // Prize money received into Bank/Cash asset, Chit liability/equity credited
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId, // Receiving asset increases
          creditAccountId: sourceAccountId,     // Chit liability / income credited
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );

      case TransactionType.assetPurchaseSale:
      case TransactionType.interestPayment:
      case TransactionType.adjustment:
        return buildTwoLeggedEntries(
          transactionId: transactionId,
          debitAccountId: destinationAccountId,
          creditAccountId: sourceAccountId,
          amount: totalAmount,
          debitMemo: memo,
          creditMemo: memo,
        );
    }
  }
}
