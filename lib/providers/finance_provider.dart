import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import '../models/account.dart';
import '../models/chit_details.dart';
import '../models/transaction_model.dart';
import '../models/app_settings.dart';

class FinanceProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Account> _accounts = [];
  List<TransactionModel> _recentTransactions = [];
  AppSettings _settings = AppSettings();
  bool _isLoading = true;

  List<Account> get accounts => _accounts;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  // Filtered Accounts
  List<Account> get poolAccounts =>
      _accounts.where((a) => a.type == AccountType.pool).toList();
  List<Account> get debtAccounts =>
      _accounts.where((a) => a.type == AccountType.debt).toList();
  List<Account> get lendingAccounts =>
      _accounts.where((a) => a.type == AccountType.lending).toList();
  List<Account> get chitAccounts =>
      _accounts.where((a) => a.type == AccountType.chit).toList();
  List<Account> get adjustmentAccounts =>
      _accounts.where((a) => a.type == AccountType.temporaryAdjustment).toList();
  List<Account> get maintenanceAccounts =>
      _accounts.where((a) => a.type == AccountType.maintenance).toList();
  List<Account> get miscellaneousAccounts =>
      _accounts.where((a) => a.type == AccountType.miscellaneous).toList();
  List<Account> get customAccounts =>
      _accounts.where((a) => a.type == AccountType.custom).toList();

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

      // 2. Fetch fresh accounts, transactions, settings
      _accounts = await _dbHelper.getAccounts();
      _recentTransactions = await _dbHelper.getAllTransactions(limit: 50);
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

  Future<void> deleteAccount(int id) async {
    await _dbHelper.deleteAccount(id);
    await loadAllData();
  }

  Future<int> addTransaction(TransactionModel tx) async {
    final id = await _dbHelper.insertTransaction(tx);
    await loadAllData();
    return id;
  }

  Future<void> deleteTransaction(int id) async {
    await _dbHelper.deleteTransaction(id);
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
}
