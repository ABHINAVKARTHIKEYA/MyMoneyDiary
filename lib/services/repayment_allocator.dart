class RepaymentSplit {
  final double interestPortion;
  final double principalPortion;

  RepaymentSplit({
    required this.interestPortion,
    required this.principalPortion,
  });

  double get total => interestPortion + principalPortion;
}

class RepaymentAllocator {
  /// Computes default repayment split based on allocation preference
  static RepaymentSplit calculateSplit({
    required double paymentAmount,
    required double currentPrincipal,
    required double accruedInterest,
    required String allocationRule, // 'interest_first' or 'principal_first'
  }) {
    if (paymentAmount <= 0) {
      return RepaymentSplit(interestPortion: 0.0, principalPortion: 0.0);
    }

    if (allocationRule == 'principal_first') {
      if (paymentAmount <= currentPrincipal) {
        return RepaymentSplit(
          principalPortion: paymentAmount,
          interestPortion: 0.0,
        );
      } else {
        final principalPaid = currentPrincipal;
        final remainder = paymentAmount - currentPrincipal;
        final interestPaid =
            remainder <= accruedInterest ? remainder : accruedInterest;
        return RepaymentSplit(
          principalPortion: principalPaid,
          interestPortion: interestPaid,
        );
      }
    } else {
      // Default: 'interest_first'
      if (paymentAmount <= accruedInterest) {
        return RepaymentSplit(
          interestPortion: paymentAmount,
          principalPortion: 0.0,
        );
      } else {
        final interestPaid = accruedInterest;
        final remainder = paymentAmount - accruedInterest;
        final principalPaid =
            remainder <= currentPrincipal ? remainder : currentPrincipal;
        return RepaymentSplit(
          interestPortion: interestPaid,
          principalPortion: principalPaid,
        );
      }
    }
  }

  /// Validates a manual split entered by the user
  static bool isValidSplit({
    required double paymentAmount,
    required double userInterestPortion,
    required double userPrincipalPortion,
  }) {
    final sum = userInterestPortion + userPrincipalPortion;
    return (sum - paymentAmount).abs() < 0.01;
  }
}
