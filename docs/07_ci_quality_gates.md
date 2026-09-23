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

## Branch protection / GitHub Rulesets

Rulesets являются административной настройкой GitHub и не хранятся в Git. Для репозитория нужно создать три **branch ruleset**: отдельно для `dev`, `stage` и `main`.

Путь в GitHub UI:

```text
Repository
  -> Settings
  -> Rules
  -> Rulesets
  -> New ruleset
  -> New branch ruleset
```

Для каждого ruleset:

- `Enforcement status`: **Active**;
- bypass list: оставить пустым, если нет осознанной необходимости в аварийном обходе;
- `Restrict deletions`: включить;
- `Block force pushes`: включить;
- `Require a pull request before merging`: включить;
- количество обязательных approvals: **0** для текущего single-developer workflow;
- `Require branches to be up to date before merging`: **не включать**.

Последний пункт важен: strict/up-to-date mode создавал бы дополнительные обновления source branch и дополнительные CI runs. Pipeline специально проверяет promotion собственными status checks и не должен повторно запускать тяжелый Stage CI.

### Ruleset: dev

Имя:

```text
Protect dev
```

Target branches:

```text
Include by pattern: dev
```

Rules:

- Require a pull request before merging;
- Require status checks to pass before merging;
- Required status check: `Dev lightweight check`;
- Restrict deletions;
- Block force pushes.

Не включать тяжелые проверки в required checks для `dev`. Назначение этой ветки — дешевая интеграция текущей разработки.

### Ruleset: stage

Имя:

```text
Protect stage
```

Target branches:

```text
Include by pattern: stage
```

Rules:

- Require a pull request before merging;
- Require status checks to pass before merging;
- Required status check: `Stage promotion gate`;
- Restrict deletions;
- Block force pushes.

`Stage promotion gate` проверяет, что PR приходит из `dev`. Полный `Stage validation` намеренно запускается **после merge/push в stage**, потому что именно resulting stage SHA затем тестируется и допускается к promotion в `main`.

### Ruleset: main

Имя:

```text
Protect main
```

Target branches:

```text
Include default branch
```

или явно:

```text
Include by pattern: main
```

Rules:

- Require a pull request before merging;
- Require status checks to pass before merging;
- Required status check: `Main promotion gate`;
- Restrict deletions;
- Block force pushes.

`Main promotion gate` проверяет две вещи:

1. source branch PR — `stage`;
2. exact head SHA уже имеет успешный push-run `Stage CI`.

Поэтому прямой feature/dev PR в `main` должен быть заблокирован самим status check.

### Проверка после настройки

После создания rulesets нужно проверить три негативных сценария:

1. direct push в `dev`, `stage` и `main` отклоняется;
2. PR `feature/* -> stage` не проходит `Stage promotion gate`;
3. PR `dev -> main` не проходит `Main promotion gate`.

И два штатных сценария:

1. `feature/* -> dev` проходит `Dev lightweight check`;
2. `dev -> stage -> Stage CI -> stage -> main` проходит всю цепочку.

Required status check в GitHub Rulesets задается по **имени job**, поэтому нужно использовать точные строки:

```text
Dev lightweight check
Stage promotion gate
Main promotion gate
```

Если GitHub не предлагает check в autocomplete, сначала нужно хотя бы один раз запустить соответствующий workflow, затем вернуться в настройки ruleset.

## Почему main не запускает тяжелый CI повторно

Commit, который попадает из `stage` в `main`, уже прошел полный Stage CI. Повторный `flutter test --coverage` и Android build на том же SHA только удваивали бы runner time.

Если в будущем появится release pipeline по тегам, release AAB/APK и iOS archive должны собираться отдельно по release tag, а не на каждом merge в `main`.
