import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/authorization/budget_action.dart';
import 'account_management_screen.dart';
import 'category_management_screen.dart';
import 'budget_members_screen.dart';
import 'budget_backup_screen.dart';
import 'diagnostics_screen.dart';
import 'synchronization_screen.dart';

final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
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
    return FutureBuilder<bool>(
      future: services.canPerformBudgetAction(
        budgetId: budgetId,
        action: BudgetAction.mutate,
      ),
      builder: (context, snapshot) {
        final canEdit = snapshot.data ?? false;
        return DefaultTabController(
          length: 6,
          child: Column(
            key: const ValueKey('settings-screen'),
            children: [
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Счета'),
                  Tab(text: 'Категории'),
                  Tab(text: 'Участники'),
                  Tab(text: 'Синхронизация'),
                  Tab(text: 'Backup'),
                  Tab(text: 'Диагностика'),
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
                    SynchronizationScreen(
                      services: services,
                      userId: userId,
                      budgetId: budgetId,
                    ),
                    BudgetBackupScreen(services: services, budgetId: budgetId),
                    DiagnosticsScreen(services: services),
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
