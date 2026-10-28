import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/authorization/budget_action.dart';
import '../navigation/app_navigation_controller.dart';
import '../navigation/app_section.dart';
import 'budget_dashboard_screen.dart';
import 'monthly_plan_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'synchronization_screen.dart';

final class AppShell extends StatefulWidget {
  const AppShell({
    required this.services,
    required this.userId,
    required this.budgetId,
    required this.budgetName,
    this.onChooseBudget,
    super.key,
  });

  final AppServices services;
  final String userId;
  final String budgetId;
  final String budgetName;
  final VoidCallback? onChooseBudget;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  late final AppNavigationController _navigation;
  String? _lastSyncResult;

  @override
  void initState() {
    super.initState();
    _navigation = AppNavigationController();
  }

  @override
  void dispose() {
    _navigation.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.budgetId != widget.budgetId) _lastSyncResult = null;
  }

  Future<void> _openSynchronization() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Синхронизация: ${widget.budgetName}')),
          body: SynchronizationScreen(
            services: widget.services,
            userId: widget.userId,
            budgetId: widget.budgetId,
            autoDiscover: true,
            onSyncResult: (result) {
              if (mounted) setState(() => _lastSyncResult = result);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _navigation,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.budgetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_lastSyncResult != null)
                  Text(
                    _lastSyncResult!,
                    key: const ValueKey('last-sync-result'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            actions: [
              IconButton(
                key: const ValueKey('open-synchronization'),
                tooltip: 'Синхронизировать',
                onPressed: _openSynchronization,
                icon: const Icon(Icons.sync),
              ),
              if (widget.onChooseBudget != null)
                IconButton(
                  key: const ValueKey('choose-budget'),
                  tooltip: 'Сменить бюджет',
                  onPressed: widget.onChooseBudget,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
            ],
          ),
          body: _SectionBody(
            section: _navigation.section,
            services: widget.services,
            userId: widget.userId,
            budgetId: widget.budgetId,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _navigation.section.index,
            onDestinationSelected: (index) {
              _navigation.select(AppSection.values[index]);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Операции',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'План',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Отчеты',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Настройки',
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.services,
    required this.userId,
    required this.budgetId,
  });

  final AppSection section;
  final AppServices services;
  final String userId;
  final String budgetId;

  @override
  Widget build(BuildContext context) {
    if (section == AppSection.transactions) {
      return BudgetDashboardScreen(
        services: services,
        budgetId: budgetId,
        userId: userId,
      );
    }
    if (section == AppSection.planning) {
      return FutureBuilder<bool>(
        future: services.canPerformBudgetAction(
          budgetId: budgetId,
          action: BudgetAction.mutate,
        ),
        builder: (context, snapshot) {
          return MonthlyPlanScreen(
            services: services,
            budgetId: budgetId,
            canEdit: snapshot.data ?? false,
          );
        },
      );
    }
    if (section == AppSection.reports) {
      return ReportsScreen(
        services: services,
        budgetId: budgetId,
        userId: userId,
      );
    }
    if (section == AppSection.settings) {
      return SettingsScreen(
        services: services,
        userId: userId,
        budgetId: budgetId,
      );
    }

    return Center(
      child: Text(
        section.label,
        key: ValueKey('section-${section.name}'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
