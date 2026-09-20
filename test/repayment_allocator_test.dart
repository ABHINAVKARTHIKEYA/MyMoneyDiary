import 'package:test/test.dart';
import '../lib/services/repayment_allocator.dart';

void main() {
  group('RepaymentAllocator Tests', () {
    test('interest_first rule when payment is less than accrued interest', () {
      final split = RepaymentAllocator.calculateSplit(
        paymentAmount: 500.0,
        currentPrincipal: 10000.0,
        accruedInterest: 1000.0,
        allocationRule: 'interest_first',
      );
      expect(split.interestPortion, equals(500.0));
      expect(split.principalPortion, equals(0.0));
    });

    test('interest_first rule when payment exceeds accrued interest', () {
      final split = RepaymentAllocator.calculateSplit(
        paymentAmount: 2500.0,
        currentPrincipal: 10000.0,
        accruedInterest: 1000.0,
        allocationRule: 'interest_first',
      );
      expect(split.interestPortion, equals(1000.0));
      expect(split.principalPortion, equals(1500.0));
    });

    test('principal_first rule when payment is less than principal', () {
      final split = RepaymentAllocator.calculateSplit(
        paymentAmount: 5000.0,
        currentPrincipal: 10000.0,
        accruedInterest: 1000.0,
        allocationRule: 'principal_first',
      );
      expect(split.principalPortion, equals(5000.0));
      expect(split.interestPortion, equals(0.0));
    });

    test('principal_first rule when payment exceeds principal', () {
      final split = RepaymentAllocator.calculateSplit(
        paymentAmount: 10500.0,
        currentPrincipal: 10000.0,
        accruedInterest: 1000.0,
        allocationRule: 'principal_first',
      );
      expect(split.principalPortion, equals(10000.0));
      expect(split.interestPortion, equals(500.0));
    });

    test('isValidSplit validates correct split sum', () {
      final valid = RepaymentAllocator.isValidSplit(
        paymentAmount: 2000.0,
        userInterestPortion: 600.0,
        userPrincipalPortion: 1400.0,
      );
      expect(valid, isTrue);

      final invalid = RepaymentAllocator.isValidSplit(
        paymentAmount: 2000.0,
        userInterestPortion: 600.0,
        userPrincipalPortion: 1200.0,
      );
      expect(invalid, isFalse);
    });
  });
}
