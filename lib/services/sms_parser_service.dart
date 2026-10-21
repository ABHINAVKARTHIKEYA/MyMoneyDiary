import '../models/transaction_model.dart';

class ParsedTransaction {
  final double amount;
  final TransactionType type;
  final String? bankName;
  final String? accountLast4;
  final String merchantOrPayee;
  final String referenceId;
  final String category;
  final DateTime date;
  final String source; // 'sms' or 'notification'
  final String rawText;

  ParsedTransaction({
    required this.amount,
    required this.type,
    this.bankName,
    this.accountLast4,
    required this.merchantOrPayee,
    required this.referenceId,
    required this.category,
    required this.date,
    required this.source,
    required this.rawText,
  });

  TransactionModel toTransactionModel({required int accountId}) {
    final noteDetails = StringBuffer();
    if (merchantOrPayee.isNotEmpty && merchantOrPayee != 'UPI / Bank Transfer') {
      noteDetails.write(merchantOrPayee);
    }
    if (bankName != null && bankName!.isNotEmpty) {
      if (noteDetails.isNotEmpty) noteDetails.write(' • ');
      noteDetails.write(bankName);
    }
    if (accountLast4 != null && accountLast4!.isNotEmpty) {
      noteDetails.write(' (A/c **$accountLast4)');
    }

    return TransactionModel(
      accountId: accountId,
      type: type,
      amount: amount,
      category: category,
      note: noteDetails.isEmpty ? 'Auto-Detected via ${source.toUpperCase()}' : noteDetails.toString(),
      date: date,
      externalRefId: referenceId,
      source: source,
    );
  }
}

class SmsParserService {
  static final List<String> _bankKeywords = [
    'HDFC', 'SBI', 'ICICI', 'AXIS', 'KOTAK', 'PNB', 'BOB', 'CANARA',
    'UNION', 'INDUSIND', 'YES BANK', 'IDFC', 'CITI', 'FEDERAL', 'RBL',
    'PAYTM', 'PHONEPE', 'GPAY', 'GOOGLE PAY', 'CRED', 'BHIM'
  ];

  static ParsedTransaction? parse({
    required String sender,
    required String body,
    DateTime? timestamp,
    String source = 'sms',
  }) {
    final cleanBody = body.replaceAll('\n', ' ').trim();
    final lower = cleanBody.toLowerCase();
    final date = timestamp ?? DateTime.now();

    // 1. Guard against non-financial alerts or OTP-only messages
    final hasFinancialTerms = lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('paid') ||
        lower.contains('spent') ||
        lower.contains('sent') ||
        lower.contains('received') ||
        lower.contains('withdrawn') ||
        lower.contains('deducted') ||
        lower.contains('transfer') ||
        lower.contains('cashback') ||
        lower.contains('refund');

    if (!hasFinancialTerms) return null;

    // Filter out purely security/login OTPs that do not include a monetary debit/credit
    if (lower.contains('otp') || lower.contains('verification code')) {
      if (!lower.contains('debited') &&
          !lower.contains('credited') &&
          !lower.contains('paid rs') &&
          !lower.contains('spent rs')) {
        return null;
      }
    }

    // 2. Determine Debit vs Credit
    TransactionType? type;
    final isDebit = lower.contains('debited') ||
        lower.contains('debit') ||
        lower.contains('paid') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('deducted') ||
        lower.contains('purchase of') ||
        lower.contains('charged') ||
        lower.contains('sent rs') ||
        lower.contains('transfer to');

    final isCredit = lower.contains('credited') ||
        lower.contains('credit') ||
        lower.contains('received') ||
        lower.contains('deposited') ||
        lower.contains('refund') ||
        lower.contains('cashback') ||
        lower.contains('added to') ||
        lower.contains('transfer from');

    if (isDebit && !isCredit) {
      type = TransactionType.debit;
    } else if (isCredit && !isDebit) {
      type = TransactionType.credit;
    } else if (isDebit && isCredit) {
      // If both words appear (e.g., "debited from A/C ... and credited to XYZ"):
      // In consumer banking SMS, the user's account is usually the first action
      final debitIdx = lower.indexOf('debit');
      final creditIdx = lower.indexOf('credit');
      type = (debitIdx < creditIdx) ? TransactionType.debit : TransactionType.credit;
    } else {
      return null;
    }

    // 3. Extract Amount
    final amount = _extractAmount(cleanBody);
    if (amount == null || amount <= 0.0) return null;

    // 4. Extract Reference ID for 100% De-duplication
    final refId = _extractReferenceId(
      body: cleanBody,
      sender: sender,
      amount: amount,
      type: type,
      date: date,
    );

    // 5. Extract Bank / Card
    final bank = _extractBank(sender, cleanBody);
    final accountLast4 = _extractAccountLast4(cleanBody);

    // 6. Extract Payee / Merchant
    final merchant = _extractMerchant(cleanBody, type);

    // 7. Auto-categorize
    final category = _categorize(merchant, cleanBody);

    return ParsedTransaction(
      amount: amount,
      type: type,
      bankName: bank,
      accountLast4: accountLast4,
      merchantOrPayee: merchant,
      referenceId: refId,
      category: category,
      date: date,
      source: source,
      rawText: cleanBody,
    );
  }

