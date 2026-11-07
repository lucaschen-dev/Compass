# Compass

Compass is a local Flutter school community app. Explore either of two fictional campuses, Alderline and Cedarbrook. Each has announcements, a campus guide, a searchable course catalog with credits and prerequisites, sample conversations, and a student profile.

Use **Find your school** to enter a campus and the arrows in the top bar to switch schools. The appearance menu offers system, light, and dark modes. Your selected school, guide reading progress, and added classmates are saved on the device or in the browser. The app uses sample data and runs locally without accounts or verification codes.

## Set up

Install Flutter, then run this command from the project directory.

```sh
flutter pub get
```

The development baseline is Flutter 3.47.7 and Dart 3.13.5.

## Run in a browser

```sh
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8766
```

Open [Compass at localhost](http://127.0.0.1:8766/). In VS Code, **Compass · Web** launches the same app in Chrome.

## Run on macOS or iOS

With Xcode set up for Flutter development, run the macOS app with:

```sh
flutter run -d macos
```

For iOS, start an iPhone simulator or connect a configured device. Run `flutter devices` to find its ID, then run `flutter run -d DEVICE_ID` with that ID. In VS Code, use **Compass · Mac** or select a device and use **Compass · Select device**.

All launch configurations use `lib/main.dart`.

## Checks

```sh
flutter analyze
flutter test
```

See the [development plan](plan.md) for upcoming iterations.
