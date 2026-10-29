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

### Isolated Android profile build

`tool/device_performance_main.dart` runs the real app shell against an encrypted,
synthetic database with the same deterministic 50,000 transactions and 50,000
sync operations as the desktop benchmark. The test entrypoint checks the Android
package name through a native channel **before opening the database** and
refuses to seed if it is not
`com.bekodeg.perftest.budget_accounting_system`. The CI build verifies that
package ID again in the APK. It installs alongside the normal app and does not
read or modify its database or preferences.

Push `perf/35-android-profile-harness` to run `Device Performance APK`, then
download the two-day artifact `isolated-device-performance-apk`. Install its
`app-profile.apk` on the test device. The first launch seeds the database;
wait for `PERF_DEVICE ready_ms` in logcat. Force-stop and relaunch the test app
for startup measurements without seed time. Record `am start -W`, Flutter
`PERF_DEVICE app_shell_first_frame_ms`, `dumpsys gfxinfo` frame counts and
percentiles, `dumpsys meminfo`, and observed navigation/scrolling on dashboard,
transaction list, monthly report and yearly report. Profile results should
include device model, Android version, build SHA and the exact dataset size.

The profile APK uses the production SQLCipher bootstrap and screen widgets, but
is a separate test application with synthetic financial data. Its debug signing
and package ID are unsuitable for release. The CI artifact is short-lived and
should not be promoted to `stage` or `main` as an application build.

## Acceptance evidence

For release acceptance, attach or link the latest `performance-baseline.log` from the `stage` run (or a manual rerun) and record the device/profile notes here or in the release acceptance document.
