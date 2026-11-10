import 'package:compass_flutter/src/for_you_page.dart';

import 'fixtures/app_session.dart';

import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/recommendations.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Home For you preferences survive refresh and remain school-scoped',
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
      await boot(tester);
      await _tap(tester, find.text('For you'));
      await _tap(tester, find.text('Interests'));
      await _tap(tester, find.byKey(const ValueKey('interest-Robotics')));
      await _tap(tester, find.byKey(const ValueKey('interest-Drawing')));
      await _tap(tester, find.byKey(const ValueKey('save-preferences')));
      expect(
        StudentPreferences.fromStorage(
          await store.getString(studentPreferencesKey(demoSchools.first)),
          demoSchools.first,
        ).interests,
        {'Drawing', 'Robotics'},
      );
      await boot(tester);
      await _tap(tester, find.text('For you'));
      expect(find.text('Try the robotics open lab'), findsOneWidget);
      await switchSchool(tester, 'Cedarbrook');
      await _tap(tester, find.text('For you'));
      expect(find.text('Make this feed yours'), findsOneWidget);
      expect(
        await store.getString(studentPreferencesKey(demoSchools.last)),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving failure keeps the draft open and permits retry', (
    tester,
  ) async {
    var shouldFail = true;
    StudentPreferences? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForYouPage(
            school: demoSchools.first,
            preferences: StudentPreferences(),
            onSavePreferences: (next) async {
              if (shouldFail) throw StateError('Storage unavailable');
              saved = next;
            },
          ),
        ),
      ),
    );
    await _tap(tester, find.byKey(const ValueKey('choose-preferences')));
    await _tap(tester, find.byKey(const ValueKey('interest-Robotics')));
    await _tap(tester, find.byKey(const ValueKey('save-preferences')));
    expect(
      find.text('Could not save preferences. Please try again.'),
      findsOneWidget,
    );
    expect(saved, isNull);
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('interest-Robotics')))
          .selected,
      isTrue,
    );
    shouldFail = false;
    await _tap(tester, find.byKey(const ValueKey('save-preferences')));
    expect(saved!.interests, {'Robotics'});
    expect(find.text('Your preferences'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 740),
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      testWidgets('preferences layout ${brightness.name} at ${size.width}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: localCompassTheme(brightness),
            home: Scaffold(
              body: ForYouPage(
                school: demoSchools.first,
                preferences: StudentPreferences(
                  interests: availableInterests(demoSchools.first),
                ),
                onSavePreferences: (_) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('peer-jordan-ellis')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tap(tester, find.byKey(const ValueKey('edit-preferences')));
        await _tap(tester, find.byKey(const ValueKey('interest-Drawing')));
        await _tap(tester, find.byKey(const ValueKey('meetup-lunch')));
        await _tap(tester, find.byKey(const ValueKey('save-preferences')));
        expect(find.text('Your preferences'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
