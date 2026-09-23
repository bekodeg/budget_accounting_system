# Drift schema history

This directory is the version-controlled history of the SQLite schema.

Drift snapshots are generated artifacts. They must be committed, must not be edited by hand, and must not be removed after a released application version has used them.

## Configuration

`build.yaml` declares the application database for Drift tooling:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          databases:
            app_database: lib/src/data/database/app_database.dart
          schema_dir: drift_schemas/
          test_dir: test/drift/
```

This makes `dart run drift_dev make-migrations` the single command for generating schema history, step-by-step migration helpers and migration tests.

## Initial snapshot

Before the first schema change, run:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev make-migrations
```

For schema version 1 Drift creates `drift_schemas/app_database/drift_schema_v1.json` and migration test support under `test/drift/`.

Commit those files before changing `schemaVersion`.

## Every schema change

1. Change table definitions in `lib/src/data/database/tables.dart`.
2. Increment `schemaVersion` in `lib/src/data/database/app_database.dart`.
3. Generate Drift code:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Generate migration artifacts:
   ```bash
   dart run drift_dev make-migrations
   ```
5. Implement the generated `fromNToN+1` migration step.
6. Extend the generated migration test with a data-integrity scenario for the changed tables.
7. Run:
   ```bash
   flutter test
   flutter analyze
   ```
8. Commit the schema snapshot, step migration, tests and schema source change together.

## Data-integrity rule

A structural schema check is not enough. For each migration that can affect existing rows, the test must:

1. create the previous schema;
2. insert representative rows using the previous schema;
3. run the real application migration;
4. verify the resulting schema;
5. verify that the representative business data is still readable and semantically unchanged.

## CI rule

CI runs `make-migrations` from a clean checkout and then executes `git diff --exit-code` for the schema/migration paths. Generated migration artifacts must match files committed to git. If generation changes tracked files, the pull request is incomplete and fails.

This catches common mistakes:

- `schemaVersion` was bumped without a new snapshot;
- tables changed without bumping `schemaVersion`;
- migration step/test files are stale;
- generated Drift schema history was not committed.

Do not use Liquibase for the application database. Drift is the single source of truth for SQLite schema and migrations.
