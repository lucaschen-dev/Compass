import 'package:compass_flutter/main.dart' as app;
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/app_session.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  testWidgets('old selected-school data cannot bypass the new login gate', (
    tester,
  ) async {
    final p = SharedPreferencesAsync();
    await p.setString('compass.preview.selectedSchool', 'alderline');
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Find Your School'), findsOneWidget);
    expect(find.byType(CupertinoTabBar), findsNothing);
    await tapVisible(tester, find.text('Find Your School'));
    expect(
      tester.getTopLeft(find.text('Alderline')).dy,
      lessThan(tester.getTopLeft(find.text('Cedarbrook')).dy),
    );
    await tester.enterText(find.byType(TextField), 'cedar');
    await tester.pump();
    expect(find.text('Alderline'), findsNothing);
    expect(find.text('Cedarbrook'), findsOneWidget);
    await tapVisible(tester, find.text('Cedarbrook'));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('@cedarbrook.example'), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('First login'), findsOneWidget);
    await tapVisible(tester, find.text('First login'));
    await tester.enterText(find.byType(TextField), 'demo');
    await tapVisible(tester, find.text('Send setup email'));
    expect(
      find.text('Email service is not configured. No email has been sent.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'guide progress, school sessions and four-tab navigation survive restart',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final p = SharedPreferencesAsync();
      await seedSession(p, demoSchools.last, selected: false);
      await seedSession(p, demoSchools.first);
      await boot(tester);
      final nav = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
      expect(nav.items.map((i) => i.label), [
        'Home',
        'Guide',
        'Chat',
        'Courses',
      ]);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Anyone up for a match?'), findsOneWidget);
      await tapVisible(tester, find.text('Guide'));
      expect(find.text('Faculty & classrooms'), findsOneWidget);
      expect(find.text('Grade'), findsOneWidget);
      await tapVisible(tester, find.text('Dress code'));
      await tapVisible(tester, find.text('Mark as read').first);
      expect(
        await p.getBool(
          'compass.preview.alderline.culture.read.alderline-science-lab-attire',
        ),
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await switchSchool(tester, 'Cedarbrook');
      expect(find.text('Cedarbrook'), findsOneWidget);
      await boot(tester);
      expect(find.text('Cedarbrook'), findsOneWidget);
      expect(
        await p.getBool('compass.preview.cedarbrook.culture.read.lab-dress'),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
