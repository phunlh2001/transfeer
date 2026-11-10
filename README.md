# transfeer

One of my pet project to tracking ETF FUESSV30 Fund

Flutter app (Android + Web), version **2.0.0**.

## Features
- **Live tracker**: polls `https://transfeer-be.onrender.com/api/etf` every 5 seconds.
  It polls **only during HOSE trading hours**: 09:00–11:30 and 13:00–15:00, Vietnam time (UTC+7), Monday–Friday.
  Outside those hours a "market closed" screen with a countdown is shown and **no API calls** are made.
  The app switches automatically at each session boundary. Public holidays are not detected.
- **Calculator**: converts a VND amount into whole fund units, average cost per unit, total cost and leftover money. No fee is included.
- **Splash screen** (~1s) with a Lottie animation, and a modern theme with Lottie illustrations (`assets/lottie/*.json`). Replace any of these files to change an animation.
- **In-app update (Android)**: on launch, the app checks the latest GitHub Release. If it is newer, a sheet offers **Update now**, which downloads the APK in-app and opens the Android installer.

## Development
```bash
flutter pub get
flutter test
flutter run -d chrome
flutter run                     # Android device or emulator

# Debug only: force a state to test both screens at any time of day
flutter run --dart-define=FORCE_MARKET=open
flutter run --dart-define=FORCE_MARKET=closed
```

## Publishing a new version (in-app update)
The release convention is: **tag = version** (e.g. `v2.0.1`), and the **attachment is a `.zip` with the `.apk` inside**.
The app downloads the zip, extracts the APK and opens the Android installer.

1. Bump `version:` in `pubspec.yaml`, e.g. `2.0.1+3`. **Always increase the `+build` number** as well; Android refuses to install a lower versionCode.
2. Commit and push to `main`. GitHub Actions ([release.yml](.github/workflows/release.yml)) sees a version with no release yet, so it:
   1. runs analyze and tests,
   2. builds the APK (no signing secrets needed),
   3. zips it as `transfeer-v2.0.1.zip`,
   4. publishes release **`v2.0.1`** with the zip attached.

   To write release notes, push an annotated tag instead (or as well); its message becomes the notes:
   ```bash
   git tag -a v2.0.1 -m "Sửa lỗi hiển thị giá"
   git push origin main v2.0.1
   ```
   A tag that doesn't match the pubspec version fails the run. An existing release is never published twice.
3. Installed apps (v2.0.0+) show the update sheet on their next launch. The release notes are shown to users, so write them in Vietnamese.

[ci.yml](.github/workflows/ci.yml) runs analyze and tests on every push and pull request.

#### Releasing locally (alternative)
`.\scripts\release.ps1` builds the same zip into `dist\`. Add `-Publish -Notes "…"` with `$env:GITHUB_TOKEN` set to create the release from your machine.

The first time, Android asks the user to allow "Cài ứng dụng không rõ nguồn gốc" for Transfeer. The app opens that setting, and the user then taps **Cài đặt** again.

### Signing (important)
Release APKs are signed with `android/upload-keystore.jks`, configured through `android/key.properties`. Both files are gitignored.
**Back them up somewhere safe.** If the key is lost, installed apps can no longer update in-app; users would have to uninstall and reinstall.
Without `key.properties` the build falls back to debug signing.

v1.0.0 has no updater and was signed with a different key, so v1 users must uninstall it and install v2.0.0 manually **once**.

### Web
The web build always serves the latest deployed version, so no updater is needed.
The backend must send CORS headers (`Access-Control-Allow-Origin`) or browsers will block the API.
