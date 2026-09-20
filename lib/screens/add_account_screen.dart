import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/chit_details.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  AccountType _selectedType = AccountType.custom;

  // Debt / Lending fields
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  String _interestRateType = 'per_month'; // 'per_month' or 'per_annum'
  bool _isCompound = false;
  String _accrualMode = 'daily'; // 'daily' or 'monthly'
  String _allocationRule = 'interest_first'; // 'interest_first' or 'principal_first'

  // Chit Fund fields
  final TextEditingController _chitTotalValueController =
      TextEditingController();
  final TextEditingController _chitDurationController =
      TextEditingController(text: '20');
  final TextEditingController _chitInstallmentController =
      TextEditingController();

  int _selectedColor = 0xFF0F3E33;

  final List<int> _availableColors = [
    0xFF0F3E33, // Emerald Primary
    0xFFE6B042, // Amber Gold
    0xFF2D8A70, // Jade Accent
    0xFF1E88E5, // Blue
    0xFF7B1FA2, // Purple
    0xFFE53935, // Red
    0xFFFB8C00, // Orange
    0xFF546E7A, // Blue Grey
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _interestRateController.dispose();
    _chitTotalValueController.dispose();
    _chitDurationController.dispose();
    _chitInstallmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDebtOrLending = _selectedType == AccountType.debt ||
        _selectedType == AccountType.lending;
    final isChit = _selectedType == AccountType.chit;
    final currency = context.watch<FinanceProvider>().settings.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Account Name
              const Text(
                'Account Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Suresh Loan, Family Chit, Car Upkeep',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter account name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 2. Account Type
              const Text(
                'Account Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<AccountType>(
                value: _selectedType,
                decoration: const InputDecoration(),
                items: AccountType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedType = val);
                  }
                },
              ),

              const SizedBox(height: 20),

              // 3. Debt & Lending Configuration
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
                        '${_selectedType == AccountType.debt ? "Debt" : "Lending"} & Interest Configuration',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emeraldDark,
                          fontSize: 15,
                        ),
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

              // 4. Chit Fund Configuration
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
                      TextFormField(
                        controller: _chitTotalValueController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Total Chit Value',
                          prefixText: '$currency ',
                          hintText: 'e.g., 200000',
                        ),
                        validator: (val) {
                          if (isChit && (val == null || val.trim().isEmpty)) {
                            return 'Please enter total chit value';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _chitDurationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (Months)',
                                hintText: '20',
                              ),
                              validator: (val) {
                                if (isChit &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Enter months';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _chitInstallmentController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Installment / Mo',
                                prefixText: '$currency ',
                              ),
                              validator: (val) {
                                if (isChit &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Enter installment';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 5. Color Palette Selection
              const Text(
                'Color Theme',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

              // 6. Submit Button
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
                  child: const Text(
                    'Create Account',
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

  void _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final isDebtOrLending = _selectedType == AccountType.debt ||
        _selectedType == AccountType.lending;
    final isChit = _selectedType == AccountType.chit;

    final principal = isDebtOrLending
        ? (double.tryParse(_principalController.text) ?? 0.0)
        : 0.0;
    final interestRate = isDebtOrLending
        ? (double.tryParse(_interestRateController.text) ?? 0.0)
        : 0.0;

    final account = Account(
      name: _nameController.text.trim(),
      type: _selectedType,
      color: _selectedColor,
      balance: principal,
      principalBalance: principal,
      accruedInterest: 0.0,
      interestRate: interestRate,
      interestRateType: _interestRateType,
      isCompound: _isCompound,
      accrualMode: _accrualMode,
      allocationRule: _allocationRule,
      lastInterestDate: isDebtOrLending ? DateTime.now() : null,
    );

    ChitDetails? chitDetails;
    if (isChit) {
      chitDetails = ChitDetails(
        accountId: 0, // Assigned in provider
        totalValue: double.parse(_chitTotalValueController.text),
        durationMonths: int.parse(_chitDurationController.text),
        nominalInstallment: double.parse(_chitInstallmentController.text),
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
