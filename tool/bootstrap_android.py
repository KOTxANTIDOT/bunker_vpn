#!/usr/bin/env python3
"""Generate the Android host project and install BUNKER's native sources."""

from pathlib import Path
import shutil
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
ROOT = REPO_ROOT / "app" / "flutter"
ANDROID_DIR = ROOT / "android"
NATIVE_DIR = REPO_ROOT / "native" / "android"
PACKAGE_PATH = Path("app/src/main/kotlin/com/bunkercat/bunker_vpn")
NATIVE_SOURCES = ("MainActivity.kt", "BunkerVpnService.kt", "LibboxRuntime.kt", "AndroidTunController.kt")


def install_native_sources() -> None:
    target_dir = ANDROID_DIR / PACKAGE_PATH
    target_dir.mkdir(parents=True, exist_ok=True)

    for filename in NATIVE_SOURCES:
        source = NATIVE_DIR / filename
        if not source.is_file():
            raise FileNotFoundError(f"Missing native Android source: {source}")
        shutil.copy2(source, target_dir / filename)


def patch_libbox_dependency() -> None:
    """Add the pinned upstream Android libbox artifact and its JitPack repository."""
    project_gradle_candidates = (
        ANDROID_DIR / "build.gradle.kts",
        ANDROID_DIR / "build.gradle",
    )
    project_gradle = next(
        (path for path in project_gradle_candidates if path.is_file()), None
    )
    if project_gradle is None:
        raise FileNotFoundError("Generated Android project build.gradle(.kts) not found")

    project_content = project_gradle.read_text(encoding="utf-8")
    jitpack = "https://jitpack.io"
    if jitpack not in project_content:
        marker = "allprojects {"
        block_start = project_content.find(marker)
        if block_start < 0:
            raise RuntimeError("Could not locate allprojects block in Android project Gradle file")
        repositories_start = project_content.find("repositories {", block_start)
        if repositories_start < 0:
            raise RuntimeError("Could not locate allprojects repositories in Android project Gradle file")
        insertion_point = repositories_start + len("repositories {")
        if project_gradle.suffix == ".kts":
            repository = '\n        maven { url = uri("https://jitpack.io") }'
        else:
            repository = "\n        maven { url 'https://jitpack.io' }"
        project_content = (
            project_content[:insertion_point]
            + repository
            + project_content[insertion_point:]
        )
        project_gradle.write_text(project_content, encoding="utf-8")

    app_candidates = (
        ANDROID_DIR / "app/build.gradle.kts",
        ANDROID_DIR / "app/build.gradle",
    )
    app_gradle = next((path for path in app_candidates if path.is_file()), None)
    if app_gradle is None:
        raise FileNotFoundError("Generated Android app build.gradle(.kts) not found")

    app_content = app_gradle.read_text(encoding="utf-8")
    dependency = "com.github.singbox-android:libbox:1.14.3"
    if dependency not in app_content:
        if app_gradle.suffix == ".kts":
            declaration = f'\n    implementation("{dependency}")'
        else:
            declaration = f"\n    implementation '{dependency}'"
        if "dependencies {" in app_content:
            app_content = app_content.replace(
                "dependencies {", "dependencies {" + declaration, 1
            )
        else:
            app_content = app_content.rstrip() + (
                "\n\ndependencies {" + declaration + "\n}\n"
            )
        app_gradle.write_text(app_content, encoding="utf-8")

def patch_manifest() -> None:
    manifest = ANDROID_DIR / "app/src/main/AndroidManifest.xml"
    if not manifest.is_file():
        raise FileNotFoundError(f"Generated Android manifest not found: {manifest}")

    content = manifest.read_text(encoding="utf-8")
    content = content.replace(
        'android:label="bunker_vpn"',
        'android:label="BUNKER VPN"',
    )

    permissions = (
        '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
        '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />',
        '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
    )
    for permission in permissions:
        permission_name = permission.split('"')[1]
        if permission_name not in content:
            content = content.replace(
                "<application",
                permission + "\n    <application",
                1,
            )

    service_declaration = """        <service
            android:name="com.bunkercat.bunker_vpn.BunkerVpnService"
            android:permission="android.permission.BIND_VPN_SERVICE"
            android:exported="true"
            android:foregroundServiceType="systemExempted">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
        </service>
"""
    if "com.bunkercat.bunker_vpn.BunkerVpnService" not in content:
        content = content.replace("</application>", service_declaration + "    </application>")

    manifest.write_text(content, encoding="utf-8")


def main() -> None:
    if not (ROOT / "pubspec.yaml").is_file():
        raise FileNotFoundError(
            f"Flutter project manifest not found: {ROOT / 'pubspec.yaml'}"
        )

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

    install_native_sources()
    patch_libbox_dependency()
    patch_manifest()
    print("Android host is ready. BUNKER native VPN service installed.")


if __name__ == "__main__":
    main()
