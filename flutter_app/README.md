# 字根工坊 Android app

Flutter app for Android that reads the same data as the web version
(`assets/wordblocks.json`, generated from `../data/*.txt` by `node ../tools/build-data.mjs`).

Screens: 字根地圖 (browse roots, prefixes and suffixes by category; root and word pages with
block splits and etymology stories), 拆解 (split any word), 複習 (spaced repetition, progress saved
on the device), 積木 (build words from blocks).

```bash
flutter pub get
flutter test
flutter run            # with an Android device or emulator connected
flutter build apk      # output: build/app/outputs/flutter-apk/app-release.apk
```

The release build is signed with the debug key so it installs directly for testing.
Set up a real signing key in `android/app/build.gradle.kts` before publishing to Google Play.
