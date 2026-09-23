# Budget Accounting System

Мобильное offline-first приложение для совместного учета доходов и расходов без централизованного backend-сервера.

## Цели

- учет доходов и расходов;
- совместное ведение одного бюджета несколькими пользователями;
- работа offline-first;
- отчеты за месяц, год и произвольный период;
- расчет остатков и исполнения плана;
- экспорт CSV/XLSX;
- создание транзакции из QR-кода/фискального чека;
- до 20 одновременно работающих участников одного бюджета.

## Технологический стек

- Flutter / Dart;
- SQLite;
- Drift как ORM/DAL и единственный механизм миграций локальной БД;
- P2P-синхронизация поверх журнала `sync_operations` (следующий этап реализации).

Liquibase удален: Drift хранит snapshots версий схемы, генерирует пошаговые миграции и тесты миграций. История схемы должна храниться в `drift_schemas/`.

## Структура приложения

```text
lib/
  main.dart
  src/
    app.dart
    bootstrap/          # composition root и lifecycle concrete dependencies
    domain/             # бизнес-модели и repository contracts
    application/        # use cases и AppServices
    data/
      database/         # Drift schema
      dal/              # SQL/Drift access
      repositories/     # adapters domain repositories -> DAL
    presentation/       # Flutter UI и локальное UI-state
```

Главное правило зависимостей: `presentation -> application -> domain`.
Drift/DAO доступны только data/bootstrap слоям; UI не должен импортировать SQL, таблицы Drift или `BudgetDal`.
Подробнее см. [логику приложения и границы слоев](docs/06_application_logic.md).

## Локальный запуск

Установить зависимости:

```bash
flutter pub get
```

Сгенерировать Drift-код:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Если Android/iOS host-проекты еще не созданы в рабочей копии, их можно сгенерировать стандартным Flutter CLI:

```bash
flutter create --platforms=android,ios .
```

После этого:

```bash
flutter run
```

## Миграции Drift

При изменении схемы:

1. изменить `lib/src/data/database/tables.dart`;
2. увеличить `schemaVersion` в `app_database.dart`;
3. выполнить:

```bash
dart run drift_dev make-migrations
```

4. реализовать сгенерированный переход `fromNToN+1`;
5. запустить migration tests;
6. закоммитить новую версию из `drift_schemas/` вместе с migration step и тестами.

Подробнее: [drift_schemas/README.md](drift_schemas/README.md).

## Архитектурное решение

Каждое устройство хранит полную локальную копию бюджета в SQLite и может работать автономно. Изменения записываются как операции в журнал синхронизации. Когда устройства получают канал связи, они обмениваются операциями напрямую (peer-to-peer). Централизованный backend не требуется.

> Если устройства физически не имеют никакого канала связи друг с другом, мгновенная совместная синхронизация невозможна. Пользователи продолжают работать локально, а изменения объединяются при следующем соединении.

## Документы

- [Требования](docs/01_requirements.md)
- [Архитектура](docs/02_architecture.md)
- [Модель данных](docs/03_data_model.md)
- [Синхронизация и конфликты](docs/04_sync_and_conflicts.md)
- [Отчеты, экспорт и чеки](docs/05_reports_and_receipts.md)
- [Логика приложения и границы слоев](docs/06_application_logic.md)
- [CI quality gates](docs/07_ci_quality_gates.md)
- [ADR-001: Local-first P2P](docs/adr/ADR-001-local-first-p2p.md)
