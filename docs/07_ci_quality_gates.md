# 7. Ветки и CI/CD pipeline

Проект использует последовательное продвижение изменений:

```text
feature/*, fix/*, chore/*
          |
          v
         dev
          |
          v
        stage
          |
          v
         main
```

Цель схемы — получать быстрый feedback во время разработки и запускать дорогие проверки только один раз перед публикацией изменений в `main`.

## Назначение веток

### Рабочие ветки

Новые задачи выполняются в отдельных ветках от `dev`:

- `feature/<issue>-<name>` — новая функциональность;
- `fix/<issue>-<name>` — исправление;
- `chore/<name>` — инфраструктура, документация и технические изменения.

Рабочая ветка вливается Pull Request-ом в `dev`.

### dev

`dev` — интеграционная ветка текущей разработки.

Коммит или merge в `dev` **не запускает Flutter SDK, codegen, тесты, coverage или Android build**. Workflow `.github/workflows/flutter-ci.yml` выполняет только дешевые проверки Git:

1. checkout;
2. `git diff --check` для измененных строк;
3. поиск оставшихся merge-conflict markers.

Это намеренно легкий gate. Его задача — быстро ловить очевидно поврежденные коммиты, не расходуя runner time на тяжелые операции.

### stage

`stage` — кандидат для тестирования перед `main`.

Продвижение выполняется Pull Request-ом **только из `dev` в `stage`**. PR запускает дешевый `Stage promotion gate`, который проверяет источник ветки.

После merge/push в `stage` workflow `.github/workflows/stage-ci.yml` выполняет полный quality gate:

1. устанавливает Flutter и зависимости;
2. запускает `build_runner`;
3. повторно запускает codegen и сравнивает SHA-256 generated files;
4. генерирует Drift migrations и migration-test helper;
5. проверяет, что versioned migration artifacts закоммичены;
6. проверяет форматирование;
7. запускает `flutter analyze`;
8. запускает полный `flutter test --coverage`;
9. публикует coverage summary и LCOV artifact;
10. собирает Android debug APK;
11. публикует APK для ручного тестирования.

Coverage хранится 7 дней. Stage APK хранится 3 дня, чтобы не расходовать artifact storage дольше необходимого.

Если Stage CI упал, изменения не продвигаются в `main`. Исправление делается в рабочей ветке, проходит через `dev` и повторно продвигается в `stage`.

### main

`main` — стабильная ветка.

Изменения должны попадать в нее Pull Request-ом **только из `stage`**.

Workflow `.github/workflows/promote-main.yml` не повторяет Flutter tests и Android build. Вместо этого дешевый `Main promotion gate`:

1. проверяет, что source branch равен `stage`;
2. берет точный head commit PR;
3. через GitHub Actions API проверяет, что этот commit уже имеет успешный push-run workflow `Stage CI`.

Таким образом тяжелые операции выполняются в `stage` один раз, а `main` принимает только уже проверенный commit.

## Рекомендуемый цикл задачи

```text
1. checkout dev
2. create feature/<issue>-<name>
3. develop + local tests
4. Pull Request -> dev
5. merge -> dev
6. когда набор изменений готов к проверке: Pull Request dev -> stage
7. merge -> stage
8. Stage CI: analyze + full tests + coverage + APK
9. ручное тестирование stage APK
10. Pull Request stage -> main
11. Main promotion gate подтверждает успешный Stage CI
12. merge -> main
```

Не следует создавать отдельный `stage` PR для каждой мелкой правки. В `dev` можно накопить логически связанный набор изменений и продвинуть его в `stage` как тестируемый кандидат.

## Локальные проверки разработчика

Поскольку `dev` намеренно не выполняет тяжелый CI, разработчик обязан проверять изменяемую функциональность локально до PR:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

При изменении схемы Drift дополнительно выполняется migration workflow, описанный в `drift_schemas/README.md`.

## Generated files policy

`*.g.dart` и аналогичные generated Dart files не коммитятся.

На `stage` воспроизводимость проверяется так:

```text
build_runner
  -> hash generated files
  -> build_runner again
  -> hash generated files again
  -> hashes must match
```

`drift_schemas/`, наоборот, является versioned history и должен находиться в Git.

## Branch protection

Для полного соблюдения pipeline рекомендуется настроить GitHub branch protection/rulesets:

- `dev`: разрешить merge через PR; required check — `Dev lightweight check`;
- `stage`: запретить прямые изменения; required check для PR — `Stage promotion gate`;
- `main`: запретить прямые изменения; required check — `Main promotion gate`.

Административные branch-protection settings не хранятся в репозитории и должны быть включены в настройках GitHub.

## Почему main не запускает тяжелый CI повторно

Commit, который попадает из `stage` в `main`, уже прошел полный Stage CI. Повторный `flutter test --coverage` и Android build на том же SHA только удваивали бы runner time.

Если в будущем появится release pipeline по тегам, release AAB/APK и iOS archive должны собираться отдельно по release tag, а не на каждом merge в `main`.
