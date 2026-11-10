import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/app_session.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 740),
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      testWidgets('new app surfaces ${brightness.name} at ${size.width}', (
        tester,
      ) async {
        final original = SharedPreferencesAsyncPlatform.instance;
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final prefs = SharedPreferencesAsync();
        await seedSession(prefs, demoSchools.first);
        await prefs.setString('compass.preview.theme', brightness.name);
        await boot(tester);
        expect(find.text('Anyone up for a match?'), findsOneWidget);
        await tapVisible(tester, find.text('For you'));
        await tapVisible(tester, find.byTooltip('Choose post topics'));
        await tapVisible(tester, find.text('Badminton'));
        await tapVisible(tester, find.text('Save topics'));
        expect(find.text('Anyone up for a match?'), findsOneWidget);
        expect(find.text('Where is the art studio?'), findsNothing);
        await destination(tester, 'Guide');
        await tapVisible(tester, find.text('Faculty & classrooms'));
        expect(find.text('Morgan Lee'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await destination(tester, 'Chat');
        await tapVisible(
          tester,
          find.text(
            demoSchools.first
                .classmate(demoSchools.first.conversations.first.personId)
                .name,
          ),
        );
        await tester.enterText(find.byType(TextField), 'A local test message');
        await tapVisible(tester, find.byTooltip('Send message'));
        expect(find.text('A local test message'), findsOneWidget);
        await tapVisible(tester, find.byTooltip('Message actions').first);
        await tapVisible(tester, find.text('Reply'));
        await tester.enterText(
          find.byType(TextField),
          'Reply in this conversation',
        );
        await tapVisible(tester, find.byTooltip('Send message'));
        expect(find.text('Reply in this conversation'), findsOneWidget);
        await tapVisible(tester, find.byTooltip('Message actions').first);
        await tapVisible(tester, find.text('Unsend'));
        expect(find.text('Message unsent'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await destination(tester, 'Courses');
        expect(find.text('Academics'), findsNothing);
        expect(find.text('English'), findsNothing);
        await tapVisible(tester, find.text('Week'));
        await tapVisible(tester, find.text('Day'));
        await tapVisible(tester, find.text('Month'));
        await tapVisible(tester, find.byTooltip('Personal center'));
        expect(find.text('Alex Chen'), findsOneWidget);
        await tapVisible(tester, find.text('Edit profile'));
        await tester.enterText(find.byType(TextField).first, 'Alex Updated');
        await tapVisible(tester, find.text('Save profile'));
        expect(find.text('Alex Updated'), findsOneWidget);
        await tapVisible(tester, find.text('Settings'));
        expect(find.text('Appearance'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
