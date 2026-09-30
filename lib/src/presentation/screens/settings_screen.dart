import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/authorization/budget_action.dart';
import 'account_management_screen.dart';
import 'category_management_screen.dart';
import 'budget_members_screen.dart';

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
    return FutureBuilder<bool>(
      future: services.canPerformBudgetAction(
        budgetId: budgetId,
        action: BudgetAction.mutate,
      ),
      builder: (context, snapshot) {
        final canEdit = snapshot.data ?? false;
        return DefaultTabController(
          length: 3,
          child: Column(
            key: const ValueKey('settings-screen'),
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Счета'),
                  Tab(text: 'Категории'),
                  Tab(text: 'Участники'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    AccountManagementScreen(
                      services: services,
                      budgetId: budgetId,
                      canEdit: canEdit,
                    ),
                    CategoryManagementScreen(
                      services: services,
                      budgetId: budgetId,
                      canEdit: canEdit,
                    ),
                    BudgetMembersScreen(services: services, budgetId: budgetId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
