import 'package:compass_flutter/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'default app opens local schools and restores their own progress',
    (tester) async {
      final originalPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = originalPreferences;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find your school'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alderline High School'));
      await tester.pumpAndSettle();
      expect(find.text('New student welcome tour'), findsOneWidget);

      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      final welcomeTour = find.byKey(
        const ValueKey('culture-toggle-alderline-welcome-tour'),
      );
      await tester.ensureVisible(welcomeTour);
      await tester.tap(welcomeTour);
      await tester.pumpAndSettle();
      expect(find.text('1 of 4 read'), findsOneWidget);

      await tester.tap(find.byTooltip('Switch school'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cedarbrook High School'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer student breakfast'), findsOneWidget);
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 3 read'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await app.main();
      await tester.pumpAndSettle();
      expect(find.text('Transfer student breakfast'), findsOneWidget);
      await tester.tap(find.byTooltip('Switch school'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alderline High School'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 4 read'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
