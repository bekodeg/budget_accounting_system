import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/models/app_startup_state.dart';
import '../../domain/models/budget_summary.dart';
import '../../domain/value_objects/currency.dart';
import 'app_shell.dart';
import 'budget_selection_screen.dart';
import 'onboarding_screen.dart';

final class AppBootstrap extends StatefulWidget {
  const AppBootstrap({required this.services, super.key});

  final AppServices services;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

final class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AppStartupState> _startup;
  bool _forceBudgetSelection = false;
  String? _watchingUserId;
  Stream<List<BudgetSummary>>? _budgetStream;
  bool _initialSyncPending = false;

  @override
  void initState() {
    super.initState();
    _startup = widget.services.resolveAppStartup();
  }

  void _reload() {
    setState(() {
      _forceBudgetSelection = false;
      _watchingUserId = null;
      _budgetStream = null;
      _startup = widget.services.resolveAppStartup();
    });
  }

  void _joined() {
    _initialSyncPending = true;
    _reload();
  }

  Stream<List<BudgetSummary>> _watchBudgets(String userId) {
    if (_watchingUserId != userId || _budgetStream == null) {
      _watchingUserId = userId;
      _budgetStream = widget.services.watchUserBudgets(userId);
    }
    return _budgetStream!;
  }

  Future<void> _createInitialBudget({
    required String userName,
    required String budgetName,
    required Currency baseCurrency,
    required bool applyDefaultCategories,
  }) async {
    await widget.services.createInitialBudget(
      userName: userName,
      budgetName: budgetName,
      baseCurrency: baseCurrency,
      applyDefaultCategories: applyDefaultCategories,
    );
    _forceBudgetSelection = false;
    _reload();
  }

  Future<void> _selectBudget({
    required String userId,
    required String budgetId,
  }) async {
    await widget.services.selectBudget(userId: userId, budgetId: budgetId);
    _forceBudgetSelection = false;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStartupState>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('startup-retry'),
                onPressed: _reload,
                child: const Text('Повторить запуск'),
              ),
            ),
          );
        }

        final startup = snapshot.requireData;
        if (startup.needsOnboarding) {
          return OnboardingScreen(
            services: widget.services,
            onCreate: _createInitialBudget,
            onJoined: _joined,
          );
        }

        final userId = startup.userId!;
        return StreamBuilder<List<BudgetSummary>>(
          stream: _watchBudgets(userId),
          initialData: startup.budgets,
          builder: (context, budgetSnapshot) {
            final budgets = budgetSnapshot.data ?? startup.budgets;
            final selected = budgets.where(
              (budget) => budget.id == startup.selectedBudgetId,
            );
            if (budgetSnapshot.hasError ||
                selected.isEmpty ||
                _forceBudgetSelection) {
              return BudgetSelectionScreen(
                services: widget.services,
                userId: userId,
                budgets: budgets,
                activeBudgetId: startup.selectedBudgetId,
                onSelect: (budgetId) =>
                    _selectBudget(userId: userId, budgetId: budgetId),
                onMembershipChanged: _reload,
                onJoined: _joined,
              );
            }

            final selectedBudget = selected.first;
            return AppShell(
              key: ValueKey('app-shell-${selectedBudget.id}'),
              services: widget.services,
              userId: userId,
              budgetId: selectedBudget.id,
              budgetName: selectedBudget.name,
              initialSyncPending: _initialSyncPending,
              onInitialSyncPromptHandled: () => _initialSyncPending = false,
              onChooseBudget: () {
                setState(() => _forceBudgetSelection = true);
              },
            );
          },
        );
      },
    );
  }
}
