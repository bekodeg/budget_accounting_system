#!/usr/bin/env python3
"""Guard the generated Android host used only for device profiling."""

from pathlib import Path

APP_ID = "com.bekodeg.perftest.budget_accounting_system"
BUILD_FILE = Path("android/app/build.gradle.kts")
MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
ACTIVITY = Path(
    "android/app/src/main/kotlin/com/bekodeg/perftest/"
    "budget_accounting_system/MainActivity.kt"
)


def main() -> None:
    build = BUILD_FILE.read_text(encoding="utf-8")
    application_id = f'applicationId = "{APP_ID}"'
    if build.count(application_id) != 1:
        raise SystemExit("Refusing performance build without its isolated application ID")

    manifest = MANIFEST.read_text(encoding="utf-8")
    label = 'android:label="budget_accounting_system"'
    if label not in manifest:
        raise SystemExit("Unexpected generated Android application label")
    MANIFEST.write_text(
        manifest.replace(label, 'android:label="Budget Performance Test"', 1),
        encoding="utf-8",
    )

    activity = ACTIVITY.read_text(encoding="utf-8")
    expected = (
        f"package {APP_ID}\n\n"
        "import io.flutter.embedding.android.FlutterActivity\n\n"
        "class MainActivity : FlutterActivity()\n"
    )
    if activity.replace("\r\n", "\n") != expected:
        raise SystemExit("Unexpected generated MainActivity; review the template")
    ACTIVITY.write_text(
        f"""package {APP_ID}

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "budget_performance/identity",
        ).setMethodCallHandler {{ call, result ->
            if (call.method == "packageName") {{
                result.success(applicationContext.packageName)
            }} else {{
                result.notImplemented()
            }}
        }}
    }}
}}
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
