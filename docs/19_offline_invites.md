# 19. Offline invitation через QR и файл

## 19.1. Формат

Invite — это bearer payload с префиксом:

    budgetinvite:<base64url-json>

Текущая версия формата:

    version = 1

Внутри передаются:

- invite_id;
- budget id / name / base currency;
- OWNER user id / name / device id / public Ed25519 key;
- назначаемая роль EDITOR или VIEWER;
- одноразовый nonce;
- issued_at / expires_at;
- crypto metadata;
- Ed25519 signature.

Роль OWNER через приглашение не выдается.

## 19.2. Crypto metadata

Version 1 фиксирует параметры bootstrap-протокола:

    signature = ed25519
    kdf = hkdf-sha256
    transport_cipher = chacha20-poly1305
    salt = <random>
    bootstrap_secret = <random 32 bytes>

Payload подписан, но сам QR/файл не шифруется. Поэтому приглашение является bearer
credential: человек, получивший QR/файл до expiration, может попытаться его принять.

Bootstrap secret предназначен для следующего этапа защищенного P2P handshake.

## 19.3. Подпись

OWNER подписывает canonical JSON без поля signature своим локальным private Ed25519 seed.

Private key берется из platform secure storage и никогда не включается в invite.

При импорте public key владельца из payload используется для проверки подписи до любых
изменений локальной БД.

## 19.4. Expiration и одноразовость

Invite по умолчанию действует 24 часа.

После успешной проверки import flow проверяет локальный consumption store.
Перед записью membership invite_id отмечается использованным.

Если SQLite-транзакция не прошла, отметка снимается.

Повторный импорт того же invite на этом устройстве возвращает
InviteError.alreadyConsumed.

До появления P2P sync глобальная одноразовость между несколькими независимыми устройствами
невозможна без общего состояния. После синхронизации consumption/revocation должен
распространяться как sync state.

## 19.5. Offline import

Импорт не требует backend.

В одной SQLite-транзакции создаются или проверяются:

1. public identity OWNER;
2. OWNER device;
3. Budget metadata;
4. OWNER membership;
5. membership текущего локального пользователя с ролью из invite.

Конфликт существующего OWNER public key или metadata бюджета отклоняет импорт целиком.

## 19.6. Пользовательский flow

OWNER:

1. открывает Настройки -> Участники;
2. выбирает Пригласить;
3. выбирает EDITOR или VIEWER;
4. получает QR;
5. может передать .budgetinvite файл через системный Share Sheet.

Получатель:

1. выбирает Сканировать QR или Открыть файл;
2. приложение проверяет format/version/expiration/signature/one-time status;
3. показывает budget name, currency, OWNER и назначаемую роль;
4. пользователь подтверждает присоединение;
5. новый budget становится последним выбранным бюджетом.

## 19.7. Транспорт

QR:

- qr_flutter рендерит payload offline;
- mobile_scanner считывает payload камерой.

Файл:

- extension: .budgetinvite;
- content: тот же raw payload, что находится в QR;
- file_picker используется для импорта;
- share_plus + app temporary directory используются для передачи файла;
- временный каталог удаляется после Share Sheet.

## 19.8. Тесты

Покрываются:

- encode/decode version 1;
- signed EDITOR/VIEWER invite;
- invalid signature;
- expiration;
- повторное использование;
- offline acceptance второй identity;
- atomic Drift persistence;
- owner public-key conflict rollback;
- QR generation UI;
- VIEWER не может создавать приглашение, но может импортировать.
