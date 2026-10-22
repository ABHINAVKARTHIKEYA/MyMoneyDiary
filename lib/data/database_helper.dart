import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../models/journal_entry.dart';
import '../models/audit_log.dart';
import '../models/chit_details.dart';
import '../models/transaction_model.dart';
import '../models/app_settings.dart';
import '../models/reminder_model.dart';
import '../models/transaction_edit_history.dart';
import '../services/interest_calculator.dart';
import '../services/double_entry_engine.dart';

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
      version: 6,
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

    if (oldVersion < 6) {
      // 1. Double-Entry columns on accounts
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN code TEXT;');
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN category TEXT NOT NULL DEFAULT 'asset';");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN sub_category TEXT NOT NULL DEFAULT 'general';");
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0.0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN notes TEXT;');
      } catch (_) {}

      // 2. Create journal_entries table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS journal_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            account_id INTEGER NOT NULL,
            entry_type TEXT NOT NULL CHECK(entry_type IN ('debit', 'credit')),
            amount REAL NOT NULL CHECK(amount > 0),
            memo TEXT,
            counter_account_id INTEGER,
            line_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
            FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_tx ON journal_entries(transaction_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_acc ON journal_entries(account_id);');
      } catch (_) {}

      // 3. Create audit_logs table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER,
            account_id INTEGER,
            action TEXT NOT NULL,
            reason TEXT NOT NULL,
            changes_json TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      } catch (_) {}

      // 4. Seed the full chart of accounts
      await _seedDoubleEntryChartOfAccounts(db);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Accounts table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'asset',
        sub_category TEXT NOT NULL DEFAULT 'general',
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        opening_balance REAL NOT NULL DEFAULT 0.0,
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
        notes TEXT,
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

    // 6. Journal Entries table (Double-Entry Line Items)
    await db.execute('''
      CREATE TABLE journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        entry_type TEXT NOT NULL CHECK(entry_type IN ('debit', 'credit')),
        amount REAL NOT NULL CHECK(amount > 0),
        memo TEXT,
        counter_account_id INTEGER,
        line_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_journal_entries_tx ON journal_entries(transaction_id);');
    await db.execute('CREATE INDEX idx_journal_entries_acc ON journal_entries(account_id);');

    // 7. Audit Logs table
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
        account_id INTEGER,
        action TEXT NOT NULL,
        reason TEXT NOT NULL,
        changes_json TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // 8. Settings table
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

    // Seed default accounts and double-entry chart of accounts
    await _seedDefaultAccounts(db);
    await _seedDoubleEntryChartOfAccounts(db);
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

  Future<void> _seedDoubleEntryChartOfAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();

    final chartOfAccounts = [
      // 1. ASSETS
      {
        'code': 'ASSET_SALARY_BANK',
        'name': 'Salary Bank Account',
        'category': 'asset',
        'sub_category': 'bank',
        'type': 'salary',
        'icon': 'work',
        'color': 0xFF1E88E5,
      },
      {
        'code': 'ASSET_SAVINGS_BANK',
        'name': 'Savings Account',
        'category': 'asset',
        'sub_category': 'bank',
        'type': 'bank',
        'icon': 'account_balance',
        'color': 0xFF0288D1,
      },
      {
        'code': 'ASSET_CASH_WALLET',
        'name': 'Cash Wallet',
        'category': 'asset',
        'sub_category': 'cash',
        'type': 'pool',
        'icon': 'account_balance_wallet',
        'color': 0xFF0F3E33,
      },
      {
        'code': 'ASSET_DEMAT',
        'name': 'Demat/Stock Account',
        'category': 'asset',
        'sub_category': 'demat',
        'type': 'demat',
        'icon': 'trending_up',
        'color': 0xFFE65100,
      },
      {
        'code': 'ASSET_GPF',
        'name': 'GPF Account',
        'category': 'asset',
        'sub_category': 'gpf',
        'type': 'bank',
        'icon': 'savings',
        'color': 0xFF00796B,
      },
      {
        'code': 'ASSET_PROPERTY',
        'name': 'Property',
        'category': 'asset',
        'sub_category': 'property',
        'type': 'custom',
        'icon': 'home',
        'color': 0xFF5D4037,
      },
      {
        'code': 'ASSET_CHIT_RECEIVABLE',
        'name': 'Chit Fund Receivable',
        'category': 'asset',
        'sub_category': 'chit',
        'type': 'chit',
        'icon': 'groups',
        'color': 0xFFB37400,
      },

      // 2. LIABILITIES
      {
        'code': 'LIAB_HOUSING_LOAN',
        'name': 'Housing Loan',
        'category': 'liability',
        'sub_category': 'loan_bank',
        'type': 'debt',
        'icon': 'home_work',
        'color': 0xFFC62828,
      },
      {
        'code': 'LIAB_PERSONAL_LOAN_1',
        'name': 'Personal Loan 1',
        'category': 'liability',
        'sub_category': 'loan_bank',
        'type': 'debt',
        'icon': 'account_balance',
        'color': 0xFFD32F2F,
      },
      {
        'code': 'LIAB_PERSONAL_LOAN_2',
        'name': 'Personal Loan 2',
        'category': 'liability',
        'sub_category': 'loan_bank',
        'type': 'debt',
        'icon': 'account_balance',
        'color': 0xFFE53935,
      },
      {
        'code': 'LIAB_FRIEND_A_LOAN',
        'name': 'Friend A Loan',
        'category': 'liability',
        'sub_category': 'loan_friend',
        'type': 'debt',
        'icon': 'person',
        'color': 0xFFAD1457,
      },
      {
        'code': 'LIAB_FRIEND_B_LOAN',
        'name': 'Friend B Loan',
        'category': 'liability',
        'sub_category': 'loan_friend',
        'type': 'debt',
        'icon': 'person',
        'color': 0xFF880E4F,
      },
      {
        'code': 'LIAB_CREDIT_CARD_1',
        'name': 'Credit Card 1',
        'category': 'liability',
        'sub_category': 'credit_card',
        'type': 'credit_card',
        'icon': 'credit_card',
        'color': 0xFF7B1FA2,
      },
      {
        'code': 'LIAB_CREDIT_CARD_2',
        'name': 'Credit Card 2',
        'category': 'liability',
        'sub_category': 'credit_card',
        'type': 'credit_card',
        'icon': 'credit_card',
        'color': 0xFF4A148C,
      },
      {
        'code': 'LIAB_CHIT_LIABILITY',
        'name': 'Chit Fund Liability',
        'category': 'liability',
        'sub_category': 'chit',
        'type': 'chit',
        'icon': 'groups',
        'color': 0xFFE65100,
      },

      // 3. INCOME
      {
        'code': 'INC_SALARY',
        'name': 'Salary',
        'category': 'income',
        'sub_category': 'income_regular',
        'type': 'custom',
        'icon': 'payments',
        'color': 0xFF2E7D32,
      },
      {
        'code': 'INC_RENT',
        'name': 'Rent Received',
        'category': 'income',
        'sub_category': 'income_regular',
        'type': 'custom',
        'icon': 'real_estate_agent',
        'color': 0xFF388E3C,
      },
      {
        'code': 'INC_DEMAT_PROFIT',
        'name': 'Demat/Stock Profit',
        'category': 'income',
        'sub_category': 'income_regular',
        'type': 'custom',
        'icon': 'trending_up',
        'color': 0xFF43A047,
      },
      {
        'code': 'INC_GPF_RECEIPT',
        'name': 'GPF Receipt',
        'category': 'income',
        'sub_category': 'income_regular',
        'type': 'custom',
        'icon': 'savings',
        'color': 0xFF4CAF50,
      },
      {
        'code': 'INC_PROPERTY_SALE',
        'name': 'Property Sale Proceeds',
        'category': 'income',
        'sub_category': 'income_regular',
        'type': 'custom',
        'icon': 'sell',
        'color': 0xFF66BB6A,
      },
      {
        'code': 'INC_INTEREST',
        'name': 'Interest Income',
        'category': 'income',
        'sub_category': 'income_regular',
        'type': 'custom',
        'icon': 'percent',
        'color': 0xFF81C784,
      },
      {
        'code': 'INC_OTHER',
        'name': 'Other Income',
        'category': 'income',
        'sub_category': 'income_regular',
        'type': 'custom',
        'icon': 'attach_money',
        'color': 0xFFA5D6A7,
      },

      // 4. EXPENSES
      {
        'code': 'EXP_CHIT_CONTRIBUTION',
        'name': 'Chit Contribution',
        'category': 'expense',
        'sub_category': 'chit',
        'type': 'custom',
        'icon': 'groups',
        'color': 0xFFBF360C,
      },
      {
        'code': 'EXP_MILK_BILL',
        'name': 'Milk Bill',
        'category': 'expense',
        'sub_category': 'expense_utility',
        'type': 'custom',
        'icon': 'water_drop',
        'color': 0xFF0277BD,
      },
      {
        'code': 'EXP_CURRENT_BILL',
        'name': 'Current Bill',
        'category': 'expense',
        'sub_category': 'expense_utility',
        'type': 'custom',
        'icon': 'electric_bolt',
        'color': 0xFFF57F17,
      },
      {
        'code': 'EXP_GROCERY',
        'name': 'Grocery/Kirana',
        'category': 'expense',
        'sub_category': 'expense_general',
        'type': 'custom',
        'icon': 'shopping_cart',
        'color': 0xFF558B2F,
      },
      {
        'code': 'EXP_HOUSING_LOAN_INTEREST',
        'name': 'Housing Loan Interest',
        'category': 'expense',
        'sub_category': 'loan_bank',
        'type': 'custom',
        'icon': 'home_work',
        'color': 0xFFC2185B,
      },
      {
        'code': 'EXP_PERSONAL_LOAN_INTEREST',
        'name': 'Personal Loan Interest',
        'category': 'expense',
        'sub_category': 'loan_bank',
        'type': 'custom',
        'icon': 'percent',
        'color': 0xFFD81B60,
      },
      {
        'code': 'EXP_FRIEND_LOAN_INTEREST',
        'name': 'Friend Loan Interest',
        'category': 'expense',
        'sub_category': 'loan_friend',
        'type': 'custom',
        'icon': 'percent',
        'color': 0xFFE91E63,
      },
      {
        'code': 'EXP_CC_INTEREST_CHARGES',
        'name': 'Credit Card Interest/Charges',
        'category': 'expense',
        'sub_category': 'credit_card',
        'type': 'custom',
        'icon': 'receipt',
        'color': 0xFF8E24AA,
      },
      {
        'code': 'EXP_HOUSEHOLD',
        'name': 'Household Expenses',
        'category': 'expense',
        'sub_category': 'expense_general',
        'type': 'custom',
        'icon': 'cottage',
        'color': 0xFF455A64,
      },
      {
        'code': 'EXP_OTHER',
        'name': 'Other Expenses',
        'category': 'expense',
        'sub_category': 'expense_general',
        'type': 'custom',
        'icon': 'receipt_long',
        'color': 0xFF607D8B,
      },

      // 5. EQUITY
      {
        'code': 'EQ_OPENING_BALANCE',
        'name': 'Opening Balance Adjustment',
        'category': 'equity',
        'sub_category': 'equity',
        'type': 'temporaryAdjustment',
        'icon': 'balance',
        'color': 0xFF0F3E33,
      },
    ];

    for (final acc in chartOfAccounts) {
      final existing = await db.query(
        'accounts',
        columns: ['id'],
        where: 'code = ? OR name = ?',
        whereArgs: [acc['code'], acc['name']],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('accounts', {
          'code': acc['code'],
          'name': acc['name'],
          'category': acc['category'],
          'sub_category': acc['sub_category'],
          'type': acc['type'],
          'icon': acc['icon'],
          'color': acc['color'],
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
          'phone_number': null,
          'is_closed': 0,
          'closed_at': null,
          'last_interest_paid_date': null,
          'is_archived': 0,
          'created_at': now,
        });
      }
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

  Future<bool> canDeleteAccount(int id) async {
    final db = await instance.database;
    // 1. Check if any transactions involve this account
    final txResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE account_id = ? OR to_account_id = ?',
      [id, id],
    );
    final txCount = (txResult.first['count'] as num?)?.toInt() ?? 0;
    if (txCount > 0) return false;

    // 2. Check if any journal entries involve this account
    try {
      final jnResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM journal_entries WHERE account_id = ? OR counter_account_id = ?',
        [id, id],
      );
      final jnCount = (jnResult.first['count'] as num?)?.toInt() ?? 0;
      if (jnCount > 0) return false;
    } catch (_) {}

    return true;
  }

  Future<int> deleteAccount(int id, {String? reason}) async {
    final canDelete = await canDeleteAccount(id);
    if (!canDelete) {
      throw StateError(
        'Cannot delete account with existing transactions. Please archive it instead.',
      );
    }
    final db = await instance.database;
    await logAudit(
      accountId: id,
      action: 'delete',
      reason: reason ?? 'Account deleted',
      changesJson: '{"account_id": $id}',
    );
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> archiveAccount(int accountId, bool archive, {String? reason}) async {
    final db = await instance.database;
    await logAudit(
      accountId: accountId,
      action: archive ? 'archive' : 'unarchive',
      reason: reason ?? (archive ? 'Account archived' : 'Account unarchived'),
      changesJson: '{"is_archived": ${archive ? 1 : 0}}',
    );
    return await db.update(
      'accounts',
      {'is_archived': archive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<int> renameAccount(int accountId, String newName, {String? reason}) async {
    final db = await instance.database;
    final old = await getAccountById(accountId);
    await logAudit(
      accountId: accountId,
      action: 'rename',
      reason: reason ?? 'Account renamed from ${old?.name} to $newName',
      changesJson: '{"old_name": "${old?.name}", "new_name": "$newName"}',
    );
    return await db.update(
      'accounts',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<List<Account>> getAccountsByCategory(AccountCategory category, {bool includeArchived = false}) async {
    final db = await instance.database;
    final whereClause = includeArchived
        ? 'category = ?'
        : 'category = ? AND is_archived = 0';
    final result = await db.query(
      'accounts',
      where: whereClause,
      whereArgs: [category.key],
      orderBy: 'name ASC',
    );
    return result.map((m) => Account.fromMap(m)).toList();
  }

  Future<void> logAudit({
    int? transactionId,
    int? accountId,
    required String action,
    required String reason,
    required String changesJson,
  }) async {
    try {
      final db = await instance.database;
      await db.insert('audit_logs', {
        'transaction_id': transactionId,
        'account_id': accountId,
        'action': action,
        'reason': reason,
        'changes_json': changesJson,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
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

      // 1b. Create & Validate Double-Entry Journal Entries
      try {
        int resolvedDestId = insertedTx.toAccountId ?? insertedTx.accountId;
        if (insertedTx.toAccountId == null) {
          if (insertedTx.isDebit) {
            final expMatch = await txn.query('accounts', columns: ['id'], where: 'category = ? AND (name LIKE ? OR sub_category LIKE ?)', whereArgs: ['expense', '%${insertedTx.category}%', '%${insertedTx.category}%'], limit: 1);
            if (expMatch.isNotEmpty) {
              resolvedDestId = expMatch.first['id'] as int;
            } else {
              final defaultExp = await txn.query('accounts', columns: ['id'], where: 'code = ?', whereArgs: ['EXP_OTHER'], limit: 1);
              if (defaultExp.isNotEmpty) resolvedDestId = defaultExp.first['id'] as int;
            }
          } else if (insertedTx.isCredit) {
            final incMatch = await txn.query('accounts', columns: ['id'], where: 'category = ? AND (name LIKE ? OR sub_category LIKE ?)', whereArgs: ['income', '%${insertedTx.category}%', '%${insertedTx.category}%'], limit: 1);
            if (incMatch.isNotEmpty) {
              resolvedDestId = incMatch.first['id'] as int;
            } else {
              final defaultInc = await txn.query('accounts', columns: ['id'], where: 'code = ?', whereArgs: ['INC_OTHER'], limit: 1);
              if (defaultInc.isNotEmpty) resolvedDestId = defaultInc.first['id'] as int;
            }
          }
        }

        final entries = insertedTx.journalEntries ??
            DoubleEntryEngine.buildJournalEntriesForType(
              transactionId: txId,
              type: insertedTx.type,
              totalAmount: insertedTx.amount,
              sourceAccountId: insertedTx.accountId,
              destinationAccountId: resolvedDestId,
              principalPortion: insertedTx.principalPortion,
              interestPortion: insertedTx.interestPortion,
              memo: insertedTx.note.isNotEmpty ? insertedTx.note : insertedTx.category,
            );

        DoubleEntryEngine.validateBalanced(entries);

        for (final entry in entries) {
          await txn.insert('journal_entries', entry.toMap());
        }
      } catch (e) {
        debugPrint('Double-entry generation note: $e');
      }

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

      // 3b. Update double-entry journal entries
      try {
        await txn.delete('journal_entries', where: 'transaction_id = ?', whereArgs: [newTx.id]);

        int resolvedDestId = newTx.toAccountId ?? newTx.accountId;
        if (newTx.toAccountId == null) {
          if (newTx.isDebit) {
            final expMatch = await txn.query('accounts', columns: ['id'], where: 'category = ? AND (name LIKE ? OR sub_category LIKE ?)', whereArgs: ['expense', '%${newTx.category}%', '%${newTx.category}%'], limit: 1);
            if (expMatch.isNotEmpty) {
              resolvedDestId = expMatch.first['id'] as int;
            } else {
              final defaultExp = await txn.query('accounts', columns: ['id'], where: 'code = ?', whereArgs: ['EXP_OTHER'], limit: 1);
              if (defaultExp.isNotEmpty) resolvedDestId = defaultExp.first['id'] as int;
            }
          } else if (newTx.isCredit) {
            final incMatch = await txn.query('accounts', columns: ['id'], where: 'category = ? AND (name LIKE ? OR sub_category LIKE ?)', whereArgs: ['income', '%${newTx.category}%', '%${newTx.category}%'], limit: 1);
            if (incMatch.isNotEmpty) {
              resolvedDestId = incMatch.first['id'] as int;
            } else {
              final defaultInc = await txn.query('accounts', columns: ['id'], where: 'code = ?', whereArgs: ['INC_OTHER'], limit: 1);
              if (defaultInc.isNotEmpty) resolvedDestId = defaultInc.first['id'] as int;
            }
          }
        }

        final entries = newTx.journalEntries ??
            DoubleEntryEngine.buildJournalEntriesForType(
              transactionId: newTx.id!,
              type: newTx.type,
              totalAmount: newTx.amount,
              sourceAccountId: newTx.accountId,
              destinationAccountId: resolvedDestId,
              principalPortion: newTx.principalPortion,
              interestPortion: newTx.interestPortion,
              memo: newTx.note.isNotEmpty ? newTx.note : newTx.category,
            );
        DoubleEntryEngine.validateBalanced(entries);
        for (final entry in entries) {
          await txn.insert('journal_entries', entry.toMap());
        }
      } catch (e) {
        debugPrint('Double-entry update note: $e');
      }

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

      // Cascade delete journal entries
      await txn.delete('journal_entries', where: 'transaction_id = ?', whereArgs: [id]);

      return await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // ==================== DOUBLE-ENTRY JOURNAL & LEDGER QUERIES ====================

  Future<List<JournalEntry>> getJournalEntriesForTransaction(int txId) async {
    final db = await instance.database;
    final results = await db.query(
      'journal_entries',
      where: 'transaction_id = ?',
      whereArgs: [txId],
      orderBy: 'line_order ASC, id ASC',
    );
    return results.map((m) => JournalEntry.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getAccountLedger(
    int accountId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? entryType,
    String? category,
  }) async {
    final db = await instance.database;
    final account = await getAccountById(accountId);
    if (account == null) return [];

    final whereClauses = <String>['je.account_id = ?'];
    final whereArgs = <dynamic>[accountId];

    if (fromDate != null) {
      whereClauses.add('t.date >= ?');
      whereArgs.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      whereClauses.add('t.date <= ?');
      whereArgs.add(toDate.toIso8601String());
    }
    if (entryType != null && entryType.isNotEmpty && entryType != 'all') {
      whereClauses.add('je.entry_type = ?');
      whereArgs.add(entryType);
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      whereClauses.add('t.category = ?');
      whereArgs.add(category);
    }

    final sql = '''
      SELECT 
        je.id as entry_id,
        je.transaction_id,
        je.entry_type,
        je.amount,
        je.memo,
        je.line_order,
        je.counter_account_id,
        t.tx_number,
        t.date as tx_date,
        t.type as tx_type,
        t.category as tx_category,
        t.note as tx_note,
        t.payment_mode,
        t.receipt_path,
        t.debit_account_name,
        t.credit_account_name,
        ca.name as counter_account_name
      FROM journal_entries je
      JOIN transactions t ON je.transaction_id = t.id
      LEFT JOIN accounts ca ON je.counter_account_id = ca.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY t.date ASC, je.id ASC
    ''';

    final rows = await db.rawQuery(sql, whereArgs);

    // Compute running balances according to account category normal balance
    double runningBalance = account.openingBalance;
    final ledgerItems = <Map<String, dynamic>>[];

    for (final row in rows) {
      final isDebit = row['entry_type'] == 'debit';
      final amount = (row['amount'] as num).toDouble();
      final delta = DoubleEntryEngine.calculateBalanceDelta(
        category: account.category,
        entryType: isDebit ? EntryType.debit : EntryType.credit,
        amount: amount,
      );
      runningBalance += delta;

      final item = Map<String, dynamic>.from(row);
      item['running_balance'] = runningBalance;
      ledgerItems.add(item);
    }

    return ledgerItems;
  }

  Future<List<Map<String, dynamic>>> getMasterJournalRegister({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    String? category,
    String? personName,
    String? paymentMode,
    String? typeKey,
    double? minAmount,
    double? maxAmount,
    String? searchQuery,
    int limit = 100,
  }) async {
    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(toDate.toIso8601String());
    }
    if (accountId != null) {
      whereClauses.add('(account_id = ? OR to_account_id = ?)');
      whereArgs.addAll([accountId, accountId]);
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (personName != null && personName.isNotEmpty) {
      whereClauses.add('person_name LIKE ?');
      whereArgs.add('%$personName%');
    }
    if (paymentMode != null && paymentMode.isNotEmpty && paymentMode != 'all') {
      whereClauses.add('payment_mode = ?');
      whereArgs.add(paymentMode);
    }
    if (typeKey != null && typeKey.isNotEmpty && typeKey != 'all') {
      whereClauses.add('type = ?');
      whereArgs.add(typeKey);
    }
    if (minAmount != null) {
      whereClauses.add('amount >= ?');
      whereArgs.add(minAmount);
    }
    if (maxAmount != null) {
      whereClauses.add('amount <= ?');
      whereArgs.add(maxAmount);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(note LIKE ? OR category LIKE ? OR debit_account_name LIKE ? OR credit_account_name LIKE ? OR bill_number LIKE ?)');
      final q = '%${searchQuery.trim()}%';
      whereArgs.addAll([q, q, q, q, q]);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final sql = 'SELECT * FROM transactions $whereString ORDER BY date DESC, id DESC LIMIT $limit';
    return await db.rawQuery(sql, whereArgs);
  }

  Future<Map<String, dynamic>> getTrialBalance() async {
    final db = await instance.database;
    final sql = '''
      SELECT 
        a.id as account_id,
        a.name as account_name,
        a.code as account_code,
        a.category as account_category,
        COALESCE(SUM(CASE WHEN je.entry_type = 'debit' THEN je.amount ELSE 0 END), 0) as total_debits,
        COALESCE(SUM(CASE WHEN je.entry_type = 'credit' THEN je.amount ELSE 0 END), 0) as total_credits
      FROM accounts a
      LEFT JOIN journal_entries je ON a.id = je.account_id
      WHERE a.is_archived = 0
      GROUP BY a.id
      ORDER BY a.category ASC, a.name ASC
    ''';
    final rows = await db.rawQuery(sql);
    double sumDebits = 0.0;
    double sumCredits = 0.0;
    final items = <Map<String, dynamic>>[];
    for (final r in rows) {
      final deb = (r['total_debits'] as num).toDouble();
      final cred = (r['total_credits'] as num).toDouble();
      sumDebits += deb;
      sumCredits += cred;
      items.add({
        'account_id': r['account_id'],
        'account_name': r['account_name'],
        'account_code': r['account_code'],
        'account_category': r['account_category'],
        'debits': deb,
        'credits': cred,
        'net_balance': deb - cred,
      });
    }
    return {
      'items': items,
      'sum_debits': sumDebits,
      'sum_credits': sumCredits,
      'is_balanced': (sumDebits - sumCredits).abs() < 0.01,
      'discrepancy': (sumDebits - sumCredits).abs(),
    };
  }

  Future<Map<String, dynamic>> getCashFlowStatement({DateTime? fromDate, DateTime? toDate}) async {
    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (fromDate != null) {
      whereClauses.add('t.date >= ?');
      whereArgs.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      whereClauses.add('t.date <= ?');
      whereArgs.add(toDate.toIso8601String());
    }
    final whereStr = whereClauses.isNotEmpty ? 'AND ${whereClauses.join(' AND ')}' : '';

    final sql = '''
      SELECT 
        t.type,
        t.amount,
        t.principal_portion,
        t.interest_portion,
        t.category
      FROM transactions t
      WHERE t.linked_tx_id IS NULL $whereStr
    ''';
    final rows = await db.rawQuery(sql, whereArgs);

    double operatingInflows = 0.0;
    double operatingOutflows = 0.0;
    double financingInflows = 0.0;
    double financingOutflows = 0.0;

    for (final r in rows) {
      final type = r['type'] as String?;
      final amount = (r['amount'] as num).toDouble();

      if (type == 'income' || type == 'credit') {
        operatingInflows += amount;
      } else if (type == 'expense' || type == 'debit' || type == 'credit_card_purchase') {
        operatingOutflows += amount;
      } else if (type == 'loan_taken') {
        financingInflows += amount;
      } else if (type == 'loan_repayment' || type == 'credit_card_payment') {
        financingOutflows += amount;
      } else if (type == 'chit_receipt') {
        financingInflows += amount;
      } else if (type == 'chit_payment') {
        financingOutflows += amount;
      }
    }

    final netOperating = operatingInflows - operatingOutflows;
    final netFinancing = financingInflows - financingOutflows;
    final netCashFlow = netOperating + netFinancing;

    return {
      'operating_inflows': operatingInflows,
      'operating_outflows': operatingOutflows,
      'net_operating': netOperating,
      'financing_inflows': financingInflows,
      'financing_outflows': financingOutflows,
      'net_financing': netFinancing,
      'net_cash_flow': netCashFlow,
    };
  }

  Future<int> seedDemoDoubleEntryScenarios() async {
    final db = await instance.database;

    Future<int?> getAccountId(String code, String name) async {
      final res = await db.query('accounts', columns: ['id'], where: 'code = ? OR name = ?', whereArgs: [code, name], limit: 1);
      return res.isNotEmpty ? (res.first['id'] as int) : null;
    }

    final salaryBankId = await getAccountId('ASSET_SALARY_BANK', 'Salary Bank Account');
    final cashWalletId = await getAccountId('ASSET_CASH_WALLET', 'Cash Wallet');
    final gpfId = await getAccountId('ASSET_GPF', 'GPF Account');
    final chitLiabId = await getAccountId('LIAB_CHIT_LIABILITY', 'Chit Fund Liability');
    final friendALoanId = await getAccountId('LIAB_FRIEND_A_LOAN', 'Friend A Loan');
    final cc1Id = await getAccountId('LIAB_CREDIT_CARD_1', 'Credit Card 1');
    final housingLoanId = await getAccountId('LIAB_HOUSING_LOAN', 'Housing Loan');
    final rentIncId = await getAccountId('INC_RENT', 'Rent Received');
    final propSaleId = await getAccountId('INC_PROPERTY_SALE', 'Property Sale Proceeds');
    final milkBillId = await getAccountId('EXP_MILK_BILL', 'Milk Bill');
    final groceryId = await getAccountId('EXP_GROCERY_KIRANA', 'Grocery / Kirana');
    final ccChargesId = await getAccountId('EXP_CC_CHARGES', 'Credit Card Interest / Charges');

    if (salaryBankId == null || cashWalletId == null || chitLiabId == null) return 0;

    int count = 0;

    // Scenario 1: Chit Payments across 5 distinct funding sources
    final chitScenarios = [
      {'src': salaryBankId, 'dest': chitLiabId, 'amt': 10000.0, 'date': DateTime(2026, 1, 10), 'memo': 'Jan 2026 Chit paid from Salary Bank Account'},
      if (gpfId != null) {'src': gpfId, 'dest': chitLiabId, 'amt': 10000.0, 'date': DateTime(2026, 2, 10), 'memo': 'Feb 2026 Chit paid from GPF Account'},
      if (rentIncId != null) {'src': rentIncId, 'dest': chitLiabId, 'amt': 10000.0, 'date': DateTime(2026, 3, 10), 'memo': 'Mar 2026 Chit paid from Rent Received'},
      if (friendALoanId != null) {'src': friendALoanId, 'dest': chitLiabId, 'amt': 10000.0, 'date': DateTime(2026, 4, 10), 'memo': 'Apr 2026 Chit paid from temporary borrowing from Friend A'},
      if (propSaleId != null) {'src': propSaleId, 'dest': chitLiabId, 'amt': 10000.0, 'date': DateTime(2026, 5, 10), 'memo': 'May 2026 Chit paid from Property Sale Proceeds'},
    ];

    for (final s in chitScenarios) {
      await insertTransaction(TransactionModel(
        accountId: s['src'] as int,
        toAccountId: s['dest'] as int,
        type: TransactionType.chitPayment,
        amount: s['amt'] as double,
        category: 'Chit Contribution',
        note: s['memo'] as String,
        date: s['date'] as DateTime,
        chitGroupName: 'Gold Chit Group',
      ));
      count++;
    }

    // Scenario 2: Milk Bill paid via 4 different sources
    if (milkBillId != null) {
      final milkScenarios = [
        {'src': salaryBankId, 'amt': 2500.0, 'date': DateTime(2026, 1, 5), 'memo': 'January milk paid from Salary Bank'},
        {'src': cashWalletId, 'amt': 2600.0, 'date': DateTime(2026, 2, 5), 'memo': 'February milk paid from Cash Wallet'},
        if (cc1Id != null) {'src': cc1Id, 'amt': 2700.0, 'date': DateTime(2026, 3, 5), 'memo': 'March milk paid via Credit Card 1'},
        if (friendALoanId != null) {'src': friendALoanId, 'amt': 2500.0, 'date': DateTime(2026, 4, 5), 'memo': 'April milk paid via borrowed money from Friend A'},
      ];

      for (final m in milkScenarios) {
        await insertTransaction(TransactionModel(
          accountId: m['src'] as int,
          toAccountId: milkBillId,
          type: m['src'] == cc1Id ? TransactionType.creditCardPurchase : TransactionType.expense,
          amount: m['amt'] as double,
          category: 'Milk Bill',
          note: m['memo'] as String,
          date: m['date'] as DateTime,
        ));
        count++;
      }
    }

    // Scenario 3: Credit Card 1 purchases, charges, and bill payment
    if (cc1Id != null) {
      if (groceryId != null) {
        await insertTransaction(TransactionModel(
          accountId: cc1Id,
          toAccountId: groceryId,
          type: TransactionType.creditCardPurchase,
          amount: 8500.0,
          category: 'Grocery / Kirana',
          note: 'Supermarket grocery charged to Card 1',
          date: DateTime(2026, 2, 14),
        ));
        count++;
      }
      if (ccChargesId != null) {
        await insertTransaction(TransactionModel(
          accountId: cc1Id,
          toAccountId: ccChargesId,
          type: TransactionType.creditCardPurchase,
          amount: 450.0,
          category: 'Credit Card Interest / Charges',
          note: 'Annual card fee and finance charge',
          date: DateTime(2026, 2, 28),
        ));
        count++;
      }
      // Payment to card from Salary Bank Account
      await insertTransaction(TransactionModel(
        accountId: salaryBankId,
        toAccountId: cc1Id,
        type: TransactionType.creditCardPayment,
        amount: 11650.0,
        category: 'Credit Card Bill Payment',
        note: 'Full payment of CC1 bill from Salary Bank',
        date: DateTime(2026, 3, 4),
      ));
      count++;
    }

    // Scenario 4: Compound Housing Loan Repayment
    if (housingLoanId != null) {
      await insertTransaction(TransactionModel(
        accountId: salaryBankId,
        toAccountId: housingLoanId,
        type: TransactionType.loanRepayment,
        amount: 40000.0,
        principalPortion: 25000.0,
        interestPortion: 15000.0,
        category: 'Housing Loan EMI',
        note: 'Compound Loan Repayment: ₹25k Principal + ₹15k Interest',
        date: DateTime(2026, 1, 15),
      ));
      count++;
    }

    // Scenario 5: Temporary Borrowing from Friend A and Repayment
    if (friendALoanId != null) {
      // 1. Money received into Cash Wallet
      await insertTransaction(TransactionModel(
        accountId: friendALoanId,
        toAccountId: cashWalletId,
        type: TransactionType.loanTaken,
        amount: 10000.0,
        category: 'Friend Borrowing',
        note: 'Emergency temporary cash borrowed from Friend A',
        personName: 'Friend A',
        date: DateTime(2026, 3, 1),
      ));
      count++;

      // 2. Direct expense paid from borrowed money
      if (groceryId != null) {
        await insertTransaction(TransactionModel(
          accountId: friendALoanId,
          toAccountId: groceryId,
          type: TransactionType.expense,
          amount: 5000.0,
          category: 'Grocery / Kirana',
          note: 'Kirana provisions paid directly from Friend A loan',
          personName: 'Friend A',
          date: DateTime(2026, 3, 10),
        ));
        count++;
      }

      // 3. Full repayment after salary credited
      await insertTransaction(TransactionModel(
        accountId: salaryBankId,
        toAccountId: friendALoanId,
        type: TransactionType.loanRepayment,
        amount: 15000.0,
        principalPortion: 15000.0,
        interestPortion: 0.0,
        category: 'Friend Loan Repayment',
        note: 'Full settlement of ₹15,000 to Friend A via UPI from Salary Bank',
        personName: 'Friend A',
        date: DateTime(2026, 3, 31),
      ));
      count++;
    }

    return count;
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
      if (tx.isDebit) {
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
      } else if (tx.isCredit) {
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
      if (tx.isCredit) {
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
      } else if (tx.isDebit) {
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
      if (tx.isCredit) {
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
      } else if (tx.isDebit) {
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

      if (tx.isDebit) {
        newBalance -= factor * tx.amount;
        if (srcAccount.type == AccountType.lending) {
          // Lending more increases principal receivable
          newPrincipal += factor * tx.amount;
        } else if (srcAccount.type == AccountType.debt) {
          // Repaying debt reduces principal & interest
          newPrincipal -= factor * tx.principalPortion;
          newInterest -= factor * tx.interestPortion;
        }
      } else if (tx.isCredit) {
        newBalance += factor * tx.amount;
        if (srcAccount.type == AccountType.debt) {
          // Borrowing more increases debt principal
          newPrincipal += factor * tx.amount;
        } else if (srcAccount.type == AccountType.lending) {
          // Receiving repayment reduces lending principal & interest
          newPrincipal -= factor * tx.principalPortion;
          newInterest -= factor * tx.interestPortion;
        }
      } else if (tx.isTransfer) {
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

    // 2. Update Destination Account (for Transfers, compound Loan Repayments, Chit Contributions, Credit Card Payments)
    if (tx.toAccountId != null && tx.toAccountId != tx.accountId) {
      final destMaps = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.toAccountId]);
      if (destMaps.isNotEmpty) {
        final destAccount = Account.fromMap(destMaps.first);
        double newDestBalance = destAccount.balance;
        double newDestPrincipal = destAccount.principalBalance;
        double newDestInterest = destAccount.accruedInterest;

        if (tx.type == TransactionType.loanRepayment || destAccount.type == AccountType.debt) {
          // Paying loan decreases liability principal & interest
          final p = tx.principalPortion > 0 ? tx.principalPortion : tx.amount;
          newDestPrincipal -= factor * p;
          newDestInterest -= factor * tx.interestPortion;
          newDestBalance -= factor * tx.amount;
        } else if (tx.type == TransactionType.creditCardPayment || destAccount.type == AccountType.creditCard) {
          // Credit card payment decreases card outstanding liability
          newDestBalance -= factor * tx.amount;
        } else if (tx.type == TransactionType.loanTaken) {
          // Loan taken received into destination account (e.g. Bank or Cash)
          newDestBalance += factor * tx.amount;
        } else if (destAccount.type == AccountType.lending) {
          // Lending out via transfer
          newDestPrincipal += factor * tx.amount;
          newDestBalance += factor * tx.amount;
        } else {
          // Standard transfer or deposit into destination
          newDestBalance += factor * tx.amount;
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
