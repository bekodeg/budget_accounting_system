# S6 performance baseline

Issue: #35

## Scope

The benchmark models a multi-year local-first budget with:

- 50,000 transactions by default;
- 50,000 sync operations by default;
- 4 accounts;
- 12 categories;
- 5 devices;
- deterministic timestamps and values so runs are comparable.

The dataset runs automatically when `stage` is updated and can also be started manually. Dataset size can be overridden for a manual run without changing source code.

## CI placement

Normal `dev` CI remains lightweight. The large-history benchmark runs on `stage` promotions, where release-quality validation already belongs, and is also available through `workflow_dispatch`. Routine feature commits therefore do not pay the performance-test cost.

## Measured paths and budgets

The harness prints actual elapsed time and fails if a path exceeds its current S6 budget.

| Path | Default budget |
| --- | ---: |
| Open active transaction history (50k rows) | 8000 ms |
| Dashboard | 4000 ms |
| Monthly report | 5000 ms |
| Year report | 6000 ms |
| Sync state vector (50k ops) | 2500 ms |
| First 500 missing ops for one device | 1500 ms |

These are release guardrails for the GitHub Ubuntu runner, not UI frame-time targets. Tightening them is expected after repeated stable runs. Relaxing a budget requires a documented reason.

The benchmark also records setup time and SQLite `page_count * page_size` as `database_bytes` so DB growth remains visible even when query latency is stable.

## Query-plan protections

S6 adds idempotent runtime indexes for hot paths that were not fully covered by the original v1 schema:

- `idx_transactions_budget_destination_account_occurred` for transfer destinations and account filters;
- `idx_sync_operations_budget_device_clock` for state-vector tail exchange;
- `idx_sync_operations_budget_entity_clock` for deterministic entity materialization.

`test/data/database/performance_indexes_test.dart` checks the indexes exist and asserts representative queries use indexed SEARCH plans rather than full table scans.

Runtime creation is deliberate: `CREATE INDEX IF NOT EXISTS` upgrades existing schema-v1 local databases without a destructive migration or schema-version bump.

## Reproducing

Run the benchmark manually:

```bash
flutter pub get
PERF_TRANSACTION_COUNT=50000 \
PERF_SYNC_OPERATION_COUNT=50000 \
flutter test benchmark/large_history_benchmark_test.dart --reporter expanded
```

Example output keys:

```text
PERF dataset_transactions=50000
PERF dataset_sync_operations=50000
PERF setup_ms=...
PERF database_bytes=...
PERF dashboard_ms=... budget_ms=4000
PERF monthly_report_ms=... budget_ms=5000
```

## Device profiling still required

The automated harness measures SQLite/Drift and repository latency on a desktop runner. Before release, profile at least one representative Android device for:

- first paint of dashboard after opening a large database;
- scrolling the transaction list with a large history;
- opening monthly/year reports;
- memory pressure while the default transaction list materializes many rows.

The current transaction list API returns the full active history rather than a paginated window. This is tracked as a release-observation point: the benchmark protects DB latency, while device profiling determines whether UI pagination must become a follow-up optimization.

## Acceptance evidence

For release acceptance, attach or link the latest `performance-baseline.log` from the `stage` run (or a manual rerun) and record the device/profile notes here or in the release acceptance document.
