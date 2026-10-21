import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../services/statement_exporter_service.dart';
import '../theme/app_theme.dart';

class StatementExportScreen extends StatefulWidget {
  const StatementExportScreen({super.key});

  @override
  State<StatementExportScreen> createState() => _StatementExportScreenState();
}

class _StatementExportScreenState extends State<StatementExportScreen> {
  int? _selectedAccountId;
  String _format = 'pdf'; // 'pdf' or 'excel'
  String _datePreset = 'this_month'; // 'this_month', 'last_month', 'last_90_days', 'all_time', 'custom'
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  String _selectedType = 'all'; // 'all', 'credit', 'debit', 'transfer'
  String _selectedMode = 'all';
  String _selectedCategory = 'all';
  bool _isGenerating = false;

  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      switch (preset) {
        case 'this_month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = now;
          break;
        case 'last_month':
          _fromDate = DateTime(now.year, now.month - 1, 1);
          _toDate = DateTime(now.year, now.month, 0);
          break;
        case 'last_90_days':
          _fromDate = now.subtract(const Duration(days: 90));
          _toDate = now;
          break;
        case 'all_time':
          _fromDate = DateTime(2020, 1, 1);
          _toDate = now;
          break;
        case 'custom':
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = finance.settings.currencySymbol;
    final formatter = NumberFormat('#,##,###.##');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Statements'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Export Format Selector
            const Text(
              'Select Export Format',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _format = 'pdf'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _format == 'pdf'
                            ? AppTheme.emeraldPrimary
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _format == 'pdf'
                              ? AppTheme.emeraldPrimary
                              : Colors.grey.shade300,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf,
                              color: _format == 'pdf'
                                  ? Colors.white
                                  : Colors.grey.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'PDF Document',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _format == 'pdf'
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _format = 'excel'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _format == 'excel'
                            ? AppTheme.emeraldPrimary
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _format == 'excel'
                              ? AppTheme.emeraldPrimary
                              : Colors.grey.shade300,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_chart,
                              color: _format == 'excel'
                                  ? Colors.white
                                  : Colors.grey.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Excel (.CSV)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _format == 'excel'
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. Account Selector
            const Text(
              'Select Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _selectedAccountId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.all_inbox, size: 20, color: AppTheme.emeraldPrimary),
                      SizedBox(width: 8),
                      Text('All Accounts Consolidated'),
                    ],
                  ),
                ),
                ...finance.accounts.map((acc) {
                  return DropdownMenuItem<int?>(
                    value: acc.id,
                    child: Row(
                      children: [
                        Icon(acc.type.iconData,
                            size: 20, color: Color(acc.color)),
                        const SizedBox(width: 8),
                        Text(acc.name),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedAccountId = val),
            ),

            const SizedBox(height: 20),

            // 3. Date Range Selector
            const Text(
              'Date Range',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('this_month', 'This Month'),
                _buildPresetChip('last_month', 'Last Month'),
                _buildPresetChip('last_90_days', 'Last 90 Days'),
                _buildPresetChip('all_time', 'All Time'),
                _buildPresetChip('custom', 'Custom Range'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text('From: ${_displayDateFormat.format(_fromDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fromDate,
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _fromDate = picked;
                          _datePreset = 'custom';
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 16),
                    label: Text('To: ${_displayDateFormat.format(_toDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _toDate,
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _toDate = picked;
                          _datePreset = 'custom';
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 4. Filters: Type, Mode
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transaction Type',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Types')),
                          DropdownMenuItem(
                              value: 'credit', child: Text('Credits (+)')),
                          DropdownMenuItem(
                              value: 'debit', child: Text('Debits (-)')),
                          DropdownMenuItem(
                              value: 'transfer', child: Text('Transfers (⇄)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Mode',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedMode,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Modes')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(
                              value: 'Credit Card', child: Text('Credit Card')),
                          DropdownMenuItem(
                              value: 'Debit Card', child: Text('Debit Card')),
                          DropdownMenuItem(
                              value: 'Net Banking', child: Text('Net Banking')),
                          DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                          DropdownMenuItem(value: 'Others', child: Text('Others')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMode = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category Filter
            const Text('Filter by Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Categories')),
                DropdownMenuItem(value: 'Food & Dining', child: Text('Food & Dining')),
                DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                DropdownMenuItem(value: 'Bills & Utilities', child: Text('Bills & Utilities')),
                DropdownMenuItem(value: 'Travel & Fuel', child: Text('Travel & Fuel')),
                DropdownMenuItem(value: 'Salary & Income', child: Text('Salary & Income')),
                DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                DropdownMenuItem(value: 'Investment', child: Text('Investment')),
                DropdownMenuItem(value: 'Chit Fund', child: Text('Chit Fund')),
                DropdownMenuItem(value: 'Debt Repayment', child: Text('Debt Repayment')),
                DropdownMenuItem(value: 'General', child: Text('General')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),

            const SizedBox(height: 24),

            // 5. Future Preview Card
            FutureBuilder<List<TransactionModel>>(
              future: finance.getFilteredTransactions(
                accountId: _selectedAccountId,
                fromDate: _fromDate,
                toDate: _toDate,
                paymentMode: _selectedMode == 'all' ? null : _selectedMode,
                typeKey: _selectedType == 'all' ? null : _selectedType,
                category: _selectedCategory == 'all' ? null : _selectedCategory,
              ),
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                double totalIn = 0.0;
                double totalOut = 0.0;
                for (final t in txs) {
                  if (t.type == TransactionType.credit) {
                    totalIn += t.amount;
                  } else {
                    totalOut += t.amount;
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldPrimary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.emeraldPrimary.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'STATEMENT SUMMARY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: AppTheme.emeraldDark,
                            ),
                          ),
                          Text(
                            '${txs.length} Transactions',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emeraldDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Inflow (+)',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                              Text(
                                '$currency ${formatter.format(totalIn)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.creditGreen,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Outflow (-)',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                              Text(
                                '$currency ${formatter.format(totalOut)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.debitRed,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Net Flow',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                              Text(
                                '$currency ${formatter.format(totalIn - totalOut)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: (totalIn - totalOut) >= 0
                                      ? AppTheme.creditGreen
                                      : AppTheme.debitRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // 6. Generate & Share Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: Text(
                  _format == 'pdf'
                      ? 'Download & Share PDF Statement'
                      : 'Download & Share Excel (.CSV)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isGenerating ? null : () => _generateStatement(finance),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final isSelected = _datePreset == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyDatePreset(key),
      selectedColor: AppTheme.emeraldPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Future<void> _generateStatement(FinanceProvider finance) async {
    setState(() => _isGenerating = true);
    try {
      final txs = await finance.getFilteredTransactions(
        accountId: _selectedAccountId,
        fromDate: _fromDate,
        toDate: _toDate,
        paymentMode: _selectedMode == 'all' ? null : _selectedMode,
        typeKey: _selectedType == 'all' ? null : _selectedType,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );

      if (txs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('No transactions found matching the selected filters.')),
          );
        }
        return;
      }

      String accountTitle = 'All Accounts';
      if (_selectedAccountId != null) {
        final acc = finance.accounts
            .firstWhere((a) => a.id == _selectedAccountId, orElse: () => finance.accounts.first);
        accountTitle = acc.name;
      }

      if (_format == 'pdf') {
        await StatementExporterService.exportToPdf(
          transactions: txs,
          accountName: accountTitle,
          fromDate: _fromDate,
          toDate: _toDate,
          currencySymbol: finance.settings.currencySymbol,
        );
      } else {
        await StatementExporterService.exportToCsv(
          transactions: txs,
          accountName: accountTitle,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export statement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
