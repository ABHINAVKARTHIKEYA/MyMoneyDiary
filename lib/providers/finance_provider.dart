import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../models/journal_entry.dart';
import '../models/audit_log.dart';
import '../models/chit_details.dart';
import '../models/transaction_model.dart';
import '../models/app_settings.dart';
import '../models/reminder_model.dart';
import '../models/transaction_edit_history.dart';
import '../services/auto_tracker_service.dart';

class FinanceProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  FinanceProvider() {
    // Listen for live background detected transactions (SMS or Notification)
    AutoTrackerService.instance.onNewTransactionDetected = () {
      loadAllData();
    };
  }

  List<Account> _accounts = [];
  List<TransactionModel> _recentTransactions = [];
  List<ReminderModel> _reminders = [];
  AppSettings _settings = AppSettings();
  bool _isLoading = true;

  List<Account> get accounts => _accounts;
  List<Account> get activeAccounts =>
      _accounts.where((a) => !a.isClosed && !a.isArchived).toList();
  List<Account> get closedAccounts =>
      _accounts.where((a) => a.isClosed).toList();
  List<TransactionModel> get recentTransactions => _recentTransactions;
  List<ReminderModel> get reminders => _reminders;
  List<ReminderModel> get activeReminders => _reminders.where((r) => !r.isPaid).toList();
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  // Filtered Active Accounts
  List<Account> get poolAccounts =>
      _accounts.where((a) => a.type == AccountType.pool && !a.isClosed).toList();
  List<Account> get salaryAccounts =>
      _accounts.where((a) => a.type == AccountType.salary && !a.isClosed).toList();
  List<Account> get bankAccounts =>
      _accounts.where((a) => a.type == AccountType.bank && !a.isClosed).toList();
  List<Account> get creditCardAccounts =>
      _accounts.where((a) => a.type == AccountType.creditCard && !a.isClosed).toList();
  List<Account> get debtAccounts =>
      _accounts.where((a) => a.type == AccountType.debt && !a.isClosed).toList();
  List<Account> get lendingAccounts =>
      _accounts.where((a) => a.type == AccountType.lending && !a.isClosed).toList();
  List<Account> get chitAccounts =>
      _accounts.where((a) => a.type == AccountType.chit && !a.isClosed).toList();
  List<Account> get insuranceAccounts =>
      _accounts.where((a) => a.type == AccountType.insurance && !a.isClosed).toList();
  List<Account> get dematAccounts =>
      _accounts.where((a) => a.type == AccountType.demat && !a.isClosed).toList();
  List<Account> get adjustmentAccounts =>
      _accounts.where((a) => a.type == AccountType.temporaryAdjustment && !a.isClosed).toList();
  List<Account> get maintenanceAccounts =>
      _accounts.where((a) => a.type == AccountType.maintenance && !a.isClosed).toList();
  List<Account> get miscellaneousAccounts =>
      _accounts.where((a) => a.type == AccountType.miscellaneous && !a.isClosed).toList();
  List<Account> get otherAccounts =>
      _accounts.where((a) => (a.type.key.startsWith('other_') || a.type == AccountType.custom) && !a.isClosed).toList();
  List<Account> get customAccounts =>
      _accounts.where((a) => a.type == AccountType.custom && !a.isClosed).toList();

  // Double-Entry Master Category Getters
  List<Account> get assetAccounts =>
      _accounts.where((a) => a.category == AccountCategory.asset && !a.isArchived).toList();
  List<Account> get liabilityAccounts =>
      _accounts.where((a) => a.category == AccountCategory.liability && !a.isArchived).toList();
  List<Account> get incomeAccounts =>
      _accounts.where((a) => a.category == AccountCategory.income && !a.isArchived).toList();
  List<Account> get expenseAccounts =>
      _accounts.where((a) => a.category == AccountCategory.expense && !a.isArchived).toList();
  List<Account> get equityAccounts =>
      _accounts.where((a) => a.category == AccountCategory.equity && !a.isArchived).toList();
  List<Account> get archivedAccounts =>
      _accounts.where((a) => a.isArchived).toList();

  // Aggregate Metrics
  double get totalAvailablePool =>
      poolAccounts.fold(0.0, (sum, a) => sum + a.balance);

  double get totalLentPrincipal =>
      lendingAccounts.fold(0.0, (sum, a) => sum + a.principalBalance);

  double get totalLentAccruedInterest =>
      lendingAccounts.fold(0.0, (sum, a) => sum + a.accruedInterest);

  double get totalLentTotal => totalLentPrincipal + totalLentAccruedInterest;

  double get totalBorrowedPrincipal =>
      debtAccounts.fold(0.0, (sum, a) => sum + a.principalBalance);

  double get totalBorrowedAccruedInterest =>
      debtAccounts.fold(0.0, (sum, a) => sum + a.accruedInterest);

  double get totalBorrowedTotal =>
      totalBorrowedPrincipal + totalBorrowedAccruedInterest;

  double get totalPendingAdjustment =>
      adjustmentAccounts.fold(0.0, (sum, a) => sum + a.balance.abs());

  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Update accrued interests dynamically
      await _dbHelper.updateAccruedInterests();

      // 2. Fetch fresh accounts, transactions, reminders, settings
      _accounts = await _dbHelper.getAccounts();
      _recentTransactions = await _dbHelper.getAllTransactions(limit: 50);
      _reminders = await _dbHelper.getReminders();
      _settings = await _dbHelper.getSettings();
    } catch (e) {
      debugPrint('Error loading finance data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> addAccount(Account account, {ChitDetails? chitDetails}) async {
    final id = await _dbHelper.insertAccount(account);
    if (account.type == AccountType.chit && chitDetails != null) {
      await _dbHelper.insertChitDetails(chitDetails.copyWith(accountId: id));
    }
    await loadAllData();
    return id;
  }

  Future<void> updateAccount(Account account) async {
    await _dbHelper.updateAccount(account);
    await loadAllData();
  }

  Future<bool> canDeleteAccount(int id) async {
    return await _dbHelper.canDeleteAccount(id);
  }

  Future<void> deleteAccount(int id, {String? reason}) async {
    await _dbHelper.deleteAccount(id, reason: reason);
    await loadAllData();
  }

  Future<void> archiveAccount(int accountId, bool archive, {String? reason}) async {
    await _dbHelper.archiveAccount(accountId, archive, reason: reason);
    await loadAllData();
  }

  Future<void> renameAccount(int accountId, String newName, {String? reason}) async {
    await _dbHelper.renameAccount(accountId, newName, reason: reason);
    await loadAllData();
  }

  Future<void> closeAccount(int accountId) async {
    await _dbHelper.closeAccount(accountId);
    await loadAllData();
  }

  Future<void> reopenAccount(int accountId) async {
    await _dbHelper.reopenAccount(accountId);
    await loadAllData();
  }

  Future<int> addTransaction(TransactionModel tx) async {
    final id = await _dbHelper.insertTransaction(tx);
    await loadAllData();
    return id;
  }

  Future<bool> updateTransaction(TransactionModel tx, {required String reason}) async {
    final success = await _dbHelper.updateTransaction(tx, reason: reason);
    if (success) {
      await loadAllData();
    }
    return success;
  }

  Future<void> deleteTransaction(int id) async {
    await _dbHelper.deleteTransaction(id);
    await loadAllData();
  }

  Future<List<TransactionEditHistory>> getTransactionEditHistory(int transactionId) async {
    return await _dbHelper.getEditHistory(transactionId);
  }

  Future<List<TransactionModel>> getFilteredTransactions({
    int? accountId,
    DateTime? fromDate,
    DateTime? toDate,
    String? category,
    String? paymentMode,
    String? typeKey,
  }) async {
    return await _dbHelper.getFilteredTransactions(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
      category: category,
      paymentMode: paymentMode,
      typeKey: typeKey,
    );
  }

  // ==================== REMINDERS ====================

  Future<int> addReminder(ReminderModel reminder) async {
    final id = await _dbHelper.insertReminder(reminder);
    await loadAllData();
    return id;
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await _dbHelper.updateReminder(reminder);
    await loadAllData();
  }

  Future<void> deleteReminder(int id) async {
    await _dbHelper.deleteReminder(id);
    await loadAllData();
  }

  Future<void> markReminderPaid(ReminderModel reminder, {bool recordToPool = true}) async {
    final now = DateTime.now();
    await _dbHelper.updateReminder(reminder.copyWith(isPaid: true, paidDate: now));

    if (recordToPool) {
      // Find Pool account to record payment
      final pool = poolAccounts.isNotEmpty ? poolAccounts.first : (_accounts.isNotEmpty ? _accounts.first : null);
      if (pool != null && pool.id != null) {
        final tx = TransactionModel(
          accountId: pool.id!,
          type: TransactionType.debit,
          amount: reminder.amount,
          category: reminder.category,
          note: 'Payment Reminder: ${reminder.title}',
          date: now,
          paymentMode: 'UPI',
        );
        await _dbHelper.insertTransaction(tx);
      }
    }

    await loadAllData();
  }

  Future<List<TransactionModel>> getAccountTransactions(int accountId) async {
    return await _dbHelper.getTransactionsByAccount(accountId);
  }

  Future<ChitDetails?> getChitDetails(int accountId) async {
    return await _dbHelper.getChitDetailsByAccountId(accountId);
  }

  Future<void> updateChitDetails(ChitDetails details) async {
    await _dbHelper.updateChitDetails(details);
    await loadAllData();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _dbHelper.updateSettings(settings);
    notifyListeners();
  }

  // ==================== AUTO DETECTION & SYNC ====================

  Future<AutoSyncResult> syncSmsTransactions({int limit = 200}) async {
    // Find Pool Account or first account to record detected transactions
    final targetAccount = poolAccounts.isNotEmpty ? poolAccounts.first : (_accounts.isNotEmpty ? _accounts.first : null);
    if (targetAccount == null || targetAccount.id == null) {
      return AutoSyncResult(
        totalScanned: 0,
        financialFound: 0,
        newAdded: 0,
        duplicatesSkipped: 0,
        newTransactions: [],
      );
    }

    final result = await AutoTrackerService.instance.syncSmsInbox(
      limit: limit,
      defaultAccountId: targetAccount.id!,
    );

    if (result.newAdded > 0) {
      await loadAllData();
    }

    return result;
  }

  Future<bool> hasSmsPermission() => AutoTrackerService.instance.hasSmsPermission();
  Future<bool> requestSmsPermission() => AutoTrackerService.instance.requestSmsPermission();
  Future<bool> isNotificationListenerEnabled() => AutoTrackerService.instance.isNotificationListenerEnabled();
  Future<void> openNotificationListenerSettings() => AutoTrackerService.instance.openNotificationListenerSettings();
}
