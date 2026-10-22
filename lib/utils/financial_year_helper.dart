class FinancialYearHelper {
  /// Returns the FY start year for a given date.
  /// If date is on or after April 1, start year is date.year.
  /// If date is before April 1, start year is date.year - 1.
  static int getFYStartYear(DateTime date) {
    return date.month >= 4 ? date.year : date.year - 1;
  }

  /// Formats the financial year label, e.g., 'FY 2025-26'
  static String formatFY(int startYear) {
    final nextYearTwoDigits = (startYear + 1) % 100;
    final nextYearStr = nextYearTwoDigits < 10 ? '0$nextYearTwoDigits' : '$nextYearTwoDigits';
    return 'FY $startYear-$nextYearStr';
  }

  /// Current Indian Financial Year label
  static String currentFinancialYear() {
    return formatFY(getFYStartYear(DateTime.now()));
  }

  /// Returns start DateTime (April 1, 00:00:00) for given FY start year
  static DateTime getStartDate(int startYear) {
    return DateTime(startYear, 4, 1, 0, 0, 0);
  }

  /// Returns end DateTime (March 31, 23:59:59) for given FY start year
  static DateTime getEndDate(int startYear) {
    return DateTime(startYear + 1, 3, 31, 23, 59, 59);
  }

  /// Parses 'FY 2025-26' or '2025-26' into start year
  static int parseStartYear(String fyString) {
    final cleaned = fyString.replaceAll('FY', '').trim();
    final parts = cleaned.split('-');
    if (parts.isNotEmpty) {
      return int.tryParse(parts[0].trim()) ?? getFYStartYear(DateTime.now());
    }
    return getFYStartYear(DateTime.now());
  }

  /// Returns available FY options covering recent and upcoming financial years
  static List<String> getAvailableFinancialYears({int count = 5}) {
    final currentYear = getFYStartYear(DateTime.now());
    final list = <String>[];
    for (int i = -2; i <= 2; i++) {
      list.add(formatFY(currentYear + i));
    }
    return list;
  }
}
