# Compass

Compass is a school community app. The current Flutter preview lets students explore two fictional schools locally. Its homepage uses the original iPhone layout with a neutral light and dark palette.

The repository also includes the legacy Buckley community client. Its iPhone and Mac interfaces use SwiftUI, with Flutter managing app state and API requests through a `MethodChannel`.

The development baseline is Flutter 3.47.7 and Dart 3.13.5. See the [development plan](plan.md) for upcoming iterations.

## Preview local schools

In VS Code, select **Compass · School preview** from **Run and Debug**. You can also start the preview from the project folder.

```sh
flutter pub get
flutter run -d web-server --target lib/preview.dart --web-hostname=127.0.0.1 --web-port=8766
```

Open [the local preview](http://127.0.0.1:8766/) and choose **Find your school**. Alderline and Cedarbrook are fictional schools with their own announcements, course catalogs, graduation requirements, guides, and sample conversations. Use the arrows at the top right to switch campuses, and the nearby appearance menu to choose light or dark mode. The selected school, guide reading progress, and added classmates are saved in your browser. This preview runs without a backend, a school account, or verification codes.

## Run the legacy Buckley web demo

Run these commands from the project folder.

```sh
flutter pub get
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8080
```

Open [http://127.0.0.1:8080](http://127.0.0.1:8080) and select **Explore the demo**. The demo uses fictional profiles and keeps changes in your browser. In VS Code, **Compass · Web demo** launches the same Flutter interface in Chrome.

The production API and private school calendar feeds have browser cross-origin restrictions. Use a native client for those features and keep private subscription URLs confidential.

## Run the legacy Buckley app on macOS

1. Install Flutter, Xcode, CocoaPods, and the Dart and Flutter extensions for VS Code.
2. Open the folder that contains `pubspec.yaml`.
3. In **Run and Debug**, select **Compass · Mac** and press **F5**.
4. Choose **Explore the demo** for the local Buckley sample community. **Join your school** requires a running Buckley-compatible service.

You can also launch the app from a terminal.

```sh
flutter pub get
flutter run -d macos
```

Flutter hot reload applies to the Dart interface. Stop and relaunch the app after changing SwiftUI code in `apple/`.

The legacy client defaults to `https://api.buckley.community`. Developers can change it on the sign-in screen. HTTP is supported for local development at `localhost` and `127.0.0.1`. Existing accounts, posts, and chats are stored on the server. Sign in again and reconnect the assignment feed after migrating from the original app. Open the original app to access its local drafts and to-dos.

## Legacy Buckley features

- School email verification, password sign-in and reset, first-time profile setup, and secure session storage.
- A community feed with important posts, search, categories, bookmarks, anonymous posting, priority requests, and requests for specific members to respond. Students can reply, report posts, block users, and manage their own posts.
- Up to 20 photos per post. Images are converted to JPEG to meet the backend limits of 1,600 pixels on the longest edge and 512 KiB per image.
- Direct messages and group chats with member selection, group details, the option to leave a group, quoted replies, message retraction, and photo and short video attachments.
- Student profiles, Instagram links, and local to-do lists separated by account.
- Private My Buckley iCalendar imports with course grouping, quiz filters, search, caching, and the option to add assignments to to-dos. The app keeps subscription credentials in secure storage, fetches the feed directly, and rejects redirects. Recurring events display a note and link back to the school platform.
- Administrator tools for paginated post search, author lookup, approval, rejection, deletion, comment removal, and report handling. The backend enforces administrator permissions.
- Local demo data, drafts, and bookmarks. Demo profiles and conversations are fictional.

## Platform support

| Platform | Interface and setup |
| --- | --- |
| macOS 14+ | SwiftUI sidebar, toolbars, forms, system menus, and split-view chat. Network and file picker entitlements are configured. Session storage uses the system Keychain with the data protection Keychain disabled, so it works without a Keychain Sharing provisioning profile. |
| iOS 17+ | SwiftUI tabs for Home, To Do, Chat, and Assignments, with post creation in the toolbar. iOS 26 and later use Liquid Glass controls. Earlier releases use the system styles available on those versions. Physical device installs and releases require Xcode signing. |
| Android | Flutter Material interface with network permissions configured. Build and device validation are pending. |
| Windows and Linux | Flutter Material interface. Build and device validation are pending. On Linux, follow the secure storage and video plugin documentation for system dependencies. |
| Web | Flutter local school preview and legacy Buckley demo. |

The Apple interfaces follow the system light or dark appearance. The app refreshes every eight seconds while in the foreground. Push notifications and APNs registration are pending for this client. The original backend includes APNs support. Video playback uses `media_kit`, and the backend enforces file size, duration, and moderation limits.

## Project layout

| Path | Purpose |
| --- | --- |
| `lib/preview.dart` | Local school preview, school selection, and browser storage. |
| `lib/main.dart` | Legacy client startup, dependency initialization, and interface selection. |
| `lib/src/native_bridge.dart` | Connects the SwiftUI interfaces to Dart state and actions. |
| `apple/` | Shared SwiftUI screens, native media previews, and UI tests. |
| `macos/Runner/MainFlutterWindow.swift` and `ios/Runner/AppDelegate.swift` | Host the Flutter engine and native Apple interfaces. |
| `lib/src/api.dart` and `lib/src/store.dart` | API requests, sessions, community features, demo state, and administrator actions. |
| `lib/src/planner.dart` | Feed URL validation, iCalendar parsing, caching, and to-dos. |
| `lib/src/photos.dart` | Photo compression. |
| `lib/src/ui.dart` and `lib/src/*_ui.dart` | Flutter screens, navigation, and interactions. |
| `backend/` | Python server and backend tests. |
| [`docs/VERIFICATION.md`](docs/VERIFICATION.md) | Migration verification record. |
| [`docs/original-swiftui/`](docs/original-swiftui/) | Archived documentation for the original SwiftUI project. Its Xcode project name and update scripts apply to that project. |

## Testing

```sh
flutter analyze
flutter test
flutter test integration_test/smoke_test.dart -d macos
```

The macOS smoke test exercises the Flutter interface. For native UI tests, open `ios/Runner.xcworkspace` or `macos/Runner.xcworkspace` in Xcode and select the **CompassNativeUI** scheme. Those tests use the local demo.

Use the following commands to test the SwiftUI-to-Dart bridge and to run the Flutter interface on macOS.

```sh
flutter test test/native_bridge_test.dart
flutter run -d macos --dart-define=FLUTTER_UI=true
```

### Local backend tests

The HTTP contract test runs when `COMPASS_TEST_API` is set. Use a Python installation that supports `hashlib.scrypt` through OpenSSL. The test server binds to localhost and uses in-memory data and test doubles for email and moderation.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r backend/requirements.txt
.venv/bin/python test/support/contract_server.py
```

Run the contract test in a second terminal.

```sh
COMPASS_TEST_API=http://127.0.0.1:18764 flutter test test/contract_test.dart
```

Run the backend unit tests from the `backend` directory.

```sh
cd backend
../.venv/bin/python -m unittest discover -q
```

Keep deployment credentials in the server configuration.

## References

- [Flutter in VS Code](https://docs.flutter.dev/tools/editors) and [Flutter networking](https://docs.flutter.dev/cookbook/networking/fetch-data)
- [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels) and [ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
- [Secure storage and macOS Keychain setup](https://pub.dev/packages/flutter_secure_storage) and [local preferences](https://pub.dev/packages/shared_preferences)
- [File picker](https://pub.dev/packages/file_picker), [time zone data](https://pub.dev/packages/timezone), [image processing](https://pub.dev/packages/image), and [video playback](https://pub.dev/packages/media_kit)
- [SwiftUI NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview), [TabView](https://developer.apple.com/documentation/swiftui/tabview), and [Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
