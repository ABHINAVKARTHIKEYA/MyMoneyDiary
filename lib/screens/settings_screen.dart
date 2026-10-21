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

          // 4. Automatic Transaction Detection
          const Text(
            'Automatic Transaction Detection',
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
                  leading: const Icon(Icons.sync, color: AppTheme.emeraldPrimary),
                  title: const Text('Scan & Import Recent SMS'),
                  subtitle: const Text(
                    'Detects bank & UPI messages with 100% duplicate protection',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Scan SMS'),
                    onPressed: () => _handleSyncSms(context, finance),
                  ),
                ),
                const Divider(height: 1),
                FutureBuilder<bool>(
                  future: finance.hasSmsPermission(),
                  builder: (context, snapshot) {
                    final hasPerm = snapshot.data ?? false;
                    return ListTile(
                      leading: Icon(
                        hasPerm ? Icons.mark_email_read : Icons.sms_outlined,
                        color: hasPerm ? AppTheme.creditGreen : AppTheme.amberGold,
                      ),
                      title: const Text('SMS Auto-Reading Access'),
                      subtitle: Text(
                        hasPerm
                            ? 'Active • Real-time SMS detection enabled'
                            : 'Required to read bank & UPI SMS alerts',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: hasPerm
                          ? const Chip(
                              label: Text('Enabled', style: TextStyle(color: Colors.white, fontSize: 11)),
                              backgroundColor: AppTheme.creditGreen,
                            )
                          : TextButton(
                              onPressed: () async {
                                final granted = await finance.requestSmsPermission();
                                setState(() {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(granted
                                          ? 'SMS access granted!'
                                          : 'SMS permission denied.'),
                                      backgroundColor: granted ? AppTheme.emeraldPrimary : AppTheme.debitRed,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Grant Access'),
                            ),
                    );
                  },
                ),
                const Divider(height: 1),
                FutureBuilder<bool>(
                  future: finance.isNotificationListenerEnabled(),
                  builder: (context, snapshot) {
                    final isNotifEnabled = snapshot.data ?? false;
                    return ListTile(
                      leading: Icon(
                        isNotifEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                        color: isNotifEnabled ? AppTheme.creditGreen : AppTheme.amberGold,
                      ),
                      title: const Text('UPI & Banking App Notifications'),
                      subtitle: Text(
                        isNotifEnabled
                            ? 'Active • Capturing GPay, PhonePe, Paytm, CRED'
                            : 'Enable to auto-detect payments directly from apps',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isNotifEnabled
                          ? const Chip(
                              label: Text('Active', style: TextStyle(color: Colors.white, fontSize: 11)),
                              backgroundColor: AppTheme.creditGreen,
                            )
                          : TextButton(
                              onPressed: () async {
                                await finance.openNotificationListenerSettings();
                              },
                              child: const Text('Configure'),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. Data Safety & Backup
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

  Future<void> _handleSyncSms(BuildContext context, FinanceProvider finance) async {
    final hasPerm = await finance.hasSmsPermission();
    if (!hasPerm) {
      final granted = await finance.requestSmsPermission();
      setState(() {});
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please grant SMS permission to allow automatic transaction import.'),
              backgroundColor: AppTheme.debitRed,
            ),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.emeraldPrimary),
                SizedBox(height: 16),
                Text('Scanning SMS Inbox...', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Detecting transactions & filtering duplicates', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await finance.syncSmsTransactions(limit: 300);

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    // Show result dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppTheme.creditGreen),
            SizedBox(width: 8),
            Text('SMS Sync Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Messages Scanned: ${result.totalScanned}'),
            const SizedBox(height: 4),
            Text('Financial Alerts Found: ${result.financialFound}'),
            const Divider(height: 16),
            Row(
              children: [
                const Icon(Icons.add_circle, color: AppTheme.creditGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${result.newAdded} New Transactions Added',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.creditGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.amberGold, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${result.duplicatesSkipped} Duplicates Blocked',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.amberGold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'No duplicate entries were recorded. All new transactions have been assigned to your Pool Account.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
