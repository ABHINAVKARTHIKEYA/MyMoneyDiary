import 'package:flutter/material.dart';

enum AccountType {
  pool,
  salary,
  bank,
  creditCard,
  debt,
  lending,
  chit,
  insurance,
  demat,
  temporaryAdjustment,
  maintenance,
  miscellaneous,
  other1,
  other2,
  other3,
  other4,
  other5,
  other6,
  other7,
  other8,
  custom,
}

extension AccountTypeExtension on AccountType {
  String get key {
    switch (this) {
      case AccountType.pool:
        return 'pool';
      case AccountType.salary:
        return 'salary';
      case AccountType.bank:
        return 'bank';
      case AccountType.creditCard:
        return 'credit_card';
      case AccountType.debt:
        return 'debt';
      case AccountType.lending:
        return 'lending';
      case AccountType.chit:
        return 'chit';
      case AccountType.insurance:
        return 'insurance';
      case AccountType.demat:
        return 'demat';
      case AccountType.temporaryAdjustment:
        return 'temporary_adjustment';
      case AccountType.maintenance:
        return 'maintenance';
      case AccountType.miscellaneous:
        return 'miscellaneous';
      case AccountType.other1:
        return 'other_1';
      case AccountType.other2:
        return 'other_2';
      case AccountType.other3:
        return 'other_3';
      case AccountType.other4:
        return 'other_4';
      case AccountType.other5:
        return 'other_5';
      case AccountType.other6:
        return 'other_6';
      case AccountType.other7:
        return 'other_7';
      case AccountType.other8:
        return 'other_8';
      case AccountType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case AccountType.pool:
        return 'Pool Account (Cash in Hand)';
      case AccountType.salary:
        return 'Salary Account';
      case AccountType.bank:
        return 'Bank Accounts';
      case AccountType.creditCard:
        return 'Credit Cards';
      case AccountType.debt:
        return 'Debt (I Owe)';
      case AccountType.lending:
        return 'Lending (Owed to Me)';
      case AccountType.chit:
        return 'Chit Funds (CHITS)';
      case AccountType.insurance:
        return 'Insurance';
      case AccountType.demat:
        return 'Demats / Stocks';
      case AccountType.temporaryAdjustment:
        return 'Temporary Adjustment';
      case AccountType.maintenance:
        return 'Maintenance';
      case AccountType.miscellaneous:
        return 'Miscellaneous';
      case AccountType.other1:
        return 'Others 1';
      case AccountType.other2:
        return 'Others 2';
      case AccountType.other3:
        return 'Others 3';
      case AccountType.other4:
        return 'Others 4';
      case AccountType.other5:
        return 'Others 5';
      case AccountType.other6:
        return 'Others 6';
      case AccountType.other7:
        return 'Others 7';
      case AccountType.other8:
        return 'Others 8';
      case AccountType.custom:
        return 'Custom Account';
    }
  }

  String get defaultIcon {
    switch (this) {
      case AccountType.pool:
        return 'account_balance_wallet';
      case AccountType.salary:
        return 'work';
      case AccountType.bank:
        return 'account_balance';
      case AccountType.creditCard:
        return 'credit_card';
      case AccountType.debt:
        return 'arrow_downward';
      case AccountType.lending:
        return 'arrow_upward';
      case AccountType.chit:
        return 'groups';
      case AccountType.insurance:
        return 'health_and_safety';
      case AccountType.demat:
        return 'trending_up';
      case AccountType.temporaryAdjustment:
        return 'swap_horiz';
      case AccountType.maintenance:
        return 'build_circle';
      case AccountType.miscellaneous:
        return 'category';
      case AccountType.other1:
        return 'folder_special';
      case AccountType.other2:
        return 'stars';
      case AccountType.other3:
        return 'pie_chart';
      case AccountType.other4:
        return 'inventory_2';
      case AccountType.other5:
        return 'savings';
      case AccountType.other6:
        return 'receipt_long';
      case AccountType.other7:
        return 'account_box';
      case AccountType.other8:
        return 'more_horiz';
      case AccountType.custom:
        return 'account_box';
    }
  }

