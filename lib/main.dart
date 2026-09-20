import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database_helper.dart';
import 'providers/finance_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lock_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database
  await DatabaseHelper.instance.database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FinanceProvider()..loadAllData(),
        ),
      ],
      child: const MyMoneyDiaryApp(),
    ),
  );
}

class MyMoneyDiaryApp extends StatelessWidget {
  const MyMoneyDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final settings = finance.settings;

    final hasSecurity = settings.isPinEnabled || settings.isBiometricEnabled;

    return MaterialApp(
      title: 'MY MONEY DIARY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode == 'emerald_dark'
          ? ThemeMode.dark
          : ThemeMode.light,
      home: hasSecurity ? const LockScreen() : const DashboardScreen(),
    );
  }
}
