import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tryBiometricAuth();
  }

  Future<void> _tryBiometricAuth() async {
    final finance = context.read<FinanceProvider>();
    if (!finance.settings.isBiometricEnabled) return;

    try {
      final canAuth = await _auth.canCheckBiometrics;
      if (canAuth) {
        final didAuth = await _auth.authenticate(
          localizedReason: 'Unlock My Money Diary',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (didAuth && mounted) {
          _unlockApp();
        }
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    }
  }

  void _unlockApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _verifyPin() {
    final finance = context.read<FinanceProvider>();
    final entered = _pinController.text.trim();
    if (entered == finance.settings.pinCode) {
      _unlockApp();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.emeraldDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.account_balance_wallet,
                      size: 88,
                      color: AppTheme.amberGold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'MY MONEY DIARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter PIN to unlock your diary',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // PIN Input
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withAlpha(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      if (val.length == 4) {
                        _verifyPin();
                      }
                    },
                  ),
                ),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: AppTheme.debitRed, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 24),

                IconButton(
                  icon: const Icon(Icons.fingerprint,
                      size: 44, color: AppTheme.amberGold),
                  onPressed: _tryBiometricAuth,
                  tooltip: 'Unlock with Biometrics',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
