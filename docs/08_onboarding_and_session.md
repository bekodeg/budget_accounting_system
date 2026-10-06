# 8. Первый запуск и локальная сессия

## 8.1. Цель

На этапе S2 приложение должно работать без backend и после чистой установки самостоятельно создать минимальный рабочий контекст:

- локального пользователя;
- либо первый собственный бюджет, либо импортированный по подписанному приглашению бюджет;
- membership пользователя в выбранном бюджете;
- локальную Ed25519 identity устройства;
- выбор активного бюджета для следующего запуска.

Источник истины для пользователя, бюджета и membership — Drift/SQLite.

В platform preferences хранятся только два восстанавливаемых идентификатора:

- `session.current_user_id`;
- `session.current_budget_id`.

Preferences не содержат финансовые данные и не считаются authoritative storage.

## 8.2. Поток первого запуска

```text
app start
  |
  v
ResolveAppStartup
  |
  +-- valid saved user + budget --> AppShell
  |
  +-- saved state missing/stale
  |      |
  |      v
  |   find first active local membership in Drift
  |      |
  |      +-- one budget -------> restore selection -> AppShell
  |      |
  |      +-- several budgets --> BudgetSelectionScreen
  |
  +-- no local membership -----> OnboardingScreen
                                  |-- создать новый бюджет
                                  +-- принять QR/.budgetinvite
```

## 8.3. Создание первого бюджета

`CreateInitialBudget`:

1. нормализует имя пользователя и название бюджета;
2. проверяет, что оба значения не пустые;
3. генерирует идентификаторы пользователя и бюджета;
4. вызывает `BudgetRepository.createOwnedBudget`;
5. data-адаптер создает `User`, `Budget` и `BudgetMember(role=OWNER)` в одной SQLite-транзакции;
6. после успешного commit сохраняет current user/budget в preferences;
7. возвращает `AppSession`.

Если SQLite-транзакция падает, ни одна из трех доменных записей не должна остаться в базе.

## 8.4. Присоединение нового устройства

Fresh-install onboarding позволяет принять подписанный invite без предварительного создания локального бюджета.

`JoinBudgetFromInvite`:

1. проверяет имя локального пользователя и отсутствие существующей local session;
2. проверяет version/expiration/Ed25519 signature приглашения;
3. генерирует новые user/device id и Ed25519 key pair;
4. сохраняет private key в platform secure storage;
5. помечает invite consumed и импортирует budget transport secret;
6. одной Drift-транзакцией создает joining user/device, budget metadata и memberships OWNER/joining user;
7. сохраняет current user/budget в preferences.

Если Drift-import завершается ошибкой, local private key, consumed marker и импортированный transport secret удаляются. Drift-транзакция не оставляет частичный User/Device/Budget/Membership.

## 8.5. Почему preferences не участвуют в SQLite-транзакции

Platform preferences и SQLite не могут участвовать в общей ACID-транзакции.

Поэтому используется правило:

- **Drift — источник истины**;
- preferences — только оптимизация выбора при следующем запуске.

Если запись preferences не удалась, успешно созданный бюджет не считается потерянным. На следующем старте `ResolveAppStartup` находит активную membership в Drift и восстанавливает preferences.

Это также соответствует ограничению `shared_preferences`: package предназначен для простого key-value состояния, а не для критичных данных.

## 8.6. Несколько бюджетов

Если у локального пользователя несколько доступных бюджетов:

- валидный `current_budget_id` открывается автоматически;
- если последний бюджет неизвестен или недоступен, показывается `BudgetSelectionScreen`;
- пользователь может повторно открыть экран выбора из AppBar;
- выбор проходит через `SelectBudget`, который сначала проверяет membership пользователя и только затем сохраняет идентификатор.

UI не может выбрать бюджет, которого нет среди доступных membership.

## 8.7. Идентификаторы

Для локальных сущностей используется UUID v4 shape, генерируемый через `Random.secure()`.

Генератор скрыт за application port `IdGenerator`, поэтому use cases тестируются с детерминированными fake-id.

## 8.8. Временное поле public_key

Таблица `users` уже требует `public_key`, но криптографическая identity относится к S4.

До реализации S4 первый локальный пользователь получает техническое значение:

```text
local-unverified:<userId>
```

Это **не криптографический ключ** и не должно использоваться для подписи, доверия или P2P-аутентификации.

S4 обязан заменить эту временную identity на реальную пару ключей.

## 8.9. Ошибки

Ошибки делятся на два класса:

- validation errors — показываются рядом с onboarding flow без очистки введённых полей;
- storage errors Drift — показываются пользователю, форма остаётся заполненной.

Ошибка записи preferences после успешной SQLite-транзакции не делает onboarding неуспешным, поскольку selection-state можно восстановить из БД.

## 8.10. Тестирование

S2 onboarding покрывается на нескольких уровнях:

- unit — `CreateInitialBudget`, `ResolveAppStartup`, `SelectBudget`;
- unit — формат UUID генератора;
- data integration — реальная in-memory Drift транзакция создания User/Budget/OWNER;
- rollback integration — пользователь не остается в БД, если создание бюджета внутри транзакции упало;
- widget — чистый запуск, ошибка сохранения, выбор из нескольких бюджетов, переключение бюджета;
- существующие navigation widget tests остаются отдельными.

Полный Flutter/analyze/build gate выполняется после продвижения `dev -> stage` согласно `docs/07_ci_quality_gates.md`.
