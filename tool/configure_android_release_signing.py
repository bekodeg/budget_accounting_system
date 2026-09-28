#!/usr/bin/env python3
from pathlib import Path

APPLICATION_ID = "com.bekodeg.budget_accounting_system"
BUILD_FILE = Path("android/app/build.gradle.kts")

if not BUILD_FILE.exists():
    raise SystemExit(
        "Expected android/app/build.gradle.kts after flutter create; "
        "the Flutter Android template may have changed."
    )

text = BUILD_FILE.read_text(encoding="utf-8")

application_id_line = f'applicationId = "{APPLICATION_ID}"'
if application_id_line not in text:
    raise SystemExit(
        f"Expected stable Android applicationId {APPLICATION_ID!r}; "
        "refusing to build an APK with a different application identity."
    )

if "import java.io.FileInputStream" in text or "import java.util.Properties" in text:
    raise SystemExit(
        "Unexpected existing keystore-property imports in generated Gradle file; "
        "review the Flutter template before changing signing configuration."
    )

signing_block = """    signingConfigs {
        create("release") {
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            storeFile = System.getenv("ANDROID_KEYSTORE_PATH")?.let { file(it) }
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
        }
    }

"""

build_types_marker = "    buildTypes {"
if build_types_marker not in text:
    raise SystemExit("Could not find buildTypes block in generated Gradle file.")

if "signingConfigs {" not in text:
    text = text.replace(build_types_marker, signing_block + build_types_marker, 1)

debug_signing = '            signingConfig = signingConfigs.getByName("debug")'
release_signing = '            signingConfig = signingConfigs.getByName("release")'

if debug_signing in text:
    text = text.replace(debug_signing, release_signing, 1)
elif release_signing not in text:
    raise SystemExit(
        "Could not find the generated debug signing assignment. "
        "Review the current Flutter Android template."
    )

BUILD_FILE.write_text(text, encoding="utf-8")
