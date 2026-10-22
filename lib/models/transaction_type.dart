enum TransactionType {
  income,
  expense,
  transfer,
  loanTaken,
  loanRepayment,
  creditCardPurchase,
  creditCardPayment,
  chitPayment,
  chitReceipt,
  assetPurchaseSale,
  interestPayment,
  adjustment,
  // Backward compatibility
  debit,
  credit,
}

extension TransactionTypeExtension on TransactionType {
  String get key {
    switch (this) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.transfer:
        return 'transfer';
      case TransactionType.loanTaken:
        return 'loan_taken';
      case TransactionType.loanRepayment:
        return 'loan_repayment';
      case TransactionType.creditCardPurchase:
        return 'credit_card_purchase';
      case TransactionType.creditCardPayment:
        return 'credit_card_payment';
      case TransactionType.chitPayment:
        return 'chit_payment';
      case TransactionType.chitReceipt:
        return 'chit_receipt';
      case TransactionType.assetPurchaseSale:
        return 'asset_purchase_sale';
      case TransactionType.interestPayment:
        return 'interest_payment';
      case TransactionType.adjustment:
        return 'adjustment';
      case TransactionType.debit:
        return 'debit';
      case TransactionType.credit:
        return 'credit';
    }
  }

  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer (Account to Account)';
      case TransactionType.loanTaken:
        return 'Loan Borrowed / Taken';
      case TransactionType.loanRepayment:
        return 'Loan Repayment (EMI / Principal)';
      case TransactionType.creditCardPurchase:
        return 'Credit Card Purchase / Expense';
      case TransactionType.creditCardPayment:
        return 'Credit Card Bill Payment';
      case TransactionType.chitPayment:
        return 'Chit Installment Payment';
      case TransactionType.chitReceipt:
        return 'Chit Prize / Dividend Received';
      case TransactionType.assetPurchaseSale:
        return 'Asset Purchase / Sale';
      case TransactionType.interestPayment:
        return 'Interest Payment';
      case TransactionType.adjustment:
        return 'Adjustment / Correction';
      case TransactionType.debit:
        return 'Expense / Debit (-)';
      case TransactionType.credit:
        return 'Income / Credit (+)';
    }
  }

  bool get isOutflow =>
      this == TransactionType.expense ||
      this == TransactionType.debit ||
      this == TransactionType.creditCardPurchase ||
      this == TransactionType.chitPayment ||
      this == TransactionType.loanRepayment;

  bool get isInflow =>
      this == TransactionType.income ||
      this == TransactionType.credit ||
      this == TransactionType.chitReceipt ||
      this == TransactionType.loanTaken;

  bool get isTransfer => this == TransactionType.transfer;

  static TransactionType fromKey(String? key) {
    switch (key?.toLowerCase().trim()) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'debit':
        return TransactionType.debit;
      case 'credit':
        return TransactionType.credit;
      case 'transfer':
        return TransactionType.transfer;
      case 'loan_taken':
        return TransactionType.loanTaken;
      case 'loan_repayment':
        return TransactionType.loanRepayment;
      case 'credit_card_purchase':
        return TransactionType.creditCardPurchase;
      case 'credit_card_payment':
        return TransactionType.creditCardPayment;
      case 'chit_payment':
        return TransactionType.chitPayment;
      case 'chit_receipt':
        return TransactionType.chitReceipt;
      case 'asset_purchase_sale':
        return TransactionType.assetPurchaseSale;
      case 'interest_payment':
        return TransactionType.interestPayment;
      case 'adjustment':
        return TransactionType.adjustment;
      default:
        return TransactionType.expense;
    }
  }
}
