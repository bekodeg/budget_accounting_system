# 21. State vector sync protocol

## 21.1. Цель

После установления защищенного LAN-канала устройства обмениваются только теми
sync_operations, которых еще нет у второй стороны. Полный журнал при каждом sync
не пересылается.

Протокол не зависит от роли TCP client/server: обе стороны выполняют одинаковую
симметричную последовательность.

## 21.2. State vector

State vector хранит максимальный Lamport clock отдельно для каждого устройства:

    {
      "device-a": 17,
      "device-b": 8
    }

Операция устройства device-a нужна peer-у, если ее clock больше значения
state_vector для device-a. Отсутствующее устройство означает clock 0.

SyncDao строит vector через MAX(logical_clock) с группировкой по device_id.
Missing operations выбираются по каждому device threshold, а не по одному
глобальному clock.

## 21.3. Wire format

Текущая версия протокола: 1.

Все frames являются UTF-8 JSON внутри уже аутентифицированного и зашифрованного
SecureLanChannel.

Типы сообщений:

### hello

    {
      "v": 1,
      "type": "hello",
      "budget_id": "...",
      "device_id": "...",
      "state_vector": { "...": "17" }
    }

Clock передается decimal string, чтобы не зависеть от ограничений JSON number.
device_id обязан совпасть с peer identity, уже подтвержденной LAN handshake.

### batch

    {
      "v": 1,
      "type": "batch",
      "budget_id": "...",
      "batch_id": "device-a:3",
      "has_more": true,
      "operations": [...]
    }

Одна операция содержит исходный op_id, entity coordinates, operation type,
canonical patch JSON, author/device ids, Lamport clock, created_at и Ed25519
signature.

Максимум 100 операций в одном batch.

### ack

    {
      "v": 1,
      "type": "ack",
      "budget_id": "...",
      "batch_id": "device-a:3",
      "state_vector": { "...": "17" }
    }

Ack отправляется только после атомарного ingest всего принятого batch.

### error

    {
      "v": 1,
      "type": "error",
      "budget_id": "...",
      "code": "...",
      "message": "..."
    }

Version mismatch, budget mismatch, invalid signature, op-id collision и batch-id
mismatch являются явными protocol errors.

## 21.4. Симметричная сессия

Обе стороны:

1. вычисляют свой state vector;
2. одновременно отправляют hello;
3. получают remote vector;
4. выбирают до 100 операций, отсутствующих у peer;
5. одновременно отправляют batch;
6. принимают и атомарно ingest-ят remote batch;
7. отправляют ack с новым local state vector;
8. получают ack своего batch и обновляют представление remote vector;
9. повторяют цикл, пока обе стороны не передали has_more = false.

Даже финальный пустой batch отправляется один раз. Поэтому обе стороны однозначно
понимают, что в текущей сессии больше операций нет.

## 21.5. Проверка remote operations

DriftSyncJournal перед вставкой каждой новой операции:

- проверяет budget_id;
- проверяет idempotence по op_id;
- отклоняет другой payload с уже существующим op_id;
- находит public identity автора;
- проверяет, что device принадлежит автору и не отозван;
- проверяет Ed25519 signature по canonical signing bytes.

Весь batch применяется внутри одной Drift/SQLite transaction.

Если хотя бы одна операция не проходит проверку, ранее вставленные операции этого
batch откатываются и ack не отправляется.

## 21.6. Retry после разрыва

Отдельная persistent retry queue для batch не требуется.

Если соединение оборвалось:

- операции, которые peer успел commit-нуть, попадут в его state vector при новом hello;
- операции, которые не были commit-нуты, останутся missing;
- повтор уже сохраненного op_id безопасно распознается как duplicate.

Поэтому новая sync-сессия продолжает с фактического состояния журналов, даже если
предыдущий ack потерялся.

## 21.7. Диагностика

SyncSessionService.synchronize возвращает локальные metrics:

- sent operations;
- received operations;
- duplicate operations;
- sent batches;
- received batches;
- started/completed timestamps;
- duration.

Метрики не отправляются наружу автоматически и не содержат содержимое бюджета.

## 21.8. Конвергенция

После обмена оба журнала содержат один набор подписанных операций. Для одинакового
набора SyncMergeEngine детерминированно получает одинаковое field-level состояние,
независимо от порядка первоначального создания операций.

Автоматические tests покрывают:

- codec round-trip;
- protocol version mismatch;
- per-device state vector;
- batch size limit;
- два peer-а с разными журналами;
- отсутствие повторной пересылки истории при втором sync;
- разрыв соединения и продолжение после reconnect;
- три peer-а с последовательными pairwise sessions;
- duplicate/collision handling;
- invalid signature rollback всего batch.
