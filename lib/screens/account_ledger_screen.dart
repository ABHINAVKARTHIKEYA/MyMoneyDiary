import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../services/statement_exporter_service.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

class AccountLedgerScreen extends StatefulWidget {
  final Account account;

  const AccountLedgerScreen({super.key, required this.account});

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  final NumberFormat _formatter = NumberFormat('#,##,###.##');
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  String _filterEntryType = 'all'; // 'all', 'debit', 'credit'
  String _filterCategory = 'all';
  int? _selectedYear;
  int? _selectedMonth; // 1-12 or null for all

  List<Map<String, dynamic>> _ledgerEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    DateTime? fromDate;
    DateTime? toDate;

    if (_selectedYear != null) {
      if (_selectedMonth != null) {
        fromDate = DateTime(_selectedYear!, _selectedMonth!, 1);
        toDate = DateTime(_selectedYear!, _selectedMonth! + 1, 0, 23, 59, 59);
      } else {
        fromDate = DateTime(_selectedYear!, 1, 1);
        toDate = DateTime(_selectedYear!, 12, 31, 23, 59, 59);
      }
    }

    final entries = await context.read<FinanceProvider>().getAccountLedger(
      widget.account.id!,
      fromDate: fromDate,
      toDate: toDate,
      entryType: _filterEntryType == 'all' ? null : _filterEntryType,
      category: _filterCategory == 'all' ? null : _filterCategory,
    );

