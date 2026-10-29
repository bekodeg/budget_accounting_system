import '../../domain/models/app_session.dart';
import '../../domain/models/initial_budget_category.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../errors/onboarding_error.dart';
import '../ports/id_generator.dart';
import '../ports/session_store.dart';
import 'apply_category_templates.dart';
import 'get_public_identity.dart';

final class CreateAdditionalBudget {
  const CreateAdditionalBudget({
    required BudgetRepository budgetRepository,
    required CategoryRepository categoryRepository,
    required SessionStore sessionStore,
    required IdGenerator idGenerator,
    required GetPublicIdentity getPublicIdentity,
  }) : _budgetRepository = budgetRepository,
       _categoryRepository = categoryRepository,
       _sessionStore = sessionStore,
       _idGenerator = idGenerator,
       _getPublicIdentity = getPublicIdentity;

  final BudgetRepository _budgetRepository;
  final CategoryRepository _categoryRepository;
  final SessionStore _sessionStore;
  final IdGenerator _idGenerator;
  final GetPublicIdentity _getPublicIdentity;

  Future<AppSession> call({
    required String userId,
    required String budgetName,
    required Currency baseCurrency,
    bool applyDefaultCategories = true,
  }) async {
    if (await _sessionStore.loadCurrentUserId() != userId) {
      throw StateError('An active local user is required.');
    }
    await _getPublicIdentity(userId);
    final name = budgetName.trim();
    if (name.isEmpty) {
      throw const OnboardingError(
        code: OnboardingErrorCode.emptyBudgetName,
        message: 'Название бюджета не может быть пустым.',
      );
    }

    final budgetId = _idGenerator.nextId();
    final templates = applyDefaultCategories
        ? await _categoryRepository.getTemplates()
        : const [];
    final categories = <InitialBudgetCategory>[
      for (final template in templates)
        InitialBudgetCategory(
          id: templateCategoryId(
            budgetId: budgetId,
            templateCode: template.code,
          ),
          name: template.name,
          kind: template.kind,
        ),
    ];

    final session = await _budgetRepository.createAdditionalOwnedBudget(
      userId: userId,
      budgetId: budgetId,
      budgetName: name,
      baseCurrency: baseCurrency,
      initialCategories: categories,
    );
    try {
      await _sessionStore.saveCurrentBudgetId(budgetId);
    } on Object {
      // The database membership remains authoritative if preferences fail.
    }
    return session;
  }
}
