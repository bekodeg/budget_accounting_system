import 'package:budget_accounting_system/src/application/errors/category_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/apply_category_templates.dart';
import 'package:budget_accounting_system/src/application/use_cases/archive_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/rename_category.dart';
import 'package:budget_accounting_system/src/domain/models/category_template.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  test('creates trimmed category with generated id', () async {
    final repository = FakeCategoryRepository();
    final useCase = CreateCategory(
      categoryRepository: repository,
      idGenerator: FakeIdGenerator(['category-1']),
    );

    final category = await useCase(
      budgetId: 'budget-1',
      name: '  Продукты  ',
      kind: CategoryKind.expense,
    );

    expect(category.id, 'category-1');
    expect(category.name, 'Продукты');
    expect(
      repository.snapshot('budget-1', includeArchived: false),
      [category],
    );
  });

  test('rejects blank category names', () async {
    final useCase = CreateCategory(
      categoryRepository: FakeCategoryRepository(),
      idGenerator: FakeIdGenerator(['category-1']),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        name: '   ',
        kind: CategoryKind.expense,
      ),
      throwsA(
        isA<CategoryError>().having(
          (error) => error.code,
          'code',
          CategoryErrorCode.emptyName,
        ),
      ),
    );
  });

  test('template application is deterministic and idempotent', () async {
    final repository = FakeCategoryRepository(
      templates: const [
        CategoryTemplate(
          code: 'expense.food',
          name: 'Продукты',
          kind: CategoryKind.expense,
          sortOrder: 10,
        ),
        CategoryTemplate(
          code: 'income.salary',
          name: 'Зарплата',
          kind: CategoryKind.income,
          sortOrder: 10,
        ),
      ],
    );
    final useCase = ApplyCategoryTemplates(repository);

    await useCase('budget-1');
    await useCase('budget-1');

    final categories = repository.snapshot(
      'budget-1',
      includeArchived: true,
    );
    expect(categories, hasLength(2));
    expect(
      categories.map((category) => category.id),
      containsAll([
        'budget-1:template:expense.food',
        'budget-1:template:income.salary',
      ]),
    );
  });

  test('reapplying templates preserves rename and archive state', () async {
    final repository = FakeCategoryRepository(
      templates: const [
        CategoryTemplate(
          code: 'expense.food',
          name: 'Продукты',
          kind: CategoryKind.expense,
          sortOrder: 10,
        ),
      ],
    );
    final apply = ApplyCategoryTemplates(repository);
    final rename = RenameCategory(repository);
    final archive = ArchiveCategory(repository);
    const templateId = 'budget-1:template:expense.food';

    await apply('budget-1');
    await rename(categoryId: templateId, name: 'Супермаркет');
    await archive(templateId);
    await apply('budget-1');

    final all = repository.snapshot(
      'budget-1',
      includeArchived: true,
    );
    expect(all, hasLength(1));
    expect(all.single.name, 'Супермаркет');
    expect(all.single.isArchived, isTrue);
  });

  test('renames and archives without deleting category', () async {
    final repository = FakeCategoryRepository();
    final create = CreateCategory(
      categoryRepository: repository,
      idGenerator: FakeIdGenerator(['category-1']),
    );
    final rename = RenameCategory(repository);
    final archive = ArchiveCategory(repository);

    final category = await create(
      budgetId: 'budget-1',
      name: 'Еда',
      kind: CategoryKind.expense,
    );
    await rename(categoryId: category.id, name: 'Продукты');
    await archive(category.id);

    expect(
      repository.snapshot('budget-1', includeArchived: false),
      isEmpty,
    );
    final all = repository.snapshot(
      'budget-1',
      includeArchived: true,
    );
    expect(all, hasLength(1));
    expect(all.single.name, 'Продукты');
    expect(all.single.isArchived, isTrue);
  });
}
