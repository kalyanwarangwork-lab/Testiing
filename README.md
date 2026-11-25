# Flashlight (Flutter, Android)

A simple flashlight app built entirely in the cloud with GitHub Actions — no Android Studio needed.

## Features
- Big on/off power button (uses the phone's camera flash)
- **Strobe** mode with adjustable speed (1–15 Hz)
- **SOS** mode (Morse code ··· — — — ···)
- **Screen light** (phone icon, top right) for phones without a flash, with a warmth slider
- Turns the flash off automatically when the app is closed
- Needs no permissions

## How the build works
`.github/workflows/build.yml` runs on every push and on demand (Actions tab → *Build Android APK* → *Run workflow*). It:
1. Installs Java 17 and Flutter (stable)
2. Generates the standard Android project files with `flutter create`
3. Runs the tests and builds a release APK
4. Uploads the APK as a workflow artifact **and** publishes it in a GitHub Release (`build-N`)

## Get the APK
- **Releases** (easiest): repo home page → *Releases* (right sidebar) → latest `Flashlight build N` → download the `.apk`.
- **Actions artifact**: *Actions* tab → latest green run → *Artifacts* → `Flashlight-APK` (a zip containing the APK; needs a GitHub login).

## Project layout
```
lib/main.dart                       # the whole Flutter UI
android/app/src/main/kotlin/...     # MainActivity: native torch control
test/widget_test.dart               # smoke test
.github/workflows/build.yml         # CI build
```

> Note: the APK is signed with a debug key generated during each build. If Android refuses to install a newer build over an older one ("App not installed"), uninstall the old version first.
