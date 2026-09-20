class AppSettings {
  final String currencySymbol;
  final bool isBiometricEnabled;
  final bool isPinEnabled;
  final String? pinCode;
  final String defaultAllocationRule; // 'interest_first' or 'principal_first'
  final String themeMode; // 'emerald_light', 'emerald_dark', 'system'

  AppSettings({
    this.currencySymbol = '₹',
    this.isBiometricEnabled = false,
    this.isPinEnabled = false,
    this.pinCode,
    this.defaultAllocationRule = 'interest_first',
    this.themeMode = 'emerald_light',
  });

  AppSettings copyWith({
    String? currencySymbol,
    bool? isBiometricEnabled,
    bool? isPinEnabled,
    String? pinCode,
    String? defaultAllocationRule,
    String? themeMode,
  }) {
    return AppSettings(
      currencySymbol: currencySymbol ?? this.currencySymbol,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      pinCode: pinCode ?? this.pinCode,
      defaultAllocationRule:
          defaultAllocationRule ?? this.defaultAllocationRule,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currency_symbol': currencySymbol,
      'is_biometric_enabled': isBiometricEnabled ? 1 : 0,
      'is_pin_enabled': isPinEnabled ? 1 : 0,
      'pin_code': pinCode,
      'default_allocation_rule': defaultAllocationRule,
      'theme_mode': themeMode,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      currencySymbol: map['currency_symbol'] as String? ?? '₹',
      isBiometricEnabled: (map['is_biometric_enabled'] as int?) == 1,
      isPinEnabled: (map['is_pin_enabled'] as int?) == 1,
      pinCode: map['pin_code'] as String?,
      defaultAllocationRule:
          map['default_allocation_rule'] as String? ?? 'interest_first',
      themeMode: map['theme_mode'] as String? ?? 'emerald_light',
    );
  }
}
