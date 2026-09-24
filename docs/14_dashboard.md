# 14. Dashboard бюджета

## 14.1. Назначение

Раздел «Операции» является ежедневным dashboard активного бюджета.

В верхней части отображаются показатели текущего календарного месяца:

- доход;
- расход;
- net cash flow;
- текущий доступный остаток.

Ниже расположен реактивный журнал операций с фильтрами.

## 14.2. Финансовая логика

Widget не агрегирует финансовые данные.

```text
BudgetDashboardScreen
 -> WatchDashboardSummary
 -> DashboardRepository
 -> DriftDashboardRepository
 -> ReportDao
 -> SQLite
```

Report query наблюдает таблицы accounts и transactions и пересчитывается после
изменений.

## 14.3. Валюты

MVP не имеет FX-модели и не складывает разные валюты.

Каждая dashboard-карточка содержит отдельную строку на currency code:

```text
1250.00 EUR
50.00 USD
```

Это относится и к cash flow, и к доступному остатку.

## 14.4. Cash flow

Месячный cash flow использует период:

```text
[first day of month, first day of next month)
```

INCOME и EXPENSE агрегируются раздельно.

TRANSFER не входит в income/expense/net.

Soft-deleted операции исключаются.

## 14.5. Доступный остаток

Для каждого активного счета:

```text
opening
+ income
- expense
- outgoing transfer
+ incoming transfer
```

После этого счета суммируются только внутри одинаковой валюты.

Архивные счета не входят в текущий «Доступно», но их история остается в БД.

## 14.6. Быстрое создание операции

Кнопка «Операция» на dashboard открывает тот же
`TransactionEditorScreen`, что и журнал.

Таким образом quick-add и обычный CRUD используют одинаковую application и
domain validation.

## 14.7. Навигация

Основные разделы:

1. Операции / dashboard;
2. План;
3. Отчеты;
4. Настройки.

Переключение активного бюджета остается в AppBar.

## 14.8. Адаптивность и тема

Dashboard metrics размещены в горизонтально прокручиваемом ряду, поэтому не
требуют фиксированной ширины телефона.

MaterialApp использует:

- Material 3;
- light theme;
- dark theme;
- `ThemeMode.system`.

## 14.9. Тестирование

Покрыты:

- monthly income/expense/net;
- transfer-neutral cash flow;
- balance по нескольким счетам;
- независимые EUR/USD агрегаты;
- dashboard cards;
- quick-add;
- реактивное обновление summary.

Полный Flutter/analyze/coverage/APK gate выполняется на stage.
