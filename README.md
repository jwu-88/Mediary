# Mediary

## Overview

Mediary is a Flutter medication companion for organizing daily medications,
reviewing schedules, and exploring common medication information on iOS and web.

Mediary is open-source software licensed under the MIT License. See
[LICENSE](LICENSE) for the full license text.

## Description

The app includes Firebase email/password and Google sign-in, a dose dashboard,
calendar, medication library, scanner prototype, weekly reports, and appearance
and account settings. Scanning, schedules, reports, profile details, and most
preferences currently use sample or local state. Mediary is a development
prototype, not a medical device or a substitute for professional medical advice.

## How to Run

Install Flutter with Dart 3.13 or newer, plus the platform tooling for your
target (Xcode and CocoaPods for iOS, or Chrome for web). Then run:

```sh
flutter pub get
flutter run
```

Use `flutter run -d chrome` for web. Firebase client configuration is included;
enable Email/Password and Google providers in the configured Firebase project
for authentication. To use another Firebase project, install the FlutterFire
CLI and run `flutterfire configure --platforms=ios,web` before launching the app.

## Verification

```sh
flutter analyze
flutter test
node --test test/web_ocr_bridge_test.mjs
flutter build web --release
flutter build ios --simulator --debug --no-codesign
```

iOS initializes Firebase with the client options in `lib/firebase_options.dart`;
the build does not require an ignored local `GoogleService-Info.plist`. Camera
permission support is enabled in the iOS Podfile. Medication reminders use iOS
local notifications, including time-sensitive delivery when allowed by the
user's notification settings.

Scanning uses Apple Vision on iOS and a reusable browser OCR worker on web.
The browser downloads its OCR engine only when scanning is first used, so it
does not block app startup. Large scan images are limited to 2400 pixels on
their longest side before recognition to keep memory use bounded.
