import '../../domain/models/app_session.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../errors/onboarding_error.dart';
import '../ports/id_generator.dart';
import '../ports/session_store.dart';

final class CreateInitialBudget {
  const CreateInitialBudget({
    required BudgetRepository budgetRepository,
    required SessionStore sessionStore,
    required IdGenerator idGenerator,
  })  : _budgetRepository = budgetRepository,
        _sessionStore = sessionStore,
        _idGenerator = idGenerator;

  final BudgetRepository _budgetRepository;
  final SessionStore _sessionStore;
  final IdGenerator _idGenerator;

  Future<AppSession> call({
    required String userName,
    required String budgetName,
    required Currency baseCurrency,
  }) async {
    final normalizedUserName = userName.trim();
    final normalizedBudgetName = budgetName.trim();

    if (normalizedUserName.isEmpty) {
      throw const OnboardingError(
        code: OnboardingErrorCode.emptyUserName,
        message: 'Имя пользователя не может быть пустым.',
      );
    }

    if (normalizedBudgetName.isEmpty) {
      throw const OnboardingError(
        code: OnboardingErrorCode.emptyBudgetName,
        message: 'Название бюджета не может быть пустым.',
      );
    }

    final userId = _idGenerator.nextId();
    final budgetId = _idGenerator.nextId();

    final session = await _budgetRepository.createOwnedBudget(
      userId: userId,
      userName: normalizedUserName,
      publicKey: 'local-unverified:$userId',
      budgetId: budgetId,
      budgetName: normalizedBudgetName,
      baseCurrency: baseCurrency,
    );

    try {
      await _sessionStore.saveSession(
        userId: session.userId,
        budgetId: session.budgetId,
      );
    } on Object {
      // Preferences keep only recoverable selection state. The Drift data is
      // authoritative, so a preference write failure must not roll back a
      // successfully created budget. Startup will reconstruct the selection.
    }

    return session;
  }
}
