import 'package:compass_flutter/main.dart' as app;
import 'package:compass_flutter/src/for_you_page.dart';
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
    'preferences and matches survive restart and stay separate by school',
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

      Future<void> forYou() => _tap(tester, find.text('For you').last);
      Future<void> switchSchool(String name) async {
        await _tap(tester, find.byTooltip('Switch school'));
        await _tap(tester, find.text(name));
        await forYou();
      }

      Future<void> restart() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await app.main();
        await tester.pumpAndSettle();
        await forYou();
      }

      Future<void> save() =>
          _tap(tester, find.byKey(const ValueKey('save-preferences')));
      final store = SharedPreferencesAsync();

      await app.main();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Find your school'));
      await _tap(tester, find.text('Alderline High School'));
      await forYou();
      expect(find.text('Choose what you enjoy'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('choose-preferences')));
      await _tap(tester, find.byKey(const ValueKey('interest-Robotics')));
      await _tap(tester, find.byKey(const ValueKey('interest-Drawing')));
      await save();
      expect(find.byKey(const ValueKey('peer-jordan-ellis')), findsOneWidget);
      expect(find.byKey(const ValueKey('peer-amara-brooks')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-robotics-lab')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('activity-sketchbook-circle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('activity-sketch-and-read')),
        findsOneWidget,
      );

      // Change both preference fields and verify recommendations really change.
      await _tap(tester, find.byKey(const ValueKey('edit-preferences')));
      await _tap(tester, find.byKey(const ValueKey('interest-Drawing')));
      await _tap(tester, find.byKey(const ValueKey('meetup-afterSchool')));
      await save();
      expect(find.byKey(const ValueKey('peer-amara-brooks')), findsNothing);
      expect(
        find.byKey(const ValueKey('activity-sketchbook-circle')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('activity-robotics-open-lab')),
        findsOneWidget,
      );
      final alderlineSaved = await store.getString(
        'compass.preview.alderline.preferences',
      );
      expect(
        StudentPreferences.fromStorage(
          alderlineSaved,
          demoSchools.first,
        ).interests,
        {'Robotics'},
      );

      // Closing the editor discards a draft without touching stored preferences.
      await _tap(tester, find.byKey(const ValueKey('edit-preferences')));
      await _tap(tester, find.byKey(const ValueKey('interest-Photography')));
      await _tap(tester, find.byTooltip('Close preferences'));
      expect(
        await store.getString('compass.preview.alderline.preferences'),
        alderlineSaved,
      );

      await switchSchool('Cedarbrook High School');
      expect(find.text('Choose what you enjoy'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('choose-preferences')));
      await _tap(tester, find.byKey(const ValueKey('interest-Theater')));
      await _tap(tester, find.byKey(const ValueKey('meetup-afterSchool')));
      await save();
      expect(find.byKey(const ValueKey('peer-noah-bennett')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-stage-crew')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-stage-open-house')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('peer-jordan-ellis')), findsNothing);
      expect(
        await store.getString('compass.preview.alderline.preferences'),
        alderlineSaved,
      );

      await switchSchool('Alderline High School');
      expect(find.byKey(const ValueKey('peer-jordan-ellis')), findsOneWidget);
      expect(find.byKey(const ValueKey('peer-noah-bennett')), findsNothing);
      await restart();
      expect(find.byKey(const ValueKey('peer-jordan-ellis')), findsOneWidget);
      expect(find.text('Meetups: After school'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('edit-preferences')));
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('interest-Robotics')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('meetup-afterSchool')),
            )
            .selected,
        isTrue,
      );
      await _tap(tester, find.byTooltip('Close preferences'));

      await switchSchool('Cedarbrook High School');
      expect(find.byKey(const ValueKey('peer-noah-bennett')), findsOneWidget);
      await restart();
      expect(find.byKey(const ValueKey('activity-stage-crew')), findsOneWidget);

      // An explicit reset is saved as empty and is not reseeded after refresh.
      await _tap(tester, find.byKey(const ValueKey('edit-preferences')));
      await _tap(tester, find.byKey(const ValueKey('reset-preferences')));
      await save();
      await restart();
      expect(find.text('Choose what you enjoy'), findsOneWidget);
      expect(find.byKey(const ValueKey('peer-noah-bennett')), findsNothing);
      await switchSchool('Alderline High School');
      expect(find.byKey(const ValueKey('peer-jordan-ellis')), findsOneWidget);
      expect(
        await store.getString('compass.preview.alderline.preferences'),
        alderlineSaved,
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
