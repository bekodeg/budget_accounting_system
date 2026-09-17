import 'package:flutter/material.dart';

import 'data/dal/dal.dart';

class BudgetAccountingApp extends StatefulWidget {
  const BudgetAccountingApp({super.key});

  @override
  State<BudgetAccountingApp> createState() => _BudgetAccountingAppState();
}

class _BudgetAccountingAppState extends State<BudgetAccountingApp> {
  late final BudgetDal _dal;

  @override
  void initState() {
    super.initState();
    _dal = BudgetDal.defaults();
  }

  @override
  void dispose() {
    _dal.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Accounting',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Text('Budget Accounting System'),
        ),
      ),
    );
  }
}
