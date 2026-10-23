enum NormalBalance {
  debit,
  credit,
}

enum AccountCategory {
  asset('asset', 'Assets', NormalBalance.debit),
  liability('liability', 'Liabilities', NormalBalance.credit),
  income('income', 'Income', NormalBalance.credit),
  expense('expense', 'Expenses', NormalBalance.debit),
  equity('equity', 'Equity', NormalBalance.credit);

  final String key;
  final String displayName;
  final NormalBalance normalBalance;

  const AccountCategory(this.key, this.displayName, this.normalBalance);

  static AccountCategory fromKey(String? key) {
    switch (key?.toLowerCase().trim()) {
      case 'liability':
        return AccountCategory.liability;
      case 'income':
        return AccountCategory.income;
      case 'expense':
        return AccountCategory.expense;
      case 'equity':
        return AccountCategory.equity;
      case 'asset':
      default:
        return AccountCategory.asset;
    }
  }
}

extension AccountCategoryExtension on AccountCategory {
  static AccountCategory fromKey(String? key) => AccountCategory.fromKey(key);
}
