# Зашифрованный backup и восстановление бюджета

## Формат

Backup имеет отдельный versioned container `.budgetbackup`.

Внешний JSON содержит только технические метаданные и crypto-параметры:

- `format = budget-accounting-backup`;
- `v = 1`;
- `created_at`;
- KDF: PBKDF2-HMAC-SHA256, 210000 iterations, random salt;
- cipher: AES-256-GCM, random nonce;
- ciphertext + authentication tag.

Внутри ciphertext хранится S4 snapshot бюджета и его digest. Приватные identity
ключи и ключ локальной БД в backup не включаются.

## Экспорт

1. Проверяется право `BudgetAction.export`.
2. Создается консистентный S4 snapshot.
3. Snapshot шифруется паролем пользователя.
4. Файл передается через Share Sheet.
5. Временный файл удаляется после завершения share flow.

Минимальная длина пароля — 8 символов.

## Preview импорта

До любой записи в локальную БД:

1. контейнер парсится;
2. проверяется версия и crypto contract;
3. AES-GCM проверяет пароль и целостность ciphertext;
4. snapshot digest и версия проверяются;
5. пользователю показываются имя бюджета, валюта и количество участников,
   категорий, счетов, операций, планов и чеков.

Неверный пароль, поврежденный ciphertext или snapshot не изменяют локальные данные.

## Restore

Если исходный `budget_id` отсутствует локально, snapshot применяется как есть
через существующий атомарный S4 restore.

Если `budget_id` уже существует:

- создается новый budget id;
- ремапятся ID категорий, счетов, receipts, transactions и plans;
- все ссылки между сущностями обновляются;
- users/devices сохраняют публичные identity ID;
- проверяются конфликты public key/device ownership;
- исходный signed sync checkpoint не переносится, так как подписи относятся к
  старому budget/entity namespace;
- восстановленный бюджет получает суффикс "(восстановлено)".

Таким образом существующий бюджет не перезаписывается.

## Проверки

Integration tests покрывают:

- export -> encrypted payload -> preview -> restore в новую БД;
- восстановление users/members/categories/accounts/transactions/plans/receipts;
- невозможность увидеть финансовые данные в plaintext контейнере;
- неверный пароль и поврежденный ciphertext без изменения БД;
- конфликт budget ID с восстановлением как отдельного remapped бюджета.
