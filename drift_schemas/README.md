# Drift schema history

This directory is the version-controlled history of the SQLite schema.

Drift can export every `schemaVersion`, generate step-by-step migrations and generate migration tests. Schema snapshots in this directory must be committed and must not be edited or removed after a released application version has used them.

## Initial snapshot

After installing Flutter dependencies and generating Drift code, create the initial schema snapshot:

```bash
dart run drift_dev make-migrations
```

For schema version 1 this creates the first snapshot under this directory.

## Every schema change

1. Change the table definitions in `lib/src/data/database/tables.dart`.
2. Increment `schemaVersion` in `lib/src/data/database/app_database.dart`.
3. Run:

```bash
dart run drift_dev make-migrations
```

4. Implement the generated `fromNToN+1` migration step.
5. Run the generated migration tests.
6. Commit the new snapshot, migration step and tests together with the schema change.

Do not use Liquibase for the application database. Drift is the single source of truth for the local SQLite schema and its migrations.
