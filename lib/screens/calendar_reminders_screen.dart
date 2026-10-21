import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reminder_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class CalendarRemindersScreen extends StatefulWidget {
  const CalendarRemindersScreen({super.key});

  @override
  State<CalendarRemindersScreen> createState() => _CalendarRemindersScreenState();
}

class _CalendarRemindersScreenState extends State<CalendarRemindersScreen> {
  String _selectedFilter = 'all'; // 'all', 'upcoming', 'due_today', 'overdue', 'paid'
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final reminders = finance.reminders;
    final currency = finance.settings.currencySymbol;
    final formatter = NumberFormat('#,##,###.##');
    final monthFormat = DateFormat('MMMM yyyy');

    // Metrics
    final dueTodayList = reminders.where((r) => r.isDueToday).toList();
    final overdueList = reminders.where((r) => r.isOverdue).toList();
    final upcomingList = reminders.where((r) => !r.isPaid && !r.isOverdue && !r.isDueToday).toList();
    final paidList = reminders.where((r) => r.isPaid).toList();

    final filteredReminders = reminders.where((r) {
      if (_selectedFilter == 'due_today') return r.isDueToday;
      if (_selectedFilter == 'overdue') return r.isOverdue;
      if (_selectedFilter == 'upcoming') return !r.isPaid && !r.isOverdue;
      if (_selectedFilter == 'paid') return r.isPaid;
      return true;
    }).toList();

