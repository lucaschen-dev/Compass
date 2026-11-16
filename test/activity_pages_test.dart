import 'package:compass_flutter/src/activity_pages.dart';
import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/demo_activities.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/app_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsync prefs;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  testWidgets('home opens clubs directory, detail apply, and friends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final school = demoSchools.first;
    await seedSession(prefs, school);
    await boot(tester);

    expect(find.text('All clubs'), findsOneWidget);
    await tapVisible(tester, find.text('All clubs'));
    expect(find.text('Robotics Lab'), findsWidgets);

    await tapVisible(tester, find.text('Robotics Lab').first);
    expect(find.text('Apply to join'), findsOneWidget);
    expect(find.text('Jordan Ellis'), findsWidgets);

    await tapVisible(tester, find.text('Apply to join'));
    expect(find.text('Cancel application'), findsOneWidget);

    final friendButton = find.text('Add friend').first;
    await tapVisible(tester, friendButton);
    expect(find.text('Friends'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await boot(tester);
    await tapVisible(tester, find.text('All clubs'));
    await tapVisible(tester, find.text('Robotics Lab').first);
    expect(find.text('Cancel application'), findsOneWidget);
  });

  test('club applies stay separate by school in community storage', () async {
    final alderline = demoSchools.first;
    final cedarbrook = demoSchools.last;
    final alderlineAccount = LocalAccount(
      email: 'alex@${alderline.id}.example',
      name: 'Alex Chen',
      grade: 11,
      salt: 's',
      passwordHash: 'h',
    );
    final cedarbrookAccount = LocalAccount(
      email: 'alex@${cedarbrook.id}.example',
      name: 'Alex Chen',
      grade: 11,
      salt: 's',
      passwordHash: 'h',
    );
    var alderlineStored = '';
    var cedarbrookStored = '';
    final alderlineController = CommunityController(
      school: alderline,
      account: alderlineAccount,
      write: (value) async => alderlineStored = value,
    );
    final cedarbrookController = CommunityController(
      school: cedarbrook,
      account: cedarbrookAccount,
      write: (value) async => cedarbrookStored = value,
    );

    await alderlineController.toggleClubApply('robotics-lab');
    expect(alderlineController.clubApplies, contains('robotics-lab'));
    expect(cedarbrookController.clubApplies, isEmpty);

    final restoredCedarbrook = CommunityController(
      school: cedarbrook,
      account: cedarbrookAccount,
      write: (_) async {},
      saved: cedarbrookStored.isEmpty ? null : cedarbrookStored,
    );
    expect(restoredCedarbrook.clubApplies, isEmpty);

    final restoredAlderline = CommunityController(
      school: alderline,
      account: alderlineAccount,
      write: (_) async {},
      saved: alderlineStored,
    );
    expect(restoredAlderline.clubApplies, contains('robotics-lab'));
  });

  test('spotlight pick is stable per school', () {
    final alderline = spotlightActivity(alderlineClubs, 'alderline');
    expect(spotlightActivity(alderlineClubs, 'alderline').id, alderline.id);
    expect(
      spotlightActivity(cedarbrookClubs, 'cedarbrook').id,
      isNot(alderline.id),
    );
  });

  test('club apply persists through CommunityController encode', () async {
    final school = demoSchools.first;
    final account = LocalAccount(
      email: 'alex@${school.id}.example',
      name: 'Alex Chen',
      grade: 11,
      salt: 's',
      passwordHash: 'h',
    );
    var stored = '';
    final controller = CommunityController(
      school: school,
      account: account,
      write: (value) async => stored = value,
    );
    await controller.toggleClubApply('robotics-lab');
    expect(controller.clubApplies, contains('robotics-lab'));

    final restored = CommunityController(
      school: school,
      account: account,
      write: (_) async {},
      saved: stored,
    );
    expect(restored.clubApplies, contains('robotics-lab'));
  });
}
