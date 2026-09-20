class InterestCalculator {
  /// Calculates daily interest rate as a fraction
  static double getDailyRate({
    required double rate,
    required String rateType, // 'per_month' or 'per_annum'
  }) {
    if (rate <= 0) return 0.0;
    if (rateType == 'per_month') {
      // Monthly rate, e.g., 2% per month (₹2 per ₹100/mo)
      // Daily rate = (rate / 100) / 30
      return (rate / 100.0) / 30.0;
    } else {
      // Annual rate, e.g., 12% per annum
      // Daily rate = (rate / 100) / 365
      return (rate / 100.0) / 365.0;
    }
  }

  /// Calculates monthly interest amount on a principal
  static double calculateMonthlyInterestAmount({
    required double principal,
    required double rate,
    required String rateType,
  }) {
    if (principal <= 0 || rate <= 0) return 0.0;
    if (rateType == 'per_month') {
      return principal * (rate / 100.0);
    } else {
      return principal * ((rate / 100.0) / 12.0);
    }
  }

  /// Calculates accrued interest between two dates
  static double calculateAccruedInterest({
    required double principal,
    required double rate,
    required String rateType,
    required bool isCompound,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    if (principal <= 0 || rate <= 0 || toDate.isBefore(fromDate)) {
      return 0.0;
    }

    final totalDays = toDate.difference(fromDate).inDays;
    if (totalDays <= 0) return 0.0;

    if (!isCompound) {
      // Simple Interest: P * r_daily * days
      final dailyRate = getDailyRate(rate: rate, rateType: rateType);
      return principal * dailyRate * totalDays;
    } else {
      // Compound Interest (monthly compounding)
      // Monthly rate:
      final monthlyRate = rateType == 'per_month'
          ? (rate / 100.0)
          : ((rate / 100.0) / 12.0);

      // Estimate full 30-day months and remaining days
      final fullMonths = totalDays ~/ 30;
      final remainingDays = totalDays % 30;

      double compoundedPrincipal = principal;
      for (int i = 0; i < fullMonths; i++) {
        compoundedPrincipal *= (1.0 + monthlyRate);
      }

      // Add simple interest on compounded principal for remaining days
      final dailyRate = getDailyRate(rate: rate, rateType: rateType);
      final remainingInterest = compoundedPrincipal * dailyRate * remainingDays;

      return (compoundedPrincipal + remainingInterest) - principal;
    }
  }
}
