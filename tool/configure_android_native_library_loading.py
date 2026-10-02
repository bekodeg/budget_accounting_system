#!/usr/bin/env python3
from pathlib import Path
import re

MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
BUILD_FILE = Path("android/app/build.gradle.kts")


def configure_manifest() -> None:
    if not MANIFEST.exists():
        raise SystemExit(f"Missing Android manifest: {MANIFEST}")

    text = MANIFEST.read_text(encoding="utf-8")
    match = re.search(r"<application\b[^>]*>", text, flags=re.DOTALL)
    if match is None:
        raise SystemExit("Unable to locate <application> in AndroidManifest.xml.")

    application = match.group(0)
    if "android:extractNativeLibs=" in application:
        updated = re.sub(
            r'android:extractNativeLibs\s*=\s*"[^"]*"',
            'android:extractNativeLibs="true"',
            application,
            count=1,
        )
    else:
        updated = application[:-1] + '\n        android:extractNativeLibs="true">'

    text = text[: match.start()] + updated + text[match.end() :]
    MANIFEST.write_text(text, encoding="utf-8")


def configure_gradle() -> None:
    if not BUILD_FILE.exists():
        raise SystemExit(f"Missing Android Gradle file: {BUILD_FILE}")

    text = BUILD_FILE.read_text(encoding="utf-8")
    if "useLegacyPackaging = true" in text:
        return
    if "packaging {" in text:
        raise SystemExit(
            "Generated Android template already contains a packaging block. "
            "Review it before inserting native-library compatibility settings."
        )

    marker = "android {"
    if marker not in text:
        raise SystemExit("Unable to locate android block in build.gradle.kts.")

    block = """android {
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
"""
    text = text.replace(marker, block, 1)
    BUILD_FILE.write_text(text, encoding="utf-8")


def main() -> None:
    configure_manifest()
    configure_gradle()


if __name__ == "__main__":
    main()
