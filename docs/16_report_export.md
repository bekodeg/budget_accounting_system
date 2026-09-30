# 16. Экспорт отчетов CSV/XLSX

## 16.1. Область экспорта

Экспорт строится из того же `ReportFilter`, что и отчет за произвольный период:

- границы `[fromInclusive, toExclusive)`;
- category ids;
- account ids;
- author ids.

Поэтому CSV/XLSX и экран отчета используют одинаковый набор исходных операций.

## 16.2. CSV

CSV содержит UTF-8 BOM и CRLF, чтобы файл предсказуемо открывался в распространенных
табличных редакторах.

Колонки:

```text
transaction_id
occurred_at
type
amount_minor
amount_decimal
currency
author_id
account_id
destination_account_id
category_id
description
```

`amount_minor` является каноническим целым значением. `amount_decimal` формируется
строково из minor units и не использует floating point.

## 16.3. XLSX

Workbook содержит минимум три листа:

1. `Summary` — income / expense / net по валютам;
2. `By Category` — фактические расходы по категориям;
3. `Transactions` — детализация операций.

Денежные значения в workbook записываются строками вместе с исходными minor units,
чтобы не терять точность при больших значениях.

## 16.4. Share Sheet и временные файлы

Экспорт полностью выполняется на устройстве.

`PlatformReportShareGateway`:

1. получает app-scoped temporary directory через `path_provider`;
2. удаляет старый каталог `budget_report_export`, если он остался;
3. записывает CSV и XLSX;
4. передает оба файла системному Share Sheet через `share_plus`;
5. в `finally` удаляет каталог экспорта.

Таким образом временные выгрузки не накапливаются между экспортами.

## 16.5. Имена файлов

Базовое имя:

```text
budget_<safe-budget-id>_<from-yyyymmdd>_<to-yyyymmdd>
```

Все символы вне `A-Z a-z 0-9 _ -` заменяются на `_`.

## 16.6. Слои

```text
PeriodReportScreen
  -> ExportReport
     -> ExtendedReportRepository
     -> ReportExportRepository
     -> ReportDocumentEncoder
     -> ReportShareGateway
```

Presentation не знает о файловой системе, XLSX library или platform sharing API.

## 16.7. Тестирование

Покрыты:

- UTF-8 CSV, стабильные колонки и escaping;
- XLSX с листами Summary / By Category / Transactions;
- точная сериализация minor units;
- безопасное детерминированное имя файла;
- orchestration ExportReport;
- smoke test реального создания и очистки временных CSV/XLSX файлов.
