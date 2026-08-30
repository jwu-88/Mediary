# Mediary

## Overview

Mediary is a Flutter medication companion for organizing daily medications,
reviewing schedules, and exploring common medication information across mobile
and web.

## Description

The app includes Firebase email/password and Google sign-in, a dose dashboard,
calendar, medication library, scanner prototype, weekly reports, and appearance
and account settings. Scanning, schedules, reports, profile details, and most
preferences currently use sample or local state. Mediary is a development
prototype, not a medical device or a substitute for professional medical advice.

## How to Run

Install Flutter with Dart 3.13 or newer, plus the platform tooling for your
target (Android SDK for Android; Xcode and CocoaPods for iOS). Then run:

```sh
flutter pub get
flutter run
```

Use `flutter run -d chrome` for web. Firebase client configuration is included;
enable Email/Password and Google providers in the configured Firebase project
for authentication. To use another Firebase project, install the FlutterFire
CLI and run `flutterfire configure` before launching the app.
