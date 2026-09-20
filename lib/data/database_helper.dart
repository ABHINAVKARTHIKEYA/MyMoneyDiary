import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../models/chit_details.dart';
import '../models/transaction_model.dart';
import '../models/app_settings.dart';
import '../services/interest_calculator.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('my_money_diary.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Accounts table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        principal_balance REAL NOT NULL DEFAULT 0.0,
        accrued_interest REAL NOT NULL DEFAULT 0.0,
        interest_rate REAL NOT NULL DEFAULT 0.0,
        interest_rate_type TEXT NOT NULL DEFAULT 'per_month',
        is_compound INTEGER NOT NULL DEFAULT 0,
        accrual_mode TEXT NOT NULL DEFAULT 'daily',
        allocation_rule TEXT NOT NULL DEFAULT 'interest_first',
        last_interest_date TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        to_account_id INTEGER,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        principal_portion REAL NOT NULL DEFAULT 0.0,
        interest_portion REAL NOT NULL DEFAULT 0.0,
        category TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        is_auto_interest INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (to_account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    // 3. Chit details table
    await db.execute('''
      CREATE TABLE chit_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL UNIQUE,
        total_value REAL NOT NULL,
        duration_months INTEGER NOT NULL,
        nominal_installment REAL NOT NULL,
        current_month INTEGER NOT NULL DEFAULT 0,
        is_lifted INTEGER NOT NULL DEFAULT 0,
        lifted_month INTEGER,
        prize_money_received REAL,
        bid_discount REAL,
        start_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // 4. Settings table
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        currency_symbol TEXT NOT NULL DEFAULT '₹',
        is_biometric_enabled INTEGER NOT NULL DEFAULT 0,
        is_pin_enabled INTEGER NOT NULL DEFAULT 0,
        pin_code TEXT,
        default_allocation_rule TEXT NOT NULL DEFAULT 'interest_first',
        theme_mode TEXT NOT NULL DEFAULT 'emerald_light'
      )
    ''');

    // Insert default settings
    await db.insert('settings', {
      'id': 1,
      'currency_symbol': '₹',
      'is_biometric_enabled': 0,
      'is_pin_enabled': 0,
      'pin_code': null,
      'default_allocation_rule': 'interest_first',
      'theme_mode': 'emerald_light',
    });

    // Seed default accounts
    await _seedDefaultAccounts(db);
  }

  Future<void> _seedDefaultAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();

    final defaultAccounts = [
      {
        'name': 'Pool Account (Main Fund)',
        'type': 'pool',
        'icon': 'account_balance',
        'color': 0xFF0F3E33,
        'balance': 0.0,
        'principal_balance': 0.0,
        'accrued_interest': 0.0,
        'interest_rate': 0.0,
        'interest_rate_type': 'per_month',
        'is_compound': 0,
        'accrual_mode': 'daily',
        'allocation_rule': 'interest_first',
        'last_interest_date': null,
        'is_archived': 0,
        'created_at': now,
      },
      {
        'name': 'Temporary Adjustment Account',
        'type': 'temporary_adjustment',
        'icon': 'swap_horiz',
        'color': 0xFFB37400,
        'balance': 0.0,
        'principal_balance': 0.0,
        'accrued_interest': 0.0,
        'interest_rate': 0.0,
        'interest_rate_type': 'per_month',
        'is_compound': 0,
        'accrual_mode': 'daily',
        'allocation_rule': 'interest_first',
        'last_interest_date': null,
        'is_archived': 0,
        'created_at': now,
      },
      {
        'name': 'Maintenance Account',
        'type': 'maintenance',
        'icon': 'build_circle',
        'color': 0xFF2E7D32,
        'balance': 0.0,
        'principal_balance': 0.0,
        'accrued_interest': 0.0,
        'interest_rate': 0.0,
        'interest_rate_type': 'per_month',
        'is_compound': 0,
        'accrual_mode': 'daily',
        'allocation_rule': 'interest_first',
        'last_interest_date': null,
        'is_archived': 0,
        'created_at': now,
      },
      {
        'name': 'Miscellaneous Account',
        'type': 'miscellaneous',
        'icon': 'category',
        'color': 0xFF546E7A,
        'balance': 0.0,
        'principal_balance': 0.0,
        'accrued_interest': 0.0,
        'interest_rate': 0.0,
        'interest_rate_type': 'per_month',
        'is_compound': 0,
        'accrual_mode': 'daily',
        'allocation_rule': 'interest_first',
        'last_interest_date': null,
        'is_archived': 0,
        'created_at': now,
      },
    ];

    for (final acc in defaultAccounts) {
      await db.insert('accounts', acc);
    }
  }

  // ==================== ACCOUNTS ====================

  Future<int> insertAccount(Account account) async {
    final db = await instance.database;
    return await db.insert('accounts', account.toMap());
  }

  Future<List<Account>> getAccounts({bool includeArchived = false}) async {
    final db = await instance.database;
    final whereClause = includeArchived ? null : 'is_archived = 0';
    final result = await db.query(
      'accounts',
      where: whereClause,
      orderBy: 'created_at ASC',
    );
    return result.map((map) => Account.fromMap(map)).toList();
  }

  Future<Account?> getAccountById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Account.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateAccount(Account account) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await instance.database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== TRANSACTIONS ====================

  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. Insert transaction
      final txId = await txn.insert('transactions', tx.toMap());

      // 2. Update Source Account
      final srcAccountMaps = await txn.query('accounts',
          where: 'id = ?', whereArgs: [tx.accountId]);
      if (srcAccountMaps.isNotEmpty) {
        final srcAccount = Account.fromMap(srcAccountMaps.first);
        double newBalance = srcAccount.balance;
        double newPrincipal = srcAccount.principalBalance;
        double newInterest = srcAccount.accruedInterest;

        if (tx.type == TransactionType.debit) {
          newBalance -= tx.amount;
          if (srcAccount.type == AccountType.lending) {
            // Lending money out increases principal owed to me
            newPrincipal += tx.amount;
          } else if (srcAccount.type == AccountType.debt) {
            // Repaying my debt reduces debt
            newPrincipal -= tx.principalPortion;
            newInterest -= tx.interestPortion;
          }
        } else if (tx.type == TransactionType.credit) {
          newBalance += tx.amount;
          if (srcAccount.type == AccountType.debt) {
            // Borrowing more increases debt principal
            newPrincipal += tx.amount;
          } else if (srcAccount.type == AccountType.lending) {
            // Borrower paying back reduces lending
            newPrincipal -= tx.principalPortion;
            newInterest -= tx.interestPortion;
          }
        } else if (tx.type == TransactionType.transfer) {
          // Debit from source
          newBalance -= tx.amount;
        }

        await txn.update(
          'accounts',
          srcAccount
              .copyWith(
                balance: newBalance,
                principalBalance: newPrincipal.clamp(0.0, double.infinity),
                accruedInterest: newInterest.clamp(0.0, double.infinity),
              )
              .toMap(),
          where: 'id = ?',
          whereArgs: [srcAccount.id],
        );
      }

      // 3. If Transfer, Update Destination Account
      if (tx.type == TransactionType.transfer && tx.toAccountId != null) {
        final destAccountMaps = await txn.query('accounts',
            where: 'id = ?', whereArgs: [tx.toAccountId]);
        if (destAccountMaps.isNotEmpty) {
          final destAccount = Account.fromMap(destAccountMaps.first);
          final newDestBalance = destAccount.balance + tx.amount;
          await txn.update(
            'accounts',
            destAccount.copyWith(balance: newDestBalance).toMap(),
            where: 'id = ?',
            whereArgs: [destAccount.id],
          );
        }
      }

      return txId;
    });
  }

  Future<List<TransactionModel>> getTransactionsByAccount(int accountId) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'account_id = ? OR to_account_id = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC, id DESC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getAllTransactions({int limit = 50}) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== CHIT DETAILS ====================

  Future<int> insertChitDetails(ChitDetails details) async {
    final db = await instance.database;
    return await db.insert('chit_details', details.toMap());
  }

  Future<ChitDetails?> getChitDetailsByAccountId(int accountId) async {
    final db = await instance.database;
    final result = await db.query(
      'chit_details',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    if (result.isNotEmpty) {
      return ChitDetails.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateChitDetails(ChitDetails details) async {
    final db = await instance.database;
    return await db.update(
      'chit_details',
      details.toMap(),
      where: 'account_id = ?',
      whereArgs: [details.accountId],
    );
  }

  // ==================== SETTINGS ====================

  Future<AppSettings> getSettings() async {
    final db = await instance.database;
    final result = await db.query('settings', where: 'id = 1');
    if (result.isNotEmpty) {
      return AppSettings.fromMap(result.first);
    }
    return AppSettings();
  }

  Future<int> updateSettings(AppSettings settings) async {
    final db = await instance.database;
    return await db.update(
      'settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }

  // ==================== INTEREST ENGINE UPDATES ====================

  /// Checks and accrues interest for all active debt & lending accounts
  Future<void> updateAccruedInterests() async {
    final db = await instance.database;
    final accounts = await getAccounts();
    final now = DateTime.now();

    for (final acc in accounts) {
      if (!acc.isInterestBearing || acc.principalBalance <= 0 || acc.interestRate <= 0) {
        continue;
      }

      final lastDate = acc.lastInterestDate ?? acc.createdAt;
      final daysDiff = now.difference(lastDate).inDays;

      if (daysDiff <= 0) continue;

      if (acc.accrualMode == 'daily') {
        final addedInterest = InterestCalculator.calculateAccruedInterest(
          principal: acc.principalBalance,
          rate: acc.interestRate,
          rateType: acc.interestRateType,
          isCompound: acc.isCompound,
          fromDate: lastDate,
          toDate: now,
        );

        final updatedAccount = acc.copyWith(
          accruedInterest: acc.accruedInterest + addedInterest,
          lastInterestDate: now,
        );
        await updateAccount(updatedAccount);
      } else if (acc.accrualMode == 'monthly' && daysDiff >= 30) {
        // Month has elapsed - calculate and post monthly interest
        final monthlyInterest = InterestCalculator.calculateMonthlyInterestAmount(
          principal: acc.principalBalance,
          rate: acc.interestRate,
          rateType: acc.interestRateType,
        );

        final updatedAccount = acc.copyWith(
          accruedInterest: acc.accruedInterest + monthlyInterest,
          lastInterestDate: now,
        );
        await updateAccount(updatedAccount);

        // Record automated transaction
        await insertTransaction(
          TransactionModel(
            accountId: acc.id!,
            type: acc.type == AccountType.debt ? TransactionType.credit : TransactionType.debit,
            amount: monthlyInterest,
            interestPortion: monthlyInterest,
            category: 'Interest Accrual',
            note: 'Automated Monthly Interest (${acc.interestRate}% ${acc.interestRateType})',
            date: now,
            isAutoInterest: true,
          ),
        );
      }
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
