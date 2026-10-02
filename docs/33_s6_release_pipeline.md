# S6 release pipeline

Issue: #37

## Release paths

Two release paths exist:

- `Main Release` publishes the exact signed APK artifact that passed Stage CI after a `stage -> main` merge.
- `Tagged Release Build` is triggered by a `v*` tag and rebuilds signed Android APK/AAB artifacts from the tagged source, runs tests, verifies the pinned signing certificate, and publishes SHA-256 checksums.

Tags must point to commits contained in `main`.

## Android signing secrets

Required repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_CERT_SHA256`

The keystore is reconstructed only in the runner temporary directory and is never uploaded as an artifact. The workflow validates the signing certificate fingerprint before building.

## Rotation procedure

1. Create a new release key in a controlled environment.
2. Record its SHA-256 certificate fingerprint with `keytool -list -v`.
3. Base64-encode the keystore without adding repository files.
4. Replace the five GitHub Actions secrets atomically.
5. Run a manual Tagged Release Build.
6. Verify the generated APK/AAB signatures and checksums.
7. Install the APK on a test device.
8. Only after validation, use the new key for production tags.

Never commit keystores, passwords, certificates, provisioning profiles, or decoded secret material.

## Local Android release build

Export the same signing variables locally, generate the Android host project, configure signing, then build:

~~~bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter create --platforms=android --project-name budget_accounting_system --org com.bekodeg --no-pub .
python3 tool/configure_lan_platform_permissions.py
python3 tool/configure_mlkit_android_dependencies.py
python3 tool/configure_android_release_signing.py
flutter build apk --release
flutter build appbundle --release
~~~

`ANDROID_KEYSTORE_PATH`, passwords and alias must be supplied through the environment.

## iOS

The tagged workflow contains an optional macOS job gated by repository variable `ENABLE_IOS_RELEASE=true`. Without Apple signing infrastructure it produces only an unsigned release app bundle for build validation.

A signed IPA/archive requires Apple distribution certificate and provisioning-profile infrastructure. Do not mark iOS signing as release-validated until a signed archive is produced and installed/tested on a real device.

## Release acceptance

Before closing #37:

- execute a tag dry-run on a `main` commit;
- verify APK and AAB artifacts exist;
- verify SHA-256 checksums;
- install the signed APK on a test device;
- confirm no signing secrets appear in logs or artifacts;
- record iOS signing status explicitly.