    // Sort by due date
    filteredReminders.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Reminders Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert),
            tooltip: 'Add Payment Reminder',
            onPressed: () => _showAddEditReminderDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Month Navigation Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.emeraldPrimary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                        1,
                      );
                    });
                  },
                ),
                Text(
                  monthFormat.format(_selectedMonth).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                        1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),

          // 2. Summary Metric Badges
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                _buildSummaryBadge(
                  label: 'Due Today',
                  count: dueTodayList.length,
                  color: AppTheme.amberGold,
                  icon: Icons.today,
                ),
                const SizedBox(width: 8),
                _buildSummaryBadge(
                  label: 'Overdue',
                  count: overdueList.length,
                  color: AppTheme.debitRed,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(width: 8),
                _buildSummaryBadge(
                  label: 'Upcoming',
                  count: upcomingList.length,
                  color: AppTheme.transferBlue,
                  icon: Icons.event,
                ),
                const SizedBox(width: 8),
                _buildSummaryBadge(
                  label: 'Paid',
                  count: paidList.length,
                  color: AppTheme.creditGreen,
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
          ),

          // 3. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${reminders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('due_today', 'Due Today (${dueTodayList.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('overdue', 'Overdue (${overdueList.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('upcoming', 'Upcoming (${upcomingList.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('paid', 'Paid (${paidList.length})'),
              ],
            ),
          ),

          const Divider(height: 1),

          // 4. Reminders List
          Expanded(
            child: filteredReminders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No payment reminders found.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap + to add a reminder for Bills, EMIs, Chits, or Rent.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredReminders.length,
                    itemBuilder: (context, index) {
                      final item = filteredReminders[index];
                      return _buildReminderCard(
                        context,
                        item,
                        currency,
                        formatter,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
        backgroundColor: AppTheme.emeraldPrimary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditReminderDialog(context),
      ),
    );
  }

  Widget _buildSummaryBadge({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() => _selectedFilter = key);
      },
      selectedColor: AppTheme.emeraldPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    ReminderModel item,
    String currency,
    NumberFormat formatter,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final dayMonthFormat = DateFormat('dd\nMMM');

    Color statusColor;
    String statusText;
    if (item.isPaid) {
      statusColor = AppTheme.creditGreen;
      statusText = 'Paid';
    } else if (item.isOverdue) {
      statusColor = AppTheme.debitRed;
      statusText = 'Overdue';
    } else if (item.isDueToday) {
      statusColor = AppTheme.amberGold;
      statusText = 'Due Today';
    } else {
      statusColor = AppTheme.transferBlue;
      statusText = 'Upcoming';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isOverdue
              ? AppTheme.debitRed.withAlpha(80)
              : Colors.transparent,
          width: 1,
        ),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Badge Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dayMonthFormat.format(item.dueDate).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: item.isPaid
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            '$currency ${formatter.format(item.amount)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: item.isPaid
                                  ? Colors.grey
                                  : AppTheme.emeraldDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatFrequency(item.frequency),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Due: ${dateFormat.format(item.dueDate)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                if (item.isPaid && item.paidDate != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Paid on: ${DateFormat("dd MMM").format(item.paidDate!)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.creditGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),

            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Note: ${item.notes}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Colors.blueGrey),
                      tooltip: 'Edit Reminder',
                      onPressed: () =>
                          _showAddEditReminderDialog(context, reminder: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.debitRed),
                      tooltip: 'Delete Reminder',
                      onPressed: () => _confirmDeleteReminder(context, item.id!),
                    ),
                  ],
                ),
                if (!item.isPaid)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark as Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.creditGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _promptMarkPaid(context, item),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Mark Unpaid'),
                    onPressed: () async {
                      await context.read<FinanceProvider>().updateReminder(
                            item.copyWith(isPaid: false, paidDate: null),
                          );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFrequency(String freq) {
    switch (freq) {
      case 'one_time':
        return '• Once';
      case 'daily':
        return '• Daily';
      case 'weekly':
        return '• Weekly';
      case 'monthly':
        return '• Monthly';
      case 'quarterly':
        return '• Quarterly';
      case 'yearly':
        return '• Yearly';
      default:
        return '• $freq';
    }
  }

  // ==================== PROMPT MARK PAID ====================
  void _promptMarkPaid(BuildContext context, ReminderModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Reminder as Paid?'),
        content: Text(
          'Would you like to record this payment of ${context.read<FinanceProvider>().settings.currencySymbol} ${item.amount.toStringAsFixed(2)} as a debit in your Pool Account automatically?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context
                  .read<FinanceProvider>()
                  .markReminderPaid(item, recordToPool: false);
            },
            child: const Text('Mark Paid Only'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context
                  .read<FinanceProvider>()
                  .markReminderPaid(item, recordToPool: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Payment of ${item.title} recorded to Pool Account!'),
                  ),
                );
              }
            },
            child: const Text('Record & Pay'),
          ),
        ],
      ),
    );
  }

  // ==================== ADD / EDIT REMINDER DIALOG ====================
  void _showAddEditReminderDialog(BuildContext context,
      {ReminderModel? reminder}) {
    final isEdit = reminder != null;
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(text: reminder?.title ?? '');
    final amountController =
        TextEditingController(text: reminder?.amount.toString() ?? '');
    final notesController = TextEditingController(text: reminder?.notes ?? '');

    DateTime selectedDate = reminder?.dueDate ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String selectedCategory = reminder?.category ?? 'Utility Bill';
    String selectedFreq = reminder?.frequency ?? 'monthly';
    int? selectedAccountId = reminder?.accountId;

    final categories = [
      'Utility Bill',
      'Credit Card Bill',
      'Rent',
      'Loan EMI',
      'Chit Fund Installment',
      'Insurance Premium',
      'Investment / SIP',
      'Subscription',
      'Others',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final finance = context.read<FinanceProvider>();
          final dateFormat = DateFormat('dd MMM yyyy');

          return AlertDialog(
            title: Text(isEdit ? 'Edit Payment Reminder' : 'Add Payment Reminder'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Reminder Title',
                        hintText: 'e.g., Electricity, SBI Credit Card, House Rent',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter reminder title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Amount
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount Due',
                        prefixText: '${finance.settings.currencySymbol} ',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        if (double.tryParse(val) == null) {
                          return 'Enter valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Category
                    DropdownButtonFormField<String>(
                      value: categories.contains(selectedCategory)
                          ? selectedCategory
                          : 'Others',
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Frequency
                    DropdownButtonFormField<String>(
                      value: selectedFreq,
                      decoration: const InputDecoration(
                        labelText: 'Repeat Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'one_time', child: Text('One-Time (No Repeat)')),
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(
                            value: 'quarterly', child: Text('Quarterly')),
                        DropdownMenuItem(
                            value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedFreq = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Due Date & Time
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: Text(dateFormat.format(selectedDate),
                                style: const TextStyle(fontSize: 11)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(selectedTime.format(ctx),
                                style: const TextStyle(fontSize: 11)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setDialogState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Linked Account
                    DropdownButtonFormField<int?>(
                      value: selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Linked Account (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No Specific Account'),
                        ),
                        ...finance.accounts.map((acc) {
                          return DropdownMenuItem<int?>(
                            value: acc.id,
                            child: Text(acc.name),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedAccountId = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Remarks (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
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
                    final combinedDue = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final rem = ReminderModel(
                      id: reminder?.id,
                      title: titleController.text.trim(),
                      amount: double.parse(amountController.text),
                      dueDate: combinedDue,
                      category: selectedCategory,
                      frequency: selectedFreq,
                      accountId: selectedAccountId,
                      notes: notesController.text.trim(),
                      isPaid: reminder?.isPaid ?? false,
                      paidDate: reminder?.paidDate,
                    );

                    Navigator.pop(ctx);
                    if (isEdit) {
                      await finance.updateReminder(rem);
                    } else {
                      await finance.addReminder(rem);
                    }
                  }
                },
                child: Text(isEdit ? 'Save Changes' : 'Add Reminder'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== CONFIRM DELETE REMINDER ====================
  void _confirmDeleteReminder(BuildContext context, int reminderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: const Text('Are you sure you want to delete this payment reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.debitRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<FinanceProvider>().deleteReminder(reminderId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
