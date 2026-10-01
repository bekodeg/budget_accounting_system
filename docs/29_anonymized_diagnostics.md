# Anonymized diagnostics

## Принцип

Diagnostic export строится по allowlist. Пакет не выполняет redaction
произвольного дампа базы: чувствительные таблицы и поля вообще не читаются.

В стандартный ZIP входят только:

- `diagnostics.json` — версия приложения, schema version, snapshot protocol,
  ОС и агрегированные технические счетчики;
- `errors.jsonl` — до 100 последних безопасных записей вида
  timestamp/category/error-type.

Не экспортируются суммы, balance, описания транзакций, merchant, QR payload,
изображения чеков, имена/ID пользователей и бюджетов, public/private keys,
signatures, transport secrets или database key.

## Preview

Перед Share Sheet пользователь видит версии, платформу, агрегированные counts,
число safe errors и точный список файлов архива.

## Safe error capture

Global Flutter/platform handlers записывают только:

- category: `sync`, `db` или `app`;
- runtime type исключения;
- UTC timestamp.

Текст exception и stack trace не сохраняются, потому что они могут содержать
пользовательские данные.

## Ограничение размера

Логи хранятся в JSONL с ротацией: 3 файла по 64 KiB. В export включаются не
более 100 последних записей. ZIP создается во временной директории и удаляется
после завершения Share Sheet.

## Проверки

Tests проверяют:

- отсутствие намеренно добавленных secret amount/description/QR/name/id/key;
- фиксированный состав ZIP;
- ротацию и bounded количество log-файлов.
