#!/usr/bin/env python3
"""Generate the Android host project and install BUNKER's Kotlin bridge."""

from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ANDROID_DIR = ROOT / "android"
NATIVE_DIR = ROOT.parent.parent / "native" / "android"
PACKAGE_PATH = Path("app/src/main/kotlin/com/bunkercat/bunker_vpn")
ACTIVITY_SOURCE = NATIVE_DIR / "MainActivity.kt"


def main() -> None:
    if not ANDROID_DIR.exists():
        subprocess.run(
            [
                "flutter",
                "create",
                "--platforms=android",
                "--org",
                "com.bunkercat",
                "--project-name",
                "bunker_vpn",
                ".",
            ],
            cwd=ROOT,
            check=True,
        )

    if not ACTIVITY_SOURCE.is_file():
        raise FileNotFoundError(f"Missing Kotlin bridge source: {ACTIVITY_SOURCE}")

    target_dir = ANDROID_DIR / PACKAGE_PATH
    target_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ACTIVITY_SOURCE, target_dir / "MainActivity.kt")

    manifest = ANDROID_DIR / "app/src/main/AndroidManifest.xml"
    if manifest.is_file():
        content = manifest.read_text(encoding="utf-8")
        content = content.replace(
            'android:label="bunker_vpn"',
            'android:label="BUNKER VPN"',
        )
        manifest.write_text(content, encoding="utf-8")

    print("Android host is ready. Kotlin bridge installed.")


if __name__ == "__main__":
    main()
