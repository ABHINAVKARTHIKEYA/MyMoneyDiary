import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../models/chit_details.dart';
import '../models/transaction_model.dart';
import '../models/app_settings.dart';
import '../models/reminder_model.dart';
import '../models/transaction_edit_history.dart';
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
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN external_ref_id TEXT;');
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN source TEXT NOT NULL DEFAULT 'manual';");
      } catch (_) {}
      try {
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_external_ref_id ON transactions (external_ref_id);');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      // 1. Transactions new columns
      final txCols = [
        "ALTER TABLE transactions ADD COLUMN payment_mode TEXT NOT NULL DEFAULT 'UPI';",
        "ALTER TABLE transactions ADD COLUMN other_payment_mode_details TEXT;",
        "ALTER TABLE transactions ADD COLUMN receipt_path TEXT;",
        "ALTER TABLE transactions ADD COLUMN debit_account_name TEXT;",
        "ALTER TABLE transactions ADD COLUMN credit_account_name TEXT;",
      ];
      for (final sql in txCols) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }

      // 2. Chit details new columns
      final chitCols = [
        "ALTER TABLE chit_details ADD COLUMN installment_before_lifting REAL;",
        "ALTER TABLE chit_details ADD COLUMN installment_after_lifting REAL;",
        "ALTER TABLE chit_details ADD COLUMN end_date TEXT;",
      ];
      for (final sql in chitCols) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }

      // 3. Create Reminders table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            due_date TEXT NOT NULL,
            frequency TEXT NOT NULL DEFAULT 'monthly',
            account_id INTEGER,
            category TEXT NOT NULL DEFAULT 'Bill',
            notes TEXT,
            is_paid INTEGER NOT NULL DEFAULT 0,
            paid_date TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
          )
        ''');
      } catch (_) {}

      // 4. Create Transaction Edit History table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transaction_edit_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            edited_at TEXT NOT NULL,
            reason TEXT NOT NULL,
            old_amount REAL NOT NULL,
            new_amount REAL NOT NULL,
            old_date TEXT NOT NULL,
            new_date TEXT NOT NULL,
            old_mode TEXT NOT NULL,
            new_mode TEXT NOT NULL,
            old_note TEXT,
            new_note TEXT,
            FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}

      // 5. Seed new required account types if missing
      await _seedNewAccountTypesIfMissing(db);
    }

    if (oldVersion < 4) {
      // 1. Accounts new column: loan_start_date
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN loan_start_date TEXT;');
      } catch (_) {}

      // 2. Transactions new column: linked_tx_id
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN linked_tx_id INTEGER;');
      } catch (_) {}

      // 3. Seed Govt Account if missing
      await _seedGovtAccountIfMissing(db);
    }

    if (oldVersion < 5) {
      // 1. Accounts phone_number, is_closed, closed_at, last_interest_paid_date
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN phone_number TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN is_closed INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN closed_at TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN last_interest_paid_date TEXT;');
      } catch (_) {}
    }
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
        loan_start_date TEXT,
        phone_number TEXT,
        is_closed INTEGER NOT NULL DEFAULT 0,
        closed_at TEXT,
        last_interest_paid_date TEXT,
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
        external_ref_id TEXT UNIQUE,
        source TEXT NOT NULL DEFAULT 'manual',
        payment_mode TEXT NOT NULL DEFAULT 'UPI',
        other_payment_mode_details TEXT,
        receipt_path TEXT,
        debit_account_name TEXT,
        credit_account_name TEXT,
        linked_tx_id INTEGER,
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
        installment_before_lifting REAL,
        installment_after_lifting REAL,
        current_month INTEGER NOT NULL DEFAULT 0,
        is_lifted INTEGER NOT NULL DEFAULT 0,
        lifted_month INTEGER,
        prize_money_received REAL,
        bid_discount REAL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // 4. Reminders table
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        due_date TEXT NOT NULL,
        frequency TEXT NOT NULL DEFAULT 'monthly',
        account_id INTEGER,
        category TEXT NOT NULL DEFAULT 'Bill',
        notes TEXT,
        is_paid INTEGER NOT NULL DEFAULT 0,
        paid_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    // 5. Transaction Edit History table
    await db.execute('''
      CREATE TABLE transaction_edit_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        edited_at TEXT NOT NULL,
        reason TEXT NOT NULL,
        old_amount REAL NOT NULL,
        new_amount REAL NOT NULL,
        old_date TEXT NOT NULL,
        new_date TEXT NOT NULL,
        old_mode TEXT NOT NULL,
        new_mode TEXT NOT NULL,
        old_note TEXT,
        new_note TEXT,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // 6. Settings table
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
        'name': 'Pool Account (Cash in Hand)',
        'type': 'pool',
        'icon': 'account_balance_wallet',
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
        'name': 'Salary Account',
        'type': 'salary',
        'icon': 'work',
        'color': 0xFF1E88E5,
        'balance': 0.0,
        'principal_balance': 0.0,
        'accrued_interest': 0.0,
        'interest_rate': 0.0,
        'interest_rate_type': 'per_month',
        'is_compound': 0,
        'accrual_mode': 'daily',
        'allocation_rule': 'interest_first',
        'last_interest_date': null,
        'loan_start_date': null,
        'is_archived': 0,
        'created_at': now,
      },
      {
        'name': 'Govt Account',
        'type': 'custom',
        'icon': 'account_balance',
        'color': 0xFF37474F,
        'balance': 0.0,
        'principal_balance': 0.0,
        'accrued_interest': 0.0,
        'interest_rate': 0.0,
        'interest_rate_type': 'per_month',
        'is_compound': 0,
        'accrual_mode': 'daily',
        'allocation_rule': 'interest_first',
        'last_interest_date': null,
        'loan_start_date': null,
        'is_archived': 0,
        'created_at': now,
      },
      {
        'name': 'Primary Bank Account',
        'type': 'bank',
        'icon': 'account_balance',
        'color': 0xFF0288D1,
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
        'name': 'Credit Card Account',
        'type': 'credit_card',
        'icon': 'credit_card',
        'color': 0xFF7B1FA2,
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
        'name': 'Insurance Account',
        'type': 'insurance',
        'icon': 'health_and_safety',
        'color': 0xFF00897B,
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
        'name': 'Demats / Stock Account',
        'type': 'demat',
        'icon': 'trending_up',
        'color': 0xFFE65100,
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
      // 8 Others Accounts (customizable and editable anytime)
      for (int i = 1; i <= 8; i++) ...[
        {
          'name': 'Others $i',
          'type': 'other_$i',
          'icon': i == 1
              ? 'folder_special'
              : i == 2
                  ? 'stars'
                  : i == 3
                      ? 'pie_chart'
                      : i == 4
                          ? 'inventory_2'
                          : i == 5
                              ? 'savings'
                              : i == 6
                                  ? 'receipt_long'
                                  : i == 7
                                      ? 'account_box'
                                      : 'more_horiz',
          'color': 0xFF455A64,
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
        }
      ]
    ];

    for (final acc in defaultAccounts) {
      await db.insert('accounts', acc);
    }
  }

  Future<void> _seedNewAccountTypesIfMissing(Database db) async {
    final now = DateTime.now().toIso8601String();
    final existingAccounts = await db.query('accounts', columns: ['type']);
    final existingTypes = existingAccounts.map((e) => e['type'] as String).toSet();

    final newAccountsToAdd = [
      if (!existingTypes.contains('salary'))
        {
          'name': 'Salary Account',
          'type': 'salary',
          'icon': 'work',
          'color': 0xFF1E88E5,
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
      if (!existingTypes.contains('bank'))
        {
          'name': 'Bank Accounts',
          'type': 'bank',
          'icon': 'account_balance',
          'color': 0xFF0288D1,
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
      if (!existingTypes.contains('credit_card'))
        {
          'name': 'Credit Cards',
          'type': 'credit_card',
          'icon': 'credit_card',
          'color': 0xFF7B1FA2,
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
      if (!existingTypes.contains('insurance'))
        {
          'name': 'Insurance',
          'type': 'insurance',
          'icon': 'health_and_safety',
          'color': 0xFF00897B,
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
      if (!existingTypes.contains('demat'))
        {
          'name': 'Demats / Stocks',
          'type': 'demat',
          'icon': 'trending_up',
          'color': 0xFFE65100,
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
      for (int i = 1; i <= 8; i++) ...[
        if (!existingTypes.contains('other_$i'))
          {
            'name': 'Others $i',
            'type': 'other_$i',
            'icon': i == 1 ? 'folder_special' : 'stars',
            'color': 0xFF455A64,
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
          }
      ]
    ];

    for (final acc in newAccountsToAdd) {
      await db.insert('accounts', acc);
    }
  }

  Future<void> _seedGovtAccountIfMissing(Database db) async {
    final now = DateTime.now().toIso8601String();
    final existing = await db.query('accounts', where: 'name = ?', whereArgs: ['Govt Account'], limit: 1);
    if (existing.isEmpty) {
      await db.insert('accounts', {
        'name': 'Govt Account',
        'type': 'custom',
        'icon': 'account_balance',
        'color': 0xFF37474F,
        'balance': 0.0,
        'principal_balance': 0.0,
        'accrued_interest': 0.0,
        'interest_rate': 0.0,
        'interest_rate_type': 'per_month',
        'is_compound': 0,
        'accrual_mode': 'daily',
        'allocation_rule': 'interest_first',
        'last_interest_date': null,
        'loan_start_date': null,
        'is_archived': 0,
        'created_at': now,
      });
    }
  }

  // ==================== ACCOUNTS ====================

  Future<int> insertAccount(Account account) async {
    final db = await instance.database;
    var accountToInsert = account;

    // If debt or lending account has a historical loanStartDate with interest rate > 0,
    // compute accrued interest till todate immediately upon creation
    if (account.isInterestBearing && account.loanStartDate != null && account.interestRate > 0) {
      final now = DateTime.now();
      final days = now.difference(account.loanStartDate!).inDays;
      if (days > 0) {
        double accrued = 0.0;
        if (account.accrualMode == 'daily') {
          accrued = InterestCalculator.calculateAccruedInterest(
            principal: account.principalBalance,
            rate: account.interestRate,
            rateType: account.interestRateType,
            isCompound: account.isCompound,
            fromDate: account.loanStartDate!,
            toDate: now,
          );
        } else if (account.accrualMode == 'monthly') {
          final months = days ~/ 30;
          for (int i = 0; i < months; i++) {
            final base = account.isCompound ? (account.principalBalance + accrued) : account.principalBalance;
            accrued += InterestCalculator.calculateMonthlyInterestAmount(
              principal: base,
              rate: account.interestRate,
              rateType: account.interestRateType,
            );
          }
        }
        if (accrued > 0) {
          accountToInsert = account.copyWith(
            accruedInterest: accrued,
            lastInterestDate: now,
          );
        }
      }
    }

    return await db.insert('accounts', accountToInsert.toMap());
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

  Future<void> closeAccount(int accountId) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'accounts',
      {
        'is_closed': 1,
        'closed_at': now,
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> reopenAccount(int accountId) async {
    final db = await instance.database;
    await db.update(
      'accounts',
      {
        'is_closed': 0,
        'closed_at': null,
      },
      where: 'id = ?',
      whereArgs: [accountId],
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

  Future<bool> transactionExistsByExternalRef(String externalRefId) async {
    if (externalRefId.trim().isEmpty) return false;
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      columns: ['id'],
      where: 'external_ref_id = ?',
      whereArgs: [externalRefId.trim()],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return TransactionModel.fromMap(result.first);
    }
    return null;
  }

  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 0. Strict duplicate check if externalRefId is present
      if (tx.externalRefId != null && tx.externalRefId!.trim().isNotEmpty) {
        final existing = await txn.query(
          'transactions',
          columns: ['id'],
          where: 'external_ref_id = ?',
          whereArgs: [tx.externalRefId!.trim()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return -1; // Duplicate detected - skip
        }
      }

      // Populate account names if missing
      var txToInsert = tx;
      if (tx.debitAccountName == null || tx.creditAccountName == null) {
        final src = await txn.query('accounts', columns: ['name'], where: 'id = ?', whereArgs: [tx.accountId]);
        String srcName = src.isNotEmpty ? (src.first['name'] as String) : 'Account';
        String? destName;
        if (tx.toAccountId != null) {
          final dest = await txn.query('accounts', columns: ['name'], where: 'id = ?', whereArgs: [tx.toAccountId]);
          if (dest.isNotEmpty) destName = dest.first['name'] as String;
        }

        txToInsert = tx.copyWith(
          debitAccountName: tx.type == TransactionType.credit ? destName : srcName,
          creditAccountName: tx.type == TransactionType.credit ? srcName : destName,
        );
      }

      // 1. Insert transaction
      final txId = await txn.insert('transactions', txToInsert.toMap());
      final insertedTx = txToInsert.copyWith(id: txId);

      // 2. Apply balance effects to accounts
      await _applyTransactionEffect(insertedTx, txn, isReversal: false);

      // 3. Reflect in Pool Account if parent transaction
      if (insertedTx.linkedTxId == null) {
        await _reflectInPool(insertedTx, txn);
      }

      return txId;
    });
  }

  Future<bool> updateTransaction(TransactionModel newTx, {required String reason}) async {
    if (newTx.id == null) return false;
    final db = await instance.database;

    return await db.transaction((txn) async {
      // 1. Fetch old transaction
      final oldTxMaps = await txn.query('transactions', where: 'id = ?', whereArgs: [newTx.id]);
      if (oldTxMaps.isEmpty) return false;
      final oldTx = TransactionModel.fromMap(oldTxMaps.first);

      // 1b. Revert and delete any previously linked pool reflections
      final linkedTxMaps = await txn.query('transactions', where: 'linked_tx_id = ?', whereArgs: [newTx.id]);
      for (final lMap in linkedTxMaps) {
        final lTx = TransactionModel.fromMap(lMap);
        await _applyTransactionEffect(lTx, txn, isReversal: true);
        await txn.delete('transactions', where: 'id = ?', whereArgs: [lTx.id]);
      }

      // 2. Revert previous effect from accounts
      await _applyTransactionEffect(oldTx, txn, isReversal: true);

      // 3. Apply new effect to accounts
      await _applyTransactionEffect(newTx, txn, isReversal: false);

      // 4. Update transactions row
      await txn.update(
        'transactions',
        newTx.toMap(),
        where: 'id = ?',
        whereArgs: [newTx.id],
      );

      // 4b. Re-reflect in Pool Account if parent transaction
      if (newTx.linkedTxId == null) {
        await _reflectInPool(newTx, txn);
      }

      // 5. Insert edit history audit record
      final history = TransactionEditHistory(
        transactionId: newTx.id!,
        editedAt: DateTime.now(),
        reason: reason.trim().isEmpty ? 'Transaction edited' : reason.trim(),
        oldAmount: oldTx.amount,
        newAmount: newTx.amount,
        oldDate: oldTx.date,
        newDate: newTx.date,
        oldMode: oldTx.paymentMode,
        newMode: newTx.paymentMode,
        oldNote: oldTx.note,
        newNote: newTx.note,
      );
      await txn.insert('transaction_edit_history', history.toMap());

      return true;
    });
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. Revert and delete all linked transactions first (e.g. pool reflections)
      final linkedTxMaps = await txn.query('transactions', where: 'linked_tx_id = ?', whereArgs: [id]);
      for (final lMap in linkedTxMaps) {
        final lTx = TransactionModel.fromMap(lMap);
        await _applyTransactionEffect(lTx, txn, isReversal: true);
        await txn.delete('transactions', where: 'id = ?', whereArgs: [lTx.id]);
      }

      final txMaps = await txn.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (txMaps.isNotEmpty) {
        final oldTx = TransactionModel.fromMap(txMaps.first);
        // Revert effect on accounts
        await _applyTransactionEffect(oldTx, txn, isReversal: true);
      }

      return await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> _reflectInPool(TransactionModel tx, DatabaseExecutor txn) async {
    // 1. Find the designated Pool Account
    final poolMaps = await txn.query('accounts', where: 'type = ?', whereArgs: ['pool'], limit: 1);
    if (poolMaps.isEmpty) return;
    final poolAccount = Account.fromMap(poolMaps.first);
    final poolId = poolAccount.id!;

    // 2. If the transaction was already created directly in the Pool account, do not duplicate
    if (tx.accountId == poolId) return;

    // 3. For transfers involving Pool account:
    // Transfer logic already adjusts Pool balance in _applyTransactionEffect.
    if (tx.type == TransactionType.transfer) {
      if (tx.accountId == poolId || tx.toAccountId == poolId) {
        return; // Already accounted for in pool balance
      }
      return; // Internal transfer between two non-pool accounts does not change net pool cash
    }

    // 4. Fetch Source Account
    final srcMaps = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.accountId]);
    if (srcMaps.isEmpty) return;
    final srcAccount = Account.fromMap(srcMaps.first);

    // 5. Account-type specific reflection rules
    if (srcAccount.type == AccountType.creditCard) {
      // RULE: Credit Card Expenditure
      // Reflected in Pool as a credit of the same amount (credit line drawn)
      // and then a debit of the same towards the expenditure made. Net pool balance impact = 0.
      if (tx.type == TransactionType.debit) {
        // Entry A: Credit in Pool (Inflow from Credit Card)
        final poolCredit = TransactionModel(
          accountId: poolId,
          type: TransactionType.credit,
          amount: tx.amount,
          category: tx.category,
          note: 'Credit line drawn via ${srcAccount.name}${tx.note.isNotEmpty ? ": " + tx.note : ""}',
          date: tx.date,
          paymentMode: tx.paymentMode,
          otherPaymentModeDetails: tx.otherPaymentModeDetails,
          receiptPath: tx.receiptPath,
          debitAccountName: srcAccount.name,
          creditAccountName: poolAccount.name,
          linkedTxId: tx.id,
        );
        final cId = await txn.insert('transactions', poolCredit.toMap());
        await _applyTransactionEffect(poolCredit.copyWith(id: cId), txn, isReversal: false);

        // Entry B: Debit in Pool (Outflow towards expense)
        final poolDebit = TransactionModel(
          accountId: poolId,
          type: TransactionType.debit,
          amount: tx.amount,
          category: tx.category,
          note: 'Spent via ${srcAccount.name}${tx.note.isNotEmpty ? ": " + tx.note : ""}',
          date: tx.date,
          paymentMode: tx.paymentMode,
          otherPaymentModeDetails: tx.otherPaymentModeDetails,
          receiptPath: tx.receiptPath,
          debitAccountName: poolAccount.name,
          creditAccountName: tx.creditAccountName ?? tx.category,
          linkedTxId: tx.id,
        );
        final dId = await txn.insert('transactions', poolDebit.toMap());
        await _applyTransactionEffect(poolDebit.copyWith(id: dId), txn, isReversal: false);
      } else if (tx.type == TransactionType.credit) {
        // Credit card bill payment / refund
        final poolCredit = TransactionModel(
          accountId: poolId,
          type: TransactionType.credit,
          amount: tx.amount,
          category: tx.category,
          note: 'Refund / Credit to ${srcAccount.name}${tx.note.isNotEmpty ? ": " + tx.note : ""}',
          date: tx.date,
          paymentMode: tx.paymentMode,
          otherPaymentModeDetails: tx.otherPaymentModeDetails,
          receiptPath: tx.receiptPath,
          debitAccountName: tx.debitAccountName ?? srcAccount.name,
          creditAccountName: poolAccount.name,
          linkedTxId: tx.id,
        );
        final pId = await txn.insert('transactions', poolCredit.toMap());
        await _applyTransactionEffect(poolCredit.copyWith(id: pId), txn, isReversal: false);
      }
    } else if (srcAccount.type == AccountType.salary) {
      // RULE: Salary Account
      // - Salary Credit: by default takes receipt from Govt Account, adds to Pool Account as credit (+).
      // - Salary Debit: debited from Salary and debited from Pool Account (-).
      //   No separate credit to Pool needed before debit since it was credited on receipt.
      if (tx.type == TransactionType.credit) {
        final poolSalaryCredit = TransactionModel(
          accountId: poolId,
          type: TransactionType.credit,
          amount: tx.amount,
          category: tx.category,
          note: tx.note.isNotEmpty ? tx.note : 'Salary Received',
          date: tx.date,
          paymentMode: tx.paymentMode,
          otherPaymentModeDetails: tx.otherPaymentModeDetails,
          receiptPath: tx.receiptPath,
          debitAccountName: tx.debitAccountName ?? 'Govt Account',
          creditAccountName: poolAccount.name,
          linkedTxId: tx.id,
        );
        final sId = await txn.insert('transactions', poolSalaryCredit.toMap());
        await _applyTransactionEffect(poolSalaryCredit.copyWith(id: sId), txn, isReversal: false);
      } else if (tx.type == TransactionType.debit) {
        final poolSalaryDebit = TransactionModel(
          accountId: poolId,
          type: TransactionType.debit,
          amount: tx.amount,
          category: tx.category,
          note: tx.note,
          date: tx.date,
          paymentMode: tx.paymentMode,
          otherPaymentModeDetails: tx.otherPaymentModeDetails,
          receiptPath: tx.receiptPath,
          debitAccountName: poolAccount.name,
          creditAccountName: tx.creditAccountName ?? tx.category,
          linkedTxId: tx.id,
        );
        final sId = await txn.insert('transactions', poolSalaryDebit.toMap());
        await _applyTransactionEffect(poolSalaryDebit.copyWith(id: sId), txn, isReversal: false);
      }
    } else {
      // RULE: All other accounts (Bank, Chit, Debt, Lending, Demat, Insurance, Others, Custom)
      // Pool reflects every transaction: Inflows add to Pool, Outflows subtract from Pool.
      if (tx.type == TransactionType.credit) {
        final poolEntry = TransactionModel(
          accountId: poolId,
          type: TransactionType.credit,
          amount: tx.amount,
          category: tx.category,
          note: tx.note,
          date: tx.date,
          paymentMode: tx.paymentMode,
          otherPaymentModeDetails: tx.otherPaymentModeDetails,
          receiptPath: tx.receiptPath,
          debitAccountName: tx.debitAccountName ?? srcAccount.name,
          creditAccountName: poolAccount.name,
          linkedTxId: tx.id,
        );
        final pId = await txn.insert('transactions', poolEntry.toMap());
        await _applyTransactionEffect(poolEntry.copyWith(id: pId), txn, isReversal: false);
      } else if (tx.type == TransactionType.debit) {
        final poolEntry = TransactionModel(
          accountId: poolId,
          type: TransactionType.debit,
          amount: tx.amount,
          category: tx.category,
          note: tx.note,
          date: tx.date,
          paymentMode: tx.paymentMode,
          otherPaymentModeDetails: tx.otherPaymentModeDetails,
          receiptPath: tx.receiptPath,
          debitAccountName: poolAccount.name,
          creditAccountName: tx.creditAccountName ?? srcAccount.name,
          linkedTxId: tx.id,
        );
        final pId = await txn.insert('transactions', poolEntry.toMap());
        await _applyTransactionEffect(poolEntry.copyWith(id: pId), txn, isReversal: false);
      }
    }
  }

  Future<void> _applyTransactionEffect(
    TransactionModel tx,
    DatabaseExecutor txn, {
    required bool isReversal,
  }) async {
    final factor = isReversal ? -1.0 : 1.0;

    // 1. Update Source Account
    final srcMaps = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.accountId]);
    if (srcMaps.isNotEmpty) {
      final srcAccount = Account.fromMap(srcMaps.first);
      double newBalance = srcAccount.balance;
      double newPrincipal = srcAccount.principalBalance;
      double newInterest = srcAccount.accruedInterest;

      if (tx.type == TransactionType.debit) {
        newBalance -= factor * tx.amount;
        if (srcAccount.type == AccountType.lending) {
          // Lending more increases principal receivable
          newPrincipal += factor * tx.amount;
        } else if (srcAccount.type == AccountType.debt) {
          // Repaying debt reduces principal & interest
          newPrincipal -= factor * tx.principalPortion;
          newInterest -= factor * tx.interestPortion;
        }
      } else if (tx.type == TransactionType.credit) {
        newBalance += factor * tx.amount;
        if (srcAccount.type == AccountType.debt) {
          // Borrowing more increases debt principal
          newPrincipal += factor * tx.amount;
        } else if (srcAccount.type == AccountType.lending) {
          // Receiving repayment reduces lending principal & interest
          newPrincipal -= factor * tx.principalPortion;
          newInterest -= factor * tx.interestPortion;
        }
      } else if (tx.type == TransactionType.transfer) {
        // Outflow from source
        newBalance -= factor * tx.amount;
      }

      DateTime? updatedLastInterestPaid = srcAccount.lastInterestPaidDate;
      if (!isReversal && tx.interestPortion > 0) {
        if (updatedLastInterestPaid == null || tx.date.isAfter(updatedLastInterestPaid)) {
          updatedLastInterestPaid = tx.date;
        }
      }

      await txn.update(
        'accounts',
        srcAccount
            .copyWith(
              balance: newBalance,
              principalBalance: newPrincipal.clamp(0.0, double.infinity),
              accruedInterest: newInterest.clamp(0.0, double.infinity),
              lastInterestPaidDate: updatedLastInterestPaid,
            )
            .toMap(),
        where: 'id = ?',
        whereArgs: [srcAccount.id],
      );
    }

    // 2. Update Destination Account (for Transfers)
    if (tx.type == TransactionType.transfer && tx.toAccountId != null) {
      final destMaps = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.toAccountId]);
      if (destMaps.isNotEmpty) {
        final destAccount = Account.fromMap(destMaps.first);
        double newDestBalance = destAccount.balance + (factor * tx.amount);
        double newDestPrincipal = destAccount.principalBalance;
        double newDestInterest = destAccount.accruedInterest;

        if (destAccount.type == AccountType.debt) {
          // Paying debt via transfer
          newDestPrincipal -= factor * tx.principalPortion;
          newDestInterest -= factor * tx.interestPortion;
        } else if (destAccount.type == AccountType.lending) {
          // Lending out via transfer
          newDestPrincipal += factor * tx.amount;
        }

        DateTime? updatedDestLastInterestPaid = destAccount.lastInterestPaidDate;
        if (!isReversal && tx.interestPortion > 0) {
          if (updatedDestLastInterestPaid == null || tx.date.isAfter(updatedDestLastInterestPaid)) {
            updatedDestLastInterestPaid = tx.date;
          }
        }

        await txn.update(
          'accounts',
          destAccount
              .copyWith(
                balance: newDestBalance,
                principalBalance: newDestPrincipal.clamp(0.0, double.infinity),
                accruedInterest: newDestInterest.clamp(0.0, double.infinity),
                lastInterestPaidDate: updatedDestLastInterestPaid,
              )
              .toMap(),
          where: 'id = ?',
          whereArgs: [destAccount.id],
        );
      }
    }
  }

  Future<List<TransactionModel>> getAllTransactions({int limit = 100}) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC',
      limit: limit,
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByAccount(int accountId) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'account_id = ? OR to_account_id = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC, created_at DESC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getFilteredTransactions({
    int? accountId,
    DateTime? fromDate,
    DateTime? toDate,
    String? category,
    String? paymentMode,
    String? typeKey,
  }) async {
    final db = await instance.database;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (accountId != null) {
      whereClauses.add('(account_id = ? OR to_account_id = ?)');
      whereArgs.add(accountId);
      whereArgs.add(accountId);
    }
    if (fromDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(toDate.toIso8601String());
    }
    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (paymentMode != null && paymentMode.isNotEmpty && paymentMode != 'All') {
      whereClauses.add('payment_mode = ?');
      whereArgs.add(paymentMode);
    }
    if (typeKey != null && typeKey.isNotEmpty && typeKey != 'All') {
      whereClauses.add('type = ?');
      whereArgs.add(typeKey.toLowerCase());
    }

    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final result = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date ASC, created_at ASC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionEditHistory>> getEditHistory(int transactionId) async {
    final db = await instance.database;
    final result = await db.query(
      'transaction_edit_history',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'edited_at DESC',
    );
    return result.map((map) => TransactionEditHistory.fromMap(map)).toList();
  }

  // ==================== REMINDERS ====================

  Future<int> insertReminder(ReminderModel reminder) async {
    final db = await instance.database;
    return await db.insert('reminders', reminder.toMap());
  }

  Future<List<ReminderModel>> getReminders() async {
    final db = await instance.database;
    final result = await db.query(
      'reminders',
      orderBy: 'is_paid ASC, due_date ASC',
    );
    return result.map((map) => ReminderModel.fromMap(map)).toList();
  }

  Future<int> updateReminder(ReminderModel reminder) async {
    final db = await instance.database;
    return await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await instance.database;
    return await db.delete(
      'reminders',
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

  // ==================== INTEREST ENGINE ====================

  Future<void> updateAccruedInterests() async {
    final db = await instance.database;
    final now = DateTime.now();

    final accounts = await getAccounts();
    for (final acc in accounts) {
      if (acc.isClosed) continue;
      if (acc.interestRate <= 0.0) continue;
      if (acc.type != AccountType.debt && acc.type != AccountType.lending) continue;

      final lastDate = acc.lastInterestDate ?? acc.createdAt;
      final days = now.difference(lastDate).inDays;

      if (days <= 0) continue;

      double accruedDelta = 0.0;
      if (acc.accrualMode == 'daily') {
        accruedDelta = InterestCalculator.calculateAccruedInterest(
          principal: acc.principalBalance,
          rate: acc.interestRate,
          rateType: acc.interestRateType,
          isCompound: acc.isCompound,
          fromDate: lastDate,
          toDate: now,
        );
      } else if (acc.accrualMode == 'monthly') {
        if (days >= 30) {
          final months = days ~/ 30;
          for (int i = 0; i < months; i++) {
            final base = acc.isCompound ? (acc.principalBalance + acc.accruedInterest + accruedDelta) : acc.principalBalance;
            accruedDelta += InterestCalculator.calculateMonthlyInterestAmount(
              principal: base,
              rate: acc.interestRate,
              rateType: acc.interestRateType,
            );
          }
        }
      }

      if (accruedDelta > 0.0) {
        final updatedAccrued = acc.accruedInterest + accruedDelta;
        await db.update(
          'accounts',
          {
            'accrued_interest': updatedAccrued,
            'last_interest_date': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [acc.id],
        );
      }
    }
  }
}
