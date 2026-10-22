import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/account.dart';
import '../models/chit_details.dart';
import '../models/transaction_model.dart';
import '../models/transaction_edit_history.dart';
import '../providers/finance_provider.dart';
import '../services/chit_service.dart';
import '../services/sms_notification_service.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

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
                              const CircleAvatar(
                                backgroundColor: Color(0xFFE0F2F1),
                                child: Icon(Icons.receipt, color: AppTheme.emeraldPrimary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          '$currency ${formatter.format(tx.amount)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppTheme.emeraldDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 13, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          dateFormat.format(tx.date),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            tx.paymentMode == 'Others' && (tx.otherPaymentModeDetails ?? '').isNotEmpty
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
                          if (tx.note.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Remarks: ${tx.note}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                            ),
                          ],
                          if (tx.receiptPath != null && tx.receiptPath!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _viewReceipt(context, tx.receiptPath!),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.amberGold.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.amberGold, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tx.receiptPath!.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.attachment,
                                      size: 14,
                                      color: AppTheme.emeraldDark,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'View Attached Proof',
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
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.sms_outlined, size: 16, color: AppTheme.emeraldPrimary),
                                label: const Text('Send SMS', style: TextStyle(fontSize: 12, color: AppTheme.emeraldPrimary)),
                                onPressed: () => SmsNotificationService.showSmsPreviewDialog(
                                  context,
                                  account: widget.account,
                                  tx: tx,
                                  initialPhone: widget.account.phoneNumber,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.history, size: 16, color: Colors.blueGrey),
                                label: const Text('History', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                onPressed: () => _showEditHistoryDialog(context, tx.id!),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.emeraldPrimary),
                                label: const Text('Edit', style: TextStyle(fontSize: 12, color: AppTheme.emeraldPrimary)),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionScreen(transactionToEdit: tx),
                                    ),
                                  );
                                  await _loadChitData();
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.debitRed),
                                label: const Text('Delete', style: TextStyle(fontSize: 12, color: AppTheme.debitRed)),
                                onPressed: () => _confirmDeleteTx(context, tx.id!),
                              ),
                            ],
                          ),
                        ],
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
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Period: ${DateFormat("dd MMM yyyy").format(_details!.startDate)} - ${DateFormat("dd MMM yyyy").format(_details!.endDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Active: $currency ${formatter.format(_details!.activeInstallment)}/mo',
                  style: const TextStyle(
                    color: AppTheme.amberGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
    final nominal = details.activeInstallment;
    final dividendController = TextEditingController(text: '0.0');
    final noteController = TextEditingController();
    final otherModeController = TextEditingController();
    double netToPay = nominal;
    DateTime selectedDate = DateTime.now();
    String paymentMode = 'UPI';
    String? receiptPath;

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
                    details.isLifted
                        ? 'Updated Installment (Post-Lifting): $currency ${nominal.toStringAsFixed(2)}'
                        : 'Current Installment (Pre-Lifting): $currency ${nominal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Installment Date Picker
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            'Date: ${DateFormat("dd MMM yyyy").format(selectedDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: details.startDate,
                              lastDate: DateTime(2050),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dividend input
                  TextFormField(
                    controller: dividendController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Dividend Earned this Month',
                      prefixText: '$currency ',
                      border: const OutlineInputBorder(),
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

                  // Payment Mode
                  DropdownButtonFormField<String>(
                    value: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: ['UPI', 'Cash', 'Credit Card', 'Debit Card', 'Net Banking', 'Cheque', 'Others']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => paymentMode = val);
                    },
                  ),
                  if (paymentMode == 'Others') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: otherModeController,
                      decoration: const InputDecoration(
                        labelText: 'Specify Other Mode Details *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Remarks / Note
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Note',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Attach Proof (Image or PDF)
                  if (receiptPath == null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.attach_file, color: AppTheme.emeraldPrimary, size: 18),
                      label: const Text('Attach Proof (Image or PDF)', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                          );
                          if (result != null && result.files.single.path != null) {
                            setDialogState(() => receiptPath = result.files.single.path);
                          }
                        } catch (_) {}
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.creditGreen.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.creditGreen),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            receiptPath!.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                            color: AppTheme.creditGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              receiptPath!.split(Platform.pathSeparator).last,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.debitRed),
                            onPressed: () => setDialogState(() => receiptPath = null),
                          ),
                        ],
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
                    category: 'Chit Installment (Month ${details.currentMonth + 1})',
                    note: noteController.text.trim().isNotEmpty
                        ? noteController.text.trim()
                        : 'Dividend: $currency ${dividendController.text}',
                    date: selectedDate,
                    paymentMode: paymentMode,
                    otherPaymentModeDetails: paymentMode == 'Others' ? otherModeController.text.trim() : null,
                    receiptPath: receiptPath,
                    debitAccountName: widget.account.name,
                    creditAccountName: 'Chit Fund',
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

  // ==================== VIEW RECEIPT ====================
  void _viewReceipt(BuildContext context, String receiptPath) {
    final file = File(receiptPath);
    final isPdf = receiptPath.toLowerCase().endsWith('.pdf');
    final fileName = receiptPath.split(Platform.pathSeparator).last;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isPdf ? Icons.picture_as_pdf : Icons.image,
                color: isPdf ? AppTheme.debitRed : AppTheme.emeraldPrimary, size: 22),
            const SizedBox(width: 8),
            const Text('Receipt Proof'),
          ],
        ),
        content: file.existsSync()
            ? (isPdf
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 48),
                        const SizedBox(height: 10),
                        Text(
                          fileName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'PDF Document (${(file.lengthSync() / 1024).toStringAsFixed(1)} KB)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Unable to display image preview'),
                      ),
                    ),
                  ))
            : Text('Receipt file not found at path: $receiptPath'),
        actions: [
          if (file.existsSync())
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(isPdf ? 'Open / Share PDF' : 'Share Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Share.shareXFiles([XFile(receiptPath)], text: 'Proof: $fileName');
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ==================== EDIT HISTORY DIALOG ====================
  void _showEditHistoryDialog(BuildContext context, int transactionId) async {
    final finance = context.read<FinanceProvider>();
    final history = await finance.getTransactionEditHistory(transactionId);
    final dtFormat = DateFormat('dd MMM yyyy, hh:mm a');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: AppTheme.emeraldPrimary),
            SizedBox(width: 8),
            Text('Edit History (Audit Trail)'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No edit history found for this transaction.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final item = history[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
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

  // ==================== CONFIRM DELETE TX ====================
  void _confirmDeleteTx(BuildContext context, int txId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Installment?'),
        content: const Text(
          'Are you sure you want to delete this installment payment? Any pool reflections and balance adjustments will be atomically reversed.',
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
              _loadChitData();
            },
            child: const Text('Delete'),
          ),
        ],
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
