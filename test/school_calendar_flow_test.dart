import 'package:compass_flutter/src/live_calendar_service.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_calendar_card.dart';
import 'package:compass_flutter/src/school_calendar_data.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/app_session.dart';
import 'fixtures/calendar_fixtures.dart';

void main() {
  testWidgets(
    'calendar, collapsed requirements and Guide catalog survive restart with school isolation',
    (tester) async {
      final original = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final store = SharedPreferencesAsync();
      await seedSession(store, demoSchools.last, selected: false);
      await seedSession(store, demoSchools.first);
      final now = DateTime.now();
      for (final school in demoSchools) {
        await store.setString(
          schoolCalendarKey(school.id),
          ImportedSchoolCalendar.parse(
            calendarFixture(
              allDayEventFixture(
                '${school.id} calendar event',
                date: dayStamp(now),
                end: dayStamp(DateTime(now.year, now.month, now.day + 1)),
              ),
            ),
          ).toStorage(),
        );
      }
      await store.setInt(
        'compass.preview.alderline.req.completed.hs-english',
        2,
      );
      await boot(tester);
      await destination(tester, 'Courses');
      expect(find.text('Academics'), findsNothing);
      expect(find.text('alderline calendar event'), findsOneWidget);
      expect(find.text('English'), findsNothing);
      await tapVisible(tester, find.text('Graduation Requirements'));
      expect(find.text('English'), findsOneWidget);
      expect(find.text('2 years of 4 years'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Previous month'));
      await tapVisible(tester, find.text('Today'));
      expect(
        await store.getInt(
          'compass.preview.alderline.req.completed.hs-english',
        ),
        2,
      );
      await destination(tester, 'Guide');
      await tapVisible(tester, find.text('Course catalog'));
      await tester.enterText(find.byType(TextField), 'Biology');
      await tester.pump();
      expect(find.widgetWithText(Card, 'Biology'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Geometry'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await switchSchool(tester, 'Cedarbrook');
      await destination(tester, 'Courses');
      expect(find.text('cedarbrook calendar event'), findsOneWidget);
      expect(find.text('alderline calendar event'), findsNothing);
      await boot(tester);
      await destination(tester, 'Courses');
      expect(find.text('cedarbrook calendar event'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('invalid and cancelled imports preserve the previous calendar', (
    tester,
  ) async {
    var payload = '<html>Log in</html>';
    var writes = 0;
    final calendar = ImportedSchoolCalendar.parse(
      calendarFixture(allDayEventFixture('Keep my events')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SchoolCalendarCard(
              schoolId: 'alderline',
              calendar: calendar,
              today: DateTime(2026, 11, 8),
              readIcs: () async => payload.isEmpty ? null : payload,
              onSaveCalendar: (_) async {
                writes++;
              },
            ),
          ),
        ),
      ),
    );
    Future<void> import() async {
      await tapVisible(tester, find.byTooltip('Calendar options'));
      await tapVisible(tester, find.text('Import calendar'));
    }

    await import();
    expect(find.text('Choose an iCalendar (.ics) file.'), findsOneWidget);
    expect(writes, 0);
    expect(find.text('Keep my events'), findsOneWidget);
    payload = '';
    await import();
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'connected feed refreshes automatically and keeps the last good data on failure',
    (tester) async {
      var fetches = 0, fail = false;
      ImportedSchoolCalendar? current;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: SchoolCalendarCard(
                  schoolId: 'alderline',
                  calendar: current,
                  today: DateTime(2026, 11, 8),
                  fetchCalendar: (url) async {
                    fetches++;
                    if (fail) {
                      throw const CalendarImportException(
                        'Network unavailable. Saved events remain.',
                      );
                    }
                    return ImportedSchoolCalendar.parse(
                      calendarFixture(
                        allDayEventFixture('Feed version $fetches'),
                      ),
                    );
                  },
                  onSaveCalendar: (next) async =>
                      setState(() => current = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('+ Connect'));
      await tester.enterText(
        find.byType(TextField),
        'webcal://demo.myschoolapp.com/calendar.ics',
      );
      await tapVisible(tester, find.text('Connect'));
      expect(
        current!.subscriptionUrl,
        'https://demo.myschoolapp.com/calendar.ics',
      );
      expect(find.text('Feed version 1'), findsOneWidget);
      await tester.pump(const Duration(minutes: 15));
      await tester.pumpAndSettle();
      expect(find.text('Feed version 2'), findsOneWidget);
      fail = true;
      await tapVisible(tester, find.byTooltip('Refresh calendar'));
      expect(
        find.text('Network unavailable. Saved events remain.'),
        findsOneWidget,
      );
      expect(find.text('Feed version 2'), findsOneWidget);
      final stored = ImportedSchoolCalendar.fromStorage(current!.toStorage());
      expect(stored!.subscriptionUrl, current!.subscriptionUrl);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 740),
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      testWidgets(
        'calendar views and import retry ${brightness.name} at ${size.width}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          var fail = true;
          ImportedSchoolCalendar? current;
          await tester.pumpWidget(
            MaterialApp(
              theme: localCompassTheme(brightness),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                    child: SchoolCalendarCard(
                      schoolId: 'alderline',
                      calendar: current,
                      today: DateTime(2026, 11, 8),
                      readIcs: () async => calendarFixture(
                        allDayEventFixture('Imported school event'),
                      ),
                      onSaveCalendar: (next) async {
                        if (fail) throw StateError('Storage unavailable');
                        setState(() => current = next);
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          Future<void> import() async {
            await tapVisible(tester, find.byTooltip('Calendar options'));
            await tapVisible(tester, find.text('Import calendar'));
          }

          await import();
          expect(current, isNull);
          expect(
            find.text('Could not save this calendar. Please try again.'),
            findsOneWidget,
          );
          fail = false;
          await import();
          expect(find.text('Imported school event'), findsOneWidget);
          await tapVisible(tester, find.text('Week'));
          await tapVisible(tester, find.text('Day'));
          await tapVisible(tester, find.text('Month'));
          await tapVisible(tester, find.byTooltip('Calendar options'));
          await tapVisible(tester, find.text('Use sample calendar'));
          expect(current, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('day timeline includes events outside normal school hours', (
    tester,
  ) async {
    final calendar = ImportedSchoolCalendar.parse(
      calendarFixture(
        'BEGIN:VEVENT\nUID:early\nDTSTAMP:20260101T000000Z\nDTSTART:20261108T010000\nDTEND:20261108T020000\nSUMMARY:Early school trip\nEND:VEVENT',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SchoolCalendarCard(
              schoolId: 'alderline',
              calendar: calendar,
              today: DateTime(2026, 11, 8),
              onSaveCalendar: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tapVisible(tester, find.text('Day'));
    expect(find.text('Early school trip'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Early school trip')).dy -
          tester.getTopLeft(find.text('01:00')).dy,
      inInclusiveRange(0, 44),
    );
    expect(tester.takeException(), isNull);
  });
  test('feed normalization refuses non-provider/private hosts', () {
    expect(
      normalizeCalendarUrl('webcal://demo.myschoolapp.com/feed').scheme,
      'https',
    );
    for (final value in [
      'http://demo.myschoolapp.com/feed',
      'https://127.0.0.1/feed',
      'https://demo.myschoolapp.com.attacker.test/feed',
    ]) {
      expect(
        () => normalizeCalendarUrl(value),
        throwsA(isA<CalendarImportException>()),
      );
    }
  });
}
