class DateDuration {
  final int years;
  final int months;
  final int days;

  const DateDuration({
    required this.years,
    required this.months,
    required this.days,
  });

  /// Computes the exact elapsed duration in years, months, and days between [start] and [end].
  static DateDuration between(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      return const DateDuration(years: 0, months: 0, days: 0);
    }

    int years = end.year - start.year;
    int months = end.month - start.month;
    int days = end.day - start.day;

    if (days < 0) {
      // Days in the month prior to `end`
      final prevMonthLastDay = DateTime(end.year, end.month, 0).day;
      days += prevMonthLastDay;
      months -= 1;
    }

    if (months < 0) {
      months += 12;
      years -= 1;
    }

    if (years < 0) {
      years = 0;
      months = 0;
      days = 0;
    }

    return DateDuration(years: years, months: months, days: days);
  }

  /// Formats the duration explicitly showing years, months, and days
  /// Example: "1 year, 3 months, 12 days" or "0 years, 2 months, 5 days"
  String formatExplicit() {
    final yStr = '$years ${years == 1 ? "year" : "years"}';
    final mStr = '$months ${months == 1 ? "month" : "months"}';
    final dStr = '$days ${days == 1 ? "day" : "days"}';
    return '$yStr, $mStr, $dStr';
  }

  /// Formats the duration omitting zero-value higher units if desired
  /// Example: "3 months, 12 days" or "5 days"
  String formatCompact() {
    final parts = <String>[];
    if (years > 0) parts.add('$years ${years == 1 ? "year" : "years"}');
    if (months > 0) parts.add('$months ${months == 1 ? "month" : "months"}');
    parts.add('$days ${days == 1 ? "day" : "days"}');
    return parts.join(', ');
  }

  @override
  String toString() => formatExplicit();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateDuration &&
          runtimeType == other.runtimeType &&
          years == other.years &&
          months == other.months &&
          days == other.days;

  @override
  int get hashCode => years.hashCode ^ months.hashCode ^ days.hashCode;
}
