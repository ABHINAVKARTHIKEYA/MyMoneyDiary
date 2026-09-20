import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/chit_details.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../services/chit_service.dart';
import '../theme/app_theme.dart';

class ChitDetailScreen extends StatefulWidget {
  final Account account;

  const ChitDetailScreen({super.key, required this.account});

  @override
  State<ChitDetailScreen> createState() => _ChitDetailScreenState();
}

class _ChitDetailScreenState extends State<ChitDetailScreen> {
  ChitDetails? _details;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChitData();
  }

  Future<void> _loadChitData() async {
    final finance = context.read<FinanceProvider>();
    _details = await finance.getChitDetails(widget.account.id!);
    _transactions = await finance.getAccountTransactions(widget.account.id!);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<FinanceProvider>().settings.currencySymbol;
    final formatter = NumberFormat('#,##,###.##');
    final dateFormat = DateFormat('dd MMM yyyy');

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.account.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_details == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.account.name)),
        body: const Center(child: Text('Chit details not found')),
      );
    }

    final summary = ChitService.computeSummary(
      details: _details!,
      chitTransactions: _transactions,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Chit Status Header Card
            _buildChitHeader(summary, currency, formatter),

            const SizedBox(height: 20),

            // 2. Action Buttons: Pay Installment & Lift Chit
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Installment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showPayInstallmentDialog(
                        context, _details!, currency),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      _details!.isLifted
                          ? Icons.check_circle
                          : Icons.celebration,
                      color: _details!.isLifted
                          ? AppTheme.creditGreen
                          : AppTheme.amberGold,
                    ),
                    label: Text(
                      _details!.isLifted ? 'Chit Lifted' : 'Lift Chit',
                      style: TextStyle(
                        color: _details!.isLifted
                            ? AppTheme.creditGreen
                            : AppTheme.emeraldDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: _details!.isLifted
                            ? AppTheme.creditGreen
                            : AppTheme.amberGold,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _details!.isLifted
                        ? null
                        : () => _showLiftChitDialog(
                            context, _details!, currency),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Installment History
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_transactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No installments recorded yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final tx = _transactions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0F2F1),
                        child: Icon(Icons.receipt, color: AppTheme.emeraldPrimary),
                      ),
                      title: Text(
                        tx.category,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${dateFormat.format(tx.date)}${tx.note.isNotEmpty ? " • ${tx.note}" : ""}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: Text(
                        '$currency ${formatter.format(tx.amount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChitHeader(
    ChitSummary summary,
    String currency,
    NumberFormat formatter,
  ) {
    final progress = summary.totalMonths > 0
        ? summary.monthsPaid / summary.totalMonths
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.emeraldDark, AppTheme.emeraldPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CHIT FUND VALUE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.isLifted
                      ? AppTheme.creditGreen.withAlpha(50)
                      : AppTheme.amberGold.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  summary.isLifted
                      ? 'Lifted (Month ${summary.liftedMonth})'
                      : 'Active / Not Lifted',
                  style: TextStyle(
                    color: summary.isLifted
                        ? AppTheme.creditGreen
                        : AppTheme.amberGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$currency ${formatter.format(summary.totalValue)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: ${summary.monthsPaid} / ${summary.totalMonths} Months',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppTheme.amberGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppTheme.amberGold),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),

          // Metrics Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Paid',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '$currency ${formatter.format(summary.totalAmountPaid)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dividends Saved',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '$currency ${formatter.format(summary.totalDividendsEarned)}',
                    style: const TextStyle(
                        color: AppTheme.amberGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (summary.isLifted)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prize Received',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      '$currency ${formatter.format(summary.prizeMoneyReceived)}',
                      style: const TextStyle(
                          color: AppTheme.creditGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPayInstallmentDialog(
    BuildContext context,
    ChitDetails details,
    String currency,
  ) {
    final nominal = details.nominalInstallment;
    final dividendController = TextEditingController(text: '0.0');
    final noteController = TextEditingController();
    double netToPay = nominal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Month ${details.currentMonth + 1} Installment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nominal Installment: $currency ${nominal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dividendController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Dividend Earned this Month',
                      prefixText: '$currency ',
                    ),
                    onChanged: (val) {
                      final div = double.tryParse(val) ?? 0.0;
                      setDialogState(() {
                        netToPay = (nominal - div).clamp(0.0, nominal);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldPrimary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Amount to Pay:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$currency ${netToPay.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emeraldDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Note',
                      hintText: 'Optional',
                    ),
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
                  Navigator.pop(ctx);
                  final finance = context.read<FinanceProvider>();
                  final tx = TransactionModel(
                    accountId: details.accountId,
                    type: TransactionType.debit,
                    amount: netToPay,
                    category:
                        'Chit Installment (Month ${details.currentMonth + 1})',
                    note: noteController.text.trim().isNotEmpty
                        ? noteController.text.trim()
                        : 'Dividend: $currency ${dividendController.text}',
                    date: DateTime.now(),
                  );
                  await finance.addTransaction(tx);
                  await finance.updateChitDetails(
                    details.copyWith(currentMonth: details.currentMonth + 1),
                  );
                  _loadChitData();
                },
                child: const Text('Record Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLiftChitDialog(
    BuildContext context,
    ChitDetails details,
    String currency,
  ) {
    final prizeMoneyController = TextEditingController();
    final discountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Chit Lifted / Won'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the auction / prize money details for this chit (Total Value: $currency ${details.totalValue.toStringAsFixed(0)}).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: prizeMoneyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Net Prize Money Received',
                  prefixText: '$currency ',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: discountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Bid Discount / Surrendered',
                  prefixText: '$currency ',
                ),
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
              backgroundColor: AppTheme.amberGold,
              foregroundColor: AppTheme.emeraldDark,
            ),
            onPressed: () async {
              final prize = double.tryParse(prizeMoneyController.text) ?? 0.0;
              final discount = double.tryParse(discountController.text) ?? 0.0;
              if (prize <= 0) return;

              Navigator.pop(ctx);
              final finance = context.read<FinanceProvider>();

              await finance.updateChitDetails(
                details.copyWith(
                  isLifted: true,
                  liftedMonth: details.currentMonth,
                  prizeMoneyReceived: prize,
                  bidDiscount: discount,
                ),
              );

              // Record Prize Money Credit to Chit Account
              await finance.addTransaction(
                TransactionModel(
                  accountId: details.accountId,
                  type: TransactionType.credit,
                  amount: prize,
                  category: 'Chit Prize Money (Lifted)',
                  note: 'Surrendered Discount: $currency $discount',
                  date: DateTime.now(),
                ),
              );

              _loadChitData();
            },
            child: const Text('Confirm Lifted'),
          ),
        ],
      ),
    );
  }
}
