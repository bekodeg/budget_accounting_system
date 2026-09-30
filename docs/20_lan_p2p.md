# 20. P2P-соединение в локальной сети

## 20.1. Назначение

LAN transport обеспечивает прямое соединение участников одного бюджета без backend.
Локальный CRUD не зависит от состояния сети: transport используется только во время
явной sync-сессии.

## 20.2. Discovery

Для Android/iOS используется пакет `nsd 5.0.1` и DNS-SD/mDNS service:

    _budgetsync._tcp

В mDNS не публикуется `budget_id` и не публикуется transport secret.

Вместо этого `LanDiscoveryTokenService` вычисляет короткий HMAC-token из
budget transport secret. Устройства одного бюджета видят одинаковый token, а
посторонний peer не может определить бюджет только по TXT metadata.

## 20.3. Transport secret

Для каждого бюджета существует устойчивый 256-bit transport secret.

Владелец:

1. создает secret при первом invitation;
2. хранит его в `flutter_secure_storage`;
3. помещает secret в подписанный invite payload как bootstrap secret.

Принимающее устройство импортирует secret только после проверки invite signature и
удаляет импорт при rollback acceptance.

## 20.4. Handshake

Каждая сторона отправляет versioned hello:

- budget id;
- user id;
- device id;
- public identity;
- случайный nonce;
- HMAC proof владения transport secret;
- Ed25519 identity signature.

Peer отклоняется, если:

- budget не совпадает;
- secret proof неверен;
- identity signature неверна;
- известный public key не совпадает;
- известное устройство принадлежит другому пользователю;
- известное устройство отозвано.

Новый неизвестный peer с валидным invite-secret допускается к первому handshake:
до первой синхронизации владелец еще может не иметь его identity в локальной БД.

## 20.5. Защищенный канал

После взаимного handshake обе стороны получают одинаковый session key:

    HKDF-SHA256(
      budget transport secret,
      ordered nonces,
      ordered device ids
    )

Payload передается через ChaCha20-Poly1305 AEAD. В AAD включается budget id.

TCP framing:

- 4-byte unsigned big-endian frame length;
- payload;
- maximum frame size: 16 MiB.

## 20.6. Manual fallback

`LanPeerSessionManager.host()` возвращает `manualEndpointCode`, содержащий
локальный IPv4 host и listener port.

Код имеет versioned формат `budgetlan:<base64url>` и может быть показан существующим
QR UI. Второе устройство декодирует его через `decodeManualEndpoint()` и использует
тот же защищенный handshake, что и при mDNS discovery.

QR содержит только endpoint. Доступ к данным все равно требует transport secret,
полученный из валидного budget invite.

## 20.7. Потеря сети и reconnect

Transport не участвует в локальных repository mutations.

При потере TCP-соединения:

- текущий channel закрывается;
- локальный CRUD продолжает работать;
- `connect()` можно вызвать повторно;
- следующая sync-сессия продолжает обмен операциями поверх журнала.

Loopback integration test открывает соединение, обменивается зашифрованным frame,
закрывает channel и успешно подключается повторно к тому же host.

## 20.8. Platform permissions

Host-проекты генерируются отдельно через `flutter create`.

После генерации выполнить:

    python3 tool/configure_lan_platform_permissions.py

Скрипт добавляет:

Android:

- `android.permission.INTERNET`;
- `android.permission.CHANGE_WIFI_MULTICAST_STATE`.

iOS:

- `NSLocalNetworkUsageDescription`;
- `NSBonjourServices = [_budgetsync._tcp]`.

Stage CI вызывает скрипт после генерации Android host project.

## 20.9. Ограничения проверки

Автоматические тесты покрывают TCP framing, handshake, encryption, invalid secret,
known identity checks, manual endpoint и reconnect.

mDNS/Bonjour discovery и iOS Local Network permission необходимо дополнительно
проверить на реальных Android/iOS устройствах в multi-device acceptance этапе.
