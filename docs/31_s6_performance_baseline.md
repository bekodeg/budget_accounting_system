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

## Device profiling

The automated harness measures SQLite/Drift and repository latency on a desktop runner. Before release, profile at least one representative Android device for:

- first paint of dashboard after opening a large database;
- scrolling the transaction list with a large history;
- opening monthly/year reports;
- memory pressure while the default transaction list materializes many rows.

The current transaction list API returns the full active history rather than a
paginated window. The database benchmark protects query latency; device
profiling also checks the cost of mapping rows and rendering the list.

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
`PERF_DEVICE ready_ms` and `PERF_DEVICE app_shell_first_frame_ms`, Flutter
`PERF_DEVICE frames=30` frame-time batches, `dumpsys meminfo`, and observed
navigation/scrolling on dashboard,
transaction list, monthly report and yearly report. Profile results should
include device model, Android version, build SHA and the exact dataset size.
`dumpsys gfxinfo` may report zero frames for Flutter rendering; its percentiles
must not be used when its frame count is zero.
CI uses an ephemeral debug signing key for this test APK. To replace it with a
later CI build, uninstall only the isolated test package first; Android rejects
an in-place update signed by a different key. The next first launch recreates
the synthetic database.

The profile APK uses the production SQLCipher bootstrap and screen widgets, but
is a separate test application with synthetic financial data. Its debug signing
and package ID are unsuitable for release. The CI artifact is short-lived and
should not be promoted to `stage` or `main` as an application build.

### Pixel 8 baseline, 2026-10-30

Physical Pixel 8, Android 17, ARM64 profile build; 50,000 deterministic
transactions and 50,000 sync operations in the encrypted test database. The
isolated package was installed alongside the production package. Runs were
made with the same device and dataset. These are single-run observations, not
statistical limits or measurements of the production-signed APK.

| Observation | Eager transaction widgets, `74d1d8b` | Lazy transaction widgets, `84f51ca` |
| --- | ---: | ---: |
| `am start -W` cold relaunch after seeding | 824 ms | 497 ms |
| Test runtime ready after relaunch | 574 ms | 371 ms |
| App shell first frame after relaunch | 590 ms | 387 ms |
| PSS after relaunch | 370,665 KB | 300,279 KB |
| Largest frame time in first 10 list swipes | 842.218 ms | 266.646 ms |
| PSS after 10 list swipes | 365,804 KB | 319,850 KB |

The eager list constructed 50,000 `Card` widgets in one build. Replacing it
with `ListView.builder` removed that synchronous construction and reduced
observed startup memory by about 70 MB. After the first optimized swipe, the
following 30-frame batches had p90 times around 5–8 ms with no frames over
16 ms in most batches. A 248–267 ms total-span first-swipe frame recurred
after cold relaunch. Diagnostic build `fd3af62` measured a 334.876 ms
first-swipe frame, with 14.863 ms build time and 6.421 ms raster time. Most of
the interval was outside these two phases, so this measurement does not
support attributing the pause to synchronous list construction. The cause of
that scheduling gap remains open for observation; the subsequent swipe frames
were below 11 ms maximum in the diagnostic run. Pagination may still reduce
the cost of mapping all rows, but needs separate evidence before implementation.

On the optimized build, the populated September 2026 monthly report and 2026
year report both rendered with category charts. The monthly navigation batches
had maximum 54.146 ms and p90 at most 24.45 ms; the year navigation batches
had maximum 19.048 ms and p90 at most 9.705 ms. PSS after each report was
286,707 KB and 287,777 KB respectively. No Flutter exception or crash was
observed in these paths.

The latest Stage Performance Baseline run `40863259647` measured a 27,926,528
byte database, 441 ms active list query, 40 ms dashboard, 42 ms monthly report,
14 ms year report, 11 ms sync state vector and 6 ms missing-operations tail.
Those numbers describe the Ubuntu CI runner and are not device UI frame times.

## Acceptance evidence

For release acceptance, attach or link the latest `performance-baseline.log` from the `stage` run (or a manual rerun) and record the device/profile notes here or in the release acceptance document.
