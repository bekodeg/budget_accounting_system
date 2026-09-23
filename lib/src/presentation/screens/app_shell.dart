import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../navigation/app_navigation_controller.dart';
import '../navigation/app_section.dart';

final class AppShell extends StatefulWidget {
  const AppShell({
    required this.services,
    required this.budgetName,
    this.onChooseBudget,
    super.key,
  });

  final AppServices services;
  final String budgetName;
  final VoidCallback? onChooseBudget;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  late final AppNavigationController _navigation;

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
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _navigation,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.budgetName),
            actions: [
              if (widget.onChooseBudget != null)
                IconButton(
                  key: const ValueKey('choose-budget'),
                  tooltip: 'Сменить бюджет',
                  onPressed: widget.onChooseBudget,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
            ],
          ),
          body: _SectionPlaceholder(section: _navigation.section),
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

final class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        section.label,
        key: ValueKey('section-${section.name}'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
