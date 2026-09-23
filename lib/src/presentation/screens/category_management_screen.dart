import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/errors/category_error.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/domain_types.dart';

final class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({
    required this.services,
    required this.budgetId,
    super.key,
  });

  final AppServices services;
  final String budgetId;

  Future<void> _createCategory(BuildContext context) async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (context) => const _CategoryEditorDialog(),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await services.createCategory(
        budgetId: budgetId,
        name: draft.name,
        kind: draft.kind,
      );
    } on CategoryError catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'Не удалось создать категорию.');
      }
    }
  }

  Future<void> _renameCategory(
    BuildContext context,
    BudgetCategory category,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameCategoryDialog(category: category),
    );
    if (name == null || !context.mounted) {
      return;
    }

    try {
      await services.renameCategory(
        categoryId: category.id,
        name: name,
      );
    } on CategoryError catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'Не удалось переименовать категорию.');
      }
    }
  }

  Future<void> _archiveCategory(
    BuildContext context,
    BudgetCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Архивировать категорию?'),
        content: Text(
          '«${category.name}» останется в истории и отчетах, '
          'но не будет предлагаться для новых операций.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Архивировать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await services.archiveCategory(category.id);
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'Не удалось архивировать категорию.');
      }
    }
  }

  Future<void> _applyTemplates(BuildContext context) async {
    try {
      await services.applyCategoryTemplates(budgetId);
      if (context.mounted) {
        _showMessage(context, 'Недостающие стандартные категории добавлены.');
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'Не удалось применить шаблоны категорий.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetCategory>>(
      stream: services.watchBudgetCategories(
        budgetId,
        includeArchived: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Не удалось загрузить категории.'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!;
        final active = categories
            .where((category) => !category.isArchived)
            .toList(growable: false);
        final archived = categories
            .where((category) => category.isArchived)
            .toList(growable: false);

        return ListView(
          key: const ValueKey('category-management'),
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('add-category'),
                  onPressed: () => _createCategory(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить категорию'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('apply-category-templates'),
                  onPressed: () => _applyTemplates(context),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Добавить стандартные'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Активных категорий пока нет.'),
                ),
              )
            else ...[
              _CategorySection(
                title: 'Расходы',
                categories: _byKind(active, CategoryKind.expense),
                onRename: (category) => _renameCategory(context, category),
                onArchive: (category) => _archiveCategory(context, category),
              ),
              _CategorySection(
                title: 'Доходы',
                categories: _byKind(active, CategoryKind.income),
                onRename: (category) => _renameCategory(context, category),
                onArchive: (category) => _archiveCategory(context, category),
              ),
              _CategorySection(
                title: 'Доходы и расходы',
                categories: _byKind(active, CategoryKind.both),
                onRename: (category) => _renameCategory(context, category),
                onArchive: (category) => _archiveCategory(context, category),
              ),
            ],
            if (archived.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Архив',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final category in archived)
                ListTile(
                  key: ValueKey('archived-category-${category.id}'),
                  enabled: false,
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(category.name),
                  subtitle: Text(_kindLabel(category.kind)),
                ),
            ],
          ],
        );
      },
    );
  }

  static List<BudgetCategory> _byKind(
    List<BudgetCategory> categories,
    CategoryKind kind,
  ) {
    return categories
        .where((category) => category.kind == kind)
        .toList(growable: false);
  }
}

final class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.categories,
    required this.onRename,
    required this.onArchive,
  });

  final String title;
  final List<BudgetCategory> categories;
  final ValueChanged<BudgetCategory> onRename;
  final ValueChanged<BudgetCategory> onArchive;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final category in categories)
          ListTile(
            key: ValueKey('category-${category.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(category.name),
            trailing: PopupMenuButton<_CategoryAction>(
              onSelected: (action) {
                switch (action) {
                  case _CategoryAction.rename:
                    onRename(category);
                  case _CategoryAction.archive:
                    onArchive(category);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _CategoryAction.rename,
                  child: Text('Переименовать'),
                ),
                PopupMenuItem(
                  value: _CategoryAction.archive,
                  child: Text('Архивировать'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

enum _CategoryAction { rename, archive }

final class _CategoryDraft {
  const _CategoryDraft({
    required this.name,
    required this.kind,
  });

  final String name;
  final CategoryKind kind;
}

final class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog();

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

final class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _nameController = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая категория'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('category-name-input'),
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Название',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CategoryKind>(
            key: const ValueKey('category-kind-input'),
            initialValue: _kind,
            decoration: const InputDecoration(
              labelText: 'Тип',
            ),
            items: CategoryKind.values
                .map(
                  (kind) => DropdownMenuItem(
                    value: kind,
                    child: Text(_kindLabel(kind)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _kind = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('save-category'),
          onPressed: () {
            Navigator.pop(
              context,
              _CategoryDraft(
                name: _nameController.text,
                kind: _kind,
              ),
            );
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}

final class _RenameCategoryDialog extends StatefulWidget {
  const _RenameCategoryDialog({
    required this.category,
  });

  final BudgetCategory category;

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

final class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Переименовать категорию'),
      content: TextField(
        key: const ValueKey('rename-category-input'),
        controller: _nameController,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('rename-category-save'),
          onPressed: () => Navigator.pop(context, _nameController.text),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

String _kindLabel(CategoryKind kind) {
  return switch (kind) {
    CategoryKind.income => 'Доходы',
    CategoryKind.expense => 'Расходы',
    CategoryKind.both => 'Доходы и расходы',
  };
}
