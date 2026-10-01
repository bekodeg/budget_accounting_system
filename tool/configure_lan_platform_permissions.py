#!/usr/bin/env python3
from __future__ import annotations

import plistlib
from pathlib import Path

SERVICE_TYPE = "_budgetsync._tcp"
ANDROID_PERMISSIONS = (
    "android.permission.INTERNET",
    "android.permission.CHANGE_WIFI_MULTICAST_STATE",
)


def configure_android() -> None:
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not manifest.exists():
        print(f"skip Android LAN permissions: {manifest} not found")
        return

    text = manifest.read_text(encoding="utf-8")
    missing = [name for name in ANDROID_PERMISSIONS if name not in text]
    if not missing:
        return

    manifest_end = text.find(">")
    if manifest_end < 0 or "<manifest" not in text[: manifest_end + 1]:
        raise RuntimeError("Unable to locate Android manifest root element.")

    insertion = "".join(
        f'\n    <uses-permission android:name="{name}" />' for name in missing
    )
    text = text[: manifest_end + 1] + insertion + text[manifest_end + 1 :]
    manifest.write_text(text, encoding="utf-8")


def configure_ios() -> None:
    info_plist = Path("ios/Runner/Info.plist")
    if not info_plist.exists():
        print(f"skip iOS LAN permissions: {info_plist} not found")
        return

    with info_plist.open("rb") as handle:
        data = plistlib.load(handle)

    data.setdefault(
        "NSLocalNetworkUsageDescription",
        "Required to discover and connect to budget participants on the local network.",
    )
    services = list(data.get("NSBonjourServices", []))
    if SERVICE_TYPE not in services:
        services.append(SERVICE_TYPE)
    data["NSBonjourServices"] = services

    with info_plist.open("wb") as handle:
        plistlib.dump(data, handle, fmt=plistlib.FMT_XML, sort_keys=False)


def main() -> None:
    configure_android()
    configure_ios()


if __name__ == "__main__":
    main()
