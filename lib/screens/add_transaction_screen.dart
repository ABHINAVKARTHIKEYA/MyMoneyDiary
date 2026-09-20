import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../services/repayment_allocator.dart';
import '../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  final Account? preselectedAccount;

  const AddTransactionScreen({super.key, this.preselectedAccount});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isTransferMode = false;

  Account? _selectedAccount;
  Account? _destinationAccount;
  TransactionType _type = TransactionType.debit;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController =
      TextEditingController(text: 'General');
  final TextEditingController _noteController = TextEditingController();

  // Debt/Lending repayment split controllers
  final TextEditingController _principalPortionController =
      TextEditingController();
  final TextEditingController _interestPortionController =
      TextEditingController();

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedAccount = widget.preselectedAccount;
    _amountController.addListener(_recalculateSplit);
  }

  @override
  void dispose() {
    _amountController.removeListener(_recalculateSplit);
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _principalPortionController.dispose();
    _interestPortionController.dispose();
    super.dispose();
  }

  bool get _isRepayment {
    if (_selectedAccount == null) return false;
    if (_selectedAccount!.type == AccountType.debt &&
        _type == TransactionType.debit) {
      return true; // Paying back what I owe
    }
    if (_selectedAccount!.type == AccountType.lending &&
        _type == TransactionType.credit) {
      return true; // Receiving payment on money I lent
    }
    return false;
  }

  void _recalculateSplit() {
    if (!_isRepayment || _selectedAccount == null) return;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _principalPortionController.text = '';
      _interestPortionController.text = '';
      return;
    }

    final split = RepaymentAllocator.calculateSplit(
      paymentAmount: amount,
      currentPrincipal: _selectedAccount!.principalBalance,
      accruedInterest: _selectedAccount!.accruedInterest,
      allocationRule: _selectedAccount!.allocationRule,
    );

    _principalPortionController.text = split.principalPortion.toStringAsFixed(2);
    _interestPortionController.text = split.interestPortion.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = finance.settings.currencySymbol;
    final accounts = finance.accounts;

    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Entry Mode Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isTransferMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isTransferMode
                                ? AppTheme.emeraldPrimary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Direct Entry',
                            style: TextStyle(
                              color: !_isTransferMode
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isTransferMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isTransferMode
                                ? AppTheme.emeraldPrimary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Transfer Between Accounts',
                            style: TextStyle(
                              color: _isTransferMode
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Account Picker (Source)
              Text(
                _isTransferMode ? 'From Account' : 'Account',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<Account>(
                value: _selectedAccount,
                decoration: const InputDecoration(),
                items: accounts.map((acc) {
                  return DropdownMenuItem(
                    value: acc,
                    child: Text('${acc.name} (${acc.type.displayName})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedAccount = val;
                    _recalculateSplit();
                  });
                },
              ),

              // Destination Account for Transfers
              if (_isTransferMode) ...[
                const SizedBox(height: 16),
                const Text(
                  'To Account',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<Account>(
                  value: _destinationAccount,
                  decoration: const InputDecoration(
                    hintText: 'Select destination account',
                  ),
                  items: accounts
                      .where((acc) => acc.id != _selectedAccount?.id)
                      .map((acc) {
                    return DropdownMenuItem(
                      value: acc,
                      child: Text('${acc.name} (${acc.type.displayName})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _destinationAccount = val;
                    });
                  },
                  validator: (val) {
                    if (_isTransferMode && val == null) {
                      return 'Please select a destination account';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),

              // 3. Debit / Credit Selection (if not transfer)
              if (!_isTransferMode) ...[
                const Text(
                  'Transaction Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Debit (-)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _type == TransactionType.debit
                              ? Colors.white
                              : AppTheme.debitRed,
                          backgroundColor: _type == TransactionType.debit
                              ? AppTheme.debitRed
                              : null,
                          side: const BorderSide(color: AppTheme.debitRed),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _type = TransactionType.debit;
                            _recalculateSplit();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Credit (+)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _type == TransactionType.credit
                              ? Colors.white
                              : AppTheme.creditGreen,
                          backgroundColor: _type == TransactionType.credit
                              ? AppTheme.creditGreen
                              : null,
                          side: const BorderSide(color: AppTheme.creditGreen),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _type = TransactionType.credit;
                            _recalculateSplit();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // 4. Amount Input
              const Text(
                'Amount',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  hintText: '0.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              // 5. Debt / Lending Repayment Split Section
              if (_isRepayment) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.amberGold.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.amberGold, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Repayment Allocation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emeraldDark,
                            ),
                          ),
                          Text(
                            'Priority: ${_selectedAccount!.allocationRule == "interest_first" ? "Interest First" : "Principal First"}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Outstanding: Principal $currency ${_selectedAccount!.principalBalance.toStringAsFixed(2)} | Accrued Int: $currency ${_selectedAccount!.accruedInterest.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _principalPortionController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Towards Principal',
                                prefixText: '$currency ',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _interestPortionController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Towards Interest',
                                prefixText: '$currency ',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 6. Category & Notes
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Groceries, Fuel, Loan, Chit installment',
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Note / Remarks',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add an optional description or reminder',
                ),
              ),

              const SizedBox(height: 16),

              // 7. Date & Time
              const Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 8. Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveTransaction,
                  child: const Text(
                    'Save Transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) return;

    final amount = double.parse(_amountController.text);
    final principalPortion =
        double.tryParse(_principalPortionController.text) ?? 0.0;
    final interestPortion =
        double.tryParse(_interestPortionController.text) ?? 0.0;

    final tx = TransactionModel(
      accountId: _selectedAccount!.id!,
      toAccountId: _isTransferMode ? _destinationAccount?.id : null,
      type: _isTransferMode ? TransactionType.transfer : _type,
      amount: amount,
      principalPortion: principalPortion,
      interestPortion: interestPortion,
      category: _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : 'General',
      note: _noteController.text.trim(),
      date: _selectedDate,
    );

    await context.read<FinanceProvider>().addTransaction(tx);
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