    if (mounted) {
      setState(() {
        _ledgerEntries = entries;
        _isLoading = false;
      });
    }
  }

  double get _totalDebits => _ledgerEntries
      .where((e) => e['entry_type'] == 'debit')
      .fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));

  double get _totalCredits => _ledgerEntries
      .where((e) => e['entry_type'] == 'credit')
      .fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));

  double get _closingBalance {
    if (_ledgerEntries.isEmpty) return widget.account.openingBalance;
    return (_ledgerEntries.last['running_balance'] as num?)?.toDouble() ??
        widget.account.balance;
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<FinanceProvider>().settings.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.account.name} Ledger', style: const TextStyle(fontSize: 16)),
            Text(
              '${widget.account.category.displayName} • Normal Balance: ${widget.account.normalBalance == NormalBalance.debit ? "Debit" : "Credit"}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Ledger (CSV / PDF)',
            onPressed: _showExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLedger,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Ledger Summary Header
          _buildSummaryCard(currency),

          // 2. Filters Bar
          _buildFiltersBar(),

          // 3. Ledger Line Items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ledgerEntries.isEmpty
                    ? _buildEmptyState()
                    : _buildLedgerList(currency),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Entry', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(preselectedAccount: widget.account),
            ),
          );
          _loadLedger();
        },
      ),
    );
  }

  Widget _buildSummaryCard(String currency) {
    return Container(
      width: double.infinity,
      color: AppTheme.emeraldPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Opening Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '$currency ${_formatter.format(widget.account.openingBalance)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Closing Running Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '$currency ${_formatter.format(_closingBalance)}',
                    style: const TextStyle(color: AppTheme.amberGold, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_downward, size: 14, color: AppTheme.creditGreen),
                    const SizedBox(width: 4),
                    Text('Total Debits: $currency ${_formatter.format(_totalDebits)}',
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
                Container(height: 14, width: 1, color: Colors.white30),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward, size: 14, color: AppTheme.debitRed),
                    const SizedBox(width: 4),
                    Text('Total Credits: $currency ${_formatter.format(_totalCredits)}',
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Entry Type Filter
            DropdownButton<String>(
              value: _filterEntryType,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Entries')),
                DropdownMenuItem(value: 'debit', child: Text('Debits Only')),
                DropdownMenuItem(value: 'credit', child: Text('Credits Only')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filterEntryType = val);
                  _loadLedger();
                }
              },
            ),
            const SizedBox(width: 8),

            // Year Filter
            ActionChip(
              avatar: const Icon(Icons.calendar_today, size: 14),
              label: Text(_selectedYear == null ? 'All Years' : '$_selectedYear'),
              onPressed: () {
                final currentYear = DateTime.now().year;
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: const Text('All Years'),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedYear = null);
                          _loadLedger();
                        },
                      ),
                      for (int y = currentYear; y >= currentYear - 5; y--)
                        ListTile(
                          title: Text('$y'),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedYear = y);
                            _loadLedger();
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),

            // Month Filter
            if (_selectedYear != null) ...[
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 14),
                label: Text(_selectedMonth == null
                    ? 'All Months'
                    : DateFormat('MMMM').format(DateTime(2026, _selectedMonth!))),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          title: const Text('All Months'),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedMonth = null);
                            _loadLedger();
                          },
                        ),
                        for (int m = 1; m <= 12; m++)
                          ListTile(
                            title: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _selectedMonth = m);
                              _loadLedger();
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],

            // Reset filters
            if (_filterEntryType != 'all' || _selectedYear != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 16),
                tooltip: 'Reset Filters',
                onPressed: () {
                  setState(() {
                    _filterEntryType = 'all';
                    _selectedYear = null;
                    _selectedMonth = null;
                  });
                  _loadLedger();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No ledger entries recorded for ${widget.account.name}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          const SizedBox(height: 6),
          const Text('Tap "New Entry" below to record a transaction.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLedgerList(String currency) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _ledgerEntries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = _ledgerEntries[index];
        final isDebit = row['entry_type'] == 'debit';
        final amount = (row['amount'] as num).toDouble();
        final runningBal = (row['running_balance'] as num).toDouble();
        final date = DateTime.tryParse(row['tx_date'] as String? ?? '') ?? DateTime.now();
        final counterAccountName = row['counter_account_name'] as String? ?? 'Offset Account';
        final memo = row['memo'] as String? ?? row['tx_note'] as String? ?? '';
        final category = row['tx_category'] as String? ?? '';
        final paymentMode = row['payment_mode'] as String? ?? '';
        final txType = row['tx_type'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry Type Icon Badge
              CircleAvatar(
                radius: 16,
                backgroundColor: isDebit ? AppTheme.emeraldPrimary.withAlpha(20) : AppTheme.amberGold.withAlpha(25),
                child: Text(
                  isDebit ? 'DR' : 'CR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDebit ? AppTheme.emeraldPrimary : AppTheme.amberGold,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Transaction Info & Counter Account
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Counter: $counterAccountName',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${isDebit ? "DR" : "CR"} $currency ${_formatter.format(amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDebit ? AppTheme.emeraldPrimary : AppTheme.debitRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(_dateFormat.format(date), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                        if (category.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(category, style: TextStyle(fontSize: 10, color: Colors.grey.shade800)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (paymentMode.isNotEmpty)
                          Text('• $paymentMode', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                    if (memo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(memo, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 4),
                    // Running Balance Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Running Balance: $currency ${_formatter.format(runningBal)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                      ),
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

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Account Ledger'),
        content: Text(
          'Export all ${_ledgerEntries.length} entries for "${widget.account.name}" to Excel-compatible CSV?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download, size: 16),
            label: const Text('Export CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final buffer = StringBuffer();
              buffer.writeln('Date,Entry ID,Type,Amount (INR),Counter Account,Category,Payment Mode,Memo,Running Balance');

              for (final r in _ledgerEntries) {
                final date = r['tx_date'] ?? '';
                final id = r['entry_id'] ?? '';
                final type = r['entry_type'] ?? '';
                final amt = r['amount'] ?? '';
                final ca = (r['counter_account_name'] ?? '').toString().replaceAll(',', ';');
                final cat = (r['tx_category'] ?? '').toString().replaceAll(',', ';');
                final mode = (r['payment_mode'] ?? '').toString().replaceAll(',', ';');
                final memo = (r['memo'] ?? '').toString().replaceAll(',', ';');
                final bal = r['running_balance'] ?? '';
                buffer.writeln('$date,$id,$type,$amt,"$ca","$cat","$mode","$memo",$bal');
              }

              // Share / Save CSV file
              await StatementExporterService.exportToCsv(
                transactions: [],
                accountName: widget.account.name,
                fromDate: _selectedYear != null ? DateTime(_selectedYear!, 1, 1) : DateTime(2026, 1, 1),
                toDate: DateTime.now(),
              );
            },
          ),
        ],
      ),
    );
  }
}
