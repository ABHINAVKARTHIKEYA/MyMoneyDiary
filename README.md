# MY MONEY DIARY 📖💰
### *Formal Double-Entry Accounting & Liability Tracking Architecture — 100% Offline-First*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Desktop-green?logo=android)](https://www.android.com)
[![Accounting](https://img.shields.io/badge/Accounting-Double--Entry%20Engine-gold)]()
[![Offline First](https://img.shields.io/badge/Storage-100%25%20Offline%20SQLite-emerald)]()
[![Tests](https://img.shields.io/badge/Tests-60%2F60%20PASSED-success)]()

<p align="center">
  <img src="assets/images/logo.jpg" width="160" height="160" alt="My Money Diary Logo" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.25);" />
</p>

---

## 🏛️ 1. Core Double-Entry Accounting Model

Every financial transaction written to the database strictly enforces the double-entry accounting identity:
$$\sum \text{Debits} \equiv \sum \text{Credits}$$

Unbalanced transactions are mathematically prohibited by `DoubleEntryEngine.validateBalanced()` and rejected before hitting persistent storage.

### Account Hierarchy & 5 Master Categories
Each account belongs to one of five fundamental categories with its respective normal balance rule:

| Category | Normal Balance | Balance Delta Equation ($\Delta$) | User Examples |
| :--- | :---: | :--- | :--- |
| **Asset** | Debit (`Dr`) | $\Delta = \text{Debit} - \text{Credit}$ | Salary Bank, Savings Account, Cash Wallet, Demat/Stocks, GPF Account, Property, Chit Receivable |
| **Liability** | Credit (`Cr`) | $\Delta = \text{Credit} - \text{Debit}$ | Housing Loan, Personal Loans 1 & 2, Friend A Loan, Friend B Loan, Credit Cards 1 & 2, Chit Liability |
| **Income** | Credit (`Cr`) | $\Delta = \text{Credit} - \text{Debit}$ | Salary, Rent Received, Demat/Stock Profit, GPF Receipt, Property Sale Proceeds, Interest Income, Other Income |
| **Expense** | Debit (`Dr`) | $\Delta = \text{Debit} - \text{Credit}$ | Chit Contribution, Milk Bill, Current Bill, Grocery/Kirana, Housing Loan Interest, Credit Card Charges |
| **Equity** | Credit (`Cr`) | $\Delta = \text{Credit} - \text{Debit}$ | Opening Balance Adjustment, Retained Earnings |

### Chart of Accounts (27 Standard Pre-Seeded Accounts)
The application automatically seeds 27 accounts across all 5 categories:
- **7 Assets**: Salary Bank Account, Savings Account, Cash Wallet, Demat/Stock Account, GPF Account, Property, Chit Fund Receivable.
- **8 Liabilities**: Housing Loan, Personal Loan 1, Personal Loan 2, Friend A Loan, Friend B Loan, Credit Card 1, Credit Card 2, Chit Fund Liability.
- **7 Income**: Salary, Rent Received, Demat/Stock Profit, GPF Receipt, Property Sale Proceeds, Interest Income, Other Income.
- **10 Expenses**: Chit Contribution, Milk Bill, Current Bill, Grocery/Kirana, Housing Loan Interest, Personal Loan Interest, Friend Loan Interest, Credit Card Interest/Charges, Household Expenses, Other Expenses.
- **1 Equity**: Opening Balance Adjustment.
- **Custom Accounts**: Up to 8 customizable "Others" accounts and unlimited user-defined accounts.

> **Data Integrity Rule**: Any account that possesses historical journal entries **cannot be deleted**. The app enforces safe archiving (`is_archived = 1`) with audit trail logging, preserving historical ledger accuracy.

---

## 📖 2. Master Journal & Dedicated Account Ledgers

### Master Journal Register (`MasterJournalScreen`)
- **Single Master Register**: Comprehensive audit log of every balanced journal entry in chronological sequence.
- **Multi-Column Filtering**: Instant filtering by date range, account, category, counterparty person, payment source, and transaction type.
- **Detailed Drilldown**: Displays transaction vouchers with balanced debit and credit leg breakdown.

### Dedicated T-Account Ledgers (`AccountLedgerScreen`)
Each account features its own ledger screen showing:
- Starting Opening Balance.
- Chronological list of transactions affecting only that account.
- Counter-Account name (where the money flowed to or from).
- Running balance computed dynamically according to normal balance rules.
- Debit (`Dr`) and Credit (`Cr`) badges with signed impacts.
- Filters by month, year, transaction type, counter-account, and category.
- **Statement Exports**: Direct export to CSV and formatted PDF reports.

---

## 💳 3. Specialized Financial Modules

### A. Compound Loan Repayments (EMI Split)
Loan repayments are generated as balanced compound entries:
1. **Debit**: Loan Liability Account (Principal reduction).
2. **Debit**: Loan Interest Expense Account (Interest cost recorded).
3. **Credit**: Bank/Cash Funding Source Account (Total payment outflow).
$$\text{Principal Repaid} + \text{Interest Expense} = \text{Total Cash Outflow}$$

### B. Temporary Borrowings from Friends
Tracks temporary loans and IOUs from relatives and friends:
- **Borrowing**: Debits Cash/Bank Asset, Credits Friend Loan Liability.
- **Direct Expense**: If money borrowed pays a bill directly, debits the relevant Expense account (e.g. Kirana) and credits Friend Loan Liability.
- **Repayment**: When salary is credited, debits Friend Loan Liability and credits Salary Bank Account.
- **Duration Tracking**: Displays elapsed years, months, and days since loan origination and since last interest payment.

### C. Multi-Chit Groups Management
- Supports multiple distinct chit groups with independent configurations:
  - Total Chit Value, tenure, starting & ending dates.
  - Installment Before Lifting vs Installment After Lifting.
  - Auction month, dividend deductions, and prize money received.
- **Multi-Source Contributions**: Choose the funding source for each installment (Salary Bank, GPF, Rent Received, Friend borrowing, Property sale proceeds).
- **Lifting / Prize Receipt**: Deposit prize money directly into Bank Account with balanced double-entry vouchers.

### D. Credit Cards Statement Cycle
- **Purchases**: Debits the specific Expense category (Milk Bill, Grocery, Household) and credits Credit Card Liability.
- **Finance Charges**: Debits Credit Card Charges and credits Card Liability.
- **Bill Payments**: Debits Card Liability and credits Bank Asset.
- **Net Outstanding**: Accurate running balance showing real-time liability.

---

## 📊 4. Dashboard, Balance Sheet & Indian Financial Year

### Balance Sheet & Fundamental Equation
The Dashboard displays a real-time Balance Sheet card verifying the fundamental equation:
$$\text{Assets} - \text{Liabilities} \equiv \text{Equity} + (\text{Income} - \text{Expenses})$$
- Green status badge displays mathematical invariant verification.
- **Trial Balance Dialog**: Interactive modal listing all 27+ ledger accounts with $\sum \text{Debits} == \sum \text{Credits}$ proof (Discrepancy: ₹0.00).

### Indian Financial Year (FY: Apr 1 – Mar 31)
- Automated support for Indian Financial Years (e.g. `FY 2025-26`, `FY 2026-27`).
- Pre-configured filters for exact April 1 to March 31 calendar boundaries.

### Cash Flow Statement
Classifies cash movements into:
- **Operating Activities**: Income receipts, utility bills, groceries, milk expenses.
- **Financing Activities**: Loans borrowed/repaid, friend IOUs, chit contributions & prize money.
- **Net Change in Cash**: Consolidated cash flow across all liquid accounts.

---

## 📥 5. CSV Statement Importer

Import bank, credit card, or custom CSV statements directly:
- **Universal Delimiter Support**: Supports comma, tab, and semicolon-delimited CSVs.
- **Column Mapping Interface**: Interactively map Date, Description/Narration, Amount (or separate Debit/Credit columns), Category, and Reference numbers.
- **Deterministic De-Duplication**: Prevents duplicate entries using cryptographic transaction signatures and external references.
- **Data Preview Table**: Preview the first rows with validation indicators before committing to the database.

---

## 🧪 6. Automated Verification Test Suite

Run the full automated test suite containing **60 verifications**:
```bash
dart test/run_verifications.dart
```

### Verification Highlights (60 Tests Passed, 0 Failed):
1. **Interest Calculator**: Per-month (₹/₹100/mo), per-annum (% p.a.), simple & compound daily accruals.
2. **Repayment Allocator**: Interest-first, principal-first, and manual split allocations.
3. **Chit Fund Engine**: Net installments, dividend deductions, pre-lifting and post-lifting dynamics.
4. **Auto-Detection & Deduplication**: SMS & notification parsing with zero duplicate tolerance.
5. **Double-Entry Engine**: Strict $\sum \text{Dr} == \sum \text{Cr}$ validation and unbalanced transaction rejection.
6. **Chart of Accounts**: 33 account types across 5 categories with normal balance deltas.
7. **Specialized Modules**: Compound EMI splits, friend debt lifecycle (settling to ₹0.00), multi-chit tracking.
8. **Financial Year & Balance Sheet**: April–March boundaries and Balance Sheet equation balance.
9. **5 Realistic Core Scenarios**: Exact validation of user-specified scenarios (Chits from 5 sources, Milk Bill from 4 sources, Credit Card 1, Compound Loan, Friend A debt).

---

## 📱 How to Download & Install the Release APK

1. Go to the **Actions** tab in this GitHub repository:  
   👉 [Actions Tab](https://github.com/ABHINAVKARTHIKEYA/MyMoneyDiary/actions)
2. Click on the latest workflow run: **"Build Android Release Artifacts"**.
3. Under the **Artifacts** section at the bottom of the page:
   - Click **`MyMoneyDiary-Release-APK`** to download the installable `.apk` directly to your Android device.
   - For Google Play Store submission, download **`MyMoneyDiary-PlayStore-AAB`**.
4. Open the downloaded `.apk` file on your Android device and tap **Install**.

---

## 🛠️ Tech Stack
- **Framework**: Flutter (Dart 3.x) targeting Android, Web, and Desktop
- **Architecture**: Provider Pattern (MVVM) with Domain Double-Entry Engine
- **Local Storage**: Offline-first SQLite (`sqflite` / `sqflite_common_ffi`)
- **Theme**: Luxury Emerald Green (`#0F3E33`), Royal Amber Gold (`#E6B042`), and Crisp Alabaster White