  static double? _extractAmount(String text) {
    // Priority patterns for currency amounts in Indian SMS
    final patterns = [
      // Rs. 1,234.50 or INR 500 or ₹ 250
      RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // for Rs 500 / of Rs 500
      RegExp(r'(?:for|of)\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // 500.00 debited / 500 INR
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)', caseSensitive: false),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '').trim();
        if (raw != null) {
          final val = double.tryParse(raw);
          if (val != null && val > 0 && val < 100000000) {
            return val;
          }
        }
      }
    }
    return null;
  }

  static String _extractReferenceId({
    required String body,
    required String sender,
    required double amount,
    required TransactionType type,
    required DateTime date,
  }) {
    // Match UPI Ref, UTR, RRN, Ref No, Txn ID
    final refReg = RegExp(
      r'(?:upi\s*ref(?:erence)?(?:\s*no\.?)?|rrn|utr|txn\s*(?:id|ref)?|ref\s*no\.?|reference(?:\s*no\.?)?)[:\s-]*([0-9a-zA-Z]{6,25})',
      caseSensitive: false,
    );
    final match = refReg.firstMatch(body);
    if (match != null && match.group(1) != null) {
      return 'REF_${match.group(1)!.trim().toUpperCase()}';
    }

    // Fallback: Deterministic signature based on amount + type + minute + sender
    // This reliably prevents duplicates even if the bank didn't include a UPI ref
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final cleanSender = sender.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    return 'SIG_${amount.toStringAsFixed(2)}_${type.key}_${year}${month}${day}_${hour}${minute}_$cleanSender';
  }

  static String? _extractBank(String sender, String body) {
    final upperSender = sender.toUpperCase();
    final upperBody = body.toUpperCase();

    for (final b in _bankKeywords) {
      if (upperSender.contains(b) || upperBody.contains(b)) {
        return b;
      }
    }
    return null;
  }

  static String? _extractAccountLast4(String body) {
    final reg = RegExp(
      r'(?:a\/c|acct|account|card)\s*(?:no\.?)?\s*(?:ending\s*)?[xX*]*([0-9]{4})',
      caseSensitive: false,
    );
    final match = reg.firstMatch(body);
    return match?.group(1);
  }

  static String _extractMerchant(String body, TransactionType type) {
    if (type == TransactionType.debit) {
      // Look for "to <Merchant>" or "at <Merchant>"
      final reg = RegExp(
        r'(?:to|at|info\/)\s+([A-Za-z0-9\s.&]{2,30}?)(?:\s+(?:on|via|ref|using|avl|bal|clear|ending|dated|\.|\n)|$)',
        caseSensitive: false,
      );
      final match = reg.firstMatch(body);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.length >= 2 && !_isIgnoredWord(name)) {
          return _cleanMerchantName(name);
        }
      }
    } else {
      // Look for "from <Sender>"
      final reg = RegExp(
        r'(?:from)\s+([A-Za-z0-9\s.&]{2,30}?)(?:\s+(?:on|via|ref|using|avl|bal|to|ending|dated|\.|\n)|$)',
        caseSensitive: false,
      );
      final match = reg.firstMatch(body);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.length >= 2 && !_isIgnoredWord(name)) {
          return _cleanMerchantName(name);
        }
      }
    }

    return 'UPI / Bank Transfer';
  }

  static bool _isIgnoredWord(String word) {
    final lower = word.toLowerCase();
    return lower == 'account' ||
        lower == 'a/c' ||
        lower == 'vpa' ||
        lower == 'bank' ||
        lower == 'your' ||
        lower == 'not' ||
        lower.contains('ref') ||
        lower.contains('bal');
  }

  static String _cleanMerchantName(String name) {
    return name
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s.&]'), '')
        .trim();
  }

  static String _categorize(String merchant, String body) {
    final text = '$merchant $body'.toLowerCase();

    if (text.contains('swiggy') ||
        text.contains('zomato') ||
        text.contains('mcdonald') ||
        text.contains('kfc') ||
        text.contains('starbucks') ||
        text.contains('cafe') ||
        text.contains('chai') ||
        text.contains('restaurant') ||
        text.contains('food') ||
        text.contains('dining') ||
        text.contains('pizza')) {
      return 'Food & Dining';
    }

    if (text.contains('amazon') ||
        text.contains('flipkart') ||
        text.contains('myntra') ||
        text.contains('meesho') ||
        text.contains('blinkit') ||
        text.contains('zepto') ||
        text.contains('instamart') ||
        text.contains('bigbasket') ||
        text.contains('supermarket') ||
        text.contains('grocer') ||
        text.contains('mart')) {
      return 'Shopping & Groceries';
    }

    if (text.contains('uber') ||
        text.contains('ola') ||
        text.contains('rapido') ||
        text.contains('metro') ||
        text.contains('petrol') ||
        text.contains('fuel') ||
        text.contains('hpcl') ||
        text.contains('bpcl') ||
        text.contains('iocl')) {
      return 'Travel & Fuel';
    }

    if (text.contains('airtel') ||
        text.contains('jio') ||
        text.contains('vi ') ||
        text.contains('vodafone') ||
        text.contains('electricity') ||
        text.contains('bescom') ||
        text.contains('water') ||
        text.contains('gas') ||
        text.contains('bill') ||
        text.contains('recharge') ||
        text.contains('broadband')) {
      return 'Utilities & Bills';
    }

    if (text.contains('hospital') ||
        text.contains('clinic') ||
        text.contains('pharmacy') ||
        text.contains('apollo') ||
        text.contains('medplus') ||
        text.contains('pharmeasy') ||
        text.contains('1mg') ||
        text.contains('medical')) {
      return 'Health & Medical';
    }

    return 'Auto-Detected';
  }
}
