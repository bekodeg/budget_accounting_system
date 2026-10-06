import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/errors/onboarding_error.dart';
import '../../domain/errors/domain_validation_error.dart';
import '../../domain/value_objects/currency.dart';
import 'budget_invite_panel.dart';

typedef CreateInitialBudgetCallback =
    Future<void> Function({
      required String userName,
      required String budgetName,
      required Currency baseCurrency,
      required bool applyDefaultCategories,
    });

final class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.services,
    required this.onCreate,
    required this.onJoined,
    super.key,
  });

  final AppServices services;
  final CreateInitialBudgetCallback onCreate;
  final VoidCallback onJoined;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

final class _OnboardingScreenState extends State<OnboardingScreen> {
  final _userNameController = TextEditingController();
  final _budgetNameController = TextEditingController();
  final _currencyController = TextEditingController(text: 'EUR');

  bool _applyDefaultCategories = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userNameController.dispose();
    _budgetNameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreate(
        userName: _userNameController.text,
        budgetName: _budgetNameController.text,
        baseCurrency: Currency(_currencyController.text),
        applyDefaultCategories: _applyDefaultCategories,
      );
    } on OnboardingError catch (error) {
      _showError(error.message);
    } on DomainValidationError catch (error) {
      _showError(error.message);
    } on Object {
      _showError('Не удалось создать бюджет. Проверьте данные и повторите.');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Text(
                  'Начало работы',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Создайте новый бюджет или присоединитесь к существующему '
                  'по приглашению. Все данные сохраняются локально.',
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey('onboarding-user-name'),
                  controller: _userNameController,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Ваше имя',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Присоединиться к бюджету',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'На устройстве владельца откройте '
                          'Настройки → Участники → Пригласить.',
                        ),
                        const SizedBox(height: 12),
                        BudgetInviteJoinActions(
                          services: widget.services,
                          joiningUserName: _userNameController.text,
                          onAccepted: widget.onJoined,
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                Text(
                  'Создать новый бюджет',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('onboarding-budget-name'),
                  controller: _budgetNameController,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Название бюджета',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('onboarding-currency'),
                  controller: _currencyController,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Базовая валюта',
                    hintText: 'EUR',
                    helperText: 'Трёхбуквенный код, например EUR, USD, RUB',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('onboarding-default-categories'),
                  value: _applyDefaultCategories,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Добавить стандартные категории'),
                  subtitle: const Text(
                    'Их можно переименовать или архивировать позже.',
                  ),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(() {
                            _applyDefaultCategories = value ?? true;
                          });
                        },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    key: const ValueKey('onboarding-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('onboarding-submit'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Создать бюджет'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
