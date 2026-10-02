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

После merge/push в `stage` workflow `.github/workflows/stage-ci.yml` выполняет полный quality gate параллельными jobs:

1. `Stage security` — один Trivy filesystem scan для `vuln`, `secret` и `misconfig`;
2. `Stage generated code` — восстанавливает cache generated Dart по hash входных Drift/dependency файлов и запускает `build_runner` только при cache miss;
3. тот же preparation job запускает Drift migration checks только при изменении database schema, `drift_schemas/` или dependency lockfiles;
4. generated Dart упаковывается с SHA-256 manifest и передается downstream jobs как короткоживущий artifact;
5. `Stage quality` и `Stage Android release` стартуют параллельно после preparation;
6. quality job проверяет форматирование, `flutter analyze`, полный `flutter test --coverage` и coverage baseline;
7. Android job восстанавливает Gradle cache, проверяет signing secrets/certificate и собирает подписанный release APK;
8. финальный job `Stage validation` сохраняет прежнее имя итогового gate и проходит только если security, generated-code, quality и Android release jobs завершились успешно.

Trivy выполняется ровно один раз и стартует параллельно с подготовкой generated code. Используется `aquasecurity/trivy-action` версии `v0.36.0`, закрепленный по commit SHA; база Trivy кешируется штатным механизмом action. На текущем этапе `ignore-unfixed: true`, поэтому gate не блокирует выпуск на уязвимости без доступного исправления.

Android build использует отдельный Gradle cache (`~/.gradle/caches`, `~/.gradle/wrapper`) с ключом от generated Android Gradle configuration и `pubspec.lock`. Это особенно ускоряет повторные release builds, которые раньше доминировали во времени Stage CI.

Coverage хранится 7 дней. Generated-code artifact хранится 1 день, Stage APK — 3 дня.

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

Форматирование должно выполняться версией Dart, совместимой с Flutter SDK из Stage CI. Если локальный SDK отличается, эталонным считается результат `dart format`, запущенный версией Dart, которую сообщает Stage CI.

## Generated files policy

`*.g.dart` и аналогичные generated Dart files не коммитятся.

Stage CI не запускает `build_runner` дважды подряд. Вместо этого generated Dart кешируется по hash входов генератора (`lib/src/data/database/**`, `pubspec.yaml`, `pubspec.lock`). При cache miss выполняется один generation pass, затем результат упаковывается вместе с SHA-256 manifest. Downstream jobs проверяют manifest после восстановления artifact.

Следствия:

- изменения, не затрагивающие Drift schema/dependencies, обычно используют уже готовый generated-code cache;
- изменение generator inputs автоматически создает новый cache key и выполняет один новый generation pass;
- quality и Android jobs получают один и тот же проверенный generated artifact.

`drift_schemas/`, наоборот, является versioned history и должен находиться в Git. Migration generation/check запускается только если текущий stage push изменяет database schema, `drift_schemas/` или dependency lockfiles; для manual `workflow_dispatch` проверка выполняется всегда.

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

## Автоматический GitHub Release

Каждый push/merge в `main` запускает workflow `.github/workflows/release-main.yml`.

Release workflow **не пересобирает Android**. Он использует APK, который уже был собран и протестирован на `stage`:

1. убеждается, что новый commit `main` является merge commit с двумя parents;
2. определяет второй parent как протестированный `stage` SHA;
3. проверяет, что дерево файлов `main` совпадает с деревом этого `stage` SHA;
4. находит успешный push-run `Stage CI` для exact stage SHA;
5. скачивает artifact `stage-budget-accounting-release-apk`;
6. вычисляет SHA-256 APK;
7. создает GitHub Release и прикладывает APK и файл checksum;
8. генерирует release notes средствами GitHub.

Тег генерируется автоматически из версии `pubspec.yaml` и номера run. Для версии `0.1.0+1` он имеет вид:

```text
v0.1.0-build.1-main.<run-number>
```

Release name сохраняет исходную Flutter-версию:

```text
Budget Accounting 0.1.0+1 · main #<run-number>
```

Workflow идемпотентен: повторный запуск не создает второй release с тем же тегом.

В GitHub Release публикуется **подписанный release APK**, собранный на `stage`. Один и тот же Android signing key должен использоваться для всех последующих версий приложения: это позволяет устанавливать обновления поверх уже установленной версии без удаления локальных данных.

## Постоянная Android-подпись

Keystore никогда не коммитится в Git. Stage CI получает его только из GitHub Actions Secrets и восстанавливает во временный файл внутри runner.

Нужно один раз создать production/test release key на доверенной машине, например:

```bash
keytool -genkeypair \
  -v \
  -keystore budget-accounting-release.jks \
  -alias budget-accounting \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

После создания ключа сохранить резервную копию keystore вне GitHub. Потеря этого файла или паролей приведет к невозможности выпускать APK, которые Android сможет установить как обновление существующего приложения.

Получить SHA-256 сертификата:

```bash
keytool -list -v \
  -keystore budget-accounting-release.jks \
  -alias budget-accounting
```

Для Linux/macOS получить base64 без переносов строк:

```bash
base64 < budget-accounting-release.jks | tr -d '\n'
```

В GitHub открыть:

```text
Repository
  -> Settings
  -> Secrets and variables
  -> Actions
  -> New repository secret
```

Создать пять secrets:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
ANDROID_CERT_SHA256
```

`ANDROID_CERT_SHA256` содержит SHA-256 fingerprint сертификата. Stage CI нормализует регистр и двоеточия и сравнивает фактический fingerprint с закрепленным значением. Это предохраняет release chain от случайной замены keystore.

Стабильный Android application id зафиксирован как:

```text
com.bekodeg.budget_accounting_system
```

Его нельзя менять между версиями, которые должны обновляться поверх уже установленного приложения.

## Почему main не запускает тяжелый CI повторно

Commit, который попадает из `stage` в `main`, уже прошел полный Stage CI. Повторный `flutter test --coverage` и Android build на том же исходном дереве только удваивали бы runner time.

`main` выполняет только дешевую release-оркестрацию: находит проверенный Stage CI artifact и публикует его как GitHub Release.
