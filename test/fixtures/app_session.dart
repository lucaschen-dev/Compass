import 'dart:convert';

import 'package:compass_flutter/main.dart' as app;
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/live_calendar_service.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> seedSession(
  SharedPreferencesAsync prefs,
  DemoSchool school, {
  bool selected = true,
}) async {
  final account = LocalAccount(
    email: 'alex@${school.id}.example',
    name: 'Alex Chen',
    grade: 11,
    salt: base64Encode(List.filled(16, 0)),
    passwordHash: base64Encode(List.filled(32, 0)),
  );
  await prefs.setString(
    accountStoreKey(school),
    jsonEncode([account.toJson()]),
  );
  await prefs.setString('compass.preview.${school.id}.session', account.email);
  await prefs.setBool(calendarPromptKey(school.id, account.email), true);
  await prefs.setString('compass.preview.theme', 'light');
  if (selected) {
    await prefs.setString('compass.preview.selectedSchool', school.id);
  }
}

Future<void> boot(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await app.main();
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> switchSchool(WidgetTester tester, String name) async {
  await tapVisible(tester, find.byTooltip('Personal center'));
  await tapVisible(tester, find.text('Settings'));
  await tapVisible(tester, find.textContaining('Alderline').first);
  await tapVisible(tester, find.text(name));
}

Future<void> destination(WidgetTester tester, String label) async {
  final nav = find.byType(CupertinoTabBar).evaluate().isNotEmpty
      ? find.byType(CupertinoTabBar)
      : find.byKey(const ValueKey('desktop-navigation'));
  await tapVisible(
    tester,
    find.descendant(of: nav, matching: find.text(label)),
  );
}
