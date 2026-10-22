import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import '../models/transaction_model.dart';
import '../models/transaction_type.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';
import 'account_ledger_screen.dart';

class MasterJournalScreen extends StatefulWidget {
  const MasterJournalScreen({super.key});

  @override
  State<MasterJournalScreen> createState() => _MasterJournalScreenState();
}

class _MasterJournalScreenState extends State<MasterJournalScreen> {
  final NumberFormat _formatter = NumberFormat('#,##,###.##');
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _journalRows = [];
  bool _isLoading = true;

  // Filter States
  int? _selectedAccountId;
  String _selectedCategory = 'all';
  String _selectedTypeKey = 'all';
  String _selectedPaymentMode = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJournal() async {
    setState(() => _isLoading = true);
    final finance = context.read<FinanceProvider>();
    final rows = await finance.getMasterJournalRegister(
      fromDate: _fromDate,
      toDate: _toDate,
      accountId: _selectedAccountId,
      category: _selectedCategory,
      typeKey: _selectedTypeKey,
      paymentMode: _selectedPaymentMode,
      searchQuery: _searchController.text.trim(),
      limit: 200,
    );

    if (mounted) {
      setState(() {
        _journalRows = rows;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = finance.settings.currencySymbol;
    final accounts = finance.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Transaction Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Register',
            onPressed: _loadJournal,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by note, category, person, or bill #...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadJournal();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _loadJournal(),
            ),
          ),

          // 2. Filter Bar
          _buildFilterBar(accounts),

          // 3. Transactions Count & Total Volume
          _buildVolumeSummary(currency),

          // 4. Master Journal List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _journalRows.isEmpty
                    ? _buildEmptyState()
                    : _buildJournalList(currency, accounts),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Entry', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          _loadJournal();
        },
      ),
    );
  }

  Widget _buildFilterBar(List<Account> accounts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Account Filter
          DropdownButton<int?>(
            value: _selectedAccountId,
            hint: const Text('All Accounts', style: TextStyle(fontSize: 12)),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Accounts', style: TextStyle(fontSize: 12))),
              ...accounts.map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() => _selectedAccountId = val);
              _loadJournal();
            },
          ),
          const SizedBox(width: 8),

          // Transaction Type Filter
          DropdownButton<String>(
            value: _selectedTypeKey,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Types', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'income', child: Text('Income', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'expense', child: Text('Expense', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'transfer', child: Text('Transfer', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'loan_taken', child: Text('Loan Taken', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'loan_repayment', child: Text('Loan Repayment', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'credit_card_purchase', child: Text('Credit Card Purchase', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'credit_card_payment', child: Text('Credit Card Payment', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'chit_payment', child: Text('Chit Payment', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'chit_receipt', child: Text('Chit Receipt', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'adjustment', child: Text('Adjustment', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedTypeKey = val);
                _loadJournal();
              }
            },
          ),
          const SizedBox(width: 8),

          // Date Range Filter Button
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 14),
            label: Text(
              _fromDate == null
                  ? 'All Dates'
                  : '${_dateFormat.format(_fromDate!)} - ${_toDate != null ? _dateFormat.format(_toDate!) : "Today"}',
              style: const TextStyle(fontSize: 11),
            ),
            onPressed: _pickDateRange,
          ),
          const SizedBox(width: 8),

          // Clear Filters
          if (_selectedAccountId != null || _selectedTypeKey != 'all' || _fromDate != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Reset Filters',
              onPressed: () {
                setState(() {
                  _selectedAccountId = null;
                  _selectedTypeKey = 'all';
                  _fromDate = null;
                  _toDate = null;
                  _searchController.clear();
                });
                _loadJournal();
              },
            ),
        ],
      ),
    );
  }

  void _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate = range.end;
      });
      _loadJournal();
    }
  }

  Widget _buildVolumeSummary(String currency) {
    final totalVol = _journalRows.fold(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_journalRows.length} Journal Transactions', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text('Total Volume: $currency ${_formatter.format(totalVol)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emeraldPrimary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No transactions match the selected criteria', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          const SizedBox(height: 6),
          const Text('Try adjusting filters or adding a new transaction.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildJournalList(String currency, List<Account> accounts) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _journalRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = _journalRows[index];
        final id = row['id'] as int;
        final txNumber = row['tx_number'] as String? ?? 'TXN-$id';
        final typeKey = row['type'] as String? ?? 'expense';
        final txType = TransactionTypeExtension.fromKey(typeKey);
        final amount = (row['amount'] as num).toDouble();
        final date = DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now();
        final category = row['category'] as String? ?? 'General';
        final note = row['note'] as String? ?? '';
        final paymentMode = row['payment_mode'] as String? ?? 'UPI';
        final debitAccName = row['debit_account_name'] as String? ?? 'Debit';
        final creditAccName = row['credit_account_name'] as String? ?? 'Credit';
        final isOutflow = txType.isOutflow;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isOutflow ? AppTheme.debitRed.withAlpha(25) : AppTheme.emeraldPrimary.withAlpha(25),
              child: Icon(
                isOutflow ? Icons.arrow_upward : Icons.arrow_downward,
                color: isOutflow ? AppTheme.debitRed : AppTheme.emeraldPrimary,
                size: 18,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    category,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$currency ${_formatter.format(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOutflow ? AppTheme.debitRed : AppTheme.emeraldPrimary,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(_dateFormat.format(date), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                      child: Text(txType.displayName, style: TextStyle(fontSize: 9, color: Colors.grey.shade800)),
                    ),
                    const SizedBox(width: 6),
                    Text('• $paymentMode', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('$debitAccName ⇄ $creditAccName', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.isNotEmpty) ...[
                      Text('Note: $note', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                      const SizedBox(height: 6),
                    ],
                    Text('Transaction Reference: $txNumber',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    // Line Items Drilldown Button
                    FutureBuilder<List<JournalEntry>>(
                      future: context.read<FinanceProvider>().getJournalEntriesForTransaction(id),
                      builder: (ctx, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox();
                        }
                        final entries = snapshot.data!;
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Double-Entry Line Items (Balanced):',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              ...entries.map((je) {
                                final acc = accounts.firstWhere(
                                  (a) => a.id == je.accountId,
                                  orElse: () => Account(name: 'Account #${je.accountId}', type: AccountType.custom),
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${je.isDebit ? "DR" : "CR"} • ${acc.name}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: je.isDebit ? AppTheme.emeraldPrimary : AppTheme.amberGold,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '$currency ${_formatter.format(je.amount)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final txModel = TransactionModel.fromMap(row);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddTransactionScreen(transactionToEdit: txModel),
                              ),
                            );
                            _loadJournal();
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.debitRed),
                          label: const Text('Delete', style: TextStyle(fontSize: 12, color: AppTheme.debitRed)),
                          onPressed: () => _confirmDelete(id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction? All balanced double-entry ledger lines will be reversed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.debitRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<FinanceProvider>().deleteTransaction(id);
              _loadJournal();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
