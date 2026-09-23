# Drift schema history

This directory is the version-controlled history of the SQLite schema.

Drift is the single source of truth for local database migrations. Liquibase or hand-maintained duplicate schemas are not used.

## Configuration

`build.yaml` registers the application database:

```yaml
databases:
  app_database: lib/src/data/database/app_database.dart
```

Schema snapshots are stored in `drift_schemas/` and generated migration tests in `test/drift/`.

## Initial snapshot

For schema version 1 run:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev make-migrations
```

The generated `drift_schema_v1.json` is the immutable reference for installations created with schema version 1.

## Every schema change

1. Change table definitions in `lib/src/data/database/tables.dart`.
2. Increment `schemaVersion` in `app_database.dart`.
3. Regenerate Drift code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

4. Generate migration artifacts:

```bash
dart run drift_dev make-migrations
```

5. Implement the generated `fromNToN+1` migration step.
6. Add a data-integrity test that inserts representative data into the previous schema, migrates it, and verifies the data afterward.
7. Run:

```bash
flutter test
```

8. Commit together:
   - schema change;
   - bumped `schemaVersion`;
   - new `drift_schema_vN.json`;
   - generated step-by-step migration helper;
   - migration tests.

## CI invariant

CI runs `dart run drift_dev make-migrations` and then checks the working tree.

If a developer changes the Drift schema or `schemaVersion` without committing all generated migration artifacts, CI fails. This makes schema history part of the reviewed source rather than a developer-local artifact.

## Snapshot rules

- Never edit an already released schema snapshot manually.
- Never delete an old snapshot while supported installations may still upgrade from that version.
- A schema version is immutable after release.
- Migration code must preserve existing user data unless a documented product requirement explicitly says otherwise.
