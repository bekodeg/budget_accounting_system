import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('initial schema seeds default category templates', () async {
    final templates = await database.select(database.categoryTemplates).get();

    expect(templates, isNotEmpty);
    expect(
      templates.any((template) => template.code == 'expense.food'),
      isTrue,
    );
    expect(
      templates.any((template) => template.code == 'income.salary'),
      isTrue,
    );
  });

  test('foreign keys are enabled', () async {
    final row = await database.customSelect('PRAGMA foreign_keys').getSingle();

    expect(row.read<int>('foreign_keys'), 1);
  });
}