  IconData get iconData {
    switch (this) {
      case AccountType.pool:
        return Icons.account_balance_wallet;
      case AccountType.salary:
        return Icons.work;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.debt:
        return Icons.arrow_downward;
      case AccountType.lending:
        return Icons.arrow_upward;
      case AccountType.chit:
        return Icons.groups;
      case AccountType.insurance:
        return Icons.health_and_safety;
      case AccountType.demat:
        return Icons.trending_up;
      case AccountType.temporaryAdjustment:
        return Icons.swap_horiz;
      case AccountType.maintenance:
        return Icons.build_circle;
      case AccountType.miscellaneous:
        return Icons.category;
      case AccountType.other1:
        return Icons.folder_special;
      case AccountType.other2:
        return Icons.stars;
      case AccountType.other3:
        return Icons.pie_chart;
      case AccountType.other4:
        return Icons.inventory_2;
      case AccountType.other5:
        return Icons.savings;
      case AccountType.other6:
        return Icons.receipt_long;
      case AccountType.other7:
        return Icons.account_box;
      case AccountType.other8:
        return Icons.more_horiz;
      case AccountType.custom:
        return Icons.folder;
    }
  }

  int get defaultColor {
    switch (this) {
      case AccountType.pool:
        return 0xFF0F3E33; // Emerald
      case AccountType.salary:
        return 0xFF1E88E5; // Blue
      case AccountType.bank:
        return 0xFF0288D1; // Cyan
      case AccountType.creditCard:
        return 0xFF7B1FA2; // Purple
      case AccountType.debt:
        return 0xFFC62828; // Red
      case AccountType.lending:
        return 0xFF2E7D32; // Green
      case AccountType.chit:
        return 0xFFB37400; // Gold
      case AccountType.insurance:
        return 0xFF00897B; // Teal
      case AccountType.demat:
        return 0xFFE65100; // Orange
      case AccountType.temporaryAdjustment:
        return 0xFFD84315; // Deep Orange
      case AccountType.maintenance:
        return 0xFF558B2F; // Olive Green
      case AccountType.miscellaneous:
        return 0xFF546E7A; // Slate
      case AccountType.other1:
      case AccountType.other2:
      case AccountType.other3:
      case AccountType.other4:
      case AccountType.other5:
      case AccountType.other6:
      case AccountType.other7:
      case AccountType.other8:
        return 0xFF455A64; // Blue Grey
      case AccountType.custom:
        return 0xFF37474F;
    }
  }

  static AccountType fromKey(String key) {
    switch (key) {
      case 'pool':
        return AccountType.pool;
      case 'salary':
        return AccountType.salary;
      case 'bank':
        return AccountType.bank;
      case 'credit_card':
        return AccountType.creditCard;
      case 'debt':
        return AccountType.debt;
      case 'lending':
        return AccountType.lending;
      case 'chit':
        return AccountType.chit;
      case 'insurance':
        return AccountType.insurance;
      case 'demat':
        return AccountType.demat;
      case 'temporary_adjustment':
        return AccountType.temporaryAdjustment;
      case 'maintenance':
        return AccountType.maintenance;
      case 'miscellaneous':
        return AccountType.miscellaneous;
      case 'other_1':
        return AccountType.other1;
      case 'other_2':
        return AccountType.other2;
      case 'other_3':
        return AccountType.other3;
      case 'other_4':
        return AccountType.other4;
      case 'other_5':
        return AccountType.other5;
      case 'other_6':
        return AccountType.other6;
      case 'other_7':
        return AccountType.other7;
      case 'other_8':
        return AccountType.other8;
      default:
        return AccountType.custom;
    }
  }
}

class Account {
  final int? id;
  final String name;
  final AccountType type;
  final String icon;
  final int color;
  final double balance;
  final double principalBalance;
  final double accruedInterest;
  final double interestRate;
  final String interestRateType; // 'per_month' or 'per_annum'
  final bool isCompound;
  final String accrualMode; // 'daily' or 'monthly'
  final String allocationRule; // 'interest_first' or 'principal_first'
  final DateTime? lastInterestDate;
  final DateTime? loanStartDate;
  final String? phoneNumber;
  final bool isClosed;
  final DateTime? closedAt;
  final DateTime? lastInterestPaidDate;
  final bool isArchived;
  final DateTime createdAt;

