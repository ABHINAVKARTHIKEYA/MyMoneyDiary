enum AccountCategory {
  asset,
  liability,
  income,
  expense,
  equity,
}

enum NormalBalance {
  debit,
  credit,
}

extension AccountCategoryExtension on AccountCategory {
  String get key {
    switch (this) {
      case AccountCategory.asset:
        return 'asset';
      case AccountCategory.liability:
        return 'liability';
      case AccountCategory.income:
        return 'income';
      case AccountCategory.expense:
        return 'expense';
      case AccountCategory.equity:
        return 'equity';
    }
  }

  String get displayName {
    switch (this) {
      case AccountCategory.asset:
        return 'Assets';
      case AccountCategory.liability:
        return 'Liabilities';
      case AccountCategory.income:
        return 'Income';
      case AccountCategory.expense:
        return 'Expenses';
      case AccountCategory.equity:
        return 'Equity';
    }
  }

  NormalBalance get normalBalance {
    switch (this) {
      case AccountCategory.asset:
      case AccountCategory.expense:
        return NormalBalance.debit;
      case AccountCategory.liability:
      case AccountCategory.income:
      case AccountCategory.equity:
        return NormalBalance.credit;
    }
  }

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
