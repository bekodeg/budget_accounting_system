import '../../domain/models/app_session.dart';
import '../../domain/models/initial_budget_category.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../errors/onboarding_error.dart';
import '../ports/id_generator.dart';
import '../ports/session_store.dart';
import 'apply_category_templates.dart';

final class CreateInitialBudget {
  const CreateInitialBudget({
    required BudgetRepository budgetRepository,
    required CategoryRepository categoryRepository,
    required SessionStore sessionStore,
    required IdGenerator idGenerator,
  }) : _budgetRepository = budgetRepository,
       _categoryRepository = categoryRepository,
       _sessionStore = sessionStore,
       _idGenerator = idGenerator;

  final BudgetRepository _budgetRepository;
  final CategoryRepository _categoryRepository;
  final SessionStore _sessionStore;
  final IdGenerator _idGenerator;

  Future<AppSession> call({
    required String userName,
    required String budgetName,
    required Currency baseCurrency,
    bool applyDefaultCategories = true,
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
    final initialCategories = applyDefaultCategories
        ? await _buildInitialCategories(budgetId)
        : const <InitialBudgetCategory>[];

    final session = await _budgetRepository.createOwnedBudget(
      userId: userId,
      userName: normalizedUserName,
      publicKey: 'local-unverified:$userId',
      budgetId: budgetId,
      budgetName: normalizedBudgetName,
      baseCurrency: baseCurrency,
      initialCategories: initialCategories,
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

  Future<List<InitialBudgetCategory>> _buildInitialCategories(
    String budgetId,
  ) async {
    final templates = await _categoryRepository.getTemplates();
    return templates
        .map(
          (template) => InitialBudgetCategory(
            id: templateCategoryId(
              budgetId: budgetId,
              templateCode: template.code,
            ),
            name: template.name,
            kind: template.kind,
          ),
        )
        .toList(growable: false);
  }
}