  Account({
    this.id,
    required this.name,
    required this.type,
    this.icon = 'account_balance_wallet',
    this.color = 0xFF0F3E33,
    this.balance = 0.0,
    this.principalBalance = 0.0,
    this.accruedInterest = 0.0,
    this.interestRate = 0.0,
    this.interestRateType = 'per_month',
    this.isCompound = false,
    this.accrualMode = 'daily',
    this.allocationRule = 'interest_first',
    this.lastInterestDate,
    this.loanStartDate,
    this.phoneNumber,
    this.isClosed = false,
    this.closedAt,
    this.lastInterestPaidDate,
    this.isArchived = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isInterestBearing =>
      type == AccountType.debt || type == AccountType.lending;

  double get totalOutstanding => principalBalance + accruedInterest;

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    String? icon,
    int? color,
    double? balance,
    double? principalBalance,
    double? accruedInterest,
    double? interestRate,
    String? interestRateType,
    bool? isCompound,
    String? accrualMode,
    String? allocationRule,
    DateTime? lastInterestDate,
    DateTime? loanStartDate,
    String? phoneNumber,
    bool? isClosed,
    DateTime? closedAt,
    DateTime? lastInterestPaidDate,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      balance: balance ?? this.balance,
      principalBalance: principalBalance ?? this.principalBalance,
      accruedInterest: accruedInterest ?? this.accruedInterest,
      interestRate: interestRate ?? this.interestRate,
      interestRateType: interestRateType ?? this.interestRateType,
      isCompound: isCompound ?? this.isCompound,
      accrualMode: accrualMode ?? this.accrualMode,
      allocationRule: allocationRule ?? this.allocationRule,
      lastInterestDate: lastInterestDate ?? this.lastInterestDate,
      loanStartDate: loanStartDate ?? this.loanStartDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isClosed: isClosed ?? this.isClosed,
      closedAt: closedAt ?? this.closedAt,
      lastInterestPaidDate: lastInterestPaidDate ?? this.lastInterestPaidDate,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.key,
      'icon': icon,
      'color': color,
      'balance': balance,
      'principal_balance': principalBalance,
      'accrued_interest': accruedInterest,
      'interest_rate': interestRate,
      'interest_rate_type': interestRateType,
      'is_compound': isCompound ? 1 : 0,
      'accrual_mode': accrualMode,
      'allocation_rule': allocationRule,
      'last_interest_date': lastInterestDate?.toIso8601String(),
      'loan_start_date': loanStartDate?.toIso8601String(),
      'phone_number': phoneNumber,
      'is_closed': isClosed ? 1 : 0,
      'closed_at': closedAt?.toIso8601String(),
      'last_interest_paid_date': lastInterestPaidDate?.toIso8601String(),
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: AccountTypeExtension.fromKey(map['type'] as String),
      icon: map['icon'] as String? ?? 'account_balance_wallet',
      color: map['color'] as int? ?? 0xFF0F3E33,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      principalBalance: (map['principal_balance'] as num?)?.toDouble() ?? 0.0,
      accruedInterest: (map['accrued_interest'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      interestRateType: map['interest_rate_type'] as String? ?? 'per_month',
      isCompound: (map['is_compound'] as int?) == 1,
      accrualMode: map['accrual_mode'] as String? ?? 'daily',
      allocationRule: map['allocation_rule'] as String? ?? 'interest_first',
      lastInterestDate: map['last_interest_date'] != null
          ? DateTime.tryParse(map['last_interest_date'] as String)
          : null,
      loanStartDate: map['loan_start_date'] != null
          ? DateTime.tryParse(map['loan_start_date'] as String)
          : null,
      phoneNumber: map['phone_number'] as String?,
      isClosed: (map['is_closed'] as int?) == 1,
      closedAt: map['closed_at'] != null
          ? DateTime.tryParse(map['closed_at'] as String)
          : null,
      lastInterestPaidDate: map['last_interest_paid_date'] != null
          ? DateTime.tryParse(map['last_interest_paid_date'] as String)
          : null,
      isArchived: (map['is_archived'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
