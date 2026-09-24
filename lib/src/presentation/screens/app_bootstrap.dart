import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/models/app_startup_state.dart';
import '../../domain/value_objects/currency.dart';
import 'app_shell.dart';
import 'budget_selection_screen.dart';
import 'onboarding_screen.dart';

final class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    required this.services,
    super.key,
  });

  final AppServices services;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

final class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AppStartupState> _startup;
  bool _forceBudgetSelection = false;

  @override
  void initState() {
    super.initState();
    _startup = widget.services.resolveAppStartup();
  }

  void _reload() {
    setState(() {
      _startup = widget.services.resolveAppStartup();
    });
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
    await widget.services.selectBudget(
      userId: userId,
      budgetId: budgetId,
    );
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
          return OnboardingScreen(onCreate: _createInitialBudget);
        }

        final userId = startup.userId!;
        if (startup.needsBudgetSelection || _forceBudgetSelection) {
          return BudgetSelectionScreen(
            budgets: startup.budgets,
            onSelect: (budgetId) => _selectBudget(
              userId: userId,
              budgetId: budgetId,
            ),
          );
        }

        final selectedBudget = startup.budgets.firstWhere(
          (budget) => budget.id == startup.selectedBudgetId,
        );

        return AppShell(
          services: widget.services,
          userId: userId,
          budgetId: selectedBudget.id,
          budgetName: selectedBudget.name,
          onChooseBudget: startup.budgets.length > 1
              ? () {
                  setState(() {
                    _forceBudgetSelection = true;
                  });
                }
              : null,
        );
      },
    );
  }
}
