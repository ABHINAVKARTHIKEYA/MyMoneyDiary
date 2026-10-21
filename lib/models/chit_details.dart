class ChitDetails {
  final int? id;
  final int accountId;
  final double totalValue;
  final int durationMonths;
  final double nominalInstallment; // Kept for backwards compatibility
  final double installmentBeforeLifting;
  final double installmentAfterLifting;
  final int currentMonth;
  final bool isLifted;
  final int? liftedMonth;
  final double? prizeMoneyReceived;
  final double? bidDiscount;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  ChitDetails({
    this.id,
    required this.accountId,
    required this.totalValue,
    required this.durationMonths,
    double? nominalInstallment,
    double? installmentBeforeLifting,
    double? installmentAfterLifting,
    this.currentMonth = 0,
    this.isLifted = false,
    this.liftedMonth,
    this.prizeMoneyReceived,
    this.bidDiscount,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  })  : nominalInstallment = nominalInstallment ?? installmentBeforeLifting ?? (durationMonths > 0 ? totalValue / durationMonths : 0.0),
        installmentBeforeLifting = installmentBeforeLifting ?? nominalInstallment ?? (durationMonths > 0 ? totalValue / durationMonths : 0.0),
        installmentAfterLifting = installmentAfterLifting ?? nominalInstallment ?? (durationMonths > 0 ? totalValue / durationMonths : 0.0),
        startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? (startDate ?? DateTime.now()).add(Duration(days: durationMonths * 30)),
        createdAt = createdAt ?? DateTime.now();

  double get activeInstallment => isLifted ? installmentAfterLifting : installmentBeforeLifting;

  int get remainingMonths =>
      (durationMonths - currentMonth).clamp(0, durationMonths);

  double get progressPercentage =>
      durationMonths > 0 ? (currentMonth / durationMonths).clamp(0.0, 1.0) : 0.0;

  ChitDetails copyWith({
    int? id,
    int? accountId,
    double? totalValue,
    int? durationMonths,
    double? nominalInstallment,
    double? installmentBeforeLifting,
    double? installmentAfterLifting,
    int? currentMonth,
    bool? isLifted,
    int? liftedMonth,
    double? prizeMoneyReceived,
    double? bidDiscount,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return ChitDetails(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      totalValue: totalValue ?? this.totalValue,
      durationMonths: durationMonths ?? this.durationMonths,
      nominalInstallment: nominalInstallment ?? this.nominalInstallment,
      installmentBeforeLifting: installmentBeforeLifting ?? this.installmentBeforeLifting,
      installmentAfterLifting: installmentAfterLifting ?? this.installmentAfterLifting,
      currentMonth: currentMonth ?? this.currentMonth,
      isLifted: isLifted ?? this.isLifted,
      liftedMonth: liftedMonth ?? this.liftedMonth,
      prizeMoneyReceived: prizeMoneyReceived ?? this.prizeMoneyReceived,
      bidDiscount: bidDiscount ?? this.bidDiscount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'total_value': totalValue,
      'duration_months': durationMonths,
      'nominal_installment': nominalInstallment,
      'installment_before_lifting': installmentBeforeLifting,
      'installment_after_lifting': installmentAfterLifting,
      'current_month': currentMonth,
      'is_lifted': isLifted ? 1 : 0,
      'lifted_month': liftedMonth,
      'prize_money_received': prizeMoneyReceived,
      'bid_discount': bidDiscount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChitDetails.fromMap(Map<String, dynamic> map) {
    final start = map['start_date'] != null
        ? DateTime.parse(map['start_date'] as String)
        : DateTime.now();
    final dur = map['duration_months'] as int? ?? 1;
    final end = map['end_date'] != null
        ? DateTime.parse(map['end_date'] as String)
        : start.add(Duration(days: dur * 30));

    final nominal = (map['nominal_installment'] as num?)?.toDouble() ?? 0.0;
    final before = (map['installment_before_lifting'] as num?)?.toDouble() ?? nominal;
    final after = (map['installment_after_lifting'] as num?)?.toDouble() ?? nominal;

    return ChitDetails(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      totalValue: (map['total_value'] as num).toDouble(),
      durationMonths: dur,
      nominalInstallment: nominal,
      installmentBeforeLifting: before,
      installmentAfterLifting: after,
      currentMonth: map['current_month'] as int? ?? 0,
      isLifted: (map['is_lifted'] as int?) == 1,
      liftedMonth: map['lifted_month'] as int?,
      prizeMoneyReceived: (map['prize_money_received'] as num?)?.toDouble(),
      bidDiscount: (map['bid_discount'] as num?)?.toDouble(),
      startDate: start,
      endDate: end,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
