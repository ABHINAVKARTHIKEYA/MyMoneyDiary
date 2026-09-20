enum AccountType {
  pool,
  debt,
  lending,
  chit,
  temporaryAdjustment,
  maintenance,
  miscellaneous,
  custom,
}

extension AccountTypeExtension on AccountType {
  String get key {
    switch (this) {
      case AccountType.pool:
        return 'pool';
      case AccountType.debt:
        return 'debt';
      case AccountType.lending:
        return 'lending';
      case AccountType.chit:
        return 'chit';
      case AccountType.temporaryAdjustment:
        return 'temporary_adjustment';
      case AccountType.maintenance:
        return 'maintenance';
      case AccountType.miscellaneous:
        return 'miscellaneous';
      case AccountType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case AccountType.pool:
        return 'Pool Account';
      case AccountType.debt:
        return 'Debt (I Owe)';
      case AccountType.lending:
        return 'Lending (Owed to Me)';
      case AccountType.chit:
        return 'Chit Fund (CHITS)';
      case AccountType.temporaryAdjustment:
        return 'Temporary Adjustment';
      case AccountType.maintenance:
        return 'Maintenance';
      case AccountType.miscellaneous:
        return 'Miscellaneous';
      case AccountType.custom:
        return 'Custom Account';
    }
  }

  static AccountType fromKey(String key) {
    switch (key) {
      case 'pool':
        return AccountType.pool;
      case 'debt':
        return AccountType.debt;
      case 'lending':
        return AccountType.lending;
      case 'chit':
        return AccountType.chit;
      case 'temporary_adjustment':
        return AccountType.temporaryAdjustment;
      case 'maintenance':
        return AccountType.maintenance;
      case 'miscellaneous':
        return AccountType.miscellaneous;
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
      isArchived: (map['is_archived'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
