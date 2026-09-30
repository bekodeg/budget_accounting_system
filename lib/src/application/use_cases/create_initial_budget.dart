import '../../domain/models/app_session.dart';
import '../../domain/models/initial_budget_category.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../errors/onboarding_error.dart';
import '../ports/id_generator.dart';
import '../ports/identity_key_pair_generator.dart';
import '../ports/identity_key_store.dart';
import '../ports/session_store.dart';
import 'apply_category_templates.dart';

final class CreateInitialBudget {
  const CreateInitialBudget({
    required BudgetRepository budgetRepository,
    required CategoryRepository categoryRepository,
    required SessionStore sessionStore,
    required IdGenerator idGenerator,
    required IdentityKeyStore identityKeyStore,
    required IdentityKeyPairGenerator identityKeyPairGenerator,
  }) : _budgetRepository = budgetRepository,
       _categoryRepository = categoryRepository,
       _sessionStore = sessionStore,
       _idGenerator = idGenerator,
       _identityKeyStore = identityKeyStore,
       _identityKeyPairGenerator = identityKeyPairGenerator;

  final BudgetRepository _budgetRepository;
  final CategoryRepository _categoryRepository;
  final SessionStore _sessionStore;
  final IdGenerator _idGenerator;
  final IdentityKeyStore _identityKeyStore;
  final IdentityKeyPairGenerator _identityKeyPairGenerator;

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
    final deviceId = _idGenerator.nextId();
    final initialCategories = applyDefaultCategories
        ? await _buildInitialCategories(budgetId)
        : const <InitialBudgetCategory>[];

    final keyPair = await _identityKeyPairGenerator.generate();
    await _identityKeyStore.saveIdentity(
      userId: userId,
      deviceId: deviceId,
      privateKey: keyPair.privateKey,
    );

    AppSession session;
    try {
      session = await _budgetRepository.createOwnedBudget(
        userId: userId,
        userName: normalizedUserName,
        publicKey: keyPair.publicKey,
        deviceId: deviceId,
        budgetId: budgetId,
        budgetName: normalizedBudgetName,
        baseCurrency: baseCurrency,
        initialCategories: initialCategories,
      );
    } on Object {
      await _identityKeyStore.deleteIdentity(
        userId: userId,
        deviceId: deviceId,
      );
      rethrow;
    }

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
