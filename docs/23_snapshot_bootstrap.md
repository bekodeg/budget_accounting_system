# 23. Первичная синхронизация через snapshot + tail

## 23.1. Цель

Новое устройство не должно скачивать и переигрывать весь журнал операций с момента
создания бюджета.

Bootstrap состоит из двух фаз:

1. атомарный snapshot материализованного бюджета;
2. обычный state-vector sync для операций, появившихся после точки snapshot.

## 23.2. Формат snapshot

Snapshot имеет versioned canonical JSON body и SHA-256 digest.

В body входят:

- schema/protocol version;
- budget id;
- created_at;
- users/public identities участников;
- devices;
- budget metadata;
- memberships;
- categories;
- accounts;
- receipts;
- transactions;
- monthly plans;
- compact checkpoint operations.

Private keys и budget transport secret в snapshot не входят.

## 23.3. Compact baseline

Для корректного LWW после bootstrap переносится не весь sync journal.

Snapshot включает:

- operation, победившую для каждого materialized field;
- победивший tombstone для удаленных сущностей;
- максимальную operation каждого device для восстановления state vector.

Таким образом новое устройство знает версии текущего materialized state и одновременно
не запрашивает старые операции, которые уже учтены в snapshot.

## 23.4. Консистентность

Создание snapshot выполняется одной Drift/SQLite transaction:

- materialized tables;
- checkpoint operations;
- state vector

читаются из одной согласованной версии БД.

Если во время передачи на исходном устройстве появляются новые операции, они не входят
в snapshot checkpoint и после bootstrap будут обнаружены обычным state-vector protocol
как tail.

## 23.5. Проверка импорта

Перед изменением локальной БД получатель проверяет:

- snapshot protocol version;
- local DB schema version;
- budget id;
- SHA-256 digest;
- принадлежность checkpoint rows бюджету;
- author/device identity каждой checkpoint operation;
- подпись checkpoint operation.

Только после успешной проверки выполняется единая SQLite transaction с upsert всех
snapshot rows и compact baseline operations.

Поврежденный или неподходящий snapshot не изменяет локальный budget state.

## 23.6. Передача по LAN

BudgetSnapshotSessionService работает поверх уже authenticated/encrypted
SecureLanChannel.

Source отправляет budget_snapshot frame. Receiver:

1. проверяет и применяет snapshot;
2. отправляет snapshot_ack с digest.

Source считает snapshot подтвержденным только после корректного ACK.

После этого обе стороны запускают обычный SyncSessionService на том же защищенном
канале и обмениваются только tail operations.

## 23.7. Compaction hook

После подтвержденного snapshot_ack вызывается BudgetSnapshotCompactionHook.

В текущей версии hook только является extension point: автоматическое удаление старых
operations не выполняется. Будущая compaction должна учитывать подтверждение snapshot
всеми необходимыми peers и сохранять compact baseline, достаточный для merge.

## 23.8. Тестирование

Integration tests покрывают:

- перенос materialized budget state;
- восстановление checkpoint state vector;
- concurrent change после создания snapshot;
- передачу только tail operation после checkpoint;
- materialization tail на новом устройстве;
- отказ импорта при поврежденном digest без частичного изменения БД.
