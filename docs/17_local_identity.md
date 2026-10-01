# 17. Локальная identity пользователя и устройства

## 17.1. Назначение

Локальная identity является основой приглашений, подписи sync operations и проверки peer.
Она создается без backend и состоит из:

- стабильного `user_id`;
- стабильного `device_id`;
- публичного Ed25519 key;
- приватного Ed25519 seed, доступного только через platform secure storage.

## 17.2. Хранение

SQLite хранит только публичную часть identity:

- `users.public_key`;
- `devices.id`, `devices.user_id`, `devices.revoked_at`.

Private key не записывается в Drift, SharedPreferences или sync_operations.

Private seed хранится через `flutter_secure_storage`, то есть в platform secure storage.
Для Android актуальная версия плагина использует защищенное хранилище на базе Android
Keystore и требует Android API 23+. Текущий Flutter stable использует более высокий
минимальный Android API, поэтому отдельное понижение/повышение minSdk в проекте не нужно.

## 17.3. Формат public key

Публичный ключ хранится в versioned/self-describing строке:

```text
ed25519:<base64url-public-key>
```

Это позволяет позднее добавить другой алгоритм без неоднозначной интерпретации старых
записей.

## 17.4. Первый запуск

При создании первого бюджета:

1. генерируются `user_id`, `budget_id` и `device_id`;
2. генерируется Ed25519 key pair;
3. private seed записывается в secure storage;
4. User, Device, Budget, OWNER membership и стартовые категории фиксируются в одной
   SQLite-транзакции;
5. при ошибке SQLite secure identity удаляется;
6. SharedPreferences сохраняют только выбранные `user_id` / `budget_id`.

## 17.5. Миграция существующих пользователей

Пользователи, созданные до S4, имеют public key вида:

```text
local-unverified:<user_id>
```

При следующем startup `EnsureLocalIdentity`:

1. определяет legacy public key;
2. создает новый `device_id` и Ed25519 key pair;
3. сохраняет private seed в secure storage;
4. атомарно обновляет `users.public_key` и создает строку `devices`;
5. при ошибке DB удаляет private seed.

Повторный startup проверяет существующий device/private key и не генерирует новую
identity.

Если public key уже подтвержден как Ed25519, но private key отсутствует, identity
автоматически не ротируется: возвращается typed `IdentityError`. Это защищает от
тихой смены криптографической identity.

## 17.6. Public API

Application layer предоставляет `GetPublicIdentity`.

Возвращается только:

```text
userId
deviceId
publicKey
```

Private key через application API никогда не возвращается.

## 17.7. Отзыв устройства

`devices.revoked_at != null` означает отозванное устройство. Такое устройство не
может использовать локальную identity для sync и получает `IdentityError.revokedDevice`.

Фактическое управление отзывом и ролями участников реализуется в следующих задачах S4.

## 17.8. Тесты

Проверяются:

- создание User + Device при onboarding;
- стабильность identity при повторном запуске;
- одноразовая миграция legacy пользователя;
- отказ для revoked device;
- соответствие private/public Ed25519;
- очистка secure key при rollback onboarding;
- отсутствие private-key колонок в обычных Drift таблицах.
