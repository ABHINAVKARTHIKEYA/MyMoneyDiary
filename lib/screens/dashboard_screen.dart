import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'account_detail_screen.dart';
import 'add_account_screen.dart';
import 'add_transaction_screen.dart';
import 'chit_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = finance.settings.currencySymbol;
    final formatter = NumberFormat('#,##,###.##');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) =>
                    const Icon(Icons.account_balance_wallet, color: AppTheme.amberGold),
              ),
            ),
            const SizedBox(width: 10),
            const Text('MY MONEY DIARY'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: finance.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => finance.loadAllData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Net Overview Banner Card
                    _buildOverviewCard(finance, currency, formatter),

                    const SizedBox(height: 20),

                    // 2. Category Filter Bar
                    _buildCategoryFilter(),

                    const SizedBox(height: 16),

                    // 3. Accounts Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Accounts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add Account'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddAccountScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildAccountsList(finance, currency, formatter),

                    const SizedBox(height: 24),

                    // 4. Recent Transactions Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (finance.recentTransactions.isNotEmpty)
                          Text(
                            'Last ${finance.recentTransactions.length}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecentTransactions(finance, currency, formatter),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text(
          'New Transaction',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    FinanceProvider finance,
    String currency,
    NumberFormat formatter,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.emeraldDark, AppTheme.emeraldPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emeraldPrimary.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL AVAILABLE FUNDS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.amberGold.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.amberGold, width: 0.8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: AppTheme.amberGold),
                    SizedBox(width: 4),
                    Text(
                      '100% Offline',
                      style: TextStyle(
                        color: AppTheme.amberGold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currency ${formatter.format(finance.totalAvailablePool)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              // Lent / Receivable
              Expanded(
                child: _buildMetricItem(
                  title: 'Lent (Receivable)',
                  amount: '$currency ${formatter.format(finance.totalLentTotal)}',
                  subtitle:
                      'Int: $currency ${formatter.format(finance.totalLentAccruedInterest)}',
                  color: AppTheme.creditGreen,
                  icon: Icons.arrow_outward,
                ),
              ),
              Container(
                height: 36,
                width: 1,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              // Borrowed / Payable
              Expanded(
                child: _buildMetricItem(
                  title: 'Debts (Payable)',
                  amount:
                      '$currency ${formatter.format(finance.totalBorrowedTotal)}',
                  subtitle:
                      'Int: $currency ${formatter.format(finance.totalBorrowedAccruedInterest)}',
                  color: AppTheme.debitRed,
                  icon: Icons.arrow_downward,
                ),
              ),
            ],
          ),
          if (finance.totalPendingAdjustment > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions,
                      size: 16, color: AppTheme.amberGold),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Adjustments: $currency ${formatter.format(finance.totalPendingAdjustment)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withAlpha(160),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      {'key': 'all', 'label': 'All Accounts'},
      {'key': 'pool', 'label': 'Pool Funds'},
      {'key': 'debts_lending', 'label': 'Debts & Lendings'},
      {'key': 'chit', 'label': 'Chits'},
      {'key': 'temporary_adjustment', 'label': 'Adjustments'},
      {'key': 'maintenance', 'label': 'Maintenance'},
      {'key': 'custom', 'label': 'Custom'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat['label']!),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  _selectedCategory = cat['key']!;
                });
              },
              selectedColor: AppTheme.emeraldPrimary.withAlpha(40),
              checkmarkColor: AppTheme.emeraldPrimary,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.emeraldPrimary : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccountsList(
    FinanceProvider finance,
    String currency,
    NumberFormat formatter,
  ) {
    List<Account> filtered = [];
    switch (_selectedCategory) {
      case 'pool':
        filtered = finance.poolAccounts;
        break;
      case 'debts_lending':
        filtered = [...finance.debtAccounts, ...finance.lendingAccounts];
        break;
      case 'chit':
        filtered = finance.chitAccounts;
        break;
      case 'temporary_adjustment':
        filtered = finance.adjustmentAccounts;
        break;
      case 'maintenance':
        filtered = finance.maintenanceAccounts;
        break;
      case 'custom':
        filtered = [
          ...finance.customAccounts,
          ...finance.miscellaneousAccounts
        ];
        break;
      default:
        filtered = finance.accounts;
    }

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No accounts found in this category',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final acc = filtered[index];
        return _buildAccountTile(acc, currency, formatter);
      },
    );
  }

  Widget _buildAccountTile(
    Account acc,
    String currency,
    NumberFormat formatter,
  ) {
    IconData iconData = Icons.account_balance_wallet;
    switch (acc.type) {
      case AccountType.pool:
        iconData = Icons.account_balance;
        break;
      case AccountType.debt:
        iconData = Icons.arrow_downward;
        break;
      case AccountType.lending:
        iconData = Icons.arrow_outward;
        break;
      case AccountType.chit:
        iconData = Icons.confirmation_number;
        break;
      case AccountType.temporaryAdjustment:
        iconData = Icons.swap_horiz;
        break;
      case AccountType.maintenance:
        iconData = Icons.build_circle;
        break;
      case AccountType.miscellaneous:
        iconData = Icons.category;
        break;
      case AccountType.custom:
        iconData = Icons.folder;
        break;
    }

    String balanceDisplay = '';
    String subtext = '';

    if (acc.isInterestBearing) {
      balanceDisplay =
          '$currency ${formatter.format(acc.totalOutstanding)}';
      subtext =
          'Principal: $currency ${formatter.format(acc.principalBalance)} | Int: $currency ${formatter.format(acc.accruedInterest)} (@ ${acc.interestRate}% ${acc.interestRateType == "per_month" ? "pm" : "pa"})';
    } else {
      balanceDisplay = '$currency ${formatter.format(acc.balance)}';
      subtext = acc.type.displayName;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(acc.color).withAlpha(40),
          child: Icon(iconData, color: Color(acc.color)),
        ),
        title: Text(
          acc.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtext,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              balanceDisplay,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: acc.type == AccountType.debt
                    ? AppTheme.debitRed
                    : acc.type == AccountType.lending
                        ? AppTheme.creditGreen
                        : null,
              ),
            ),
            const SizedBox(height: 2),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
        onTap: () {
          if (acc.type == AccountType.chit) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChitDetailScreen(account: acc),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountDetailScreen(account: acc),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildRecentTransactions(
    FinanceProvider finance,
    String currency,
    NumberFormat formatter,
  ) {
    if (finance.recentTransactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No transactions recorded yet.\nTap "New Transaction" to add your first entry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: finance.recentTransactions.take(10).length,
      itemBuilder: (context, index) {
        final tx = finance.recentTransactions[index];
        final isCredit = tx.type == TransactionType.credit;
        final isTransfer = tx.type == TransactionType.transfer;

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
            title: Text(
              tx.category.isNotEmpty ? tx.category : 'General',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${dateFormat.format(tx.date)}${tx.note.isNotEmpty ? " • ${tx.note}" : ""}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
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
          ),
        );
      },
    );
  }
}
