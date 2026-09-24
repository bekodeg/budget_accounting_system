import 'dart:async';

import 'package:flutter/material.dart';

import 'application/app_services.dart';
import 'presentation/screens/app_bootstrap.dart';

class BudgetAccountingApp extends StatefulWidget {
  const BudgetAccountingApp({
    required this.services,
    this.onDispose,
    super.key,
  });

  final AppServices services;
  final Future<void> Function()? onDispose;

  @override
  State<BudgetAccountingApp> createState() => _BudgetAccountingAppState();
}

class _BudgetAccountingAppState extends State<BudgetAccountingApp> {
  @override
  void dispose() {
    final onDispose = widget.onDispose;
    if (onDispose != null) {
      unawaited(onDispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Accounting',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: AppBootstrap(services: widget.services),
    );
  }
}
