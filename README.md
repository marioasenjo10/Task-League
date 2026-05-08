# Task League ⚔️

A gamified task manager with fighting leagues. Complete tasks, earn coins, attack opponents and climb the rankings — available on Android, iOS and Web.

Built with **Flutter + Firebase**.

## Features

- 🏆 Weekly & monthly competitive leagues
- ⚔️ Attack opponents by completing tasks
- 🛡️ Shield mechanics to protect your HP
- 🎭 Unlockable fighter skins
- 📅 Calendar and recurring tasks
- 📊 Stats, history and rankings
- 🔔 Push notifications for attacks received

## Stack

| Layer | Tech |
|---|---|
| Framework | Flutter 3.x |
| State | Riverpod + riverpod_generator |
| Backend | Firebase (Auth, Firestore, FCM) |
| Navigation | go_router |
| Charts | fl_chart |

## Setup

1. Clone the repo
2. Add your Firebase config files (not committed — see below)
3. Run `flutter pub get`
4. Run `flutter run`

### Firebase files needed (not in repo)

These must be obtained from Firebase Console and placed manually:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

### Generate icons & splash

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Android release build

```bash
# Requires android/key.properties with keystore credentials (not in repo)
flutter build appbundle --release
```

## Package

- **Android**: `com.masen.taskfight`
- **iOS**: `com.masen.taskfight`
