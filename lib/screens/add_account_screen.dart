import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/chit_details.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? accountToEdit;

  const AddAccountScreen({super.key, this.accountToEdit});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _initialBalanceController =
      TextEditingController(text: '0.00');
  AccountType _selectedType = AccountType.bank;

  // Debt / Lending fields
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  String _interestRateType = 'per_month'; // 'per_month' or 'per_annum'
  bool _isCompound = false;
  String _accrualMode = 'daily'; // 'daily' or 'monthly'
  String _allocationRule = 'interest_first'; // 'interest_first' or 'principal_first'
  DateTime _loanDate = DateTime.now();

  // Chit Fund fields
  final TextEditingController _chitTotalValueController =
      TextEditingController();
  final TextEditingController _chitDurationController =
      TextEditingController(text: '20');
  final TextEditingController _chitInstallmentBeforeController =
      TextEditingController();
  final TextEditingController _chitInstallmentAfterController =
      TextEditingController();
  DateTime _chitStartDate = DateTime.now();
  late DateTime _chitEndDate;

  int _selectedColor = 0xFF0288D1;

  final List<int> _availableColors = [
    0xFF0F3E33, // Emerald Primary
    0xFF1E88E5, // Blue (Salary)
    0xFF0288D1, // Cyan (Bank)
    0xFF7B1FA2, // Purple (Credit Card)
    0xFF00897B, // Teal (Insurance)
    0xFFE65100, // Orange (Demat)
    0xFFE6B042, // Amber Gold (Chit)
    0xFF2D8A70, // Jade Accent
    0xFFC62828, // Red (Debt)
    0xFF2E7D32, // Green (Lending)
    0xFF455A64, // Blue Grey (Others)
  ];

  @override
  void initState() {
    super.initState();
    _chitEndDate = DateTime.now().add(const Duration(days: 20 * 30));

    if (widget.accountToEdit != null) {
      final acc = widget.accountToEdit!;
      _nameController.text = acc.name;
      _phoneNumberController.text = acc.phoneNumber ?? '';
      _selectedType = acc.type;
      _selectedColor = acc.color;
      _initialBalanceController.text = acc.balance.toStringAsFixed(2);
      _principalController.text = acc.principalBalance.toStringAsFixed(2);
      _interestRateController.text = acc.interestRate.toString();
      _interestRateType = acc.interestRateType;
      _isCompound = acc.isCompound;
      _accrualMode = acc.accrualMode;
      _allocationRule = acc.allocationRule;
      if (acc.loanStartDate != null) {
        _loanDate = acc.loanStartDate!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _initialBalanceController.dispose();
    _principalController.dispose();
    _interestRateController.dispose();
    _chitTotalValueController.dispose();
    _chitDurationController.dispose();
    _chitInstallmentBeforeController.dispose();
    _chitInstallmentAfterController.dispose();
    super.dispose();
  }

  void _onTypeChanged(AccountType? newType) {
    if (newType == null) return;
    setState(() {
      _selectedType = newType;
      _selectedColor = newType.defaultColor;
      if (_nameController.text.isEmpty ||
          AccountType.values.any((t) => t.displayName == _nameController.text)) {
        if (newType.key.startsWith('other_')) {
          _nameController.text = newType.displayName;
        }
      }
    });
  }

  void _updateChitDates() {
    final months = int.tryParse(_chitDurationController.text) ?? 20;
    setState(() {
      _chitEndDate = _chitStartDate.add(Duration(days: months * 30));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDebtOrLending = _selectedType == AccountType.debt ||
        _selectedType == AccountType.lending;
    final isChit = _selectedType == AccountType.chit;
    final currency = context.watch<FinanceProvider>().settings.currencySymbol;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountToEdit != null ? 'Edit Account' : 'Add New Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Account Type Selection
              const Text(
                'Select Account Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<AccountType>(
                value: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: AccountType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(type.iconData, color: Color(type.defaultColor), size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            type.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onTypeChanged,
              ),

              const SizedBox(height: 16),

              // 2. Account Name
              const Text(
                'Account Name (Editable anytime)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., HDFC Salary, SBI Savings, ICICI Amazon Pay, Car Chit',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(_selectedType.iconData, color: Color(_selectedColor)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter account name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 2b. Mobile Number
              const Text(
                'Mobile Number (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'e.g. +91 9876543210',
                  helperText: 'For sending standard transaction SMS & payment updates',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Initial Balance for non-debt/lending/chit accounts
              if (!isDebtOrLending && !isChit) ...[
                const Text(
                  'Initial Balance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _initialBalanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '$currency ',
                    border: const OutlineInputBorder(),
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Debt & Lending Configuration
              if (isDebtOrLending) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.amberGold.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.amberGold, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedType == AccountType.debt ? "Debt (Payable)" : "Lending (Receivable)"} & Interest Configuration',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emeraldDark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Date of Taking / Lending Loan
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.calendar_month, color: AppTheme.emeraldPrimary, size: 20),
                        label: Text(
                          '${_selectedType == AccountType.debt ? "Date of Taking Loan" : "Date of Lending Loan"}: ${dateFormat.format(_loanDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emeraldDark),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _loanDate,
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _loanDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Initial Principal
                      TextFormField(
                        controller: _principalController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Initial Principal Amount',
                          prefixText: '$currency ',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (isDebtOrLending &&
                              (val == null || val.trim().isEmpty)) {
                            return 'Please enter principal amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Interest Rate & Type
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _interestRateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Rate of Interest',
                                hintText: 'e.g., 2.0 or 12.0',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (isDebtOrLending &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Enter rate';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<String>(
                              value: _interestRateType,
                              decoration: const InputDecoration(
                                labelText: 'Rate Type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'per_month',
                                  child: Text('₹ / ₹100 / mo'),
                                ),
                                DropdownMenuItem(
                                  value: 'per_annum',
                                  child: Text('% p.a. (Yearly)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _interestRateType = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Accrual Frequency: Daily vs Monthly
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Accrual Frequency',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'daily', label: Text('Daily')),
                              ButtonSegment(
                                  value: 'monthly', label: Text('Monthly')),
                            ],
                            selected: {_accrualMode},
                            onSelectionChanged: (val) {
                              setState(() => _accrualMode = val.first);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Simple vs Compound Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Compound Interest (Monthly)'),
                        subtitle: Text(
                          _isCompound
                              ? 'Interest is added to principal every month'
                              : 'Simple interest is calculated on initial principal',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                        value: _isCompound,
                        onChanged: (val) => setState(() => _isCompound = val),
                      ),

                      // Repayment Priority: Interest First vs Principal First
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Repayment Priority',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _allocationRule,
                            items: const [
                              DropdownMenuItem(
                                value: 'interest_first',
                                child: Text('Interest First'),
                              ),
                              DropdownMenuItem(
                                value: 'principal_first',
                                child: Text('Principal First'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _allocationRule = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 5. Chit Fund Configuration
              if (isChit) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.jadeAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.jadeAccent, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chit Fund Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emeraldDark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Total Chit Value
                      TextFormField(
                        controller: _chitTotalValueController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Chit Value',
                          prefixText: '$currency ',
                          hintText: 'e.g., 200000',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (isChit && (val == null || val.trim().isEmpty)) {
                            return 'Please enter total chit value';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Duration (months)
                      TextFormField(
                        controller: _chitDurationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'No. of Months (Duration)',
                          hintText: 'e.g. 20',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _updateChitDates(),
                        validator: (val) {
                          if (isChit && (val == null || val.trim().isEmpty)) {
                            return 'Enter duration in months';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Dates: Starting Date and Ending Date
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                'Start: ${dateFormat.format(_chitStartDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _chitStartDate,
                                  firstDate: DateTime(2015),
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _chitStartDate = picked;
                                    _updateChitDates();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event, size: 16),
                              label: Text(
                                'End: ${dateFormat.format(_chitEndDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _chitEndDate,
                                  firstDate: _chitStartDate,
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null) {
                                  setState(() => _chitEndDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Installment Before Lifting & Installment After Lifting
                      TextFormField(
                        controller: _chitInstallmentBeforeController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Installment Before Lifting',
                          prefixText: '$currency ',
                          hintText: 'e.g., 8500',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (isChit && (val == null || val.trim().isEmpty)) {
                            return 'Enter installment before lifting';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _chitInstallmentAfterController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Installment After Lifting',
                          prefixText: '$currency ',
                          hintText: 'e.g., 10000',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (isChit && (val == null || val.trim().isEmpty)) {
                            return 'Enter installment after lifting';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 6. Color Palette Selection
              const Text(
                'Color Theme',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _availableColors.map((colorVal) {
                  final isSelected = _selectedColor == colorVal;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorVal),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),

              // 7. Submit Button
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
                  onPressed: _saveAccount,
                  child: Text(
                    widget.accountToEdit != null ? 'Save Changes' : 'Create Account',
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

  void _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final isDebtOrLending = _selectedType == AccountType.debt ||
        _selectedType == AccountType.lending;
    final isChit = _selectedType == AccountType.chit;

    final principal = isDebtOrLending
        ? (double.tryParse(_principalController.text) ?? 0.0)
        : 0.0;
    final initialBalance = !isDebtOrLending && !isChit
        ? (double.tryParse(_initialBalanceController.text) ?? 0.0)
        : principal;
    final interestRate = isDebtOrLending
        ? (double.tryParse(_interestRateController.text) ?? 0.0)
        : 0.0;
    final phone = _phoneNumberController.text.trim().isEmpty
        ? null
        : _phoneNumberController.text.trim();

    if (widget.accountToEdit != null) {
      final updated = widget.accountToEdit!.copyWith(
        name: _nameController.text.trim(),
        type: _selectedType,
        color: _selectedColor,
        phoneNumber: phone,
        openingBalance: initialBalance,
        principalBalance: isDebtOrLending ? principal : widget.accountToEdit!.principalBalance,
        balance: !isDebtOrLending && !isChit ? initialBalance : widget.accountToEdit!.balance,
        interestRate: interestRate,
        interestRateType: _interestRateType,
        isCompound: _isCompound,
        accrualMode: _accrualMode,
        allocationRule: _allocationRule,
        loanStartDate: isDebtOrLending ? _loanDate : widget.accountToEdit!.loanStartDate,
      );

      await context.read<FinanceProvider>().updateAccount(updated);

      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    final account = Account(
      name: _nameController.text.trim(),
      type: _selectedType,
      color: _selectedColor,
      balance: initialBalance,
      openingBalance: initialBalance,
      principalBalance: principal,
      accruedInterest: 0.0,
      interestRate: interestRate,
      interestRateType: _interestRateType,
      isCompound: _isCompound,
      accrualMode: _accrualMode,
      allocationRule: _allocationRule,
      loanStartDate: isDebtOrLending ? _loanDate : null,
      lastInterestDate: isDebtOrLending ? _loanDate : null,
      phoneNumber: phone,
    );

    ChitDetails? chitDetails;
    if (isChit) {
      final totalVal = double.parse(_chitTotalValueController.text);
      final duration = int.parse(_chitDurationController.text);
      final beforeLift =
          double.parse(_chitInstallmentBeforeController.text);
      final afterLift =
          double.parse(_chitInstallmentAfterController.text);

      chitDetails = ChitDetails(
        accountId: 0, // Assigned in provider
        totalValue: totalVal,
        durationMonths: duration,
        installmentBeforeLifting: beforeLift,
        installmentAfterLifting: afterLift,
        startDate: _chitStartDate,
        endDate: _chitEndDate,
      );
    }

    await context
        .read<FinanceProvider>()
        .addAccount(account, chitDetails: chitDetails);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
