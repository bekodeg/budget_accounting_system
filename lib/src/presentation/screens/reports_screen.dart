import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import 'monthly_report_screen.dart';
import 'period_report_screen.dart';
import 'year_report_screen.dart';

final class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    required this.services,
    required this.budgetId,
    required this.userId,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        key: const ValueKey('reports-screen'),
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Месяц'),
              Tab(text: 'Год'),
              Tab(text: 'Период'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                MonthlyReportScreen(services: services, budgetId: budgetId),
                YearReportScreen(services: services, budgetId: budgetId),
                PeriodReportScreen(
                  services: services,
                  budgetId: budgetId,
                  userId: userId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
