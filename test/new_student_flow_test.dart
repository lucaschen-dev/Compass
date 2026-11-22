import 'dart:convert';

import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/app_session.dart';

void main() {
  setUp(() {
    final original = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
  });

  testWidgets('First week opens resources and classmates stay account-scoped', (
    tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    final school = demoSchools.first;
    final classmate = school.classmates.firstWhere(
      (person) =>
          !school.conversations.any((chat) => chat.personId == person.id),
    );
    const first = LocalAccount(
      email: 'first@alderline.example',
      name: 'First Student',
      grade: 9,
    );
    const second = LocalAccount(
      email: 'second@alderline.example',
      name: 'Second Student',
      grade: 9,
    );
    final sessionKey = 'compass.preview.${school.id}.session';
    await prefs.setString(
      accountStoreKey(school),
      jsonEncode([first.toJson(), second.toJson()]),
    );
    await prefs.setString('compass.preview.selectedSchool', school.id);
    await prefs.setString(sessionKey, first.email);
    await boot(tester);

    await tapVisible(tester, find.text('First week'));
    await tapVisible(tester, find.text('Find an adviser or classroom'));
    expect(find.text('Morgan Lee'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Meet sample classmates'));
    await tester.enterText(find.byType(TextField), classmate.name);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(TextButton, 'Add friend'));
    expect(find.text('Added'), findsOneWidget);

    await prefs.setString(sessionKey, second.email);
    await boot(tester);
    await tapVisible(tester, find.text('First week'));
    await tapVisible(tester, find.text('Meet sample classmates'));
    await tester.enterText(find.byType(TextField), classmate.name);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Add friend'), findsOneWidget);
    expect(find.text('Added'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Privacy can unblock a demo chat without removing its history', (
    tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    final school = demoSchools.first;
    await seedSession(prefs, school);
    final accounts = LocalAccounts(
      prefs,
      school,
      await prefs.getString(accountStoreKey(school)),
    );
    final account = accounts.find('alex@${school.id}.example')!;
    final storageKey = communityStoreKey(school, account);
    final community = CommunityController(
      school: school,
      account: account,
      write: (_) async {},
    );
    final thread = community.threads.first;
    await community.updateThread(thread.copyWith(left: true));
    await prefs.setString(storageKey, community.encode());
    community.dispose();
    await boot(tester);

    await tapVisible(tester, find.byTooltip('Personal center'));
    await tapVisible(tester, find.text('Settings'));
    await tapVisible(tester, find.text('Privacy'));
    expect(find.text(thread.name), findsOneWidget);
    await tapVisible(tester, find.text('Unblock'));
    expect(find.text('No blocked demo chats.'), findsOneWidget);
    final saved = jsonDecode(
      (await prefs.getString(storageKey))!,
    ) as Map<String, dynamic>;
    final restored = ChatThread.fromJson(
      (saved['threads'] as List).first as Map<String, dynamic>,
    );
    expect(restored.left, isFalse);
    expect(
      restored.messages.map((m) => m.text),
      thread.messages.map((m) => m.text),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
