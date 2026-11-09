import 'package:compass_flutter/main.dart' as app;
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_calendar_card.dart';
import 'package:compass_flutter/src/school_calendar_data.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/calendar_fixtures.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'calendar ordering, Guide catalog search and school isolation survive restart',
    (tester) async {
      final original = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = original;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final today = DateTime.now();
      final date = dayStamp(today);
      final end = dayStamp(DateTime(today.year, today.month, today.day + 1));
      final store = SharedPreferencesAsync();
      await store.setString('compass.preview.selectedSchool', 'alderline');
      for (final school in demoSchools) {
        await store.setString(
          schoolCalendarKey(school.id),
          ImportedSchoolCalendar.parse(
            calendarFixture(
              allDayEventFixture(
                '${school.id} calendar event',
                date: date,
                end: end,
              ),
            ),
          ).toStorage(),
        );
      }
      const progressKey = 'compass.preview.alderline.req.completed.hs-english';
      await store.setInt(progressKey, 2);
      await app.main();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Courses').last);
      expect(find.text('alderline calendar event'), findsOneWidget);
      expect(find.text('cedarbrook calendar event'), findsNothing);
      expect(find.text('Course catalog'), findsNothing);
      expect(
        tester.getTopLeft(find.text('School calendar')).dy,
        lessThan(tester.getTopLeft(find.text('Graduation Requirements')).dy),
      );
      await tapVisible(tester, find.byTooltip('Next month'));
      await tapVisible(tester, find.byTooltip('Previous month'));
      await tapVisible(tester, find.text('Today'));
      expect(find.text('alderline calendar event'), findsOneWidget);
      expect(
        await store.getInt(progressKey),
        2,
        reason: 'Calendar browsing must not change requirement progress',
      );

      await tapVisible(tester, find.text('Guide').last);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('guide-course-catalog')))
            .dy,
        greaterThan(
          tester.getTopLeft(find.text(demoSchools.first.guide.last.title)).dy,
        ),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Biology');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Card, 'Biology'), findsOneWidget);
      expect(find.text('English 9'), findsNothing);
      await tester.enterText(find.byType(TextField), 'no such class');
      await tester.pumpAndSettle();
      expect(find.text('No courses match your search.'), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Switch school'));
      await tapVisible(tester, find.text('Cedarbrook High School'));
      await tapVisible(tester, find.text('Courses').last);
      expect(find.text('cedarbrook calendar event'), findsOneWidget);
      expect(find.text('alderline calendar event'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await app.main();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Courses').last);
      expect(find.text('cedarbrook calendar event'), findsOneWidget);
      await tapVisible(tester, find.text('Guide').last);
      expect(find.text('No courses match your search.'), findsNothing);
      expect(find.text('Stagecraft'), findsOneWidget);
      expect(find.text('Biology'), findsNothing);
      expect(await store.getInt(progressKey), 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid and cancelled imports keep the existing calendar', (
    tester,
  ) async {
    final old = ImportedSchoolCalendar.parse(
      calendarFixture(allDayEventFixture('Keep this event')),
    );
    String? input = '<html>Login</html>';
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCalendarCard(
            schoolId: 'alderline',
            calendar: old,
            today: DateTime(2026, 11, 8),
            readIcs: () async => input,
            onSaveCalendar: (_) async {
              saves++;
            },
          ),
        ),
      ),
    );
    await tapVisible(tester, find.byTooltip('Import calendar'));
    expect(find.text('Choose an iCalendar (.ics) file.'), findsOneWidget);
    expect(find.text('Keep this event'), findsOneWidget);
    expect(saves, 0);
    input = null;
    await tapVisible(tester, find.byTooltip('Import calendar'));
    expect(saves, 0);
    expect(find.text('Keep this event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 740),
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      testWidgets(
        'calendar import and layout ${brightness.name} at ${size.width}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          ImportedSchoolCalendar? calendar;
          var failSave = true;
          await tester.pumpWidget(
            MaterialApp(
              theme: localCompassTheme(brightness),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, update) => SchoolCalendarCard(
                      schoolId: 'alderline',
                      calendar: calendar,
                      today: DateTime(2026, 11, 8),
                      readIcs: () async => calendarFixture(
                        allDayEventFixture('Imported study day'),
                      ),
                      onSaveCalendar: (next) async {
                        if (failSave) throw StateError('Storage full');
                        update(() => calendar = next);
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tapVisible(tester, find.byTooltip('Import calendar'));
          expect(
            find.text('Could not save this calendar. Please try again.'),
            findsOneWidget,
          );
          expect(calendar, isNull);
          failSave = false;
          await tapVisible(tester, find.byTooltip('Import calendar'));
          expect(find.text('Imported calendar · 1 event'), findsOneWidget);
          expect(find.text('Imported study day'), findsOneWidget);
          expect(calendar!.events, hasLength(1));
          await tapVisible(tester, find.byTooltip('Use sample calendar'));
          expect(calendar, isNull);
          expect(find.text('Sample events'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
