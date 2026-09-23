import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import 'account_management_screen.dart';
import 'category_management_screen.dart';

final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.services,
    required this.budgetId,
    super.key,
  });

  final AppServices services;
  final String budgetId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        key: const ValueKey('settings-screen'),
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Счета'),
              Tab(text: 'Категории'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AccountManagementScreen(
                  services: services,
                  budgetId: budgetId,
                ),
                CategoryManagementScreen(
                  services: services,
                  budgetId: budgetId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
