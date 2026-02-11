# 🐉 Dragon Chat Mobile

Flutter app for iOS and Android with Matrix chat and LiveKit voice/video.

## Features

- ✅ Matrix chat (E2EE)
- ✅ Voice calls (LiveKit)
- ✅ Video calls (LiveKit)
- ✅ Screen sharing
- ✅ Push notifications
- ✅ Dark theme
- ✅ iOS & Android

## Quick Start

### Prerequisites

- Flutter SDK 3.16+
- Xcode (for iOS)
- Android Studio (for Android)

### Development

```bash
# Get dependencies
flutter pub get

# Run on device/emulator
flutter run

# Run on specific device
flutter run -d ios
flutter run -d android
```

### Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (needs Xcode)
flutter build ios --release

# Open in Xcode for signing
open ios/Runner.xcworkspace
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── app_theme.dart        # Colors, themes
├── services/
│   ├── matrix_service.dart   # Matrix SDK wrapper
│   ├── livekit_service.dart  # LiveKit wrapper
│   └── notification_service.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── chat_screen.dart
│   └── call_screen.dart
├── widgets/                  # Reusable widgets
└── models/                   # Data models
```

## Configuration

### Change Default Servers

Edit `lib/services/matrix_service.dart`:
```dart
static const String defaultHomeserver = 'https://matrix.y7xyz.com';
```

Edit `lib/services/livekit_service.dart`:
```dart
static const String defaultLiveKitUrl = 'wss://livekit.y7xyz.com';
```

### iOS Setup

1. Open `ios/Runner.xcworkspace` in Xcode
2. Set your Team/Bundle ID
3. Add capabilities:
   - Push Notifications
   - Background Modes (Voice over IP, Audio)
   - Camera
   - Microphone

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Dragon Chat needs camera for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Dragon Chat needs microphone for calls</string>
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>audio</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### Android Setup

Edit `android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 24
        targetSdkVersion 34
    }
}
```

Add permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

## Push Notifications

1. Create Firebase project
2. Add `google-services.json` to `android/app/`
3. Add `GoogleService-Info.plist` to `ios/Runner/`
4. Configure Firebase Cloud Messaging

## App Icons

Replace icons in:
- `android/app/src/main/res/mipmap-*/`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Use flutter_launcher_icons package:
```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
```

Then run:
```bash
flutter pub run flutter_launcher_icons
```

## Splash Screen

Use flutter_native_splash:
```yaml
flutter_native_splash:
  color: "#1a1a2e"
  image: assets/splash.png
```

## Release Checklist

### Android
1. Update `versionCode` and `versionName` in `build.gradle`
2. Create signing key: `keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key`
3. Configure signing in `build.gradle`
4. Build: `flutter build appbundle`
5. Upload to Play Store

### iOS
1. Update version in Xcode
2. Configure signing
3. Archive: Product → Archive
4. Upload to App Store Connect

## Dependencies

| Package | Purpose |
|---------|---------|
| matrix | Matrix protocol |
| livekit_client | Voice/video calls |
| provider | State management |
| hive | Local database |
| flutter_secure_storage | Secure credentials |
| flutter_local_notifications | Local notifications |
| firebase_messaging | Push notifications |

## Troubleshooting

### iOS build fails
```bash
cd ios && pod install && cd ..
flutter clean && flutter pub get
```

### Android build fails
```bash
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get
```

### LiveKit connection issues
- Check server URL (wss://)
- Verify token is valid
- Check firewall allows WebRTC ports

---

Created by Dragon 🐉 for Yahya
