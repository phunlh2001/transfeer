import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'state/market_session.dart';
import 'state/portfolio_store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TransfeerApp());
}

class TransfeerApp extends StatelessWidget {
  const TransfeerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MarketSession()),
        ChangeNotifierProvider(create: (_) => PortfolioStore()..load()),
      ],
      child: MaterialApp(
        title: 'Transfeer · FUESSV30',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        // Whole app in Vietnamese (incl. built-in Material texts).
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AppShell(),
      ),
    );
  }
}
