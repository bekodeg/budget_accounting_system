from pathlib import Path

BUILD_FILE = Path("android/app/build.gradle.kts")
MARKER = "// budget-accounting: mlkit text-recognition modules"

DEPENDENCIES = """
dependencies {
    // budget-accounting: mlkit text-recognition modules
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}
""".strip()


def main() -> None:
    if not BUILD_FILE.exists():
        raise SystemExit(f"Android build file not found: {BUILD_FILE}")

    content = BUILD_FILE.read_text(encoding="utf-8")
    if MARKER in content:
        return

    BUILD_FILE.write_text(
        content.rstrip() + "\n\n" + DEPENDENCIES + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
