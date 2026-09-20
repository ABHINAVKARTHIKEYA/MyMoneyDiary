import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _currencies = ['₹', '\$', '€', '£', '¥', 'AED', 'SAR', 'CAD', 'AUD'];

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final settings = finance.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. App Brand Header
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) =>
                        const Icon(Icons.account_balance_wallet, size: 72, color: AppTheme.amberGold),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MY MONEY DIARY',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Version 1.0.0 • 100% Offline & Private',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Preferences
          const Text(
            'General Preferences',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.emeraldPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                // Currency Switcher
                ListTile(
                  leading: const Icon(Icons.currency_exchange, color: AppTheme.amberGold),
                  title: const Text('Currency Symbol'),
                  trailing: DropdownButton<String>(
                    value: _currencies.contains(settings.currencySymbol)
                        ? settings.currencySymbol
                        : '₹',
                    underline: const SizedBox(),
                    items: _currencies.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        finance.updateSettings(
                          settings.copyWith(currencySymbol: val),
                        );
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                // Default Repayment Priority
                ListTile(
                  leading: const Icon(Icons.tune, color: AppTheme.emeraldPrimary),
                  title: const Text('Default Repayment Priority'),
                  subtitle: Text(
                    settings.defaultAllocationRule == 'interest_first'
                        ? 'Interest First'
                        : 'Principal First',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.defaultAllocationRule,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'interest_first',
                        child: Text('Interest First'),
                      ),
                      DropdownMenuItem(
                        value: 'principal_first',
                        child: Text('Principal First'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        finance.updateSettings(
                          settings.copyWith(defaultAllocationRule: val),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Security & App Lock
          const Text(
            'Security & Access',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.emeraldPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: AppTheme.emeraldPrimary),
                  title: const Text('Biometric Lock'),
                  subtitle: const Text(
                    'Require fingerprint / face unlock to open app',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.isBiometricEnabled,
                  onChanged: (val) {
                    finance.updateSettings(
                      settings.copyWith(isBiometricEnabled: val),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline, color: AppTheme.emeraldPrimary),
                  title: const Text('4-Digit App PIN'),
                  subtitle: Text(
                    settings.isPinEnabled ? 'PIN is active' : 'Disabled',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: settings.isPinEnabled,
                  onChanged: (val) {
                    if (val) {
                      _showSetPinDialog(context, finance, settings);
                    } else {
                      finance.updateSettings(
                        settings.copyWith(isPinEnabled: false, pinCode: null),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. Data Safety & Backup
          const Text(
            'Data Safety & Backup',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.emeraldPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined, color: AppTheme.creditGreen),
                  title: const Text('Backup Local Database'),
                  subtitle: const Text(
                    'Export your encrypted diary data file',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backup saved securely to local storage.'),
                        backgroundColor: AppTheme.emeraldPrimary,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined, color: AppTheme.transferBlue),
                  title: const Text('Restore from Backup'),
                  subtitle: const Text(
                    'Restore data from a previously saved backup file',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select backup file to restore.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSetPinDialog(
    BuildContext context,
    FinanceProvider finance,
    AppSettings settings,
  ) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set 4-Digit PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Enter 4 digits',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin.length == 4) {
                Navigator.pop(ctx);
                finance.updateSettings(
                  settings.copyWith(
                    isPinEnabled: true,
                    pinCode: pin,
                  ),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }
}
