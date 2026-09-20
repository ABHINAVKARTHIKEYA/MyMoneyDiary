import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    // Fetch latest account state from provider
    final currentAccount = finance.accounts.firstWhere(
      (a) => a.id == widget.account.id,
      orElse: () => widget.account,
    );
    final currency = finance.settings.currencySymbol;
    final formatter = NumberFormat('#,##,###.##');
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(currentAccount.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Account',
            onPressed: () => _confirmDeleteAccount(context, currentAccount),
          ),
        ],
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future: finance.getAccountTransactions(currentAccount.id!),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? [];
          final filteredTxs = transactions.where((tx) {
            if (_filter == 'debit') return tx.type == TransactionType.debit;
            if (_filter == 'credit') return tx.type == TransactionType.credit;
            if (_filter == 'transfer') return tx.type == TransactionType.transfer;
            return true;
          }).toList();

          return Column(
            children: [
              // 1. Account Summary Header
              _buildHeader(currentAccount, currency, formatter),

              // 2. Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('credit', 'Credits (+)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('debit', 'Debits (-)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('transfer', 'Transfers (⇄)'),
                  ],
                ),
              ),

              // 3. Transactions List
              Expanded(
                child: filteredTxs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'No transactions found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filteredTxs.length,
                        itemBuilder: (context, index) {
                          final tx = filteredTxs[index];
                          final isCredit = tx.type == TransactionType.credit;
                          final isTransfer =
                              tx.type == TransactionType.transfer;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isTransfer
                                    ? AppTheme.transferBlue.withAlpha(30)
                                    : isCredit
                                        ? AppTheme.creditGreen.withAlpha(30)
                                        : AppTheme.debitRed.withAlpha(30),
                                child: Icon(
                                  isTransfer
                                      ? Icons.swap_horiz
                                      : isCredit
                                          ? Icons.add
                                          : Icons.remove,
                                  color: isTransfer
                                      ? AppTheme.transferBlue
                                      : isCredit
                                          ? AppTheme.creditGreen
                                          : AppTheme.debitRed,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx.category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${isCredit ? "+" : isTransfer ? "" : "-"} $currency ${formatter.format(tx.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isTransfer
                                          ? AppTheme.transferBlue
                                          : isCredit
                                              ? AppTheme.creditGreen
                                              : AppTheme.debitRed,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(tx.date),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                                  if (tx.note.isNotEmpty)
                                    Text(
                                      tx.note,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (tx.principalPortion > 0 ||
                                      tx.interestPortion > 0)
                                    Text(
                                      'Principal: $currency ${formatter.format(tx.principalPortion)} | Interest: $currency ${formatter.format(tx.interestPortion)}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.emeraldPrimary,
                                          fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.grey),
                                onPressed: () async {
                                  await finance.deleteTransaction(tx.id!);
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddTransactionScreen(preselectedAccount: currentAccount),
            ),
          );
          setState(() {});
        },
      ),
    );
  }

  Widget _buildHeader(
    Account acc,
    String currency,
    NumberFormat formatter,
  ) {
    return Container(
      width: double.infinity,
      color: AppTheme.emeraldPrimary,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            acc.type.displayName.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.amberGold,
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            acc.isInterestBearing
                ? '$currency ${formatter.format(acc.totalOutstanding)}'
                : '$currency ${formatter.format(acc.balance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (acc.isInterestBearing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Principal',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(
                        '$currency ${formatter.format(acc.principalBalance)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.white30),
                  Column(
                    children: [
                      const Text('Accrued Interest',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(
                        '$currency ${formatter.format(acc.accruedInterest)}',
                        style: const TextStyle(
                            color: AppTheme.amberGold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.white30),
                  Column(
                    children: [
                      const Text('Rate',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(
                        '${acc.interestRate}% ${acc.interestRateType == "per_month" ? "pm" : "pa"}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _filter = key;
        });
      },
      selectedColor: AppTheme.emeraldPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, Account acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete "${acc.name}" and all its transaction history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<FinanceProvider>().deleteAccount(acc.id!);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.debitRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
