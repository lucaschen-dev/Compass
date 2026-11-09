# Compass

Compass is a local Flutter school community app. Explore either of two fictional campuses, Alderline and Cedarbrook. Each has announcements, a campus guide, a searchable course catalog with credits and prerequisites, sample conversations, and a student profile.

Use **Find your school** to enter a campus and the arrows in the top bar to switch schools. The appearance menu offers system, light, and dark modes. Your selected school, guide reading progress, and added classmates are saved on the device or in the browser. The app uses sample data and runs locally without accounts or verification codes.

Open **For you** to choose interests and a preferred meetup time. Compass recommends up to three sample peers, clubs, and events per category, showing the interests behind each match. More shared interests rank first; equal matches are ordered alphabetically. Meetup time filters clubs and events. Each school's preferences are saved separately, and **Reset** followed by **Save preferences** clears only that school's choices. All matching runs locally using fictional school data.

## School calendar and courses

**Courses** shows a month calendar above **Graduation Requirements**. Select a day to see its events, use the arrows to change months, or choose **Today**. Each demo school has separate sample events.

Use the calendar's **Import calendar** button to open an `.ics` file. Imports are saved locally under `compass.preview.<school-id>.calendar`; switching schools never shares an import. **Use sample calendar** removes only the current school's import. The searchable **Course catalog** is at the bottom of **Guide**, with credits and prerequisites preserved.

Calendar integration uses `enough_icalendar` to parse iCalendar, bundled `timezone` data for timed events, and Flutter's `file_selector` for local imports. A `webcal://` subscription can supply its ICS document over HTTPS; this app imports that document instead of embedding a private feed URL, using a Google Calendar API, or relying on a third-party proxy. Personal feed URLs and events are not included in source or app assets. Refresh a snapshot by importing a newer export; this is not a live subscription.

The importer supports expanded all-day and timed events, including exclusive end dates and cancelled/revised entries. It rejects event recurrence rules and overrides rather than displaying incomplete results; export those as individual occurrences. Timezone transition rules are handled separately and are not treated as events. Imports are limited to 512 KB and 2,000 events.

Calendar browsing and imports do not change graduation progress. Automatic event-to-course matching for `requirementsChecklist` is future work.

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
