import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../models/transaction_edit_history.dart';
import '../providers/finance_provider.dart';
import '../services/statement_exporter_service.dart';
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
          // Rename Account button
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename Account',
            onPressed: () => _showRenameAccountDialog(context, currentAccount),
          ),
          // Export Statement button
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Statement (Excel & PDF)',
            onPressed: () => _showExportStatementDialog(context, currentAccount),
          ),
          // Delete Account button
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
                          final isTransfer = tx.type == TransactionType.transfer;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1.5,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
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
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    tx.category,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${isCredit ? "+" : isTransfer ? "" : "-"} $currency ${formatter.format(tx.amount)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isTransfer
                                                        ? AppTheme.transferBlue
                                                        : isCredit
                                                            ? AppTheme.creditGreen
                                                            : AppTheme.debitRed,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time,
                                                    size: 13,
                                                    color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dateFormat.format(tx.date),
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade700),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    tx.paymentMode == 'Others' &&
                                                            (tx.otherPaymentModeDetails ?? '')
                                                                .isNotEmpty
                                                        ? 'Mode: ${tx.otherPaymentModeDetails}'
                                                        : 'Mode: ${tx.paymentMode}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Debit & Credit Accounts (Double-Entry visibility)
                                  if ((tx.debitAccountName ?? '').isNotEmpty ||
                                      (tx.creditAccountName ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if ((tx.debitAccountName ?? '')
                                              .isNotEmpty) ...[
                                            const Text('Dr: ',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.debitRed)),
                                            Text(tx.debitAccountName!,
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                            const SizedBox(width: 8),
                                          ],
                                          if ((tx.creditAccountName ?? '')
                                              .isNotEmpty) ...[
                                            const Text('Cr: ',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.creditGreen)),
                                            Text(tx.creditAccountName!,
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Remarks / Note
                                  if (tx.note.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Remarks: ${tx.note}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800),
                                    ),
                                  ],

                                  // Principal & Interest Split (for Debt/Lending)
                                  if (tx.principalPortion > 0 ||
                                      tx.interestPortion > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Principal: $currency ${formatter.format(tx.principalPortion)} | Interest: $currency ${formatter.format(tx.interestPortion)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.emeraldPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],

                                  // Attached Receipt proof
                                  if (tx.receiptPath != null &&
                                      tx.receiptPath!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () =>
                                          _viewReceipt(context, tx.receiptPath!),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.amberGold.withAlpha(25),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: AppTheme.amberGold,
                                              width: 0.8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.attachment,
                                                size: 14,
                                                color: AppTheme.emeraldDark),
                                            SizedBox(width: 4),
                                            Text(
                                              'View Attached Receipt Proof',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.emeraldDark,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Action Buttons: Edit, History, Delete
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.history,
                                            size: 16, color: Colors.blueGrey),
                                        label: const Text(
                                          'History',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blueGrey),
                                        ),
                                        onPressed: () => _showEditHistoryDialog(
                                            context, tx.id!),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 16,
                                            color: AppTheme.emeraldPrimary),
                                        label: const Text(
                                          'Edit',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.emeraldPrimary),
                                        ),
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AddTransactionScreen(
                                                transactionToEdit: tx,
                                              ),
                                            ),
                                          );
                                          setState(() {});
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 16,
                                            color: AppTheme.debitRed),
                                        label: const Text(
                                          'Delete',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.debitRed),
                                        ),
                                        onPressed: () =>
                                            _confirmDeleteTx(context, tx.id!),
                                      ),
                                    ],
                                  ),
                                ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(acc.type.iconData, color: AppTheme.amberGold, size: 18),
              const SizedBox(width: 8),
              Text(
                acc.type.displayName.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.amberGold,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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

  // ==================== RENAME ACCOUNT ====================
  void _showRenameAccountDialog(BuildContext context, Account acc) {
    final nameController = TextEditingController(text: acc.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Account Name'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You can rename "${acc.name}" anytime. Transactions linked to this account will remain intact.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Account name cannot be empty';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newName = nameController.text.trim();
                Navigator.pop(ctx);
                final updatedAcc = acc.copyWith(name: newName);
                await context.read<FinanceProvider>().updateAccount(updatedAcc);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Account renamed to "$newName"')),
                  );
                }
              }
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );
  }

  // ==================== EXPORT STATEMENT ====================
  void _showExportStatementDialog(BuildContext context, Account acc) {
    DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime toDate = DateTime.now();
    String selectedFormat = 'pdf'; // 'pdf' or 'excel'
    String selectedRange = 'last_30_days'; // 'all', 'last_30_days', 'custom'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final df = DateFormat('dd MMM yyyy');
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.file_download, color: AppTheme.emeraldPrimary),
                const SizedBox(width: 8),
                Expanded(child: Text('Export Statement: ${acc.name}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Format:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('PDF Document'),
                          selected: selectedFormat == 'pdf',
                          onSelected: (val) =>
                              setDialogState(() => selectedFormat = 'pdf'),
                          selectedColor: AppTheme.emeraldPrimary.withAlpha(40),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.table_chart, size: 16),
                          label: const Text('Excel (.csv)'),
                          selected: selectedFormat == 'excel',
                          onSelected: (val) =>
                              setDialogState(() => selectedFormat = 'excel'),
                          selectedColor: AppTheme.emeraldPrimary.withAlpha(40),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Date Range:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRange,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'last_30_days', child: Text('Last 30 Days')),
                      DropdownMenuItem(
                          value: 'all', child: Text('All Time History')),
                      DropdownMenuItem(
                          value: 'custom', child: Text('Custom Date Range')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedRange = val;
                          if (val == 'all') {
                            fromDate = DateTime(2020, 1, 1);
                            toDate = DateTime.now();
                          } else if (val == 'last_30_days') {
                            fromDate =
                                DateTime.now().subtract(const Duration(days: 30));
                            toDate = DateTime.now();
                          }
                        });
                      }
                    },
                  ),
                  if (selectedRange == 'custom') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: fromDate,
                                firstDate: DateTime(2015),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setDialogState(() => fromDate = picked);
                              }
                            },
                            child: Text('From: ${df.format(fromDate)}',
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: toDate,
                                firstDate: DateTime(2015),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() => toDate = picked);
                              }
                            },
                            child: Text('To: ${df.format(toDate)}',
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: Text(selectedFormat == 'pdf'
                    ? 'Generate PDF'
                    : 'Generate Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final finance = context.read<FinanceProvider>();
                  final txs = await finance.getFilteredTransactions(
                    accountId: acc.id,
                    fromDate: fromDate,
                    toDate: toDate,
                  );

                  if (txs.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'No transactions found for the selected range.')),
                      );
                    }
                    return;
                  }

                  try {
                    if (selectedFormat == 'pdf') {
                      await StatementExporterService.exportToPdf(
                        transactions: txs,
                        accountName: acc.name,
                        fromDate: fromDate,
                        toDate: toDate,
                        currencySymbol: finance.settings.currencySymbol,
                      );
                    } else {
                      await StatementExporterService.exportToCsv(
                        transactions: txs,
                        accountName: acc.name,
                        fromDate: fromDate,
                        toDate: toDate,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to export statement: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== EDIT HISTORY DIALOG ====================
  void _showEditHistoryDialog(BuildContext context, int transactionId) async {
    final history = await context
        .read<FinanceProvider>()
        .getTransactionEditHistory(transactionId);
    final dtFormat = DateFormat('dd MMM yyyy, hh:mm a');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: AppTheme.emeraldPrimary),
            SizedBox(width: 8),
            Text('Edit History Audit Log'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No edits recorded. This transaction has its original values.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = history[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.amberGold,
                        child: Icon(Icons.edit, size: 14, color: AppTheme.emeraldDark),
                      ),
                      title: Text(
                        'Reason: ${item.reason}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            dtFormat.format(item.editedAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          if (item.changesSummary.isNotEmpty)
                            Text(
                              item.changesSummary,
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ==================== VIEW RECEIPT ====================
  void _viewReceipt(BuildContext context, String receiptPath) {
    final file = File(receiptPath);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attached Receipt Proof'),
        content: file.existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Unable to display image preview'),
                  ),
                ),
              )
            : Text('Receipt file not found at path: $receiptPath'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ==================== CONFIRM DELETE TX ====================
  void _confirmDeleteTx(BuildContext context, int txId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction? Balance adjustments will be atomically reversed.',
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
              await context.read<FinanceProvider>().deleteTransaction(txId);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ==================== CONFIRM DELETE ACCOUNT ====================
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
