import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../services/repayment_allocator.dart';
import '../services/sms_notification_service.dart';
import '../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  final Account? preselectedAccount;
  final TransactionModel? transactionToEdit;

  const AddTransactionScreen({
    super.key,
    this.preselectedAccount,
    this.transactionToEdit,
  });

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
  final TextEditingController _categoryController = TextEditingController(text: 'General');
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _otherModeController = TextEditingController();
  final TextEditingController _counterpartyController = TextEditingController();
  final TextEditingController _recipientPhoneController = TextEditingController();
  bool _sendSmsOption = false;

  // Debt/Lending repayment split controllers
  final TextEditingController _principalPortionController = TextEditingController();
  final TextEditingController _interestPortionController = TextEditingController();

  // Formal double-entry auxiliary controllers
  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _chitGroupController = TextEditingController();
  final TextEditingController _referenceNumberController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String _paymentMode = 'UPI';
  final List<String> _paymentModes = [
    'UPI',
    'Cash',
    'Credit Card',
    'Debit Card',
    'Net Banking',
    'Cheque',
    'Others',
  ];

  String? _receiptPath;

  @override
  void initState() {
    super.initState();
    _selectedAccount = widget.preselectedAccount;

    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _amountController.text = tx.amount.toStringAsFixed(2);
      _categoryController.text = tx.category;
      _noteController.text = tx.note;
      _selectedDate = tx.date;
      _selectedTime = TimeOfDay(hour: tx.date.hour, minute: tx.date.minute);
      _type = tx.type;
      _isTransferMode = tx.type == TransactionType.transfer;
      _paymentMode = _paymentModes.contains(tx.paymentMode) ? tx.paymentMode : 'Others';
      if (_paymentMode == 'Others') {
        _otherModeController.text = tx.otherPaymentModeDetails ?? '';
      }
      if (tx.type == TransactionType.credit) {
        _counterpartyController.text = tx.debitAccountName ?? '';
      } else if (tx.type == TransactionType.debit) {
        _counterpartyController.text = tx.creditAccountName ?? '';
      }
      _receiptPath = tx.receiptPath;
      if (tx.principalPortion > 0) {
        _principalPortionController.text = tx.principalPortion.toStringAsFixed(2);
      }
      if (tx.interestPortion > 0) {
        _interestPortionController.text = tx.interestPortion.toStringAsFixed(2);
      }
      _billNumberController.text = tx.billNumber ?? '';
      _personNameController.text = tx.personName ?? '';
      _chitGroupController.text = tx.chitGroupName ?? '';
      _referenceNumberController.text = tx.referenceNumber ?? '';
    } else {
      if (_selectedAccount?.type == AccountType.salary && _type == TransactionType.credit) {
        _counterpartyController.text = 'Govt Account';
        _categoryController.text = 'Salary & Income';
      }
    }

    if (_selectedAccount?.phoneNumber != null && _selectedAccount!.phoneNumber!.isNotEmpty) {
      _recipientPhoneController.text = _selectedAccount!.phoneNumber!;
    }

    _amountController.addListener(_recalculateSplit);
  }

  @override
  void dispose() {
    _amountController.removeListener(_recalculateSplit);
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _otherModeController.dispose();
    _counterpartyController.dispose();
    _recipientPhoneController.dispose();
    _principalPortionController.dispose();
    _interestPortionController.dispose();
    _billNumberController.dispose();
    _personNameController.dispose();
    _chitGroupController.dispose();
    _referenceNumberController.dispose();
    super.dispose();
  }

  bool get _requiresTwoAccounts =>
      _isTransferMode ||
      _type == TransactionType.transfer ||
      _type == TransactionType.loanRepayment ||
      _type == TransactionType.creditCardPayment ||
      _type == TransactionType.creditCardPurchase ||
      _type == TransactionType.chitPayment ||
      _type == TransactionType.chitReceipt ||
      _type == TransactionType.loanTaken;

  bool get _isRepayment {
    if (_type == TransactionType.loanRepayment) return true;
    if (_selectedAccount == null) return false;
    if (_selectedAccount!.type == AccountType.debt && _type == TransactionType.debit) {
      return true; // Paying back what I owe
    }
    if (_selectedAccount!.type == AccountType.lending && _type == TransactionType.credit) {
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
      if (widget.transactionToEdit != null) {
        _selectedAccount = accounts.firstWhere(
          (a) => a.id == widget.transactionToEdit!.accountId,
          orElse: () => accounts.first,
        );
        if (widget.transactionToEdit!.toAccountId != null) {
          _destinationAccount = accounts.firstWhere(
            (a) => a.id == widget.transactionToEdit!.toAccountId,
            orElse: () => accounts.last,
          );
        }
      } else {
        _selectedAccount = accounts.first;
      }
    }

    final isEditMode = widget.transactionToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Transaction' : 'New Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Transaction Type Selector (Debit, Credit, Transfer & Advanced Double-Entry Flow)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        label: 'Debit (-)',
                        icon: Icons.arrow_circle_down,
                        isSelected: !_isTransferMode && (_type == TransactionType.debit || _type == TransactionType.expense),
                        color: AppTheme.debitRed,
                        onTap: () {
                          setState(() {
                            _isTransferMode = false;
                            _type = TransactionType.debit;
                            _recalculateSplit();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildTypeButton(
                        label: 'Credit (+)',
                        icon: Icons.arrow_circle_up,
                        isSelected: !_isTransferMode && (_type == TransactionType.credit || _type == TransactionType.income),
                        color: AppTheme.creditGreen,
                        onTap: () {
                          setState(() {
                            _isTransferMode = false;
                            _type = TransactionType.credit;
                            if (_selectedAccount?.type == AccountType.salary) {
                              if (_counterpartyController.text.isEmpty) {
                                _counterpartyController.text = 'Govt Account';
                              }
                              if (_categoryController.text == 'General' || _categoryController.text.isEmpty) {
                                _categoryController.text = 'Salary & Income';
                              }
                            }
                            _recalculateSplit();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildTypeButton(
                        label: 'Transfer (⇄)',
                        icon: Icons.swap_horiz,
                        isSelected: _isTransferMode || _type == TransactionType.transfer,
                        color: AppTheme.transferBlue,
                        onTap: () {
                          setState(() {
                            _isTransferMode = true;
                            _type = TransactionType.transfer;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Accounting Flow Dropdown (Full 12 Double-Entry Types)
              DropdownButtonFormField<TransactionType>(
                value: _type,
                decoration: InputDecoration(
                  labelText: 'Double-Entry Transaction Flow',
                  prefixIcon: const Icon(Icons.account_tree, color: AppTheme.emeraldPrimary, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: [
                  TransactionType.debit,
                  TransactionType.credit,
                  TransactionType.transfer,
                  TransactionType.loanRepayment,
                  TransactionType.loanTaken,
                  TransactionType.creditCardPurchase,
                  TransactionType.creditCardPayment,
                  TransactionType.chitPayment,
                  TransactionType.chitReceipt,
                  TransactionType.assetPurchaseSale,
                  TransactionType.interestPayment,
                  TransactionType.adjustment,
                ].map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _type = val;
                      _isTransferMode = val == TransactionType.transfer;
                      _recalculateSplit();
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              // 2. Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  labelText: 'Transaction Amount *',
                  hintText: '0.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter an amount';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) return 'Please enter a valid amount';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // 3. Payment Mode Selection
              const Text(
                'Payment Mode *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _paymentModes.contains(_paymentMode) ? _paymentMode : 'UPI',
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.payment, color: AppTheme.emeraldPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _paymentModes.map((mode) {
                  return DropdownMenuItem(value: mode, child: Text(mode));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _paymentMode = val);
                  }
                },
              ),

              // Extra mandatory field if 'Others' payment mode is selected
              if (_paymentMode == 'Others') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otherModeController,
                  decoration: InputDecoration(
                    labelText: 'Specify Other Payment Mode Details (Required) *',
                    hintText: 'e.g., Gold Voucher, Crypto, Third Party Escrow',
                    prefixIcon: const Icon(Icons.edit_note, color: AppTheme.amberGold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (_paymentMode == 'Others' && (val == null || val.trim().isEmpty)) {
                      return 'Please specify the exact payment mode details';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),

              // 4. Accounts Selection (Debit & Credit Accounts)
              if (!_requiresTwoAccounts) ...[
                Text(
                  _type.isOutflow ? 'Paid From (Debit Account) *' : 'Received In (Credit Account) *',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Account>(
                  value: _selectedAccount,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_balance_wallet, color: AppTheme.emeraldPrimary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc,
                      child: Text('${acc.name} (${acc.type.displayName})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAccount = val;
                      if (val?.type == AccountType.salary && _type.isInflow) {
                        if (_counterpartyController.text.isEmpty || _counterpartyController.text == 'Govt Account') {
                          _counterpartyController.text = 'Govt Account';
                        }
                        if (_categoryController.text == 'General' || _categoryController.text.isEmpty) {
                          _categoryController.text = 'Salary & Income';
                        }
                      }
                      _recalculateSplit();
                    });
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  _type.isOutflow
                      ? 'Paid To / Beneficiary (Credit Account / Party)'
                      : 'Received From / Source (Debit Account / Payer)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _counterpartyController,
                  decoration: InputDecoration(
                    hintText: _type.isOutflow
                        ? 'e.g., Vendor, Store, Merchant'
                        : (_selectedAccount?.type == AccountType.salary ? 'Govt Account' : 'e.g., Govt Account, Employer, Client'),
                    prefixIcon: Icon(
                      _type.isOutflow ? Icons.store : Icons.account_balance,
                      color: AppTheme.emeraldPrimary,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else ...[
                // Dual Account Flow: Source -> Destination
                Text(
                  _type == TransactionType.creditCardPurchase
                      ? 'Credit Card Charged (Liability Source) *'
                      : _type == TransactionType.creditCardPayment
                          ? 'Paid From Bank Account (Source) *'
                          : _type == TransactionType.loanRepayment
                              ? 'Paid From Bank Account (Source) *'
                              : _type == TransactionType.loanTaken
                                  ? 'Borrowed From (Lender / Friend Liability) *'
                                  : _type == TransactionType.chitPayment
                                      ? 'Paid From (Funding Source Account) *'
                                      : _type == TransactionType.chitReceipt
                                          ? 'Chit Fund Account (Source) *'
                                          : 'Transfer From (Source Account) *',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Account>(
                  value: _selectedAccount,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.outbox, color: AppTheme.debitRed),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc,
                      child: Text('${acc.name} (${acc.category.displayName})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() {
                    _selectedAccount = val;
                    _recalculateSplit();
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  _type == TransactionType.creditCardPurchase
                      ? 'Expense Category / Account (Destination) *'
                      : _type == TransactionType.creditCardPayment
                          ? 'Paid To Credit Card (Destination) *'
                          : _type == TransactionType.loanRepayment
                              ? 'Loan Account (Liability Destination) *'
                              : _type == TransactionType.loanTaken
                                  ? 'Received In (Bank / Cash Destination) *'
                                  : _type == TransactionType.chitPayment
                                      ? 'Chit Fund Account (Destination) *'
                                      : _type == TransactionType.chitReceipt
                                          ? 'Deposit To (Bank / Cash Destination) *'
                                          : 'Transfer To (Destination Account) *',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Account>(
                  value: _destinationAccount,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.move_to_inbox, color: AppTheme.creditGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: accounts.where((a) => a.id != _selectedAccount?.id).map((acc) {
                    return DropdownMenuItem(
                      value: acc,
                      child: Text('${acc.name} (${acc.category.displayName})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() {
                    _destinationAccount = val;
                    _recalculateSplit();
                  }),
                  validator: (val) {
                    if (_requiresTwoAccounts && val == null) return 'Please choose a destination account';
                    return null;
                  },
                ),
              ],

              // Repayment Split breakdown (if Debt or Lending)
              if (_isRepayment) ...[
                const SizedBox(height: 20),
                Card(
                  color: AppTheme.amberGold.withAlpha(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, color: AppTheme.amberGold, size: 20),
                            SizedBox(width: 8),
                            Text('Repayment Allocation Split', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _principalPortionController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Principal Portion',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _interestPortionController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Interest Portion',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 5. Category & Remarks
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Salary, Groceries, Rent, Fuel, Investment',
                  prefixIcon: const Icon(Icons.category, color: AppTheme.emeraldPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Remarks / Transaction Details',
                  hintText: 'Add remarks, bill number, or specific notes...',
                  prefixIcon: const Icon(Icons.notes, color: AppTheme.emeraldPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 20),

              // 6. Custom Date & Time Selection (Past / Present / Future)
              const Text('Date & Time of Transaction *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              _selectedTime.hour,
                              _selectedTime.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: AppTheme.emeraldPrimary),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _selectedTime = pickedTime;
                            _selectedDate = DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: AppTheme.emeraldPrimary),
                            const SizedBox(width: 8),
                            Text(_selectedTime.format(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 7. Receipt / Proof Attachment
              const Text('Receipt / Bill Proof Attachment', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_receiptPath == null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.attach_file, color: AppTheme.emeraldPrimary),
                  label: const Text('Attach Receipt / Proof (Image or PDF)'),
                  onPressed: _pickReceiptFile,
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.creditGreen.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.creditGreen.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppTheme.creditGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Receipt Attached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              _receiptPath!.split(Platform.pathSeparator).last,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.change_circle_outlined, color: AppTheme.emeraldPrimary),
                        tooltip: 'Change file',
                        onPressed: _pickReceiptFile,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.debitRed),
                        tooltip: 'Remove',
                        onPressed: () => setState(() => _receiptPath = null),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // 7b. Mobile Number & SMS Notification Option
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: _sendSmsOption,
                        onChanged: (val) => setState(() => _sendSmsOption = val),
                        contentPadding: EdgeInsets.zero,
                        title: const Row(
                          children: [
                            Icon(Icons.sms_outlined, color: AppTheme.emeraldPrimary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Send Standard SMS / Text Message',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          'Sends pre-filled transaction confirmation to recipient mobile number',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      if (_sendSmsOption || (_selectedAccount?.phoneNumber?.isNotEmpty ?? false)) ...[
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _recipientPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Recipient Mobile Number',
                            hintText: 'e.g. +91 9876543210',
                            prefixIcon: const Icon(Icons.phone_android, size: 18),
                            border: const OutlineInputBorder(),
                            helperText: _selectedAccount?.phoneNumber != null
                                ? 'Pre-filled from "${_selectedAccount!.name}"'
                                : 'Enter mobile number to receive text update',
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 7c. Additional Details Accordion (Bill No, Person/Friend, Chit Group, Reference)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: const Icon(Icons.more_horiz, color: AppTheme.emeraldPrimary),
                    title: const Text(
                      'Additional Audit & Reference Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Bill number, lender/friend, chit group, or reference details',
                      style: TextStyle(fontSize: 11),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _billNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Bill / Invoice Number',
                                hintText: 'e.g., INV-2026-001',
                                prefixIcon: Icon(Icons.receipt, size: 18),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _personNameController,
                              decoration: const InputDecoration(
                                labelText: 'Lender / Friend / Beneficiary Name',
                                hintText: 'e.g., Friend A, Ramesh, Landlord',
                                prefixIcon: Icon(Icons.person, size: 18),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _chitGroupController,
                              decoration: const InputDecoration(
                                labelText: 'Chit Group / Auction Name',
                                hintText: 'e.g., Gold Chits Group A',
                                prefixIcon: Icon(Icons.groups, size: 18),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _referenceNumberController,
                              decoration: const InputDecoration(
                                labelText: 'External Reference / UTR / Cheque No.',
                                hintText: 'e.g., UTR1234567890',
                                prefixIcon: Icon(Icons.tag, size: 18),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 8. Submit / Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isEditMode ? _handleEditSubmission : _handleNewSubmission,
                  child: Text(
                    isEditMode ? 'Update Transaction' : 'Save Transaction',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceiptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _receiptPath = result.files.single.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick file: $e')),
        );
      }
    }
  }

  void _handleNewSubmission() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) return;

    final amount = double.parse(_amountController.text.trim());
    final principalPortion = double.tryParse(_principalPortionController.text.trim()) ?? 0.0;
    final interestPortion = double.tryParse(_interestPortionController.text.trim()) ?? 0.0;

    String? debitName;
    String? creditName;

    if (_requiresTwoAccounts) {
      if (_type == TransactionType.creditCardPurchase) {
        debitName = _destinationAccount?.name ?? 'Expense';
        creditName = _selectedAccount!.name;
      } else if (_type == TransactionType.loanTaken) {
        debitName = _destinationAccount?.name ?? 'Bank/Cash';
        creditName = _selectedAccount!.name;
      } else {
        debitName = _selectedAccount!.name;
        creditName = _destinationAccount?.name ?? 'Account';
      }
    } else {
      if (_type.isOutflow) {
        debitName = _selectedAccount!.name;
        creditName = _counterpartyController.text.trim().isNotEmpty
            ? _counterpartyController.text.trim()
            : 'Expenditure';
      } else {
        debitName = _counterpartyController.text.trim().isNotEmpty
            ? _counterpartyController.text.trim()
            : (_selectedAccount?.type == AccountType.salary ? 'Govt Account' : 'External Payer');
        creditName = _selectedAccount!.name;
      }
    }

    final tx = TransactionModel(
      accountId: _selectedAccount!.id!,
      toAccountId: _requiresTwoAccounts ? _destinationAccount?.id : null,
      type: _isTransferMode ? TransactionType.transfer : _type,
      amount: amount,
      principalPortion: principalPortion,
      interestPortion: interestPortion,
      category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : 'General',
      note: _noteController.text.trim(),
      date: _selectedDate,
      paymentMode: _paymentMode,
      otherPaymentModeDetails: _paymentMode == 'Others' ? _otherModeController.text.trim() : null,
      receiptPath: _receiptPath,
      debitAccountName: debitName,
      creditAccountName: creditName,
      billNumber: _billNumberController.text.trim().isNotEmpty ? _billNumberController.text.trim() : null,
      personName: _personNameController.text.trim().isNotEmpty ? _personNameController.text.trim() : null,
      chitGroupName: _chitGroupController.text.trim().isNotEmpty ? _chitGroupController.text.trim() : null,
      referenceNumber: _referenceNumberController.text.trim().isNotEmpty ? _referenceNumberController.text.trim() : null,
    );

    final txId = await context.read<FinanceProvider>().addTransaction(tx);
    final insertedTx = tx.copyWith(id: txId);

    if (_sendSmsOption && _recipientPhoneController.text.trim().isNotEmpty && _selectedAccount != null) {
      final msg = SmsNotificationService.generateTransactionMessage(
        account: _selectedAccount!,
        tx: insertedTx,
      );
      await SmsNotificationService.sendSms(
        phoneNumber: _recipientPhoneController.text.trim(),
        message: msg,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handleEditSubmission() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) return;

    final reasonController = TextEditingController();

    // Prompt user for mandatory Reason for Editing
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history_edu, color: AppTheme.emeraldPrimary),
            SizedBox(width: 8),
            Text('Reason for Edit'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a brief reason for editing this transaction (Audit trail requirement):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g., Corrected wrong amount, updated payment mode, typo in remarks',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final r = reasonController.text.trim();
              if (r.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason for editing.')),
                );
                return;
              }
              Navigator.pop(ctx, r);
            },
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );

    if (reason == null || !mounted) return;

    final amount = double.parse(_amountController.text.trim());
    final principalPortion = double.tryParse(_principalPortionController.text.trim()) ?? 0.0;
    final interestPortion = double.tryParse(_interestPortionController.text.trim()) ?? 0.0;

    String? debitName;
    String? creditName;

    if (_requiresTwoAccounts) {
      if (_type == TransactionType.creditCardPurchase) {
        debitName = _destinationAccount?.name ?? 'Expense';
        creditName = _selectedAccount!.name;
      } else if (_type == TransactionType.loanTaken) {
        debitName = _destinationAccount?.name ?? 'Bank/Cash';
        creditName = _selectedAccount!.name;
      } else {
        debitName = _selectedAccount!.name;
        creditName = _destinationAccount?.name ?? 'Account';
      }
    } else {
      if (_type.isOutflow) {
        debitName = _selectedAccount!.name;
        creditName = _counterpartyController.text.trim().isNotEmpty
            ? _counterpartyController.text.trim()
            : 'Expenditure';
      } else {
        debitName = _counterpartyController.text.trim().isNotEmpty
            ? _counterpartyController.text.trim()
            : (_selectedAccount?.type == AccountType.salary ? 'Govt Account' : 'External Payer');
        creditName = _selectedAccount!.name;
      }
    }

    final updatedTx = widget.transactionToEdit!.copyWith(
      accountId: _selectedAccount!.id!,
      toAccountId: _requiresTwoAccounts ? _destinationAccount?.id : null,
      type: _isTransferMode ? TransactionType.transfer : _type,
      amount: amount,
      principalPortion: principalPortion,
      interestPortion: interestPortion,
      category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : 'General',
      note: _noteController.text.trim(),
      date: _selectedDate,
      paymentMode: _paymentMode,
      otherPaymentModeDetails: _paymentMode == 'Others' ? _otherModeController.text.trim() : null,
      receiptPath: _receiptPath,
      debitAccountName: debitName,
      creditAccountName: creditName,
      billNumber: _billNumberController.text.trim().isNotEmpty ? _billNumberController.text.trim() : null,
      personName: _personNameController.text.trim().isNotEmpty ? _personNameController.text.trim() : null,
      chitGroupName: _chitGroupController.text.trim().isNotEmpty ? _chitGroupController.text.trim() : null,
      referenceNumber: _referenceNumberController.text.trim().isNotEmpty ? _referenceNumberController.text.trim() : null,
    );

    final success = await context.read<FinanceProvider>().updateTransaction(updatedTx, reason: reason);
    if (mounted) {
      if (success) {
        if (_sendSmsOption && _recipientPhoneController.text.trim().isNotEmpty && _selectedAccount != null) {
          final msg = SmsNotificationService.generateTransactionMessage(
            account: _selectedAccount!,
            tx: updatedTx,
          );
          await SmsNotificationService.sendSms(
            phoneNumber: _recipientPhoneController.text.trim(),
            message: msg,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction updated and edit history logged.'),
            backgroundColor: AppTheme.emeraldPrimary,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update transaction.'),
            backgroundColor: AppTheme.debitRed,
          ),
        );
      }
    }
  }
}
