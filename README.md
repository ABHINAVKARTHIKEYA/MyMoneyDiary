# MY MONEY DIARY 📖💰
### *All at one place — Offline-First Personal Finance Manager*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-green?logo=android)](https://www.android.com)
[![License](https://img.shields.io/badge/License-Proprietary-gold)]()
[![Offline First](https://img.shields.io/badge/Storage-100%25%20Offline%20SQLite-emerald)]()

<p align="center">
  <img src="assets/images/logo.jpg" width="160" height="160" alt="My Money Diary Logo" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.25);" />
</p>

---

## 🌟 Key Features

### 1. 💼 Custom & Core Accounts
- **Pool Account**: Central cash, bank, or shared family fund.
- **Debts (Money Borrowed)**: Track what you owe with live interest accrual.
- **Lendings (Money Lent)**: Track who owes you with live interest accrual.
- **Chit Funds (CHITS / Beesi)**: Complete lifecycle tracking with monthly dividends and auction prize money.
- **Temporary Adjustment Account**: Suspense / transit ledger for office advances, dinner bill splits, and temporary friend IOUs.
- **Maintenance Account**: Dedicated upkeep tracker for vehicles, home repairs, and society dues.
- **Miscellaneous & Custom Accounts**: Create any number of user-defined accounts.

### 2. 📈 Dynamic Interest Calculation Engine
- **Dual Rate Types**:
  - `₹ per ₹100 / month` (traditional Indian informal lending)
  - `% per annum (p.a.)` (formal / banking rates)
- **Calculation Modes**:
  - `Daily Up-to-Date`: Dynamic accrual on the fly based on elapsed days.
  - `Monthly`: End-of-month automatic interest postings to the ledger.
- **Compounding Switch**:
  - `Simple Interest`: Calculated purely on the principal base.
  - `Compound Interest`: Accrued interest is capitalized into the principal monthly.
- **Separation of Metrics**: Principal balance and accrued interest are always displayed distinctly.

### 3. ⚖️ Repayment Allocation Engine
- Choose between **Interest First** (standard) or **Principal First**.
- Automatic split calculation when recording payments, with **manual override fields** for exact control.

### 4. 🎟️ Chit Funds (CHITS) Module
- Tracks Total Chit Value, tenure, and nominal installments.
- Records monthly dividends earned and automatically calculates net payment (`Nominal - Dividend`).
- Records the "Lifted / Taken" event (auction discount surrendered, net prize money received).
- Visual progress bar and net gain/loss analytics.

### 5. 🔒 100% Offline & Biometric Security
- All financial data is stored locally in an encrypted SQLite database on your device.
- **Biometric Lock** (Fingerprint / Face Unlock) + **4-digit PIN** gatekeeper.
- JSON / Database file backup & restore.

---

## 📱 How to Download & Install the Release APK

1. Go to the **Actions** tab in this GitHub repository:  
   👉 [Actions Tab](https://github.com/ABHINAVKARTHIKEYA/MyMoneyDiary/actions)
2. Click on the latest workflow run: **"Build Android Release Artifacts"**.
3. Under the **Artifacts** section at the bottom of the page:
   - Click **`MyMoneyDiary-Release-APK`** to download the installable `.apk` directly to your Android phone.
   - For Google Play Store submission, download **`MyMoneyDiary-PlayStore-AAB`**.
4. Open the downloaded `.apk` file on your Android device and tap **Install**.

---

## 🛠️ Tech Stack
- **Framework**: Flutter (Dart 3.x) with Material 3 Design
- **Architecture**: Provider Pattern (MVVM)
- **Local Storage**: SQLite (`sqflite`)
- **Theme**: Luxury Emerald Green (`#0F3E33`) & Royal Amber Gold (`#E6B042`)
