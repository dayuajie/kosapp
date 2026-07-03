import 'package:flutter/material.dart';
import 'package:kos_app/presentation/pages/root_page.dart';
import 'package:kos_app/presentation/pages/finance/user_finance/finance_page.dart';
import 'package:kos_app/presentation/pages/tenants_page.dart';


class KosApp extends StatelessWidget {
  const KosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Manajemen Kos',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D5EF6)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
      ),
      routes: {
        '/': (_) => const RootPage(),
        '/transactions': (_) => const FinancePage(),
        '/tenants': (_) => const TenantsPage(),
      },
      initialRoute: '/',
    );
  }
}


