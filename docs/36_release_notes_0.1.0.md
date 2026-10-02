# Release notes — 0.1.0+2

## Первый MVP release candidate

Версия 0.1.0+2 представляет первый полный local-first MVP приложения Budget Accounting System.

## Основные возможности

- локальное создание бюджета и профиля пользователя;
- счета, категории, доходы, расходы и переводы;
- месячный план по категориям и расчет plan/fact;
- dashboard, месячные, годовые и произвольные отчеты;
- экспорт CSV/XLSX;
- создание операций из фискального QR;
- импорт фотографии/скана чека и OCR;
- роли OWNER / EDITOR / VIEWER;
- offline invitations;
- P2P LAN synchronization без централизованного backend;
- state-vector incremental sync;
- deterministic conflict resolution;
- multi-peer coordinator topology и failover;
- snapshot bootstrap нового устройства;
- шифрование локальной БД;
- зашифрованный backup/restore;
- anonymized diagnostics.

## Качество и release engineering

S6 добавляет:

- автоматизированный critical user-flow regression;
- coverage baseline gate;
- performance benchmark на 50 000 транзакций и 50 000 sync operations;
- query-plan regression checks;
- 5-device simulated convergence regression;
- concurrent create/update/delete conflict regression;
- tag-triggered Android release workflow;
- signed APK/AAB build path;
- SHA-256 release checksums.

## Известные ограничения

- Финальный physical-device acceptance для multi-device lifecycle/network-loss scenarios выполняется отдельно.
- Android release artifact должен быть установлен и проверен на реальном устройстве перед публичным релизом.
- Подписанный iOS archive требует доступной Apple Developer signing infrastructure.
- mDNS может блокироваться политиками локальной сети; предусмотрен manual endpoint fallback.
- При полной сетевой изоляции изменения остаются локальными и синхронизируются только после появления канала связи.
- Отдельного пользовательского экрана полной истории изменения полей пока нет; техническая история хранится в signed sync journal.

## Безопасность

Release signing keys, database keys и transport secrets не хранятся в репозитории.

Diagnostics построены по allowlist и не должны включать пользовательские финансовые данные или ключевой материал.

## Обновление

Перед установкой release candidate рекомендуется сохранить актуальный encrypted backup важного бюджета.

Для production release используйте только артефакт, прошедший release pipeline и соответствующий опубликованному SHA-256 checksum.
