import 'package:test/test.dart';
import '../lib/services/interest_calculator.dart';

void main() {
  group('InterestCalculator Tests', () {
    test('calculateDailyRate for per_month (₹ per ₹100/mo)', () {
      // 2% per month => (2 / 100) / 30 = 0.000666...
      final rate = InterestCalculator.getDailyRate(
        rate: 2.0,
        rateType: 'per_month',
      );
      expect(rate, closeTo(0.0006666, 0.00001));
    });

    test('calculateDailyRate for per_annum (% p.a.)', () {
      // 12% per year => (12 / 100) / 365
      final rate = InterestCalculator.getDailyRate(
        rate: 12.0,
        rateType: 'per_annum',
      );
      expect(rate, closeTo(0.0003287, 0.00001));
    });

    test('calculateMonthlyInterestAmount for per_month', () {
      // Principal 1,00,000 at 2% per month = 2,000
      final interest = InterestCalculator.calculateMonthlyInterestAmount(
        principal: 100000.0,
        rate: 2.0,
        rateType: 'per_month',
      );
      expect(interest, equals(2000.0));
    });

    test('calculateMonthlyInterestAmount for per_annum', () {
      // Principal 1,20,000 at 12% per year = 1,200 per month
      final interest = InterestCalculator.calculateMonthlyInterestAmount(
        principal: 120000.0,
        rate: 12.0,
        rateType: 'per_annum',
      );
      expect(interest, equals(1200.0));
    });

    test('calculateAccruedInterest simple interest for 60 days at 2% per month', () {
      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 3, 2); // 60 days
      final interest = InterestCalculator.calculateAccruedInterest(
        principal: 50000.0,
        rate: 2.0,
        rateType: 'per_month',
        isCompound: false,
        fromDate: from,
        toDate: to,
      );
      // 50000 * (0.02 / 30) * 60 = 2000
      expect(interest, closeTo(2000.0, 1.0));
    });

    test('calculateAccruedInterest compound interest for 60 days (2 months)', () {
      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 3, 2); // 60 days
      final interest = InterestCalculator.calculateAccruedInterest(
        principal: 50000.0,
        rate: 2.0,
        rateType: 'per_month',
        isCompound: true,
        fromDate: from,
        toDate: to,
      );
      // Month 1: 50,000 * 0.02 = 1,000 => Principal = 51,000
      // Month 2: 51,000 * 0.02 = 1,020 => Total Interest = 2,020
      expect(interest, closeTo(2020.0, 1.0));
    });
  });
}
